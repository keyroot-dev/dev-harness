# リポジトリ構造定義書作成ガイド

## 基本原則

### 1. 役割の明確化

各ディレクトリは単一の明確な役割を持つべきです。

**悪い例**:
```
src/
├── stuff/           # 曖昧
├── misc/            # 雑多
└── utils/           # 汎用的すぎる
```

**良い例**:
```
src/
└── task-management/     # 機能領域（何のシステムかを叫ぶ）
    ├── entities/        # ドメインの不変条件
    ├── use-cases/       # アプリ固有ルール + 境界I/F
    ├── adapters/        # Controller / Presenter / CLI
    └── infrastructure/  # DB/FS実装（DIPでI/Fを実装）
```

### 2. トップは機能、内側がレイヤー（Screaming Architecture）

トップレベルを `ui/ services/ repositories/` という**技術レイヤー**で切ると、構造は
「MVCフレームワークです」としか叫ばない。トップは**ユースケース／機能領域**で切り、
レイヤー（entities / use-cases / adapters / infrastructure）はその**内側**に置く。

```
src/
├── task-management/        # ← "タスク管理システム" と叫ぶ
│   ├── entities/
│   ├── use-cases/
│   ├── adapters/
│   └── infrastructure/
└── archiving/              # 機能が増えたら領域を足す
    └── …
```

> `architecture.md` の依存性のルール（依存はすべて内向き）と構造を一致させるための分割です。

### 3. レイヤー優先は「機能が1つの間」だけの暫定形

機能が1つしかない小さなCLI等では、`src/` 直下に `entities/ use-cases/ adapters/ infrastructure/`
を置く「レイヤー優先」でも構いません。ただし**2つ目の機能が現れた時点で機能優先へ移行**します。

**レイヤーの対応（クリーンアーキテクチャの輪）**:
```
最も内側  entities/        … ドメインの不変条件（何にも依存しない）
          use-cases/       … アプリ固有ルール + 境界I/F（Repository等）を所有
          adapters/        … Controller / Presenter / CLI（外形↔内形の変換）
最も外側  infrastructure/  … DB/FS/Web の詳細（use-cases のI/Fを実装する＝DIP）
```

> ❌ `services/`（複数形・技術レイヤー）をトップに置かない。技術が主役になり Screaming Architecture に反する。

## ディレクトリ構造の設計

### 機能領域 × レイヤーの表現

```typescript
// 悪い例1: 平坦な構造（責務が混在）
src/
├── TaskCLI.ts
├── TaskService.ts
├── TaskRepository.ts
└── UserRepository.ts

// 悪い例2: トップが技術レイヤー（"何のシステムか" を叫ばない）
src/
├── cli/
├── services/
└── repositories/

// 良い例: トップは機能領域、内側がレイヤー（依存は内向き）
src/
├── task-management/
│   ├── entities/        Task.ts
│   ├── use-cases/       CreateTask.ts / TaskRepository.ts（I/F）
│   ├── adapters/        TaskController.ts
│   └── infrastructure/  FileTaskRepository.ts（I/Fを実装）
└── user-management/
    ├── entities/        User.ts
    ├── use-cases/       AuthenticateUser.ts
    └── …
```

### テストディレクトリの配置

**推奨構造**:
```
project/
├── src/
│   └── task-management/
│       └── use-cases/
│           └── CreateTask.ts
└── tests/
    ├── unit/
    │   └── task-management/
    │       └── use-cases/
    │           └── CreateTask.test.ts
    ├── integration/
    └── e2e/
```

**理由**:
- テストコードが本番コードと分離
- ビルド時にテストを除外しやすい
- テストタイプごとに整理可能

## 命名規則のベストプラクティス

### ディレクトリ名の原則

**1. 機能領域はドメインの言葉で（トップレベル）**
```
✅ task-management/
✅ user-authentication/
✅ archiving/

❌ services/        # トップに技術レイヤーを置かない
❌ controllers/
```

理由: トップが「何のシステムか」を叫ぶように（Screaming Architecture）

**1b. 内側のレイヤーは輪の名前に揃える**
```
✅ entities/  use-cases/  adapters/  infrastructure/

❌ services/  repositories/  controllers/  # MVC由来の技術レイヤー名
```

理由: `architecture.md` のクリーンアーキテクチャの輪と一致させ、依存方向を読み取りやすくするため

**2. kebab-caseを使う**
```
✅ task-management/
✅ user-authentication/

❌ TaskManagement/
❌ userAuthentication/
```

理由: URL、ファイルシステムとの互換性

**3. 具体的な名前を使う**
```
✅ validators/       # 入力検証
✅ formatters/       # データ整形
✅ parsers/          # データ解析

❌ utils/            # 汎用的すぎる
❌ helpers/          # 曖昧
❌ common/           # 意味不明
```

### ファイル名の原則

