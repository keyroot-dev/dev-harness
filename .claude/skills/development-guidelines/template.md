# 開発ガイドライン (Development Guidelines)

> このテンプレート内のコード例は **TypeScript** で記述されています。命名規則（camelCase 等）やイディオムは言語によって異なるため、プロジェクトの言語の慣習に読み替えて記入してください（例: Python は snake_case、定数 UPPER_SNAKE_CASE 等）。

## コーディング規約

### 命名規則

#### 変数・関数

**例（TypeScript / JavaScript）**:
```typescript
// ✅ 良い例
const userProfileData = fetchUserProfile();
function calculateTotalPrice(items: CartItem[]): number { }

// ❌ 悪い例
const data = fetch();
function calc(arr: any[]): number { }
```

**原則**:
- 変数: camelCase、名詞または名詞句
- 関数: camelCase、動詞で始める
- 定数: UPPER_SNAKE_CASE
- Boolean: `is`, `has`, `should`で始める

#### クラス・インターフェース

```typescript
// ユースケース: PascalCase + 動詞（何をしたいか）。"Manager"/"Service" でまとめない
class CreateTask { }
class AuthenticateUser { }

// エンティティ: PascalCase + 名詞（ドメインの言葉）
class Task { }

// インターフェース: PascalCase、I接頭辞またはなし
interface ITaskRepository { }
interface Task { }

// 型エイリアス: PascalCase
type TaskStatus = 'todo' | 'in_progress' | 'completed';
```

### コードフォーマット

**インデント**: [2スペース/4スペース/タブ]

**行の長さ**: 最大[80/100/120]文字

**例**:
```typescript
// [言語] コードフォーマット例
[コード例]
```

### コメント規約

**関数・クラスのドキュメント**:
```typescript
/**
 * タスクの合計数を計算する
 *
 * @param tasks - 計算対象のタスク配列
 * @param filter - フィルター条件(オプション)
 * @returns タスクの合計数
 * @throws {ValidationError} タスク配列が不正な場合
 */
function countTasks(
  tasks: Task[],
  filter?: TaskFilter
): number {
  // 実装
}
```

**インラインコメント**:
```typescript
// ✅ 良い例: なぜそうするかを説明
// キャッシュを無効化して、最新データを取得
cache.clear();

// ❌ 悪い例: 何をしているか(コードを見れば分かる)
// キャッシュをクリアする
cache.clear();
```

### エラーハンドリング

**原則**:
- 予期されるエラー: 適切なエラークラスを定義
- 予期しないエラー: 上位に伝播
- エラーを無視しない

**例**:
```typescript
// エラークラス定義
class ValidationError extends Error {
  constructor(
    message: string,
    public field: string,
    public value: unknown
  ) {
    super(message);
    this.name = 'ValidationError';
  }
}

// エラーハンドリング
try {
  const task = await taskService.create(data);
} catch (error) {
  if (error instanceof ValidationError) {
    console.error(`検証エラー [${error.field}]: ${error.message}`);
    // ユーザーにフィードバック
  } else {
    console.error('予期しないエラー:', error);
    throw error; // 上位に伝播
  }
}
```

## Git運用ルール

### ブランチ戦略

**ブランチ種別**:
- `main`: 本番環境にデプロイ可能な状態
- `develop`: 開発の最新状態
- `feature/[機能名]`: 新機能開発
- `fix/[修正内容]`: バグ修正
- `refactor/[対象]`: リファクタリング

**フロー**:
```
main
  └─ develop
      ├─ feature/task-management
      ├─ feature/user-auth
      └─ fix/task-validation
```

### コミットメッセージ規約

**フォーマット**:
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type**:
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメント
- `style`: コードフォーマット
- `refactor`: リファクタリング
- `test`: テスト追加・修正
- `chore`: ビルド、補助ツール等

**例**:
```
feat(task): タスクの優先度設定機能を追加

ユーザーがタスクに優先度(高/中/低)を設定できるようにしました。
- Taskモデルにpriorityフィールドを追加
- CLIに--priorityオプションを追加
- 優先度によるソート機能を実装

Closes #123
```

### プルリクエストプロセス

**作成前のチェック**:
- [ ] 全てのテストがパス
- [ ] Lintエラーがない
- [ ] 型チェックがパス
- [ ] 競合が解決されている

