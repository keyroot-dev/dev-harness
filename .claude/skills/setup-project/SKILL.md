---
name: setup-project
description: 初回セットアップ: 意図(PRD/アーキ芯)を固め、動く土台(Walking Skeleton)を立ててから描写ドキュメントを導出する
disable-model-invocation: true
---

# 初回プロジェクトセットアップ

このコマンドは、**意図（intent）を先に固め、動く土台（Walking Skeleton）を立ててから、その土台を描写（description）するドキュメントを導出する**流れで、プロジェクトの永続ドキュメントと最初の動くコードを用意します。

> **設計の正本はここで再定義しない。** 「いつ承認で止まるか」は `.claude/rules/spec-driven-workflow.md`「承認ゲートの方針（正本）」、「どのドキュメントを前/後に書くか」は `.claude/rules/document-management.md`「意図と描写の分離（正本）」に従う。本コマンドはそれを実行する手順にすぎない。
>
> 要点:
> - **意図（先）**: `product-requirements.md`（承認ゲート1）と `architecture.md` の芯（依存の向き・レイヤ境界・技術スタック）、およびPRDから導出する `docs/backlog.md`（機能単位の全体俯瞰）。
> - **動く土台**: Walking Skeleton（端から端まで動く縦切り1本＋CI・フィットネス関数が緑）。動くことを見せて承認ゲート2。
> - **描写（後）**: `repository-structure.md`・`development-guidelines.md` は骨格の現実から導出。`functional-design.md`・`glossary.md` はスタブで置き、以後 `/add-feature` が機能ごとに育てる。憶測でコードの前に描写を書かない（context poisoning を避ける）。

## 実行方法

```bash
claude
> /setup-project
```

## 実行前の確認

`docs/ideas/` ディレクトリ内のアイデアメモを確認します（特定のファイル名には依存しません）。
```bash
# 確認
ls docs/ideas/

# マークダウンのアイデアメモが存在する場合（README.md 等の説明ファイルは除外）
✅ docs/ideas/ にアイデアメモが見つかりました
   この内容を元にPRDを作成します

# アイデアメモが存在しない場合
⚠️  docs/ideas/ にアイデアメモがありません
   対話形式でヒアリングしながらPRDを作成します
```

## 手順

### ステップ0: インプットの読み込み

1. `docs/ideas/` 内のマークダウンファイルを全て読む（`README.md` 等の説明ファイルは除外してよい）
2. 内容を理解し、PRD作成の参考にする。アイデアメモが無い場合は、ステップ1で対話ヒアリングに切り替える

### ステップ1: プロダクト要求定義書の作成

1. **prd-writingスキル**をロード
2. `docs/ideas/`の内容を元に`docs/product-requirements.md`を作成
3. 壁打ちで出たアイデアを具体化：
   - 詳細なユーザーストーリー
   - 受け入れ条件
   - 非機能要件
   - 成功指標
4. **ユーザーに見せる前に自己レビューを1周かける**: `Task`ツールで`doc-reviewer`サブエージェントを起動し（`subagent_type`: "doc-reviewer"）、作成したPRDをレビューさせる。**[必須]指摘を自己修正**してからユーザーに提示する（[推奨]・[提案]はレビュー要点として承認依頼に添える）。これは承認ゲートを増やすのではなく、ゲートに出す成果物の質を上げて承認の往復を減らすための工程
5. ユーザーに確認を求め、**承認されるまで待機**（＝承認ゲート1: 意図）

**PRD承認後、意図（アーキ芯）は連続生成してよい。描写ドキュメントは Walking Skeleton の後まで作らない。**

### ステップ2: アーキテクチャの芯を作成（意図 / intent）

1. **architecture-designスキル**をロード
2. `docs/product-requirements.md`を読む
3. スキルの「芯（コア）」に従い、`docs/architecture.md` に**薄い芯だけ**を書く:
   - 依存の向き（依存はすべて内向き）とレイヤ境界
   - 技術スタック（言語・ランタイム・テスト/Lintツール）
   - これらは Walking Skeleton を1本通すのに必要な最小限の「決定」に限る。詳細な構造は骨格の後に育てる。

### ステップ2.5: バックログの種まき（意図 / intent）

