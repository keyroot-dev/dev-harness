#!/usr/bin/env bash
#
# stop-freshness.sh — Stop フック。
#
# 応答を終える前に `scripts/progress.sh` の鮮度検査（backlog ⇔ tasklist の乖離）を確認する。
# 乖離（❌）があれば一度だけ exit 2 で停止を差し戻し、修正を促す。
# 無限ループ防止: stop_hook_active（このフックによる継続中）なら必ず許可する。
# ⚠️（警告）は停止を妨げない。
#
# stdin: Claude Code のフック入力 JSON（stop_hook_active を参照）

set -euo pipefail

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$root"

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0

# このフックが差し戻した継続中なら、二度目は止めない（無限ループ防止）
[ "$(jq -r '.stop_hook_active // false' <<<"$input")" = "true" ] && exit 0

# 集計対象が無ければ何もしない（テンプレート直後）
[ -f docs/backlog.md ] || exit 0

if ! out="$(bash scripts/progress.sh 2>&1)"; then
  {
    printf '%s\n' "$out"
    echo
    echo "→ 進捗記録に乖離があります。backlog の状態（scripts/backlog-state.sh）または tasklist を実態に合わせてから完了してください。"
  } >&2
  exit 2
fi
exit 0
