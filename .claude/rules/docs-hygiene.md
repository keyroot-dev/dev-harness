---
paths:
  - "docs/**"
---

# docs/ 編集時のガード

`docs/` 配下のファイルを読む・編集するときに適用される。理由と定義の正本は常時ロードの `.claude/rules/document-management.md`「意図と描写の分離（正本）」と `.claude/rules/spec-driven-workflow.md`「承認ゲートの方針（正本）」— ここでは再定義せず、その場で効く禁止形だけを示す。

- 描写ドキュメントに、実在しないコードの構成・用語・設定を憶測で書かない
- 意図ドキュメント（PRD / architecture.md の芯）を実装の都合で直接書き換えない（変更案として提示し承認を仰ぐ）
- `docs/backlog.md` の状態列を手で更新しない
- 時点スナップショット（進捗報告書等）を `docs/` に保存しない
