---
paths:
  - ".claude/**"
  - "scripts/**"
---

# テンプレート自身の保守規律

`.claude/`（スキル・エージェント・rules）や `scripts/` を編集するときに適用される。

- **正本（Single Source of Truth）を再定義しない。** 規律・方針は正本の一箇所だけで定義し、他のスキル・コマンドはファイルパスで参照する。同じ規律を2箇所に書いたら、それはバグである。
  - 承認ゲートの方針: `.claude/rules/spec-driven-workflow.md`
  - 意図と描写の分離: `.claude/rules/document-management.md`
  - タスク完遂規律・テスト駆動規律: `.claude/skills/steering/SKILL.md` モード2
- **変更後は必ず `bash scripts/check-config.sh` を実行する**（CI でも走るが、手元で先に落とす）。スキル・エージェント・ガイドのリネームや正本の移動は、参照網の静かな断線を生みやすい。
- 正本セクションを別ファイルへ移すときは、参照元（`Skill(...)`・`.md` 相対リンク・本文中の言及）を grep で全数洗い出してから更新する。
- rules ファイルのフロントマターに書けるキーは `paths` のみ。`paths` を付けなければ常時ロード（CLAUDE.md と同格）になる。
