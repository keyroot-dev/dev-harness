# アーキテクチャ設計ガイド

> 本ガイドの技術選定例（Node.js / TypeScript など）は、原則を説明するための**例示**です。実際の設計ではプロジェクトの言語・スタックに置き換えてください。

## 基本原則

### 1. 技術選定には理由を明記

**悪い例**:
```
- Node.js
- TypeScript
```

**良い例**:
```
- Node.js v24.11.0 (LTS)
  - 2026年4月までの長期サポート保証により、本番環境での安定稼働が期待できる
  - 非同期I/O処理に優れ、APIサーバーとして高いパフォーマンスを発揮
  - npmエコシステムが充実しており、必要なライブラリの入手が容易

- TypeScript 5.x
  - 静的型付けによりコンパイル時にバグを検出でき、保守性が向上
  - IDEの補完機能が強力で、開発効率が高い
  - チーム開発における型定義の共有により、コードの可読性と品質が担保される

- npm 11.x
  - Node.js v24.11.0に標準搭載されており、別途インストール不要
  - workspaces機能によりモノレポ構成に対応
  - package-lock.jsonによる依存関係の厳密な管理が可能
```

### 2. 依存性のルール（クリーンアーキテクチャの絶対原則）

> 🧭 **依存性のルールの正本（Single Source of Truth）。** このリポジトリにおける「依存方向の定義・図・Do/Don't」は、**この節一箇所で定義する**。
> 他のスキル・コマンド・エージェント（`repository-structure` / `development-guidelines` / `implementation-validator` / `add-feature` 等）は、この規則を**再定義せず参照し、各自の文脈に適用するだけ**にする。
> 規則の表現を見直すときは、必ずこの節だけを変更すればよい状態に保つこと。
> （`template.md` の図は**生成される `docs/architecture.md` を自己完結させるための出力用**であり、規則の二重定義ではない。規則の意味を変えるならここを直す。）
>
> 🔧 **執行機構の雛形**: この規則を Lint/CI で機械強制するための言語別サンプル設定（dependency-cruiser / import-linter / depguard / ArchUnit）は `templates/fitness/README.md` にある。Walking Skeleton の時点でそこから1本立てる（承認ゲート2の合格条件）。

**ソースコードの依存は、必ず内側（高レベルの方針）に向ける。** 外側（詳細）が内側に依存し、内側は外側を一切知らない。これがクリーンアーキテクチャの唯一にして最重要のルールです。

```
┌────────────────────────────────────────────┐
│ Frameworks & Drivers (最も外側 = 詳細)        │  DB / CLI / Web / FS
│  ┌──────────────────────────────────────┐  │
│  │ Interface Adapters                    │  │  Controller / Presenter
│  │  ┌────────────────────────────────┐  │  │  Repository実装
│  │  │ Use Cases (Interactor)         │  │  │
│  │  │  «interface» Repository ◄───────┼──┼──┼─ I/FはUse Case側が所有
│  │  │  ┌──────────────────────────┐  │  │  │
│  │  │  │ Entities (心臓部)         │  │  │  │  ドメインの不変条件
│  │  │  └──────────────────────────┘  │  │  │
│  │  └────────────────────────────────┘  │  │
│  └──────────────────────────────────────┘  │
└────────────────────────────────────────────┘
        依存はすべて内向き ───→ 中心へ
```

**やってはいけないこと（古典レイヤードの罠）**:

```
UI → UseCase → Data (NG)   ← ビジネスルールが「詳細」のDBに依存している
```

ビジネスルール（UseCase / Entities）がDBやファイルI/Oに依存してはいけません。DB・Web・フレームワークはすべて**詳細**であり、ビジネスルールが「使う」道具であって「従う」主人ではありません。

**正しい形（依存性逆転 = DIP）**:

```
UI → UseCase ← Data (OK)   ← Dataが、UseCaseの所有するI/Fを実装する
```

Repositoryの**インターフェースはUseCase層が定義**し、**実装はData層（最も外側）が提供**します。矢印が `Data → UseCase` と内向きに逆転することで、DBを差し替えてもビジネスルールは1行も変わりません。

### 3. 詳細の決定は最後まで遅延させる（Screaming Architecture）

アーキテクチャは「何のシステムか」を叫ぶべきで、「何のフレームワークか」を叫んではいけません。

```
NG: "Node.js + TypeScript のプロジェクトです"   ← フレームワークが主役
OK: "タスク管理システムです (create/complete/archive)"  ← ユースケースが主役
```

技術選定（言語・DB・フレームワーク）は重要ですが、**最初に決めることではなく、最後まで遅延させられる決定**として扱います。良いアーキテクチャは、DBやフレームワークを「あとで差し替えられる」状態に保ちます。技術選定の理由付け（原則1）は必要ですが、ドメインモデルとユースケースを定義した**後**に行ってください。

