#!/usr/bin/env bash
#
# progress.sh — 進捗の機械集計と鮮度検査（利用者プロジェクトの Fitness Function）。
#
# 進捗の真実は docs/backlog.md（機能単位の全体俯瞰）と .steering/*/tasklist.md
# （振る舞い単位の3値チェックボックス）に分散して記録されている。本スクリプトは
# それを横断集計し、あわせて両者の乖離を機械検出する。手書きの進捗表は必ず腐るが、
# 真実から導出された進捗は腐らない（CLAUDE.md「描写の鮮度は機械で守る」）。
#
#   1. docs/backlog.md の機能単位の状態集計（完了/実装中/未着手）
#   2. .steering/*/tasklist.md ごとのタスク集計と総計
#   3. 鮮度検査: backlog で完了[x]なのに tasklist に未完了が残る → ❌（非ゼロ終了）
#              steering ディレクトリが backlog に未登録 → ⚠️（警告のみ）
#   4. --since YYYY-MM-DD: git 履歴から期間内に [x] 化した振る舞いを抽出
#
# 使い方:  bash scripts/progress.sh [--since YYYY-MM-DD]

set -euo pipefail

# リポジトリルートへ移動（scripts/ の1つ上）
cd "$(dirname "$0")/.."

since=""
if [ "${1:-}" = "--since" ]; then
  since="${2:?--since には日付（YYYY-MM-DD）を指定してください}"
fi

fail=0
warned=0
err()  { printf '  ❌ %s\n' "$1"; fail=1; }
warn() { printf '  ⚠️  %s\n' "$1"; warned=1; }

# チェックボックス行を数える（grep -c は0件時に非ゼロ終了するため || true）
count() { grep -cE "$1" "$2" 2>/dev/null || true; }

# 集計対象がまだ無いプロジェクト（テンプレート直後など）では正常終了する
if ! compgen -G '.steering/*/tasklist.md' >/dev/null && [ ! -f docs/backlog.md ]; then
  echo "集計対象がまだありません（docs/backlog.md も .steering/*/tasklist.md も未作成）"
  echo "→ /setup-project でバックログを種まきし、/add-feature で作業を始めると集計できます"
  exit 0
fi

# ── 1. 全体俯瞰（機能単位） ──────────────────────────────────────────
if [ -f docs/backlog.md ]; then
  echo "==> 全体俯瞰（docs/backlog.md / 機能単位）"
  awk -F'|' '
    $5 ~ /\[x\]/ { done++ }
    $5 ~ /\[-\]/ { doing++ }
    $5 ~ /\[ \]/ { todo++ }
    END {
      printf "  機能: 完了 %d ／ 実装中 %d ／ 未着手 %d（全 %d 機能）\n",
             done, doing, todo, done + doing + todo
    }
  ' docs/backlog.md
  echo
fi

# ── 2. 作業単位の進捗（振る舞い単位） ────────────────────────────────
if compgen -G '.steering/*/tasklist.md' >/dev/null; then
  echo "==> 作業単位の進捗（.steering/*/tasklist.md / 振る舞い単位）"
  printf '  %s\n' '| steering | 完了 | 実装中 | 未着手 | 進捗 |'
  printf '  %s\n' '|----------|-----:|-------:|-------:|-----:|'
  tx=0; tp=0; to=0
  for f in .steering/*/tasklist.md; do
    d=$(basename "$(dirname "$f")")
    x=$(count '^[[:space:]]*- \[x\]' "$f")
    p=$(count '^[[:space:]]*- \[-\]' "$f")
    o=$(count '^[[:space:]]*- \[ \]' "$f")
    t=$((x + p + o)); pct=0
    if [ "$t" -gt 0 ]; then pct=$((x * 100 / t)); fi
    printf '  | %s | %d | %d | %d | %d%% |\n' "$d" "$x" "$p" "$o" "$pct"
    tx=$((tx + x)); tp=$((tp + p)); to=$((to + o))
  done
  tt=$((tx + tp + to)); tpct=0
  if [ "$tt" -gt 0 ]; then tpct=$((tx * 100 / tt)); fi
  printf '  | %s | %d | %d | %d | %d%% |\n' "**総計**" "$tx" "$tp" "$to" "$tpct"
  echo
fi

# ── 3. 鮮度検査（backlog ⇔ tasklist の乖離） ─────────────────────────
if [ -f docs/backlog.md ]; then
  echo "==> 鮮度検査（backlog ⇔ tasklist の乖離）"

  # backlog で完了[x]の行の steering 先に、未完了タスクが残っていないか
  while IFS= read -r link; do
    tl=".steering/${link}/tasklist.md"
    if [ -f "$tl" ] && grep -qE '^[[:space:]]*- \[( |-)\]' "$tl"; then
      err "backlog では完了ですが ${tl} に未完了タスクが残っています"
    fi
  done < <(awk -F'|' '$5 ~ /\[x\]/ { gsub(/[[:space:]]/, "", $6); if ($6 != "" && $6 != "-") print $6 }' docs/backlog.md)

  # steering ディレクトリが backlog に登録されているか（全体俯瞰からの漏れ）
  for f in .steering/*/tasklist.md; do
    [ -f "$f" ] || continue
    d=$(basename "$(dirname "$f")")
    if ! grep -q "$d" docs/backlog.md; then
      warn "${d} が docs/backlog.md に登録されていません（全体俯瞰から漏れています）"
    fi
  done

  if [ "$fail" -eq 0 ] && [ "$warned" -eq 0 ]; then
    echo "  ✅ 乖離なし"
  fi
  echo
fi

# ── 4. 期間内に完了した振る舞い（git 履歴から導出） ──────────────────
if [ -n "$since" ]; then
  echo "==> ${since} 以降に完了した振る舞い（git 履歴から導出）"
  completed=$(git log --since="$since" -p -- '.steering/*/tasklist.md' 2>/dev/null \
                | grep -E '^\+[[:space:]]*- \[x\]' \
                | sed -E 's/^\+[[:space:]]*- \[x\][[:space:]]*/  ✅ /' \
                | sort -u || true)
  if [ -n "$completed" ]; then
    printf '%s\n' "$completed"
  else
    echo "  （該当なし。tasklist の [x] 化がコミットされているか確認してください）"
  fi
  echo
fi

if [ "$fail" -ne 0 ]; then
  echo "RESULT: ❌ 進捗記録に乖離があります（修正してから報告してください）"
  exit 1
fi
echo "RESULT: ✅ 進捗記録は一貫しています"