**PRテンプレート**:
```markdown
## 概要
[変更内容の簡潔な説明]

## 変更理由
[なぜこの変更が必要か]

## 変更内容
- [変更点1]
- [変更点2]

## テスト
- [ ] ユニットテスト追加
- [ ] 手動テスト実施

## スクリーンショット(該当する場合)
[画像]

## 関連Issue
Closes #[Issue番号]
```

**レビュープロセス**:
1. セルフレビュー
2. 自動テスト実行
3. レビュアーアサイン
4. レビューフィードバック対応
5. 承認後マージ

## テスト戦略

### テストの種類

#### ユニットテスト

**対象**: 個別の関数・クラス

**カバレッジ目標**: [80/90/100]%

**例**:
```typescript
describe('CreateTask', () => {
  it('正常なデータでタスクを作成できる', async () => {
    const useCase = new CreateTask(mockRepository);
    const output = await useCase.execute({ title: 'テストタスク' });

    expect(output.id).toBeDefined();
    expect(output.title).toBe('テストタスク');
  });

  it('タイトルが空の場合ValidationErrorをスローする', async () => {
    const useCase = new CreateTask(mockRepository);

    await expect(
      useCase.execute({ title: '' })
    ).rejects.toThrow(ValidationError);
  });
});
```

#### 統合テスト

**対象**: 複数コンポーネントの連携

**例**:
```typescript
describe('Task ライフサイクル', () => {
  it('作成→完了が実際の repository 実装を通して動く', async () => {
    // 実装を結線（ユースケース × 本物の infrastructure 実装）
    const repository = new FileTaskRepository(tmpStorage);
    const createTask = new CreateTask(repository);
    const completeTask = new CompleteTask(repository);

    // 作成
    const created = await createTask.execute({ title: 'テスト' });

    // 完了（別のユースケースで状態遷移）
    await completeTask.execute({ id: created.id });

    // 永続化された状態を確認
    const stored = await repository.findById(TaskId.from(created.id));
    expect(stored?.completed).toBe(true);
  });
});
```

#### E2Eテスト

**対象**: ユーザーシナリオ全体

**例**:
```typescript
describe('タスク管理フロー', () => {
  it('ユーザーがタスクを追加して完了できる', async () => {
    // タスク追加
    await cli.run(['add', '新しいタスク']);
    expect(output).toContain('タスクを追加しました');

    // タスク一覧表示
    await cli.run(['list']);
    expect(output).toContain('新しいタスク');

    // タスク完了
    await cli.run(['complete', '1']);
    expect(output).toContain('タスクを完了しました');
  });
});
```

### テスト命名規則

**パターン**: `[対象]_[条件]_[期待結果]`

**例**:
```typescript
// ✅ 良い例
it('create_emptyTitle_throwsValidationError', () => { });
it('findById_existingId_returnsTask', () => { });
it('delete_nonExistentId_throwsNotFoundError', () => { });

// ❌ 悪い例
it('test1', () => { });
it('works', () => { });
it('should work correctly', () => { });
```

### モック・スタブの使用

**原則**:
- 外部依存(API、DB、ファイルシステム)はモック化
- ビジネスロジックは実装を使用

**例**:
```typescript
// リポジトリをモック化
const mockRepository: ITaskRepository = {
  save: jest.fn(),
  findById: jest.fn(),
  findAll: jest.fn(),
  delete: jest.fn(),
};

// ユースケースは実際の実装を使用（注入するのは I/F のモックだけ）
const useCase = new CreateTask(mockRepository);
```

## アーキテクチャ境界の強制 (Architecture Fitness Functions)

`architecture.md` の依存性のルール（依存はすべて内向き）は、**人間のレビューに頼らず機械で強制する**。
依存方向の違反は目視では必ず漏れる。import境界を静的解析で検査し、**違反したらCIを落とす**。

**ルール（言語非依存の意図）**:
- `entities/` は外側（use-cases / adapters / infrastructure）を import したら **error**
- `use-cases/` は `adapters/ infrastructure/` を import したら **error**（境界I/Fは use-cases 側が所有）
- `adapters/` は `infrastructure/` の具象を import したら **error**（Controllerが詳細を直結し構成ルートを迂回するのを防ぐ）
- 具象の `new`／配線は**構成ルート（`index.ts` / `main`）だけ**に許す。それ以外は依存を注入で受け取る
- 機能領域をまたぐ import は禁止（共有は `shared/` 経由のみ）。循環依存は **error**