### 4. 測定可能な要件

すべてのパフォーマンス要件は測定可能な形で記述します。

## クリーンアーキテクチャの設計

### 各層の責務（依存は内向き）

**Entities（心臓部 / 最も内側）**:
```typescript
// 責務: 企業全体で通用する最高レベルのビジネスルールと不変条件。
//       Taskは「データ構造」ではなく、自身のルールを守る「振る舞いを持つオブジェクト」。
class Task {
  private constructor(
    readonly id: TaskId,
    readonly title: string,
    readonly completed: boolean,
  ) {}

  // 不変条件はエンティティ自身が守る（外部のvalidate関数に漏らさない）
  static create(id: TaskId, title: string): Task {
    if (title.length === 0 || title.length > 200) {
      throw new ValidationError('タイトルは1〜200文字で入力してください');
    }
    return new Task(id, title, false);
  }

  complete(): Task {
    if (this.completed) {
      throw new DomainError('完了済みのタスクは再度完了できません');
    }
    return new Task(this.id, this.title, true);
  }
}
```

**Use Case（Interactor）**:
```typescript
// 責務: アプリケーション固有のビジネスルール。動詞（ユーザーが何をしたいか）で命名する。
//       依存するのは「自分が所有するインターフェース」だけ。具体的なDBは知らない。

// 境界を外向きに越えるデータは「DTO（出力モデル）」にする。Entityは境界の外へ出さない。
interface CreateTaskOutput {
  readonly id: string;
  readonly title: string;
}

class CreateTask {
  // 依存するのは抽象（TaskRepository インターフェース）。実装は注入される。
  constructor(private readonly repository: TaskRepository) {}

  async execute(input: CreateTaskInput): Promise<CreateTaskOutput> {
    const task = Task.create(TaskId.generate(), input.title);
    await this.repository.save(task);
    // Entityそのものではなく、外側が必要とする形（DTO）に詰め替えて返す
    return { id: task.id.value, title: task.title };
  }
}
```

> **境界を越えるデータ規則**: Entity を Use Case の外（Controller/CLI/Web）へ素通しで渡さない。
> Entity を漏らすと、内側のドメイン変更が外側を直接壊し、依存方向が事実上逆流する。
> 境界をまたぐ入出力は必ず単純なDTO（データ構造）に詰め替える。

**Repository インターフェース（境界 / UseCase層が所有）**:
```typescript
// 責務: 内側が外側に求める「契約」を定義する。実装はここには書かない。
//       このインターフェースはUseCase層に属し、DataレイヤーがDIPで実装する。
interface TaskRepository {
  save(task: Task): Promise<void>;
  findById(id: TaskId): Promise<Task | null>;
}
```

**Interface Adapters（Controller / 最も外側に近い）**:
```typescript
// 責務: 外側の形式（CLI入力）を内側のユースケースが理解できる形に変換する。
class CLI {
  constructor(private readonly createTask: CreateTask) {}

  // OK: ユースケースを呼び出すだけ。ビジネスロジックも永続化も持たない。
  //     受け取るのはDTO（CreateTaskOutput）であってEntityではない。
  async addTask(title: string) {
    const output = await this.createTask.execute({ title });
    console.log(`Created: ${output.id}`);
  }
}
```

**Frameworks & Drivers（詳細 / 最も外側）**:
```typescript
// 責務: DB・ファイルI/Oなどの「詳細」。UseCase層のインターフェースを実装する（DIP）。
//       依存の矢印は Data → UseCase（内向き）。
class FileTaskRepository implements TaskRepository {
  async save(task: Task): Promise<void> {
    await this.storage.write(task);
  }
  async findById(id: TaskId): Promise<Task | null> {
    return this.storage.read(id);
  }
}
```

## 構成ルート（Composition Root / Main）── 詳細が詳細に出会う唯一の場所

依存はすべてコンストラクタで注入する（上記の例はすべてそうなっている）。では**その依存グラフを誰が配線するのか**。それが「構成ルート」だ。Mainはクリーンアーキテクチャで**最も外側・最も汚いコンポーネント**であり、具象を `new` してよい**唯一の場所**である。

```
              ┌────────── Main / index.ts（構成ルート・最外周）──────────┐
              │ ここだけが具象を new し、内側へ注入する                     │
              │   const repo = new FileTaskRepository(storage); // 詳細    │
              │   const createTask = new CreateTask(repo);      // 注入    │
              │   const cli = new CLI(createTask);              // 注入    │
              └──────────────────────────────────────────────────────────┘
                         │ 配線された依存を内側へ渡すだけ
                         ▼
        adapters → use-cases → entities（各層は「自分が new する」ことをしない）
```