**1. クラスファイル: PascalCase。ユースケースは動詞、境界I/Fと実装は役割で**
```typescript
// ✅ ユースケース: 動詞（ユーザーが何をしたいか）。"Service" でひとまとめにしない
//    use-cases/
CreateTask.ts
CompleteTask.ts
AuthenticateUser.ts

// ✅ 境界インターフェース（use-cases が所有する契約）
//    use-cases/
TaskRepository.ts      // interface
ArchiveRepository.ts   // interface

// ✅ 詳細（infrastructure / adapters）: I/Fを実装する具象には「何で実装したか」を冠する
//    infrastructure/   FileTaskRepository.ts / SqliteTaskRepository.ts
//    adapters/         TaskController.ts / TaskCliPresenter.ts

// ❌ 避ける: TaskService.ts / TaskManager.ts
//    「何をする」かを叫ばず、複数のユースケースを1クラスに溜め込む温床になる
```

**2. 関数ファイル: camelCase + 動詞で始める**
```typescript
// ユーティリティ関数
formatDate.ts
validateEmail.ts
parseCommandArguments.ts
```

**3. 型定義ファイル: PascalCase または kebab-case**
```typescript
// インターフェース定義
Task.ts
UserProfile.ts

// 型定義集
task-types.d.ts
api-types.d.ts
```

**4. 定数ファイル: UPPER_SNAKE_CASE または kebab-case**
```typescript
// 定数定義
API_ENDPOINTS.ts
ERROR_MESSAGES.ts

// または
api-endpoints.ts
error-messages.ts
```

## 依存関係の管理

### レイヤー間の依存ルール（依存はすべて内向き）

> 📌 **依存性のルールの正本は `architecture-design/guide.md` §2。** ここではその規則を**ディレクトリ構造・import に適用**する（規則そのものを再定義しない）。規則の意味を変えるときは正本を直す。

依存方向の図と Do/Don't（古典レイヤードの罠・DIP の解説）は**正本（§2）に一元化**されている。
ここで確認するのは、その規則が**ディレクトリ間の import にどう現れるか**だけだ ──
import の矢印は必ず外側のディレクトリ（adapters / infrastructure）から内側（use-cases → entities）へ向く。

```typescript
// ✅ 良い例: 外側 → 内側（内向き）
// adapters/TaskController.ts
import { CreateTask } from '../use-cases/CreateTask';

// ✅ 良い例: DIP — infrastructure が use-cases のI/Fを実装（依存は内向き）
// infrastructure/FileTaskRepository.ts
import { TaskRepository } from '../use-cases/TaskRepository'; // I/Fは use-cases 側が所有
export class FileTaskRepository implements TaskRepository { /* ... */ }

// ❌ 悪い例: 内側 → 外側（外向き依存は禁止）
// use-cases/CreateTask.ts
import { FileTaskRepository } from '../infrastructure/FileTaskRepository'; // 禁止！詳細に依存している
// entities/Task.ts
import { TaskController } from '../adapters/TaskController'; // 禁止！心臓部は何にも依存しない
```

> **この依存方向は Lint/CI で機械的に強制する**（`development-guidelines.md` の「アーキテクチャ境界の強制」参照）。

### 循環依存の回避

機能領域をまたぐ循環（`task-management` ⇄ `user-management`）は ADP 違反だ。解決の鍵は**依存性逆転（DIP）**：必要な契約を**呼ぶ側のユースケース層に置き、相手はそれを実装する**。

**問題のあるコード**:
```typescript
// task-management/use-cases/AssignTask.ts
import { GetUser } from '../../user-management/use-cases/GetUser'; // 機能領域またぎ → 禁止

// user-management/use-cases/NotifyUser.ts
import { GetTask } from '../../task-management/use-cases/GetTask'; // 逆向きにも依存 → 循環！
```

**解決策1: 必要な契約を呼ぶ側の use-cases に置く（DIP で内向きに）**
```typescript
// task-management/use-cases/UserDirectory.ts ── task 側が「自分が欲しい契約」を所有する
export interface UserDirectory {
  findName(userId: string): Promise<string | null>;
}

// task-management/use-cases/AssignTask.ts ── 抽象にのみ依存。user-management を import しない
export class AssignTask {
  constructor(private readonly users: UserDirectory) {}
}

// user-management/adapters/UserDirectoryAdapter.ts ── 実装は user 側が外側で提供（依存は内向き）
import { UserDirectory } from '../../task-management/use-cases/UserDirectory';
export class UserDirectoryAdapter implements UserDirectory { /* GetUser を呼ぶ */ }
```
矢印が両方とも `task-management/use-cases` の抽象へ内向きに向き、循環が消える。

**解決策2: 共有の純粋な関心事は `shared/` に抽出する**
```typescript
// shared/notification/Notifier.ts ── ドメイン非依存の横断的関心事だけを置く
export interface Notifier {
  notify(userId: string, message: string): Promise<void>;
}
```
両機能領域は `shared/` の抽象に依存する（`shared/` は誰も逆に import しないので循環しない）。
ビジネスルールやエンティティは `shared/` に置かないこと（それは特定の機能領域に属する）。

## スケーリング戦略

### 推奨構造