**ツール例**（プロジェクトの言語で標準的なものを選ぶ）:

| 言語 | ツール例 |
|------|---------|
| TypeScript / JS | `dependency-cruiser` / `eslint-plugin-boundaries` |
| Java / Kotlin | ArchUnit |
| Python | import-linter |
| Go | `go-arch-lint` / `depguard` |

**雛形（TypeScript / dependency-cruiser）**:
```js
// .dependency-cruiser.js
module.exports = {
  forbidden: [
    {
      name: 'entities-no-outward-deps',
      severity: 'error',
      from: { path: '(^|/)entities/' },
      to:   { path: '(^|/)(use-cases|adapters|infrastructure)/' },
    },
    {
      name: 'use-cases-no-detail-deps',
      severity: 'error',
      from: { path: '(^|/)use-cases/' },
      to:   { path: '(^|/)(adapters|infrastructure)/' },
    },
    {
      // adapters（Controller/Presenter）が infrastructure の具象に直結するのを禁止。
      // 詳細の注入は構成ルート（src/index.ts 等）だけで行う。
      name: 'adapters-no-infra-deps',
      severity: 'error',
      from: { path: '(^|/)adapters/' },
      to:   { path: '(^|/)infrastructure/' },
    },
    {
      // 散文の約束「機能領域をまたぐ import は禁止（共有は shared/ 経由のみ）」を実際に強制する。
      // src/<feature>/… から別の src/<feature>/… への import を error にする（shared/ は除外）。
      name: 'no-cross-feature-import',
      severity: 'error',
      from: { path: '^src/(?!shared/)([^/]+)/' },
      to:   {
        path: '^src/(?!shared/)([^/]+)/',
        pathNot: '^src/$1/',           // 同一機能領域内の import は許可（後方参照で from と同じ領域を除外）
      },
    },
    { name: 'no-circular', severity: 'error', from: {}, to: { circular: true } },
  ],
};
```
CIに `depcruise --validate .dependency-cruiser.js src` を追加し、`lint`/`typecheck`/`test` と並べて必須化する。

## コードレビュー基準

### レビューポイント

**機能性**:
- [ ] 要件を満たしているか
- [ ] エッジケースが考慮されているか
- [ ] エラーハンドリングが適切か

**可読性**:
- [ ] 命名が明確か
- [ ] コメントが適切か
- [ ] 複雑なロジックが説明されているか

**保守性**:
- [ ] 重複コードがないか
- [ ] 責務が明確に分離されているか
- [ ] 変更の影響範囲が限定的か

**パフォーマンス**:
- [ ] 不要な計算がないか
- [ ] メモリリークの可能性がないか
- [ ] データベースクエリが最適化されているか

**セキュリティ**:
- [ ] 入力検証が適切か
- [ ] 機密情報がハードコードされていないか
- [ ] 権限チェックが実装されているか

### レビューコメントの書き方

**建設的なフィードバック**:
```markdown
## ✅ 良い例
この実装だと、タスク数が増えた時にパフォーマンスが劣化する可能性があります。
代わりに、インデックスを使った検索を検討してはどうでしょうか？

## ❌ 悪い例
この書き方は良くないです。
```

**優先度の明示**:
- `[必須]`: 修正必須
- `[推奨]`: 修正推奨
- `[提案]`: 検討してほしい
- `[質問]`: 理解のための質問

## 開発環境セットアップ

### 必要なツール

| ツール | バージョン | インストール方法 |
|--------|-----------|-----------------|
| [ツール1] | [バージョン] | [コマンド] |
| [ツール2] | [バージョン] | [コマンド] |

### セットアップ手順

```bash
# 1. リポジトリのクローン
git clone [URL]
cd [project-name]

# 2. 依存関係のインストール
[インストールコマンド]

# 3. 環境変数の設定
cp .env.example .env
# .envファイルを編集

# 4. 開発サーバーの起動
[起動コマンド]
```

### 推奨開発ツール(該当する場合)

- [ツール1]: [説明]
- [ツール2]: [説明]