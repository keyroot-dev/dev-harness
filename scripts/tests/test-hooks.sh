# test-hooks.sh — scripts/hooks/*.sh（規律の機械的強制）と backlog-state.sh の回帰テスト。
# run-tests.sh から source される。フック入力はヒアドキュメントの JSON で再現する。
# 注: フックは jq を前提とする（無い環境では fail-open）。テスト環境にも jq が必要。

if ! command -v jq >/dev/null 2>&1; then
  echo "  ⚠️  jq が無いため hooks のテストをスキップします"
else

seed_backlog() {
  mkdir -p "$SB/docs"
  cat > "$SB/docs/backlog.md" <<'EOF'
# プロダクトバックログ

| # | 機能 | 優先度 | 依存 | 状態 | steering |
|---|------|--------|------|------|----------|
| 1 | タスク追加 | 高 | - | [ ] 未着手 | - |
| 2 | タスク一覧 | 中 | - | [ ] 未着手 | - |

## 運用ルール

- 状態の更新は scripts/backlog-state.sh を使う
EOF
}

# CLAUDE_PROJECT_DIR をサンドボックスに向けてフックを実行する
run_hook() {
  local stdin="$1" hook="$2"
  OUT="$(cd "$SB" && printf '%s' "$stdin" | CLAUDE_PROJECT_DIR="$SB" bash "scripts/hooks/$hook" 2>&1)"
  RC=$?
}

# ── pre-edit-backlog.sh ──────────────────────────────────────────────

test_case "hooks: backlog の状態マーカーを変える Edit をブロックする（exit 2）"
sandbox hk-block
seed_backlog
run_hook '{"tool_name":"Edit","tool_input":{"file_path":"docs/backlog.md","old_string":"| 1 | タスク追加 | 高 | [ ] 未着手 | - |","new_string":"| 1 | タスク追加 | 高 | [x] 完了 | - |"}}' pre-edit-backlog.sh
assert 2 "backlog-state.sh"

test_case "hooks: 状態列に触れない backlog の編集（優先度変更等）は許可する"
sandbox hk-allow-prio
seed_backlog
run_hook '{"tool_name":"Edit","tool_input":{"file_path":"docs/backlog.md","old_string":"| 2 | タスク一覧 | 中 | [ ] 未着手 | - |","new_string":"| 2 | タスク一覧 | 高 | [ ] 未着手 | - |"}}' pre-edit-backlog.sh
assert_rc 0

test_case "hooks: 行の追加（マーカー列の末尾追加）は許可する"
sandbox hk-allow-add
seed_backlog
run_hook '{"tool_name":"Edit","tool_input":{"file_path":"docs/backlog.md","old_string":"| 2 | タスク一覧 | 中 | [ ] 未着手 | - |","new_string":"| 2 | タスク一覧 | 中 | [ ] 未着手 | - |\n| 3 | タスク削除 | 低 | [ ] 未着手 | - |"}}' pre-edit-backlog.sh
assert_rc 0

test_case "hooks: backlog 以外のファイルの編集には関与しない"
sandbox hk-other-file
seed_backlog
run_hook '{"tool_name":"Edit","tool_input":{"file_path":"docs/glossary.md","old_string":"[ ]","new_string":"[x]"}}' pre-edit-backlog.sh
assert_rc 0

test_case "hooks: 状態マーカーを変える Write（全文上書き）もブロックする"
sandbox hk-block-write
seed_backlog
run_hook '{"tool_name":"Write","tool_input":{"file_path":"docs/backlog.md","content":"| 1 | タスク追加 | 高 | [-] 実装中 | x |\n| 2 | タスク一覧 | 中 | [ ] 未着手 | - |"}}' pre-edit-backlog.sh
assert 2 "backlog-state.sh"

# ── post-edit-config.sh ──────────────────────────────────────────────

test_case "hooks: .claude 編集後に check-config.sh の違反を検出する（exit 2）"
sandbox hk-config-broken
mkdir -p "$SB/.claude/skills/empty"
run_hook '{"tool_name":"Write","tool_input":{"file_path":"'"$SB"'/.claude/skills/empty/README.md"}}' post-edit-config.sh
assert 2 "SKILL.md がありません"

test_case "hooks: .claude 編集後、整合していれば通す"
sandbox hk-config-ok
mkdir -p "$SB/.claude"
run_hook '{"tool_name":"Write","tool_input":{"file_path":"'"$SB"'/.claude/settings.json"}}' post-edit-config.sh
assert_rc 0

test_case "hooks: 対象外パスの編集では check-config.sh を実行しない"
sandbox hk-config-skip
run_hook '{"tool_name":"Write","tool_input":{"file_path":"'"$SB"'/src/index.ts"}}' post-edit-config.sh
assert_rc 0

# ── post-edit-docs.sh ────────────────────────────────────────────────

test_case "hooks: docs 編集後に「詳細な嘘」を検出する（exit 2）"
sandbox hk-docs-lie
mkdir -p "$SB/docs"
printf '# 機能設計書\n\n`src/ghost/Missing.ts` が担当する。\n' > "$SB/docs/functional-design.md"
run_hook '{"tool_name":"Edit","tool_input":{"file_path":"'"$SB"'/docs/functional-design.md"}}' post-edit-docs.sh
assert 2 "Missing.ts"

