# spec-driven-template

Claude Code を使った**スペック駆動開発**のためのプロジェクトテンプレートです。言語・フレームワークに依存せず、どのプロジェクトの起点としても使えます。

「何を作るか」を永続ドキュメント（`docs/`）で定義し、「今回何をするか」をステアリングファイル（`.steering/`）で計画してから実装する、という流れをスキル・コマンド・エージェントで支援します。

ドキュメントは2種類に分けて扱います。**意図（intent／何を・なぜ）はコードの前に、描写（description／どこに何が）はコードの後に**書きます。まず意図を固め、動く土台（Walking Skeleton）を1本立ててから、その土台を描写するドキュメントを導出します。理由は「動くソフトウェアが唯一の真実の源」であり、存在しないコードの描写を先に書くと、それが「詳細な嘘」となってAIの生成を汚染する（context poisoning）ためです。

## 含まれるもの

```
.claude/
├── rules/       プロジェクトの規律（常時ロード＋パス条件付き。下記「rules による規律の配置」参照）
├── skills/      スペック駆動開発の各スキル（PRD・機能設計・アーキテクチャ等）
│               + ワークフロー系 setup-project / add-feature / change-spec / review-docs / progress-report（/コマンドとして起動）
├── agents/      doc-reviewer / implementation-validator / drift-auditor / pattern-scout
└── settings.json
CLAUDE.md        技術スタックの記入欄と rules への索引（要編集）
.mcp.json        MCP サーバー定義（Context7 / Serena / Playwright）
docs/            永続ドキュメント（何を作るか）
.steering/       作業単位のドキュメント（今回何をするか）
.devcontainer/   Dev Container 定義（任意）
.github/         設定の自己検査と回帰テストを回す CI
scripts/         check-config.sh（設定リポジトリ自身の Fitness Function）
                 check-drift.sh（描写ドキュメント⇔実コードの機械検査）
                 progress.sh（進捗の機械集計と backlog⇔tasklist の鮮度検査）
                 backlog-state.sh（backlog 状態列の正規更新経路）
                 hooks/（編集・停止のたびに上記検査を自動実行するガードレール）
                 tests/（これらのスクリプト自身の回帰テスト）
templates/       fitness/（アーキ境界検査の言語別サンプル = Fitness Function スターターキット。
                 Walking Skeleton 時に1本立てるのがゲート2の合格条件）
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

# 開発途中の仕様変更（影響分析 → 意図の改訂を承認 → 伝播）
/change-spec [変更内容]

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
[3] pattern-scout サブエージェントが既存の命名規則・パターンを調査（圧縮ブリーフだけを
    本体に返し、実装ループのコンテキストを節約。境界違反パターンは「踏襲禁止」と報告）
[4] tasklist.md を「振る舞い単位」で具体化
[5] 各振る舞いを 🔴Red→🟢Green→🔵Refactor で実装（テストはループ内で走る）
[6] implementation-validator サブエージェントで品質検証
[7] スイート全体の回帰 → Lint → 型チェック → アーキ境界検査（失敗は自分で修正）
[8] 振り返りを tasklist.md に記載し、描写ドキュメントを育てる
    └ functional-design.md に実装機能を追記／glossary.md に新用語を追記
       backlog.md の該当行を [x] 完了に更新（着手時に [-] 実装中になっている）
    └ drift-auditor サブエージェントが育てた描写と実コードの乖離を監査（嘘があれば
       ドキュメント側を修正。描写の鮮度を機械で守る）
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

開発が始まった後に「作るもの」自体を変えたくなったら `/change-spec` です。実装済み・実装中の機能への影響を分析し、意図（PRD・アーキ芯）の改訂案を承認ゲートに出してから、バックログと進行中の作業計画へ変更を伝播します（「やっぱり期限は必須にしたい」のような会話からも自動で起動します）。

```bash
> /change-spec タスクの期限をオプションから必須に変更
```

### 補足: バンドル済みスキルの併用

このテンプレート独自のフロー（`/setup-project`・`/add-feature`）に加えて、Claude Code 標準の
バンドルスキルを組み合わせると効果的です。

- `/add-feature` の実装後、追加のコードレビューが欲しいときは `/code-review`
- 反復的な修正・調査を回したいときは `/loop`、原因調査には `/debug`

これらは `/` メニューから直接呼び出せます（本テンプレートの設定変更は不要）。

### 補足: MCP サーバー

`.mcp.json` で3つの MCP サーバーを定義しています（初回接続時に承認を求められます）。

```
 フロー                              MCP                効果
