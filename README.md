# spec-driven-template

Claude Code を使った**スペック駆動開発**のためのプロジェクトテンプレートです。言語・フレームワークに依存せず、どのプロジェクトの起点としても使えます。

「何を作るか」を永続ドキュメント（`docs/`）で定義し、「今回何をするか」をステアリングファイル（`.steering/`）で計画してから実装する、という流れをスキル・コマンド・エージェントで支援します。

ドキュメントは2種類に分けて扱います。**意図（intent／何を・なぜ）はコードの前に、描写（description／どこに何が）はコードの後に**書きます。まず意図を固め、動く土台（Walking Skeleton）を1本立ててから、その土台を描写するドキュメントを導出します。理由は「動くソフトウェアが唯一の真実の源」であり、存在しないコードの描写を先に書くと、それが「詳細な嘘」となってAIの生成を汚染する（context poisoning）ためです。

## 含まれるもの

```
.claude/
├── skills/      スペック駆動開発の各スキル（PRD・機能設計・アーキテクチャ等）
│               + ワークフロー系 setup-project / add-feature / review-docs / progress-report（/コマンドとして起動）
├── agents/      doc-reviewer / implementation-validator
└── settings.json
CLAUDE.md        ワークフローとプロジェクト規約（要編集）
docs/            永続ドキュメント（何を作るか）
.steering/       作業単位のドキュメント（今回何をするか）
.devcontainer/   Dev Container 定義（任意）
.github/         設定の自己検査（check-config.sh）を回す CI
scripts/         check-config.sh（設定リポジトリ自身の Fitness Function）
                 progress.sh（進捗の機械集計と backlog⇔tasklist の鮮度検査）
```

## 使い方

### 1. このテンプレートを起点にする

```bash
git clone <this-repo> my-project
cd my-project
```

### 2. プロジェクトに合わせて設定

- `CLAUDE.md` の「技術スタック」を自分のプロジェクトに合わせて記入する
- 必要に応じて `.devcontainer/devcontainer.json` を調整する
  （言語ランタイムや `postCreateCommand` を追加）

### 3. ドキュメントを作成して開発を始める

```bash
# 永続ドキュメントを対話的に作成
/setup-project

# 機能を追加（定型フロー）
/add-feature [機能名]

# 進捗を俯瞰・PM向けに報告
/progress-report
```

スペック駆動開発の詳細を意識する必要はありません。普通に会話で依頼すれば、Claude Code が適切なスキルを判断して読み込みます。詳しくは `CLAUDE.md` を参照してください。

### 4. 具体例：ToDo アプリを作ってみる

全体の流れは「アイデアメモ → `/setup-project` で意図＋動く土台 → `/add-feature` で実装」です。

```
docs/ideas/*.md → /setup-project ─────────────────────────────→ /add-feature → 実機能
（壁打ちメモ）     🛑PRD(意図)  →  アーキ芯  →  🏗️動く骨格  →  描写ドキュメント     🏃TDDで自走
                  承認・ゲート1              🛑確認・ゲート2   （骨格から導出/種まき）

  意図(intent)＝先 ──────────┤ 動く土台 ├────── 描写(description)＝後
```

#### ステップ 1: アイデアメモを置く（任意）

壁打ちの成果物を `docs/ideas/` に置いておくと、`/setup-project` がそれを読んで PRD の下書きにします。

```bash
# docs/ideas/todo-app.md（自由形式でOK）
# 「個人用のToDoアプリ。タスクのCRUD、期限、完了チェック。まずはCLIで」
```

> メモが無くても大丈夫です。その場合 `/setup-project` が対話でヒアリングしてくれます。

#### ステップ 2: 意図を固め、動く土台まで立てる

```bash
> /setup-project
```

```
① product-requirements.md（意図）を作成
   → 🛑「内容を確認してください。承認いただけたら次に進みます」← ゲート1（意図）
        あなた: 「OK、承認します」
② architecture.md の芯（意図）… 依存の向き・レイヤ境界・技術スタックを薄く1枚
   docs/backlog.md（意図）… PRDの機能を一覧化（全体俯瞰の地図。状態列は以後機械更新）
③ 🏗️ Walking Skeleton を実装 … `todo add`→`todo list` が端から端まで通る最小の1本
   CI・フィットネス関数（アーキ境界検査・テスト）が緑
   → 🛑「骨格が動きます。実行して確認してください」← ゲート2（動く土台）
④ 骨格の"現実"から描写ドキュメントを導出・種まき
   ├ repository-structure.md … 骨格が作ったツリーを描写（憶測ゼロ）
   ├ development-guidelines.md … 骨格の test/lint/CI 設定から種を採る
   ├ functional-design.md … スタブ（以後 /add-feature が育てる）
   └ glossary.md … スタブ（以後 /add-feature が育てる）
```

