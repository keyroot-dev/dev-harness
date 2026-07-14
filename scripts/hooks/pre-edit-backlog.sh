#!/usr/bin/env bash
#
# pre-edit-backlog.sh — PreToolUse(Edit|Write) フック。
#
# `docs/backlog.md` の状態列（`[ ]`/`[-]`/`[x]`）は「描写」であり、正規の更新経路は
# `scripts/backlog-state.sh` のみ（.claude/rules/docs-hygiene.md）。Edit/Write による
# 状態マーカーの書き換えをここでブロックし、文書規律を機械的に強制する。
#
# 判定: 編集前後の状態マーカー列を比較する。
#   - マーカー列が同一            → 許可（状態に触れない編集）
#   - 一方が他方の前方一致（追加/削除）→ 許可（行の追加・削除は意図の変更として別規律が守る）
#   - それ以外（マーカー値の変更）   → ブロック（exit 2）
#
# stdin: Claude Code のフック入力 JSON（tool_name / tool_input）

set -euo pipefail

input="$(cat)"

# jq が無い環境ではガードを効かせられない（fail-open）。警告だけ出して許可する。
command -v jq >/dev/null 2>&1 || {
  echo "⚠️  jq が見つからないため backlog 状態列ガードをスキップしました（devcontainer には同梱）" >&2
  exit 0
}

file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
case "$file" in
  */docs/backlog.md|docs/backlog.md) ;;
  *) exit 0 ;;
esac

tool="$(jq -r '.tool_name // empty' <<<"$input")"

# 文字列中の状態マーカー列を抽出する
markers() { printf '%s' "$1" | grep -oE '\[( |x|-)\]' | tr '\n' ' ' || true; }

case "$tool" in
  Edit)
    old="$(jq -r '.tool_input.old_string // ""' <<<"$input")"
    new="$(jq -r '.tool_input.new_string // ""' <<<"$input")"
    ;;
  Write)
    new="$(jq -r '.tool_input.content // ""' <<<"$input")"
    if [ -f "$file" ]; then old="$(cat "$file")"; else old=""; fi
    ;;
  *) exit 0 ;;
esac

om="$(markers "$old")"
nm="$(markers "$new")"

[ "$om" = "$nm" ] && exit 0
case "$nm" in "$om"*) exit 0 ;; esac
case "$om" in "$nm"*) exit 0 ;; esac

cat >&2 <<'EOF'
❌ docs/backlog.md の状態列を Edit/Write で直接変更することは禁止されています
   （.claude/rules/docs-hygiene.md「docs/ 編集時のガード」）。
   状態の更新は必ず正規経路を使ってください:
     bash scripts/backlog-state.sh start <機能名> <steering名>   # 着手: [-] 実装中
     bash scripts/backlog-state.sh done  <機能名>                # 完了: [x] 完了
EOF
exit 2