**やってはいけないこと**:
```typescript
// ❌ use-case や adapter の中で具象を new する → DIPを静かに破る
class CreateTask {
  private repository = new FileTaskRepository(); // 禁止！詳細に直結している
}
```

**ルール**:
- 具象（`FileTaskRepository` 等）を `new` してよいのは構成ルート（`index.ts` / `main`）**だけ**。
- use-cases / adapters / entities は、依存を**受け取る**（注入される）。自分で生成しない。
- 「詳細が詳細に出会う（adapter が infrastructure の具象に触れる）」のも構成ルートに閉じ込める。これは機械強制する（`development-guidelines.md` のFitness Function参照）。

> ⚠️ **これは循環参照ではない（DIPである）**: 依存性の「規則そのもの（方針）」はこのアーキテクチャ文書が**所有**し、その「執行機構（dependency-cruiser 設定等の詳細）」は外側の `development-guidelines.md` が**提供**する。規則が変われば設定を直す ── 依存は機構→規則の**内向き**だ。相互に名前が出てくるが、変更の依存方向は一方向であり、ADP違反（循環）ではない。

## コンポーネント原則（円の中だけでなく「塊」の設計）

クリーンアーキテクチャは4つの輪（依存性のルール）だけではない。複数のクラスを束ねた
**コンポーネント（モジュール／パッケージ／デプロイ単位）**の凝集と結合にも原則がある。
機能領域（`task-management/` 等）をどう切り、どう依存させるかの判断基準として使う。

### 凝集性 ── 何を1つのコンポーネントに入れるか

```
REP (再利用・リリース等価) … リリースできる単位 = 再利用できる単位。バージョンを付けて束ねる
CCP (閉鎖性共通)          … 同じ理由で変わるものは1つに集める（SRPのコンポーネント版）
CRP (全再利用)            … 一緒に使わないものを同じコンポーネントに入れない
```

> 3つは互いに張り合う（テンション・トライアングル）。開発初期は **CCP寄り**（変更しやすさ優先）、
> 再利用が増えるにつれ **REP/CRP寄り** へ重心を移す。最初から完璧な分割を狙わない。

### 結合性 ── コンポーネント間の依存をどう張るか

```
ADP (非循環依存)  … コンポーネントの依存グラフに循環を作らない（DAGに保つ）
SDP (安定依存)    … 依存は「より安定した方向」へ向ける（変わりにくいものに依存する）
SAP (安定抽象)    … 安定したコンポーネントほど抽象的であれ（= 方針＝抽象、詳細＝具象）
```

```
   不安定・具象 (変えやすい)            安定・抽象 (変わりにくい)
   infrastructure / adapters  ──依存──▶  use-cases / entities
   （DB・Web・CLIの詳細）                  （方針・ビジネスルール）
            SDP: 矢印は安定の方へ ─────────▶  SAP: 安定の極は抽象の極
```

`entities` は最も安定し最も抽象的（方針）であるべきで、`infrastructure` は最も不安定で具象的（詳細）。
これが守られていれば、依存性のルールと自然に一致する。

> **循環依存（ADP違反）の検出**: import単位だけでなくコンポーネント単位でも循環を禁止する。
> `repository-structure.md` / `development-guidelines.md` の境界強制ツールで機械的に検査する。

## 品質特性（パフォーマンス／セキュリティ／スケーラビリティ）

> ⚠️ **以下は「方針」ではなく主に「詳細・運用関心事」だ。** アーキテクチャ文書の主役は
> 境界とユースケース（何のシステムか）であって、ベンチマーク値・chmod・semver方針ではない。
> これらは構造から「あとで差し替えられる詳細」として扱い、本来は `development-guidelines.md`
> （運用ガイドライン）に厚く書く。ここでは**測定可能な目標と原則だけ**を簡潔に示し、
> 詳細でアーキテクチャの声をかき消さないこと。依存関係管理の節（後述）と同じ刃を当てる。

### パフォーマンス（原則のみ）

アーキテクチャ視点で守るのは**一点**: 要件は**測定可能**な形にする（「速いこと」ではなく「操作Xは入力Nで目標T以内、測定方法は…」）。具体的なSLO表・ベンチ数値・測定環境は**詳細**であり、生成する `docs/architecture.md` の「パフォーマンス要件」表（測定可能な目標）と、`development-guidelines.md`（測定手順・ツール）に置く。本ガイドに版数や `console.time` のスニペットは書かない。

### セキュリティ（アーキテクチャに属する一点 = 入力検証の二層分離）

> chmod・環境変数・暗号化方式などの**運用手段は詳細**であり、正本は `development-guidelines.md`。ここに置くのは、**どこにルールが宿るか**という境界の話 ── これだけがアーキテクチャの関心事だ。