test_case "hooks: docs 編集後、真実の描写なら通す"
sandbox hk-docs-ok
mkdir -p "$SB/docs" "$SB/src"
printf 'export {}\n' > "$SB/src/index.ts"
printf '# 機能設計書\n\n`src/index.ts` が入口。\n' > "$SB/docs/functional-design.md"
run_hook '{"tool_name":"Edit","tool_input":{"file_path":"'"$SB"'/docs/functional-design.md"}}' post-edit-docs.sh
assert_rc 0

# ── stop-freshness.sh ────────────────────────────────────────────────

test_case "hooks: 停止時に進捗乖離があれば一度だけ差し戻す（exit 2）"
sandbox hk-stop-stale
seed_backlog
mkdir -p "$SB/.steering/20260101-tsuika"
printf -- '- [ ] 未完了\n' > "$SB/.steering/20260101-tsuika/tasklist.md"
( cd "$SB" && bash scripts/backlog-state.sh start "タスク追加" "20260101-tsuika" >/dev/null && bash scripts/backlog-state.sh done "タスク追加" >/dev/null )
run_hook '{"stop_hook_active":false}' stop-freshness.sh
assert 2 "乖離"

test_case "hooks: stop_hook_active なら差し戻さない（無限ループ防止）"
sandbox hk-stop-active
seed_backlog
mkdir -p "$SB/.steering/20260101-tsuika"
printf -- '- [ ] 未完了\n' > "$SB/.steering/20260101-tsuika/tasklist.md"
( cd "$SB" && bash scripts/backlog-state.sh start "タスク追加" "20260101-tsuika" >/dev/null && bash scripts/backlog-state.sh done "タスク追加" >/dev/null )
run_hook '{"stop_hook_active":true}' stop-freshness.sh
assert_rc 0

# ── backlog-state.sh ─────────────────────────────────────────────────

test_case "backlog-state: start で状態が [-] 実装中になり steering 列が埋まる"
sandbox bs-start
seed_backlog
run backlog-state.sh start "タスク追加" "20260102-tsuika"
grep -q '| \[-\] 実装中 | 20260102-tsuika |' "$SB/docs/backlog.md" && RC=0 || RC=1
assert_rc 0

test_case "backlog-state: done で状態が [x] 完了になる"
sandbox bs-done
seed_backlog
run backlog-state.sh start "タスク追加" "20260102-tsuika"
run backlog-state.sh done "タスク追加"
grep -q '| \[x\] 完了 |' "$SB/docs/backlog.md" && RC=0 || RC=1
assert_rc 0

test_case "backlog-state: 未登録の機能への start は行を追加する（表の直後）"
sandbox bs-append
seed_backlog
run backlog-state.sh start "タスク検索" "20260103-kensaku"
# 追加行が「## 運用ルール」より前（表の末尾）に入っていること
awk '/タスク検索/ { row = NR } /## 運用ルール/ { rule = NR } END { exit !(row > 0 && row < rule) }' "$SB/docs/backlog.md" && RC=0 || RC=1
assert_rc 0

test_case "backlog-state: 複数行に一致する曖昧な機能名はエラーにする"
sandbox bs-ambiguous
seed_backlog
run backlog-state.sh done "タスク"
assert 1 "複数行に一致"

test_case "backlog-state: split で該当行を改名し、残りの縦切りを未着手で直下に追加する"
sandbox bs-split
seed_backlog
run backlog-state.sh start "タスク追加" "20260104-tsuika"
run backlog-state.sh split "タスク追加" "追加（基本）" "追加（期限）" "追加（タグ）"
# 改名: 元の行が今回の縦切り名になり、状態・steering は保持される
grep -q '| 追加（基本） | 高 | - | \[-\] 実装中 | 20260104-tsuika |' "$SB/docs/backlog.md" && \
# 行追加: 優先度は元の行を引き継ぎ、依存は直前の縦切りに連鎖する
grep -q '| 追加（期限） | 高 | 追加（基本） | \[ \] 未着手 | - |' "$SB/docs/backlog.md" && \
grep -q '| 追加（タグ） | 高 | 追加（期限） | \[ \] 未着手 | - |' "$SB/docs/backlog.md" && \
# 挿入位置: 追加行は元の行の直下（既存の次行「タスク一覧」より前）に入る
awk '/追加（タグ）/ { tag = NR } /タスク一覧/ { next_row = NR } END { exit !(tag > 0 && tag < next_row) }' "$SB/docs/backlog.md" && RC=0 || RC=1
assert_rc 0

test_case "backlog-state: split 後は今回の縦切り名で done できる"
sandbox bs-split-done
seed_backlog
run backlog-state.sh start "タスク追加" "20260104-tsuika"
run backlog-state.sh split "タスク追加" "追加（基本）" "追加（期限）"
run backlog-state.sh done "追加（基本）"
grep -q '| 追加（基本） | 高 | - | \[x\] 完了 |' "$SB/docs/backlog.md" && RC=0 || RC=1
assert_rc 0

test_case "backlog-state: 残りの縦切り名なしの split はエラーにする"
sandbox bs-split-noargs
seed_backlog
run backlog-state.sh split "タスク追加" "追加（基本）"
assert 1 "残りの縦切り名が1つ以上必要"

fi  # jq ガードの終わり
