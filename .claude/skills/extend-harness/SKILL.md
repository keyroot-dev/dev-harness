---
name: extend-harness
description: この dev-harness テンプレート自身に Claude Code の新機能（スキル・フック・サブエージェント・ルール・スクリプト）を追加・変更するときに使用。「新しいスキルを作りたい」「フックを追加したい」「サブエージェントを増やしたい」「ルールを足したい」など、.claude/ や scripts/ 配下の成果物を増やす依頼がトリガー。成果物タイプ別の作成手順とリポジトリ固有の登録チェックリストを提供し、スキル執筆の汎用技術は skill-creator プラグインに委譲する。
argument-hint: [作りたい機能の説明]
---

# ハーネス拡張（このリポジトリへの Claude 機能追加）

このテンプレート自身に成果物を追加するときの**ルーティングと登録チェックリスト**です。

> **正本はここで再定義しない。** 保守の禁止事項（正本の重複定義禁止・検査の実行義務）は
> `.claude/rules/config-maintenance.md`「テンプレート自身の保守規律」が単一の真実。
> 本スキルはそれを「成果物を新しく作る」場面に展開した手順にすぎない。

**作りたい機能:** $ARGUMENTS

## ステップ0: 成果物タイプの判別

`$ARGUMENTS` から作るものを判別する。判別できないときは、この図を見せて1回だけ確認する。

```
 何を作る？
   │
   ├─ Claude に手順・知識を与えたい ────────────▶ [A] スキル
   │    （「〇〇するときはこう動け」）
   ├─ ツール実行の前後で機械的に強制したい ──────▶ [B] フック
   │    （Claude の意思と無関係に必ず走る）
   ├─ 独立したコンテキストで作業を任せたい ──────▶ [C] サブエージェント
   │    （調査・監査・相談など、結果だけ欲しい）
   ├─ 毎セッション/特定ファイルで守らせたい規律 ──▶ [D] ルール
   │    （手順ではなく制約・原則）
   └─ 決定論的な検査・集計を足したい ───────────▶ [E] スクリプト
        （LLM に判定させない部分）
```

迷ったら: **機械で強制できるものはスキルにしない**（フック/スクリプトへ）。**毎回must な制約はスキルにしない**（ルールへ。スキルはロードされないことがある）。

## タイプ別手順

### [A] スキル（`.claude/skills/<name>/`）

1. **執筆は委譲する**: `Skill('skill-creator:skill-creator')` を起動し、SKILL.md の構成・description の最適化・progressive disclosure はそちらの知識で書く（汎用技術をこのリポジトリで再実装しない）
2. ただし委譲中も、このリポジトリ固有の制約を上書きで適用する:
   - フロントマターの許可キーは `scripts/check-config.sh` の許可リストが正本（現在: `name|description|argument-hint|user-invocable|disable-model-invocation|allowed-tools|model`）。新キーを採用するなら check-config.sh の許可リストも同時に更新する
   - 既存の規律（承認ゲート・意図と描写・タスク完遂など）に触れる内容は、本文へ複写せず正本ファイルへのパス参照で書く
3. ユーザー承認なしで起動させたいなら `settings.json` の `permissions.allow` に `Skill(<name>)` を追加する

### [B] フック（`scripts/hooks/` + `settings.json`）

フックは必ず**3点セット**で作る（1つでも欠けたら未完成）:

1. `scripts/hooks/<name>.sh` — 既存フック（`post-edit-config.sh` 等）を雛形にする。stdin の JSON を `jq` で読む・対象外パスは `exit 0` で素通し・Claude へのフィードバックは stderr + `exit 2`、という既存パターンを踏襲する
2. `settings.json` の `hooks` へ登録 — イベント（PreToolUse / PostToolUse / Stop 等）と matcher を選ぶ。コマンドは `bash "$CLAUDE_PROJECT_DIR/scripts/hooks/<name>.sh"` 形式
3. `scripts/tests/test-hooks.sh` へテスト追加 — 既存テストの形式に合わせ、対象パス/対象外パス両方の振る舞いを固定する

### [C] サブエージェント（`.claude/agents/<name>.md`）

1. 既存エージェント（`uncle-bob.md`・`drift-auditor.md` 等）を雛形にする
2. フロントマターの許可キーは `name|description|tools|model|color`（check-config.sh [6] が検査）
3. `description` には**起動条件を具体的な場面で列挙**する（親エージェントはこれだけを見て起動判断する）
4. `tools` は最小権限にする（調査系なら `Read, Grep, Glob`）
5. スキル・コマンドから `subagent_type` で指名する場合、名前の綴りは check-config.sh [3] が検査する

### [D] ルール（`.claude/rules/<topic>.md`）

1. 1ファイル1トピック。フロントマターに書けるキーは **`paths` のみ**（付けなければ常時ロード。常時ロードはコンテキスト常駐コストなので、特定ファイル編集時だけ効けばよい規律には必ず `paths` を付ける）
2. **`CLAUDE.md` の索引表に行を追加する**（ルール名・ロード条件・内容の3列）
3. 既存の正本と重複する内容を書かない。関連する正本があればパス参照でつなぐ

### [E] スクリプト（`scripts/`）

1. 既存スクリプト（`check-config.sh`・`progress.sh` 等)の流儀に合わせる: `set -euo pipefail`・冒頭コメントで存在理由を説明・違反時は非ゼロ終了（CI で落とせる形）
2. `scripts/tests/test-<name>.sh` を追加し、`scripts/tests/run-tests.sh` から実行されることを確認する
3. スキル・フックから呼ぶ場合、呼び出し側にはコマンドの実体をベタ書きせず、役割を一言添える

## 共通の締め（タイプを問わず必ず実行）

```
 □ 正本の再定義がないか（同じ規律を2箇所に書いたらバグ。パス参照に置き換える）
 □ 登録漏れがないか
     スキル       → settings.json の allow（必要な場合）
     フック       → settings.json の hooks ＋ test-hooks.sh
     ルール       → CLAUDE.md の索引表
     スクリプト   → scripts/tests/ のテスト
 □ bash scripts/check-config.sh が緑か
     （PostToolUse フックでも自動実行されるが、完了宣言の前に手で最終確認する）
 □ scripts/ か scripts/tests/ を触ったなら bash scripts/tests/run-tests.sh も緑か
 □ README.md に成果物一覧・構成図があれば追記したか
```

すべて緑になってから完了を報告する。コミットを求められたら `Skill('commit-message')` に従う。
