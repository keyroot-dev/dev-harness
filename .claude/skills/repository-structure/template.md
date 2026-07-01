# リポジトリ構造定義書 (Repository Structure Document)

> **構造の第一原則: ディレクトリは "何のシステムか" を叫べ（Screaming Architecture）**
> トップレベルを `services/ controllers/ repositories/` のような**技術レイヤー**で切ると、
> 構造は「MVCフレームワークです」としか叫ばない。トップは**ユースケース／機能領域**で切り、
> レイヤー（entities / use-cases / adapters / infrastructure）はその**内側**に置く。
> これにより `architecture.md` の依存性のルール（依存はすべて内向き）と構造が一致する。

## プロジェクト構造

```
project-root/
├── src/                       # ソースコード（トップは "機能領域" で切る）
│   ├── [feature-a]/           # 例: task-management ── 何のシステムかを叫ぶ
│   │   ├── entities/          # 心臓部: ドメインの不変条件（外側を一切importしない）
│   │   ├── use-cases/         # アプリ固有ルール + 境界I/F（Repository等）を所有
│   │   ├── adapters/          # Controller / Presenter（外形↔内形の変換）
│   │   └── infrastructure/    # 詳細: DB/FS実装。use-cases のI/Fを実装する（DIP）
│   ├── [feature-b]/           # 例: archiving
│   │   └── …
│   └── shared/                # 機能横断の純粋な共有物（型・ユーティリティのみ）
├── tests/                     # テストコード
│   ├── unit/                  # ユニットテスト（entities/use-cases はFW無しで通る）
│   ├── integration/           # 統合テスト
│   └── e2e/                   # E2Eテスト
├── docs/                      # プロジェクトドキュメント
├── config/                    # 設定ファイル
└── scripts/                   # ビルド・デプロイスクリプト
```

> **レイヤー優先 vs 機能優先**: 小さなCLI等で機能が1つしかないうちは、`src/` 直下に
> `entities/ use-cases/ adapters/ infrastructure/` を置く「レイヤー優先」でもよい。
> ただし**機能が2つ目に増えた時点で機能優先へ移行**する。いずれの場合も
> `services/`（複数形・技術レイヤー）をトップに置くことは避ける。

## ディレクトリ詳細

### src/ (ソースコードディレクトリ)

#### [ディレクトリ1]

**役割**: [説明]

**配置ファイル**:
- [ファイルパターン1]: [説明]
- [ファイルパターン2]: [説明]

**命名規則**:
- [規則1]
- [規則2]

**依存関係**:
- 依存可能: [ディレクトリ名]
- 依存禁止: [ディレクトリ名]

**例**:
```
[ディレクトリ名]/
├── [example-file1].ts
└── [example-file2].ts
```

#### [ディレクトリ2]

**役割**: [説明]

**配置ファイル**:
- [ファイルパターン1]: [説明]

**命名規則**:
- [規則1]

**依存関係**:
- 依存可能: [ディレクトリ名]
- 依存禁止: [ディレクトリ名]

### tests/ (テストディレクトリ)

#### unit/

**役割**: ユニットテストの配置

**構造**:
```
tests/unit/
└── src/                    # srcディレクトリと同じ構造
    └── [layer]/
        └── [filename].test.ts
```

**命名規則**:
- パターン: `[テスト対象ファイル名].test.ts`
- 例: `CreateTask.ts` → `CreateTask.test.ts`

#### integration/

**役割**: 統合テストの配置

**構造**:
```
tests/integration/
└── [feature]/              # 機能単位でディレクトリ分割
    └── [scenario].test.ts
```

#### e2e/

**役割**: E2Eテストの配置

**構造**:
```
tests/e2e/
└── [user-scenario]/        # ユーザーシナリオ単位
    └── [flow].test.ts
```

### docs/ (ドキュメントディレクトリ)

**配置ドキュメント**:
- `product-requirements.md`: プロダクト要求定義書
- `functional-design.md`: 機能設計書
- `architecture.md`: アーキテクチャ設計書
- `repository-structure.md`: リポジトリ構造定義書(本ドキュメント)
- `development-guidelines.md`: 開発ガイドライン
- `glossary.md`: 用語集

### config/ (設定ファイルディレクトリ - 該当する場合)

**配置ファイル**:
- 設定ファイル
- 定数定義ファイル

**例**:
```
config/
├── default.ts
└── constants.ts
```

### scripts/ (スクリプトディレクトリ - 該当する場合)

**配置ファイル**:
- ビルドスクリプト
- 開発補助スクリプト

## ファイル配置規則

### ソースファイル

| ファイル種別 | 配置先 | 命名規則 | 例 |
|------------|--------|---------|-----|
| [種別1] | [ディレクトリ] | [規則] | [例] |
| [種別2] | [ディレクトリ] | [規則] | [例] |

### テストファイル

| テスト種別 | 配置先 | 命名規則 | 例 |
|-----------|--------|---------|-----|
| ユニットテスト | tests/unit/ | [対象].test.ts | CreateTask.test.ts |
| 統合テスト | tests/integration/ | [機能].test.ts | task-crud.test.ts |
| E2Eテスト | tests/e2e/ | [シナリオ].test.ts | user-workflow.test.ts |

### 設定ファイル

| ファイル種別 | 配置先 | 命名規則 |
|------------|--------|---------|
| 環境設定 | config/environments/ | [環境名].ts |
| ツール設定 | プロジェクトルート | [ツール名].config.js |
| 型定義 | src/types/ | [対象].d.ts |

## 命名規則

### ディレクトリ名

- **機能領域ディレクトリ（トップレベル）**: kebab-case。ドメインの言葉で命名し、
  「何のシステムか」を叫ばせる
  - 例: `task-management/`, `user-authentication/`, `archiving/`
