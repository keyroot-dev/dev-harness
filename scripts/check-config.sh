#!/usr/bin/env bash
#
# check-config.sh — この設定リポジトリ自身の Fitness Function。
#
# このテンプレートは利用者のプロジェクトに対して「アーキテクチャ境界を文書の
# 『禁止』で終わらせず Lint/CI で機械強制せよ」と説いている。であれば、設定
# 自身の不変条件も機械的に守るべきだ。本スクリプトは以下を検査する:
#
#   1. .claude/skills/<name>/ には必ず SKILL.md がある
#   2. どこかで参照される Skill(<name>) は実在するスキルである
#   3. settings.json の allow に並ぶ Skill(<name>) は実在するスキルである
#   4. subagent_type で指名されるエージェントは .claude/agents/<name>.md として実在する
#   5. .claude 配下・CLAUDE.md・README.md から相対参照される .md ファイルが実在する
#      （「正本」参照の網はファイル間リンクで編まれている。リネームによる静かな断線を防ぐ）
#   6. .claude 配下（rules / skills / agents）のフロントマターが正しい（閉じた --- / 許可キーのみ）
#      （不正なフロントマターは本文としてコンテキストに混入し、静かにルールが壊れる）
#   7. `path/to.md`「見出し」形式で参照される見出しが参照先に実在する
#      （ファイルパスの実在は 5 が守るが、見出しのリネームはそれだけでは検出できない）
#
# 違反が1件でもあれば非ゼロ終了する（CI で落とせる）。
#
# 使い方:  bash scripts/check-config.sh

set -euo pipefail

# リポジトリルートへ移動（scripts/ の1つ上）
cd "$(dirname "$0")/.."

fail=0
err() { printf '  ❌ %s\n' "$1"; fail=1; }

# フロントマター検査（[6] で使用）。
#   $1=対象ファイル  $2=許可キーの正規表現（例: "paths"）  $3=フロントマター必須なら yes
# CRLF で保存されたファイルでも検査が働くよう、比較の前に必ず \r を除去する。
check_frontmatter() {
  local file="$1" allowed="$2" required="$3" end
  if [ "$(head -n1 "$file" | tr -d '\r')" != "---" ]; then
    [ "$required" = "yes" ] && err "${file} にフロントマター（--- で始まるブロック）がありません"
    return 0
  fi
  # 2行目以降で最初に現れる --- がフロントマターの閉じ
  # （|| true: set -e/pipefail 下では grep の不一致=exit 1 がスクリプトを殺すため）
  end=$(tail -n +2 "$file" | tr -d '\r' | grep -n '^---$' | head -n1 | cut -d: -f1 || true)
  if [ -z "$end" ]; then
    err "${file} のフロントマターが閉じていません（--- がありません）"
    return 0
  fi
  # 空のフロントマター: 検査するキーがない（BSD の head は -n 0 を受け付けない）
  [ "$end" -le 1 ] && return 0
  # トップレベルキーは許可リストのみ（リスト項目・空行は除外）
  while IFS= read -r key; do
    printf '%s\n' "$key" | grep -qE "^(${allowed})$" \
      || err "${file} のフロントマターに未知のキー『${key}』があります（許可: ${allowed}）"
  done < <(tail -n +2 "$file" | tr -d '\r' | head -n "$((end - 1))" \
            | grep -E '^[A-Za-z0-9_-]+:' | sed -E 's/^([A-Za-z0-9_-]+):.*/\1/')
  return 0
}

# 注: `cmd | while ...` はパイプ右辺がサブシェルになり、ループ内の fail 代入が
#     親シェルへ伝わらない。そのため全ループをプロセス置換 `< <(...)` で回し、
#     fail を確実に親シェルへ反映させる。

