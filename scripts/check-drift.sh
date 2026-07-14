#!/usr/bin/env bash
#
# check-drift.sh — 描写ドキュメント⇔実コードの機械検査（利用者プロジェクトの Fitness Function）。
#
# 「描写の鮮度は機械で守る」（.claude/rules/document-management.md）の実体。
# 描写ドキュメントの主張のうち**決定論的に検証できるもの**（パスの実在）をここで検査し、
# LLM でしか判定できない意味的な乖離だけを drift-auditor サブエージェントに残す。
# 判定の非対称性は drift-auditor と同じ: ドキュメントに在ってコードに無い＝「詳細な嘘」で ❌。
#
#   1. docs/repository-structure.md — ツリー記法（├──/└──）と `バックティック内パス` の実在 → ❌
#   2. docs/functional-design.md    — `バックティック内パス` の実在 → ❌
#   3. docs/development-guidelines.md — `バックティック内パス` の実在 → ⚠️（設定例・雛形を含むため警告どまり）
#   4. docs/glossary.md             — `バックティック内の識別子` がコード上に生きているか → ⚠️
#
# プレースホルダー（[名前]・{名前}・グロブ・…）を含む記述は検査対象外（テンプレート・例示のため）。
# 違反（❌）が1件でもあれば非ゼロ終了する（CI・hooks で落とせる）。
#
# 使い方:  bash scripts/check-drift.sh                  # 全描写ドキュメントを検査
#          bash scripts/check-drift.sh --quick <file>   # 指定ファイルに関する検査のみ（hooks 用）

set -euo pipefail

# リポジトリルートへ移動（scripts/ の1つ上）
cd "$(dirname "$0")/.."

quick=""
if [ "${1:-}" = "--quick" ]; then
  quick="${2:?--quick には対象ファイルのパスを指定してください}"
  # リポジトリルート相対に正規化
  quick="${quick#"$PWD"/}"
fi

fail=0
warned=0
err()  { printf '  ❌ %s\n' "$1"; fail=1; }
warn() { printf '  ⚠️  %s\n' "$1"; warned=1; }

# 対象ドキュメントを検査すべきか（--quick 指定時はそのファイルのみ）
target() {
  [ -f "$1" ] || return 1
  [ -z "$quick" ] || [ "$quick" = "$1" ]
}

# 検査対象がまだ無いプロジェクト（テンプレート直後など）では正常終了する
if [ ! -f docs/repository-structure.md ] && [ ! -f docs/functional-design.md ] \
   && [ ! -f docs/development-guidelines.md ] && [ ! -f docs/glossary.md ]; then
  echo "検査対象がまだありません（描写ドキュメントが未生成です）"
  echo "→ /setup-project の Walking Skeleton 後に生成されると検査できます"
  exit 0
fi

# ── パス候補のフィルタ ───────────────────────────────────────────────
# プレースホルダー・グロブ・URL・例示を除外し、リポジトリ相対の実パス候補だけ通す。
is_checkable_path() {
  case "$1" in
    *'['*|*'{'*|*'<'*|*'*'*|*'('*|*'$'*|*'…'*|*'...'*|*' '*) return 1 ;;
    http*|/*|~*|-*|../*) return 1 ;;
    */*) return 0 ;;
    *) return 1 ;;  # スラッシュを含まない語（コマンド名等）は対象外
  esac
}

# パスの実在検査（末尾 / はディレクトリとして検査）
path_exists() {
  case "$1" in
    */) [ -d "$1" ] ;;
    *)  [ -e "$1" ] ;;
  esac
}

# `バックティック` 内のパス候補を抽出する
extract_backtick_paths() {
  grep -oE '`[^`]+`' "$1" 2>/dev/null | sed -e 's/^`//' -e 's/`$//' -e 's/#.*$//' | sort -u || true
}

