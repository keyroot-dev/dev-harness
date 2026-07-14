#!/usr/bin/env bash
#
# post-edit-config.sh — PostToolUse(Edit|Write) フック。
#
# `.claude/`・`scripts/`・`CLAUDE.md`・`README.md` が編集されたら、その場で
# `scripts/check-config.sh`（設定リポジトリ自身の Fitness Function）を実行する。
# 設定・参照網の破壊を「編集した瞬間」に検出し、CI まで持ち越さない。
# 違反があれば exit 2 で Claude にフィードバックする（編集自体は済んでいるため、修正を促す）。
#
# stdin: Claude Code のフック入力 JSON（tool_input.file_path を参照）

set -euo pipefail

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$root"

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0

file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
[ -z "$file" ] && exit 0
rel="${file#"$root"/}"

case "$rel" in
  .claude/*|scripts/*|CLAUDE.md|README.md) ;;
  *) exit 0 ;;
esac

if ! out="$(bash scripts/check-config.sh 2>&1)"; then
  {
    printf '%s\n' "$out"
    echo
    echo "→ 直前の編集（${rel}）が設定の不変条件を壊しています。上記の ❌ を修正してください。"
  } >&2
  exit 2
fi
exit 0