echo "==> [1/7] 各スキルに SKILL.md が存在するか"
for dir in .claude/skills/*/; do
  [ -d "$dir" ] || continue
  [ -f "${dir}SKILL.md" ] || err "${dir} に SKILL.md がありません"
done

echo "==> [2/7] 参照される Skill(<name>) が実在するか（.md / .json 全体）"
while IFS= read -r name; do
  [ -z "$name" ] && continue
  [ -d ".claude/skills/${name}" ] \
    || err "Skill('${name}') が参照されていますが .claude/skills/${name}/ が存在しません"
done < <(grep -rhoE "Skill\(['\"]?[a-z0-9-]+['\"]?\)" .claude 2>/dev/null \
          | sed -E "s/Skill\(['\"]?([a-z0-9-]+)['\"]?\)/\1/" | sort -u)

echo "==> [3/7] subagent_type で指名されるエージェントが実在するか"
while IFS= read -r name; do
  [ -z "$name" ] && continue
  [ -f ".claude/agents/${name}.md" ] \
    || err "subagent_type \"${name}\" が指名されていますが .claude/agents/${name}.md が存在しません"
done < <(grep -rhoE "subagent_type[^\"']{0,4}[\"'][a-z0-9-]+[\"']" .claude 2>/dev/null \
          | sed -E "s/.*[\"']([a-z0-9-]+)[\"']$/\1/" | sort -u)

echo "==> [4/7] settings.json の allow するスキルが実在するか"
if [ -f .claude/settings.json ]; then
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    [ -d ".claude/skills/${name}" ] \
      || err "settings.json が Skill(${name}) を許可していますが該当スキルが存在しません"
  done < <(grep -oE "Skill\([a-z0-9-]+\)" .claude/settings.json 2>/dev/null \
            | sed -E "s/Skill\(([a-z0-9-]+)\)/\1/" | sort -u)
fi

echo "==> [5/7] 参照される .md への相対パスが実在するか"
# 対象: スラッシュを含む .md 参照（`./guide.md` `guides/process.md` `.claude/...` 等）。
# docs/ と .steering/ は利用者プロジェクトで生成されるプレースホルダーなので対象外。
# 解決は「参照元ファイルのディレクトリ → リポジトリルート → .claude/skills/」の順で試す。
while IFS=: read -r file ref; do
  [ -z "$ref" ] && continue
  case "$ref" in
    /*|docs/*|.steering/*) continue ;;
    # 正式版ドキュメント6種は利用者プロジェクトで生成される成果物（テンプレートには存在しない）。
    # ガイド内の「生成物からの相対リンク例」（./architecture.md 等）はこのため対象外。
    *product-requirements.md|*functional-design.md|*architecture.md|*repository-structure.md|*development-guidelines.md|*glossary.md) continue ;;
  esac
  base="$(dirname "$file")"
  if [ -f "$ref" ] || [ -f "${base}/${ref}" ] || [ -f ".claude/skills/${ref}" ]; then
    continue
  fi
  err "${file} が『${ref}』を参照していますが、ファイルとして解決できません"
done < <(grep -roE "[A-Za-z0-9_.-]*(/[A-Za-z0-9_.-]+)+\.md" .claude CLAUDE.md README.md 2>/dev/null | sort -u)

echo "==> [6/7] .claude 配下のフロントマターが正しいか（rules / skills / agents）"
# フロントマターは Claude Code が解釈する。--- が閉じていない・未知のキーがある場合、
# 本文としてコンテキストに混入したり、意図したスコープ・ツール制限が効かない（静かな破損）。
# 許可リスト方式（タイポを未知キーとして検出する）。新しいキーを採用したらここに追記する。
while IFS= read -r f; do
  [ -z "$f" ] && continue
  check_frontmatter "$f" "paths" no
done < <(find .claude/rules -name '*.md' -type f 2>/dev/null | sort)
while IFS= read -r f; do
  [ -z "$f" ] && continue
  check_frontmatter "$f" "name|description|argument-hint|user-invocable|disable-model-invocation|allowed-tools|model" yes
done < <(find .claude/skills -name 'SKILL.md' -type f 2>/dev/null | sort)
while IFS= read -r f; do
  [ -z "$f" ] && continue
  check_frontmatter "$f" "name|description|tools|model|color" yes
done < <(find .claude/agents -name '*.md' -type f 2>/dev/null | sort)

echo "==> [7/7] 参照される「見出し」が参照先に実在するか"
# 対象: `path/to.md`「見出し」形式の正本参照。パスの解決規則は [5] と同じで、
# 解決できない参照（利用者プロジェクトで生成される成果物等）は [5] に委ねる。
# 照合は見出しの「（」より前を、参照先の見出し行（#）への部分一致で確認する
# （例:「承認ゲートの方針（正本）」→「承認ゲートの方針」を含む見出しがあれば OK）。
while IFS=: read -r file match; do
  [ -z "$match" ] && continue
  ref="${match#\`}"; ref="${ref%%\`*}"
  heading="${match#*「}"; heading="${heading%」}"
  case "$ref" in /*|docs/*|.steering/*) continue ;; esac
  base="$(dirname "$file")"
  target=""
  for cand in "$ref" "${base}/${ref}" ".claude/skills/${ref}"; do
    if [ -f "$cand" ]; then target="$cand"; break; fi
  done
  [ -z "$target" ] && continue
  key="${heading%%（*}"
  [ -z "$key" ] && key="$heading"
  grep -E '^#{1,6} ' "$target" | grep -F "$key" >/dev/null \
    || err "${file} が『${ref}』の見出し「${heading}」を参照していますが、該当する見出しがありません"
done < <(grep -roE "\`[A-Za-z0-9_.-]*(/[A-Za-z0-9_.-]+)+\.md\`「[^」]+」" .claude CLAUDE.md README.md 2>/dev/null | sort -u)

echo
if [ "$fail" -ne 0 ]; then
  echo "RESULT: ❌ 設定の不変条件に違反があります（上記を修正してください）"
  exit 1
fi
echo "RESULT: ✅ 設定の整合性チェックをパスしました"