──────────────────────────────────────────────────────────────────────
 Walking Skeleton / 実装ループ       Context7           バージョン一致の最新
   ライブラリ・フレームワーク利用      (HTTP・依存なし)    公式docsを取得し、古い
                                                        APIの幻覚を防ぐ
 /add-feature の既存パターン把握     Serena             LSPベースのシンボル検索。
   （コードが育ってから効く）          (要 uv)            Grep より正確な参照追跡
 検証・動作確認                      Playwright         ヘッドレスブラウザ操作。
   （Webプロジェクトの場合）           (要 Node.js)       CI・devcontainer 内でも動く
──────────────────────────────────────────────────────────────────────
```

選定の規律は本文と同じです: **描写は真実でなければ毒**。モデルの記憶にある古いライブラリ知識は「詳細な嘘」になり得るため、Context7 で現物のdocsを取得します。一方、`gh` CLI で足りる GitHub 操作などに MCP は追加しません（ツール定義はコンテキストを消費するため、最小セットに絞っています）。

Serena・Playwright はローカルに `uv`・`Node.js` が必要です（`.devcontainer/devcontainer.json` には組み込み済み）。不要なら `.mcp.json` から該当エントリを削除してください。

## rules による規律の配置

プロジェクトの規律は CLAUDE.md に一枚岩で書かず、`.claude/rules/` に**1ファイル1トピック**で分割しています（Claude Code の [rules 機構](https://code.claude.com/docs/en/memory)）。ロード条件を使い分けることで、特定の場面でしか要らない規律を常時コンテキストの外に置けます（常時ロードの2ファイルは旧 CLAUDE.md と同格に毎セッション載るため、分割そのものは常時ロード量を減らしません。効くのは `paths` によるスコープです）。

```
                     ┌─ 常時ロード（CLAUDE.md と同格・毎セッション）
                     │   spec-driven-workflow.md   承認ゲートの方針（正本）ほか
                     │   document-management.md    意図と描写の分離（正本）ほか
 .claude/rules/ ─────┤
                     └─ パス条件付き（該当ファイルを扱う時だけロード）
                         docs-hygiene.md          paths: docs/**
                         config-maintenance.md    paths: .claude/**, scripts/**
```

この分割には副次効果があります。スキルからの「正本」参照が**ファイルパス＋見出し**の形になるため、参照切れを `check-config.sh`（下記）が機械検出できます。ファイルのリネームはリンク検査が、`` `ファイルパス.md`「見出し」`` 形式で引用した見出しのリネームは見出し検査が捕まえ、静かな断線が検出可能な故障に変わります。

- 規律を足すときは `.claude/rules/` に新しいトピックファイルを追加する（CLAUDE.md には書かない）
- 特定の場所でだけ効かせたい規律は `paths` フロントマターでスコープする（例: 利用者プロジェクトで `src/domain/**` にレイヤ境界の規律を張る）
- CLAUDE.md に残るのは、利用者がプロジェクトごとに記入する「技術スタック」のみ

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
- `.claude/` 配下（rules / skills / agents）のフロントマターが正しい（`---` が閉じている・キーが許可リスト内。CRLF 保存でも検査が働く）
- `` `ファイルパス.md`「見出し」`` 形式で参照される見出しが参照先に実在する（見出しリネームによる断線も検出）

スキル・エージェント・ガイドをリネーム・削除したのに参照が古いまま、という「リンク切れ」を防ぎます。「正本（Single Source of Truth）」の網はファイル間参照で編まれているため、その断線は機械で検出します。

検査スクリプト自身も `scripts/tests/run-tests.sh`（依存ゼロの純 bash）で回帰テストされ、CI で毎回実行されます。

## 並列開発と夜間バッチ運用

`docs/backlog.md` の「依存」列と git worktree を組み合わせると、複数機能を安全に並列実装できます。並列可能かどうかは人が推測せず、機械が判定します（`bash scripts/progress.sh` が「並列着手可能」を列挙し、依存違反を警告します）。

```
docs/backlog.md
| # | 機能     | 依存   | 状態        |
| 1 | 認証     | -      | [x] 完了    |
| 2 | プロフィール | 認証 | [ ] 未着手  | ─┐ 依存が満たされた未着手
| 3 | 通知     | 認証   | [ ] 未着手  | ─┤ → worktree を切って並列に着手できる
| 4 | 課金     | 通知   | [ ] 未着手  |   （課金は通知の完了待ち）

 main ──┬── worktree A（feat/profile）… claude で /add-feature プロフィール
        └── worktree B（feat/notify） … claude で /add-feature 通知
             ↓ それぞれ完了後 main へマージ（.steering/ は gitignore なので衝突しない）
```

```bash
# 1. 並列着手できる機能を機械判定
bash scripts/progress.sh          # 「並列着手可能: プロフィール、通知」

# 2. 機能ごとに worktree を切り、別セッションで /add-feature を実行
git worktree add ../myapp-profile -b feat/profile
git worktree add ../myapp-notify  -b feat/notify
(cd ../myapp-profile && claude --permission-mode acceptEdits "/add-feature プロフィール")
(cd ../myapp-notify  && claude --permission-mode acceptEdits "/add-feature 通知")

# 3. 完了後にマージして片付け
git merge feat/profile && git merge feat/notify
git worktree remove ../myapp-profile ../myapp-notify
```

**夜間バッチ運用**: `/add-feature` は無停止設計（承認ゲートは意図の変更時のみ）なので、ヘッドレスで夜に回して朝レビューできます。`claude -p "/add-feature 通知"` をスケジューラ（cron / CI の schedule トリガー / Claude Code の `/schedule`）から起動するだけです。翌朝は `bash scripts/progress.sh --since <昨日の日付>` で「昨夜完了した振る舞い」を確認し、`/code-review` を掛けてからマージします。

## 規律の機械的強制（hooks）

規律を文書の「お願い」で終わらせず、hooks（`settings.json`）で決定論的に強制します。編集・停止のライフサイクルに検査が張り付いているため、違反はその瞬間に検出されます:

```
 Edit/Write 前 ──▶ pre-edit-backlog.sh   backlog の状態列の直接変更をブロック
 │                                       （正規経路: scripts/backlog-state.sh）
 Edit/Write 後 ─┬▶ post-edit-config.sh   .claude/・scripts/ 編集 → check-config.sh を即実行
 │             └▶ post-edit-docs.sh     docs/ 編集 → check-drift.sh --quick を即実行
 │                                       （「詳細な嘘」を書いた瞬間に検出）
 応答の停止前 ──▶ stop-freshness.sh      progress.sh の鮮度検査。乖離があれば一度だけ
                                         差し戻す（stop_hook_active で無限ループは防止）
```

- フックは入力 JSON の解析に `jq` を使います（devcontainer には同梱。無い環境では検査をスキップして許可する fail-open）
- `docs/backlog.md` の状態列は `bash scripts/backlog-state.sh start|done|split` だけが更新できます（`/add-feature` もこれを使う。`split` は計画時に機能が大きすぎた場合の縦切り分割を backlog に反映する）
- 描写ドキュメントの機械検査は単体でも実行できます: `bash scripts/check-drift.sh`（パス実在は ❌、用語の生存は ⚠️。意味的な乖離は `drift-auditor` サブエージェントが担当）

## ライセンス

MIT License（`LICENSE` を参照）