止まるのは **PRD承認** と **骨格の確認** の2回。どちらも「方向を握る」ための検査点です。③を境に、以降のドキュメントは**憶測ではなく、動くコードの記録**になります。

#### ステップ 3: 技術スタックを埋める

`CLAUDE.md` の「技術スタック」節を、実際の構成に合わせて記入します（例：TypeScript / Node.js / vitest / eslint）。以降のテスト・Lint コマンドはここが真実の源になります。アーキ芯（②）と Walking Skeleton（③）はこの技術スタックに沿って作られます。

#### ステップ 4: 機能を実装する

```bash
> /add-feature タスクの完了チェック
```

これ以降は**完了まで停止しません**。各タスクを 🔴Red→🟢Green→🔵Refactor（テスト駆動）で実装します。

```
[1] .steering/20260701-タスクの完了チェック/ を作成（requirements/design/tasklist）
[2] CLAUDE.md と docs/ を読む（骨格が作った"事実"の repo構造・ガイドを参照）
[3] 既存コードを Grep して命名規則・パターンを把握（骨格が規約の実例になっている）
[4] tasklist.md を「振る舞い単位」で具体化
[5] 各振る舞いを 🔴Red→🟢Green→🔵Refactor で実装（テストはループ内で走る）
[6] implementation-validator サブエージェントで品質検証
[7] スイート全体の回帰 → Lint → 型チェック → アーキ境界検査（失敗は自分で修正）
[8] 振り返りを tasklist.md に記載し、描写ドキュメントを育てる
    └ functional-design.md に実装機能を追記／glossary.md に新用語を追記
       backlog.md の該当行を [x] 完了に更新（着手時に [-] 実装中になっている）
```

描写ドキュメントは「最初に書く」ものではなく「コードと同じ速度で育てる」ものです。完了後、追加でレビューが欲しければ `/code-review` を続けて実行できます。

#### ステップ 5: 進捗を俯瞰・報告する

全体の現在地は `docs/backlog.md` を開くだけで分かります（機能×状態×steeringリンクの地図）。PMへの報告が要るときは:

```bash
> /progress-report
```

`scripts/progress.sh` が backlog と `.steering/*/tasklist.md` を横断集計し（backlog⇔tasklist の乖離も機械検出）、その真実からアジャイル形式の報告（完了した振る舞い／進行中／次にやること／リスク）をチャットに組み立てます。報告書ファイルは保存しません — 進捗の真実は backlog と tasklist にあり、報告はそこからの導出ビューです（期間差分は git 履歴から再導出できます）。

#### ステップ 6: 日常の編集は会話で

コマンドを覚える必要はありません。普通に頼めば適切なスキルが自動で動きます。

```bash
> PRD に「タスクのタグ付け」機能を追加して
> architecture.md のデータ永続化の方針を SQLite に見直して
> glossary.md に「アーカイブ」の定義を追加して
> /add-feature タスクの検索          # 次の機能もコマンド一発
```

### 補足: バンドル済みスキルの併用

このテンプレート独自のフロー（`/setup-project`・`/add-feature`）に加えて、Claude Code 標準の
バンドルスキルを組み合わせると効果的です。

- `/add-feature` の実装後、追加のコードレビューが欲しいときは `/code-review`
- 反復的な修正・調査を回したいときは `/loop`、原因調査には `/debug`

これらは `/` メニューから直接呼び出せます（本テンプレートの設定変更は不要）。

## 設定の自己検査（Fitness Function）

このテンプレートは利用者のプロジェクトに「境界を文書の禁止で終わらせず機械強制せよ」と説きます。設定自身も同じ規律に従い、整合性を機械的に検査できます。

```bash
bash scripts/check-config.sh
```

検査内容（違反があれば非ゼロ終了。`.github/workflows/check-config.yml` により push / PR ごとに CI でも自動実行されます）:

- 各スキルに `SKILL.md` が存在する
- `.claude/` 配下で参照される `Skill(<name>)` が実在するスキルである（skill 本文・settings.json をまたいで検査）
- `.claude/` 配下で `subagent_type` に指名されるエージェントが実在する
- `.claude/` 配下・`CLAUDE.md`・`README.md` から相対参照される `.md` ファイルが実在する（利用者プロジェクトで生成される `docs/` 等のプレースホルダーは対象外）

スキル・エージェント・ガイドをリネーム・削除したのに参照が古いまま、という「リンク切れ」を防ぎます。「正本（Single Source of Truth）」の網はファイル間参照で編まれているため、その断線は機械で検出します。

## ライセンス

MIT License（`LICENSE` を参照）
