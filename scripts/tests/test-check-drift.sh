# test-check-drift.sh — check-drift.sh（描写ドキュメントの機械検査）の回帰テスト。
# run-tests.sh から source される。

# 実コードと一致した描写ドキュメント一式を種まきする。
# 各テストはここから「嘘」を1つ混入させ、検出されることを確認する。
seed_described_project() {
  mkdir -p "$SB/docs" "$SB/src/task/entities" "$SB/src/task/use-cases"
  printf 'export class Task {}\n' > "$SB/src/task/entities/Task.ts"
  printf 'export class CreateTask {}\n' > "$SB/src/task/use-cases/CreateTask.ts"
  cat > "$SB/docs/repository-structure.md" <<'EOF'
# リポジトリ構造定義書

## プロジェクト構造

```
src/
└── task/
    ├── entities/
    │   └── Task.ts
    └── use-cases/
        └── CreateTask.ts
```

検査スクリプトは `scripts/check-drift.sh` にある。
EOF
  cat > "$SB/docs/functional-design.md" <<'EOF'
# 機能設計書

タスク作成は `src/task/use-cases/CreateTask.ts` が担当する。
EOF
  cat > "$SB/docs/development-guidelines.md" <<'EOF'
# 開発ガイドライン

テストは `scripts/tests/` に置く…わけではなく、この例では省略。
EOF
  mkdir -p "$SB/scripts/tests"
  cat > "$SB/docs/glossary.md" <<'EOF'
# 用語集

### タスク

**定義**: ユーザーが管理する作業単位。クラス名は `Task`。
EOF
}

test_case "check-drift: 描写ドキュメントが未生成なら正常終了する"
sandbox cd-empty
run check-drift.sh
assert 0 "検査対象がまだありません"

test_case "check-drift: コードと一致した描写はパスする"
sandbox cd-ok
seed_described_project
run check-drift.sh
assert 0 "✅"

test_case "check-drift: ツリー記法に実在しないパスがあれば ❌（詳細な嘘）"
sandbox cd-tree-lie
seed_described_project
cat > "$SB/docs/repository-structure.md" <<'EOF'
# リポジトリ構造定義書

```
src/
└── task/
    ├── entities/
    │   └── Task.ts
    └── services/
        └── TaskService.ts
```
EOF
run check-drift.sh
assert 1 "src/task/services/"

test_case "check-drift: ツリーのプレースホルダー（[名前]・…）は検査対象外"
sandbox cd-placeholder
seed_described_project
cat > "$SB/docs/repository-structure.md" <<'EOF'
# リポジトリ構造定義書

```
src/
└── [feature-name]/
    ├── entities/
    │   └── …
    └── {layer}/
```
EOF
run check-drift.sh
assert 0 "✅"

test_case "check-drift: バックティック内の実在しないパスを ❌ 検出する"
sandbox cd-backtick-lie
seed_described_project
printf '\n削除機能は `src/task/use-cases/DeleteTask.ts` が担当する。\n' >> "$SB/docs/functional-design.md"
run check-drift.sh
assert 1 "DeleteTask.ts"

test_case "check-drift: development-guidelines の断線は ⚠️ 警告（終了コードは 0）"
sandbox cd-guideline-warn
seed_described_project
printf '\nLint 設定は `config/lint/strict.conf` を使う。\n' >> "$SB/docs/development-guidelines.md"
run check-drift.sh
assert 0 "config/lint/strict.conf"

test_case "check-drift: glossary の識別子がコードに無ければ ⚠️ 警告（終了コードは 0）"
sandbox cd-glossary-warn
seed_described_project
printf '\n### 昔の名前\n\nクラス名は `LegacyTodo`。\n' >> "$SB/docs/glossary.md"
run check-drift.sh
assert 0 "LegacyTodo"

test_case "check-drift: --quick は指定ファイルの検査だけを行う"
sandbox cd-quick
seed_described_project
# functional-design に嘘を混入させても、repository-structure だけの --quick では検出されない
printf '\n削除機能は `src/task/use-cases/DeleteTask.ts` が担当する。\n' >> "$SB/docs/functional-design.md"
run check-drift.sh --quick docs/repository-structure.md
assert_not_contains 0 "DeleteTask.ts"

test_case "check-drift: --quick で指定ファイル自体の嘘は検出する"
sandbox cd-quick-hit
seed_described_project
printf '\n削除機能は `src/task/use-cases/DeleteTask.ts` が担当する。\n' >> "$SB/docs/functional-design.md"
run check-drift.sh --quick docs/functional-design.md
assert 1 "DeleteTask.ts"