**標準パターン（機能領域 × レイヤー）**:
```
src/
├── task-management/
│   ├── entities/        Task.ts
│   ├── use-cases/       CreateTask.ts / CompleteTask.ts / TaskRepository.ts（I/F）
│   ├── adapters/        TaskController.ts
│   └── infrastructure/  FileTaskRepository.ts
├── user-management/
│   ├── entities/        User.ts
│   ├── use-cases/       AuthenticateUser.ts
│   └── …
├── shared/              # 機能横断の純粋な共有物のみ（型・ユーティリティ）
└── index.ts             # 構成ルート（Composition Root）: 具象を new し注入する唯一の場所
```

**理由**:
- トップが「何のシステムか」を叫ぶ（Screaming Architecture）
- 依存方向（内向き）が構造から読み取れる
- 機能領域ごとに独立してテスト・変更でき、影響範囲が閉じる

> **`index.ts` は構成ルート（Composition Root）** ── `FileTaskRepository` 等の具象を `new` し、
> 内側へ注入するのはここ**だけ**。use-cases / adapters / entities は依存を受け取り、自分で生成しない。
> 「詳細が詳細に出会う（adapter が infrastructure の具象に触れる）」のもここに閉じ込める。
> 詳細は `architecture.md` の「構成ルート」節を参照。

### モジュール分離のタイミング

**分離を検討する兆候**:
1. ディレクトリ内のファイル数が10個以上
2. 関連する機能がまとまっている
3. 独立してテスト可能
4. 他の機能への依存が少ない

**分離の手順**:
```text
// Before: レイヤー優先（機能が1つの間だけの暫定形）。2つ目の機能が混ざり始めた合図。
src/
├── entities/        Task.ts / User.ts
├── use-cases/       CreateTask.ts / CompleteTask.ts / AuthenticateUser.ts
├── adapters/        TaskController.ts
└── infrastructure/  FileTaskRepository.ts

// After: 機能領域 × レイヤー（トップが "何のシステムか" を叫ぶ）
src/
├── task-management/
│   ├── entities/        Task.ts
│   ├── use-cases/       CreateTask.ts / CompleteTask.ts / TaskRepository.ts（I/F）
│   ├── adapters/        TaskController.ts
│   └── infrastructure/  FileTaskRepository.ts
└── user-management/
    ├── entities/        User.ts
    └── use-cases/       AuthenticateUser.ts
```

> ❌ `modules/task/TaskService.ts` のように、技術レイヤー名（`services/`）や「Service」接尾辞へ退避しない。
> 分離後も内側は `entities/ use-cases/ adapters/ infrastructure/` の輪に揃え、ユースケースは動詞で命名する。

## 特殊なケースの対応

### 共有コードの配置

**shared/ ディレクトリ**
```
src/
├── shared/              # 機能横断の純粋な共有物のみ
│   ├── utils/           # 汎用ユーティリティ
│   ├── types/           # 共通型定義
│   └── constants/       # 共通定数
├── task-management/
└── user-management/
```

**ルール**:
- 本当に複数の機能領域で使われる、純粋（ドメイン非依存）なもののみ
- 特定機能でしか使わないものは、その機能領域の中に置く
- `shared/` にビジネスルールやドメインエンティティを置かない（機能領域に属させる）

### 設定ファイルの管理(該当する場合)

```
config/
├── default.ts           # デフォルト設定
└── constants.ts         # 定数定義
```

### スクリプトの管理(該当する場合)

```
scripts/
├── build.sh             # ビルドスクリプト
└── dev-tools.ts         # 開発補助スクリプト
```

## ドキュメント配置

### ドキュメントの種類と配置先

**プロジェクトルート**:
- `README.md`: プロジェクト概要
- `CONTRIBUTING.md`: 貢献ガイド
- `LICENSE`: ライセンス

**docs/ ディレクトリ**:
- `product-requirements.md`: PRD
- `functional-design.md`: 機能設計書
- `architecture.md`: アーキテクチャ設計書
- `repository-structure.md`: 本ドキュメント
- `development-guidelines.md`: 開発ガイドライン
- `glossary.md`: 用語集

**ソースコード内**:
- TSDoc/JSDocコメント: 関数・クラスの説明

## チェックリスト

- [ ] 各ディレクトリの役割が明確に定義されている
- [ ] トップレベルが機能領域で切られている（Screaming Architecture / `services/` 等の技術レイヤーをトップに置いていない）
- [ ] 内側のレイヤーが輪の名前（entities/use-cases/adapters/infrastructure）に揃っている
- [ ] 依存方向が内向き（外側→内側）で、infrastructure がDIPで内側のI/Fを実装している
- [ ] 依存方向がLint/CIで機械的に強制されている
- [ ] 命名規則が一貫している
- [ ] テストコードの配置方針が決まっている
- [ ] 循環依存がない
- [ ] スケーリング戦略が考慮されている
- [ ] 共有コードの配置ルールが定義されている
- [ ] 設定ファイルの管理方法が決まっている
- [ ] ドキュメントの配置場所が明確である