# ── 1. repository-structure.md: ツリー記法の実在検査 ─────────────────
if target docs/repository-structure.md; then
  echo "==> 描写検査: docs/repository-structure.md（構造の実在）"

  # ツリー記法を ASCII に正規化（├└─│ はマルチバイトで、awk 実装によって
  # 文字数の数え方が変わる。sed の文字列置換でバイト依存を消してから深さを計算する）。
  # 1レベル = 4文字（"|   " または "    "）。マーカー行以外（ルート行等）は base として記憶し、
  # 「base + パス」「パスそのまま」のどちらかで解決できれば実在とみなす。
  while IFS= read -r line; do
    rel="${line#*$'\t'}"
    base="${line%%$'\t'*}"
    is_checkable_path "$rel" || continue
    if path_exists "$rel" || { [ -n "$base" ] && path_exists "${base}${rel}"; }; then
      continue
    fi
    err "docs/repository-structure.md がツリーに『${base}${rel}』を記載していますが、実在しません（詳細な嘘）"
  done < <(
    sed -e 's/├/+/g; s/└/+/g; s/│/|/g; s/─/-/g' docs/repository-structure.md \
    | awk '
      /^(```|~~~)/ { infence = !infence; depth_reset(); next }
      function depth_reset() { for (d in stack) delete stack[d]; base = "" }
      {
        if (!infence) next
        if (match($0, /\+-- /)) {
          depth = (RSTART - 1) / 4
          name = substr($0, RSTART + 4)
          sub(/[ \t]*#.*$/, "", name)   # 行内コメントを除去
          sub(/[ \t]+$/, "", name)
          if (name == "") next
          stack[depth] = name
          for (d in stack) if (d + 0 > depth) delete stack[d]
          path = ""
          for (d = 0; d <= depth; d++) {
            if (!(d in stack)) { path = ""; break }
            path = path stack[d]
            if (d < depth && path !~ /\/$/) path = path "/"
          }
          if (path != "") printf "%s\t%s\n", base, path
        } else if ($0 ~ /^[A-Za-z0-9_.\/-]+\/[ \t]*$/) {
          # フェンス内のマーカー無し行（例: ".claude/" や "project-root/"）はツリーの基点
          base = $0
          sub(/[ \t]+$/, "", base)
        }
      }
    '
  )

  # バックティック内のパスも実在を検査する
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    is_checkable_path "$p" || continue
    path_exists "$p" \
      || err "docs/repository-structure.md が『${p}』を記載していますが、実在しません（詳細な嘘）"
  done < <(extract_backtick_paths docs/repository-structure.md)
  echo
fi

# ── 2. functional-design.md: 参照パスの実在検査 ──────────────────────
if target docs/functional-design.md; then
  echo "==> 描写検査: docs/functional-design.md（参照パスの実在）"
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    is_checkable_path "$p" || continue
    path_exists "$p" \
      || err "docs/functional-design.md が『${p}』を参照していますが、実在しません（詳細な嘘）"
  done < <(extract_backtick_paths docs/functional-design.md)
  echo
fi

# ── 3. development-guidelines.md: 参照パスの実在検査（警告） ─────────
if target docs/development-guidelines.md; then
  echo "==> 描写検査: docs/development-guidelines.md（参照パスの実在 / 警告）"
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    is_checkable_path "$p" || continue
    path_exists "$p" \
      || warn "docs/development-guidelines.md が『${p}』を参照していますが、実在しません（設定例なら無視可）"
  done < <(extract_backtick_paths docs/development-guidelines.md)
  echo
fi

# ── 4. glossary.md: 用語の生存性検査（警告） ─────────────────────────
if target docs/glossary.md; then
  echo "==> 描写検査: docs/glossary.md（用語がコード上に生きているか / 警告）"
  # バックティック内の識別子（クラス名・関数名・フィールド名等）が、
  # ドキュメント類を除くリポジトリのどこかに登場するかを確認する。
  while IFS= read -r term; do
    [ -z "$term" ] && continue
    if ! grep -rqF "$term" . \
         --exclude-dir=docs --exclude-dir=.git --exclude-dir=.steering \
         --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.serena \
         --exclude-dir=.claude 2>/dev/null; then
      warn "docs/glossary.md の識別子『${term}』がコード上に見つかりません（リネーム済みなら用語集を更新）"
    fi
  done < <(grep -oE '`[A-Za-z][A-Za-z0-9_]{2,}`' docs/glossary.md 2>/dev/null \
            | sed -e 's/`//g' | sort -u || true)
  echo
fi

if [ "$fail" -ne 0 ]; then
  echo "RESULT: ❌ 描写ドキュメントに「詳細な嘘」があります（修正するのはドキュメント側です）"
  exit 1
fi
if [ "$warned" -ne 0 ]; then
  echo "RESULT: ✅ 嘘は検出されませんでした（⚠️ の鮮度低下は確認を推奨）"
  exit 0
fi
echo "RESULT: ✅ 描写ドキュメントの機械検査をパスしました"
