# プロジェクトメモリ

## 技術スタック

> このセクションはプロジェクトごとに記入してください（言語・ランタイム・主要フレームワーク・パッケージマネージャー・テスト/ビルドツールなど）。
> 例:
>
> - 開発環境: devcontainer
> - 言語/ランタイム: [例: TypeScript 5.x / Node.js, Python 3.12, Go 1.22 など]
> - パッケージマネージャー: [例: npm / pip / go mod など]
> - テスト: [例: vitest / pytest / go test など]
> - Lint/Format: [例: eslint + prettier / ruff など]
> - ビルド: [例: tsc / なし など]

## プロジェクトの規律（`.claude/rules/` に分割）

このプロジェクトの規律は `.claude/rules/` にトピック別で定義されており、Claude Code が自動的にロードする（`paths` なしのルールは毎セッション、`paths` 付きは該当ファイルを扱うときのみ）。

| ルール | ロード条件 | 内容 |
|---|---|---|
| `.claude/rules/spec-driven-workflow.md` | 常時 | 基本フロー・**承認ゲートの方針（正本）**・ステアリング運用・開発プロセス |
| `.claude/rules/document-management.md` | 常時 | **意図と描写の分離（正本）**・`docs/`／`.steering/` の役割 |
| `.claude/rules/docs-hygiene.md` | `docs/**` を扱うとき | docs 編集時のガード（backlog 状態列の手動更新禁止など） |
| `.claude/rules/config-maintenance.md` | `.claude/**`・`scripts/**` を扱うとき | テンプレート自身の保守規律（check-config.sh の実行など） |

> このファイル（CLAUDE.md）には、利用者がプロジェクトごとに記入する内容（技術スタック）だけを置く。規律の追加・変更は該当する rules ファイルで行い、新しいトピックは `.claude/rules/` に1ファイル1トピックで追加する。