**入力検証は責務を二層に分け、ビジネスルールを外に漏らさない。**

ドメインの不変条件（「タイトルは1〜200文字」など）は**エンティティ自身**が守る（本ガイド冒頭の `Task.create` 参照）。これを外部の自由関数（`validateTitle`）に二重定義してはいけない。いずれ片方だけ変わってルールが食い違う。

外側（adapters / infrastructure）の入力検証は、**ドメインに到達する前の「信頼できない外形」を弾く**ことに限る ── 型・エンコーディング・サイズ上限（DoS対策の粗いガード）など、ドメインルールではない関心事だ。

```typescript
// 外側（adapter）: 信頼できない入力の「形」だけを守る。文字数=200 等のドメインルールは書かない。
function assertUntrustedString(raw: unknown): string {
  if (typeof raw !== 'string') throw new ValidationError('文字列が必要です');
  if (raw.length > 10_000) throw new ValidationError('入力が大きすぎます'); // 乱用防止の粗いガード
  return raw;
}

// ドメインルール（1〜200文字）はエンティティの中だけにある ── 単一の真実
const task = Task.create(TaskId.generate(), assertUntrustedString(input.title));
```

### スケーラビリティ（境界が効いていれば、後から差し替えられる）

データ量増加への具体策（ページネーション・アーカイブ・インデックス）は**詳細**だが、アーキテクチャ視点の要は「それらが**ユースケースと抽象（境界I/F）越し**に足せること」だ。下の例のように、新しいユースケースは動詞で命名し、具体的なストレージではなく**自分が所有するI/F**にのみ依存する ── これが守られていれば、保存先や索引方式は後から差し替えられる。

```typescript
// アーカイブ機能の例: ユースケースは動詞で命名し、抽象（インターフェース）にのみ依存する
class ArchiveCompletedTasks {
  constructor(
    private readonly repository: TaskRepository,
    private readonly archive: ArchiveRepository, // どちらもUseCase層が所有するI/F
  ) {}

  async execute(olderThan: Date): Promise<void> {
    const oldTasks = await this.repository.findCompleted(olderThan);
    await this.archive.save(oldTasks);
    await this.repository.deleteMany(oldTasks.map(t => t.id));
  }
}
```

## 依存関係管理

> ⚠️ **これは「詳細」であって「方針」ではない。** ライブラリのバージョン固定方針（semver の `^` / `~` / 完全固定の使い分け、lockfile 運用）は最も外側の運用関心事であり、**正本は `development-guidelines.md`（運用ガイドライン）に置く**。アーキテクチャ文書の主役は境界とユースケース（何のシステムか）なので、ここに具体的な版数表は書かない。
>
> アーキテクチャ視点で確認すべきは**一点だけ**: 外部ライブラリへの依存が**内側（entities / use-cases）に染み出していないか**（ライブラリ型をドメインに持ち込んでいないか）。版数の管理表は運用ガイドラインへ。

## チェックリスト

- [ ] ドメインモデル（Entities）とユースケースが、技術選定より先に定義されている
- [ ] 依存性のルールが守られている（依存はすべて内向き / ビジネスルールがDB・FWに依存していない）
- [ ] **依存方向がLint/CIで機械的に強制されている**（違反でビルドが落ちる。ドキュメントの「禁止」だけで終わらせない）
- [ ] Repository等の境界インターフェースをUseCase層が所有し、Data層がDIPで実装している
- [ ] 具象の生成（`new`）が構成ルート（`index.ts`/`main`）に閉じており、内側の層が自分で詳細を生成していない
- [ ] 境界を外向きに越えるデータがDTO（出力モデル）になっている（Entityを外側に漏らしていない）
- [ ] アーキテクチャが「何のシステムか」を叫んでいる（Screaming Architecture）
- [ ] コンポーネント分割が凝集性原則（REP/CCP/CRP）を踏まえている
- [ ] コンポーネント依存が非循環（ADP）で、安定・抽象の方向（SDP/SAP）に向いている
- [ ] 技術選定（言語・DB・FW）が「遅延可能な詳細」として扱われ、各選定に理由が記載されている
- [ ] パフォーマンス要件が測定可能である
- [ ] セキュリティ: 入力検証が二層に分離されている（ドメインの不変条件はエンティティが所有し、外側は「信頼できない外形」だけを弾く）
- [ ] スケーラビリティ: 具体策が境界I/F越しに追加できる形になっている（ユースケースが抽象にのみ依存）
- [ ] 運用詳細（バックアップ戦略・依存バージョン管理・chmod等）がアーキ文書に混入せず、`development-guidelines.md` に委譲されている
- [ ] テスト戦略が定義されている（ビジネスルールがFW・DBなしで単体テストできる）