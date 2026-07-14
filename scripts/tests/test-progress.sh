# test-progress.sh — progress.sh（進捗集計と鮮度検査）の回帰テスト。
# run-tests.sh から source される。
# progress.sh は docs/backlog.md の列位置（$5=状態, $6=steering）に依存している。
# backlog テンプレート（.claude/skills/progress-report/templates/backlog.md）の
# 列構成を変えるときは、このテストと progress.sh を同時に更新すること。

# backlog + steering の典型的な進行状態を種まきする:
#   機能A: 完了（tasklist も全完了） / 機能B: 実装中 / 機能C: 未着手
seed_project() {
  mkdir -p "$SB/docs" "$SB/.steering/20260101-feat-a" "$SB/.steering/20260102-feat-b"
  cat > "$SB/docs/backlog.md" <<'EOF'
# プロダクトバックログ

| # | 機能 | 優先度 | 状態 | steering |
|---|------|--------|------|----------|
| 1 | 機能A | 高 | [x] 完了 | 20260101-feat-a |
| 2 | 機能B | 中 | [-] 実装中 | 20260102-feat-b |
| 3 | 機能C | 低 | [ ] 未着手 | - |
EOF
  cat > "$SB/.steering/20260101-feat-a/tasklist.md" <<'EOF'
# tasklist
- [x] Aが空入力のときエラーを返す
- [x] Aが正常入力のとき登録される
EOF
  cat > "$SB/.steering/20260102-feat-b/tasklist.md" <<'EOF'
# tasklist
- [x] Bの一覧が取得できる
- [-] Bの絞り込みができる
- [ ] Bの並び替えができる
EOF
}

test_case "progress: 集計対象が無いテンプレート直後は正常終了する"
sandbox pg-empty
run progress.sh
assert 0 "集計対象がまだありません"

test_case "progress: backlog の機能単位集計が列位置（\$5=状態）通りに数えられる"
sandbox pg-count
seed_project
run progress.sh
assert 0 "完了 1 ／ 実装中 1 ／ 未着手 1（全 3 機能）"

test_case "progress: 乖離が無ければ鮮度検査が ✅ になる"
sandbox pg-fresh
seed_project
run progress.sh
assert 0 "✅ 乖離なし"

test_case "progress: backlog[x] なのに tasklist に未完了が残る乖離を ❌ 検出する"
sandbox pg-stale
seed_project
printf -- '- [ ] Aの取り残しタスク\n' >> "$SB/.steering/20260101-feat-a/tasklist.md"
run progress.sh
assert 1 "未完了タスクが残っています"

test_case "progress: backlog 未登録の steering を ⚠️ 警告する（終了コードは 0）"
sandbox pg-rogue
seed_project
mkdir -p "$SB/.steering/20260103-rogue"
printf -- '- [ ] 野良タスク\n' > "$SB/.steering/20260103-rogue/tasklist.md"
run progress.sh
assert 0 "登録されていません"