1. 承認済みの `docs/product-requirements.md` から、**機能単位の一覧**を導出する
2. `.claude/skills/progress-report/templates/backlog.md` のテンプレートに従い、`docs/backlog.md` を作成する
   - 行の存在と優先度は意図（PRD由来）。状態はすべて `[ ] 未着手` で置く
   - 承認済みPRDからの導出なので連続生成してよい（承認ゲートは増やさない）
3. 以後、状態列は `/add-feature` が機械更新し、`/progress-report` がここから全体俯瞰を導出する

### ステップ3: Walking Skeleton の実装（動く土台）

1. PRDのコア機能から、**端から端まで動く最小の縦切り1本**を選ぶ（例: ToDoアプリなら `add`→`list` だけ）。バックログ（ステップ2.5）の最優先の機能から選ぶとよい。
2. `Skill('add-feature')` の実装フロー（TDD / Red-Green-Refactor）を用いて、この縦切りを実装する。あわせて CI とフィットネス関数（アーキ境界検査・テストランナー）を立て、緑にする。
3. **動くことをユーザーに見せて承認を待つ（＝承認ゲート2: 動く土台）。**
   ```
   「Walking Skeleton が動く状態になりました（CI・フィットネス関数も緑）。
   実行して確認してください。承認いただけたら、骨格を元に残りのドキュメントを導出します。」
   ```

### ステップ4: リポジトリ構造定義書の作成（描写 / description）

1. **repository-structureスキル**をロード
2. **骨格が実際に生成したディレクトリツリー**を真実の源として読む
3. スキルのテンプレートに従い、`docs/repository-structure.md` に**現実を描写**する（憶測で構造を発明しない）

### ステップ5: 開発ガイドラインの作成（描写 / description）

1. **development-guidelinesスキル**をロード
2. **骨格のテスト/Lint/型チェック/CI設定**を真実の源として読む
3. スキルのテンプレートに従い、`docs/development-guidelines.md` に骨格から**種を採って**具体化する

### ステップ6: 機能設計書のスタブ作成（描写 / 以後育てる）

1. **functional-designスキル**をロード
2. `docs/functional-design.md` を**見出し構造だけのスタブ**として作成する（Walking Skeleton で実装済みの縦切りぶんのみ記述）
3. 未実装機能は書かない。以後 `/add-feature` が機能ごとに追記して育てる

### ステップ7: 用語集のスタブ作成（描写 / 以後育てる）

1. **glossary-creationスキル**をロード
2. `docs/glossary.md` を**スタブ**として作成する（PRDと骨格で実際に登場した用語のみ定義）
3. 未登場の用語は先取りしない。以後 `/add-feature` がドメイン用語を追記して育てる

## 完了条件

- `product-requirements.md`（承認済み）と `architecture.md` の芯が作成されている
- `docs/backlog.md` がPRDから機能単位に導出されている
- Walking Skeleton が動作し、CI・フィットネス関数が緑（承認済み）
- `repository-structure.md`・`development-guidelines.md` が骨格の現実から導出されている
- `functional-design.md`・`glossary.md` がスタブとして存在する（＝この時点では最小で正しい）

完了時のメッセージ:
```
「初回セットアップが完了しました!

意図（先に確定）:
✅ docs/product-requirements.md（承認済み）
✅ docs/architecture.md（芯）
✅ docs/backlog.md（PRDから機能単位に導出 / 状態列は以後 /add-feature が機械更新）

動く土台:
✅ Walking Skeleton（動作確認済み / CI・フィットネス関数が緑）

描写（骨格から導出）:
✅ docs/repository-structure.md（現実を描写）
✅ docs/development-guidelines.md（骨格から種を採取）
✅ docs/functional-design.md（スタブ / 以後 add-feature が育てる）
✅ docs/glossary.md（スタブ / 以後 add-feature が育てる）

これで、動くコードと、それを正しく描写したドキュメントが揃いました。

今後の使い方:
- 機能の追加: /add-feature [機能名]（TDDで実装し、描写ドキュメントも育てます）
  例: /add-feature ユーザー認証

- ドキュメントの編集: 普通に会話で依頼してください
  例: 「PRDに新機能を追加して」「architecture.mdの芯を見直して」

- 進捗の確認・報告: /progress-report（全体俯瞰は docs/backlog.md を開くだけ）

- ドキュメントレビュー: /review-docs [パス]
  例: /review-docs docs/product-requirements.md
」
```