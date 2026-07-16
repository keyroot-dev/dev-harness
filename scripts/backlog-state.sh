#!/usr/bin/env bash
#
# backlog-state.sh — docs/backlog.md の状態列（描写）の正規更新経路。
#
# backlog の行と優先度は「意図」（人が舵を握る）、状態列だけは「描写」であり
# `/add-feature` が機械更新する（.claude/rules/document-management.md）。
# 状態列を Edit で手動更新することは hooks（scripts/hooks/pre-edit-backlog.sh）が
# ブロックするため、状態の変更は必ずこのスクリプトを通す。
#
# 使い方:
#   bash scripts/backlog-state.sh start <機能名> <steering名>   # 着手: [-] 実装中 + steering 列記入
#                                                               # 該当行が無ければ行を追加（スコープ追加）
#   bash scripts/backlog-state.sh done  <機能名>                # 完了: [x] 完了
#   bash scripts/backlog-state.sh split <機能名> <今回の縦切り名> <残りの縦切り名>...
#                                        # 機能分割: 該当行を今回の縦切り名に改名し、残りの縦切りを
#                                        # [ ] 未着手 で直下に行追加（依存列は直前の縦切りに連鎖）
#
# <機能名> は backlog の「機能」列に部分一致で照合する（複数行に一致したらエラー）。

set -euo pipefail

# リポジトリルートへ移動（scripts/ の1つ上）
cd "$(dirname "$0")/.."

cmd="${1:?使い方: backlog-state.sh <start|done|split> <機能名> [引数...]}"
feature="${2:?機能名を指定してください}"
steering="${3:-}"

[ -f docs/backlog.md ] || { echo "❌ docs/backlog.md がありません（/setup-project で種まきしてください）"; exit 1; }

case "$cmd" in
  start) [ -n "$steering" ] || { echo "❌ start には steering 名（[YYYYMMDD]-[機能名]）が必要です"; exit 1; } ;;
  done)  ;;
  split)
    newname="${3:-}"
    [ -n "$newname" ] || { echo "❌ split には今回の縦切り名が必要です"; exit 1; }
    shift 3
    [ "$#" -ge 1 ] || { echo "❌ split には残りの縦切り名が1つ以上必要です"; exit 1; }
    ;;
  *) echo "❌ 不明なコマンド: ${cmd}（start | done | split）"; exit 1 ;;
esac

# 「機能」列（$3）に部分一致し、状態列（$6）にマーカーを持つデータ行を数える
# （列構成の正本: .claude/skills/progress-report/templates/backlog.md — | # | 機能 | 優先度 | 依存 | 状態 | steering |）
matched="$(awk -F'|' -v f="$feature" 'index($3, f) && $6 ~ /\[/ { c++ } END { print c + 0 }' docs/backlog.md)"

if [ "$matched" -gt 1 ]; then
  echo "❌ 機能名『${feature}』が backlog の複数行に一致します。一意になる名前を指定してください"
  exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

if [ "$matched" -eq 0 ]; then
  if [ "$cmd" = "start" ]; then
    # バックログ外の着手＝スコープ追加。行を追加する（完了報告で明示する運用は
    # backlog テンプレートの「運用ルール」に従う）。表の最終行の直後に挿入する。
    n="$(awk -F'|' '$2 ~ /^[ \t]*[0-9]+[ \t]*$/ { if ($2 + 0 > m) m = $2 + 0 } END { print m + 1 }' docs/backlog.md)"
    awk -v row="| ${n} | ${feature} | 中 | - | [-] 実装中 | ${steering} |" '
      /^\|/ { last = NR }
      { lines[NR] = $0 }
      END {
        for (i = 1; i <= NR; i++) {
          print lines[i]
          if (i == last) print row
        }
      }
    ' docs/backlog.md > "$tmp" && mv "$tmp" docs/backlog.md
    echo "➕ backlog に行を追加し着手を記録: ${feature} → [-] 実装中（${steering}）※スコープ追加"
    exit 0
  fi
  echo "❌ 機能『${feature}』の行が backlog に見つかりません"
  exit 1
fi

if [ "$cmd" = "split" ]; then
  # 機能分割: 該当行（実装中の機能）を今回の縦切り名に改名し、残りの縦切りを
  # [ ] 未着手 で直下に追加する。優先度は元の行を引き継ぎ、依存列は直前の
  # 縦切りに連鎖させる（縦切り同士は同じファイルを触るため並列にしない）。
  # 行の追加は意図の領域なので、呼び出し側（/add-feature）が完了報告で明示する。
  n="$(awk -F'|' '$2 ~ /^[ \t]*[0-9]+[ \t]*$/ { if ($2 + 0 > m) m = $2 + 0 } END { print m + 1 }' docs/backlog.md)"
  # 残りの縦切りリストは改行区切りの環境変数で渡す（BSD awk は -v 値内の改行を許さない）
  REST_SLICES="$(printf '%s\n' "$@")" \
  awk -F'|' -v OFS='|' -v f="$feature" -v newname="$newname" -v n="$n" '
    index($3, f) && $6 ~ /\[/ {
      prio = $4
      gsub(/^[ \t]+|[ \t]+$/, "", prio)
      $3 = " " newname " "
      print
      dep = newname
      count = split(ENVIRON["REST_SLICES"], slices, "\n")
      for (i = 1; i <= count; i++) {
        printf "| %d | %s | %s | %s | [ ] 未着手 | - |\n", n + i - 1, slices[i], prio, dep
        dep = slices[i]
      }
      next
    }
    { print }
  ' docs/backlog.md > "$tmp" && mv "$tmp" docs/backlog.md
  echo "🔀 機能を分割: ${feature} → 今回: ${newname} ／ 残り: $*（[ ] 未着手 で行追加・依存は直前の縦切り）※スコープ変更として完了報告で明示すること"
  exit 0
fi

awk -F'|' -v OFS='|' -v f="$feature" -v cmd="$cmd" -v s="$steering" '
  index($3, f) && $6 ~ /\[/ {
    if (cmd == "start") { $6 = " [-] 実装中 "; $7 = " " s " " }
    else                { $6 = " [x] 完了 " }
  }
  { print }
' docs/backlog.md > "$tmp" && mv "$tmp" docs/backlog.md

if [ "$cmd" = "start" ]; then
  echo "▶️  着手を記録: ${feature} → [-] 実装中（${steering}）"
else
  echo "✅ 完了を記録: ${feature} → [x] 完了"
fi