- **レイヤーディレクトリ（機能の内側）**: クリーンアーキテクチャの輪の名前に揃える
  - 例: `entities/`, `use-cases/`, `adapters/`, `infrastructure/`
  - ❌ 避ける: `services/`, `repositories/`, `controllers/` をトップに置くこと
    （技術レイヤーが主役になり、Screaming Architecture に反する）

### ファイル名

- **クラスファイル**: PascalCase
  - 例: `TaskService.ts`, `UserRepository.ts`
- **関数ファイル**: camelCase
  - 例: `formatDate.ts`, `validateEmail.ts`
- **定数ファイル**: UPPER_SNAKE_CASE
  - 例: `API_ENDPOINTS.ts`, `ERROR_MESSAGES.ts`

### テストファイル名

- パターン: `[テスト対象].test.ts` または `[テスト対象].spec.ts`
- 例: `TaskService.test.ts`, `formatDate.spec.ts`

## 依存関係のルール

### レイヤー間の依存（依存性のルール: 矢印はすべて内向き）

```
Frameworks & Drivers (UI / DB / FS)
    ↓ (OK) 内向き
Interface Adapters
    ↓ (OK) 内向き
Use Cases  ──「境界インターフェース」を所有
    ↓ (OK) 内向き
Entities (心臓部)
```

**ポイント**: DB・FSなどの「詳細」は最も外側にあり、Use Case層が所有するインターフェースを
**実装**することで内向きに依存する（DIP）。Use Case・Entities は外側を一切知らない。

**禁止される依存**（外向きの依存はすべてNG）:
- Use Cases → Frameworks & Drivers (❌ ビジネスルールがDB/FWに依存してはいけない)
- Entities → Use Cases / 外側すべて (❌ 心臓部は何にも依存しない)
- 内側のany → 外側のany (❌)

> **この禁止は「機械」に守らせる（ドキュメントのお願いで終わらせない）**:
> 依存方向は人間のレビューでは漏れる。**import境界をLint/CIで強制し、違反でビルドを落とす**。
> 採用ツールは言語に合わせる（例: TypeScript なら `dependency-cruiser` または
> `eslint-plugin-boundaries`、Java なら ArchUnit、Python なら import-linter）。
> 最低限、次のルールをCIに入れる:
> - `entities/` は同一機能の `entities/` と `shared/` 以外を import したら **error**
> - `use-cases/` は `adapters/ infrastructure/` を import したら **error**
> - 機能領域をまたぐ import は原則 **禁止**（共有は `shared/` 経由のみ）
> 設定の雛形は `development-guidelines.md` に置く。

### モジュール間の依存

**循環依存の禁止**:
```typescript
// ❌ 悪い例: 循環依存
// fileA.ts
import { funcB } from './fileB';

// fileB.ts
import { funcA } from './fileA';  // 循環依存
```

**解決策**:
```typescript
// ✅ 良い例: 共通モジュールの抽出
// shared.ts
export interface SharedType { /* ... */ }

// fileA.ts
import { SharedType } from './shared';

// fileB.ts
import { SharedType } from './shared';
```

## スケーリング戦略

### 機能の追加

新しい機能を追加する際の配置方針:

1. **小規模機能**: 既存ディレクトリに配置
2. **中規模機能**: レイヤー内にサブディレクトリを作成
3. **大規模機能**: 独立したモジュールとして分離

**例**:
```
src/
└── task-management/             # 機能領域（トップは機能で叫ぶ）
    ├── entities/
    │   ├── Task.ts              # 既存エンティティ
    │   └── Subtask.ts           # 中規模機能の追加
    └── use-cases/
        ├── CreateTask.ts
        ├── AddSubtask.ts
        └── CategorizeTask.ts
```

### ファイルサイズの管理

**ファイル分割の目安**:
- 1ファイル: 300行以下を推奨
- 300-500行: リファクタリングを検討
- 500行以上: 分割を強く推奨

**分割方法**:
```typescript
// 悪い例: 1ファイルに全機能
// TaskService.ts (800行)

// 良い例: 責務ごとに分割
// TaskService.ts (200行) - CRUD操作
// TaskValidationService.ts (150行) - バリデーション
// TaskNotificationService.ts (100行) - 通知処理
```

## 特殊ディレクトリ

### .steering/ (ステアリングファイル)

**役割**: 特定の開発作業における「今回何をするか」を定義

**構造**:
```
.steering/
└── [YYYYMMDD]-[task-name]/
    ├── requirements.md      # 今回の作業の要求内容
    ├── design.md            # 変更内容の設計
    └── tasklist.md          # タスクリスト
```

**命名規則**: `20250115-add-user-profile` 形式

### .claude/ (Claude Code設定)

**役割**: Claude Code設定とカスタマイズ

**構造**:
```
.claude/
├── skills/                  # スキル（/コマンドもここに統合。<name>/SKILL.md）
├── agents/                  # サブエージェント定義
└── settings.json            # 権限・フック等の設定
```

> 補足: 旧来の `.claude/commands/*.md` も引き続き動作しますが、現在はスキルへ統合され、
> `.claude/skills/<name>/SKILL.md` に置くのが推奨です（補助ファイル同梱・呼び出し制御が可能）。

## 除外設定

### .gitignore

プロジェクトで除外すべきファイル:
- `node_modules/`
- `dist/`
- `.env`
- `.steering/` (タスク管理用の一時ファイル)
- `*.log`
- `.DS_Store`

### .prettierignore, .eslintignore

ツールで除外すべきファイル:
- `dist/`
- `node_modules/`
- `.steering/`
- `coverage/`