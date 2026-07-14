#!/usr/bin/env bash
#
# post-edit-docs.sh — PostToolUse(Edit|Write) フック。
#
# `docs/` 配下の描写ドキュメントが編集されたら、その場で
# `scripts/check-drift.sh --quick`（描写⇔実コードの機械検査）を実行する。
# 「詳細な嘘」（実在しないパスの記載）を書いた瞬間に検出し、context poisoning の芽を摘む。
# 違反があれば exit 2 で Claude にフィードバックする。
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
  docs/*) ;;
  *) exit 0 ;;
esac

if ! out="$(bash scripts/check-drift.sh --quick "$rel" 2>&1)"; then
  {
    printf '%s\n' "$out"
    echo
    echo "→ 直前の編集（${rel}）に「詳細な嘘」があります。修正するのはドキュメント側です（真実の源はコード）。"
  } >&2
  exit 2
fi
exit 0
