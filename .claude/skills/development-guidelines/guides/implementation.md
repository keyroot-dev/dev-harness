# 実装ガイド (Implementation Guide)

> このガイドのコード例は **TypeScript** を題材にしていますが、原則（型安全性・命名・エラーハンドリング・テスト容易性など）は言語非依存です。プロジェクトの言語の慣習・型システム・標準ライブラリに読み替えて適用してください。

## コーディング規約（例: TypeScript / JavaScript）

### 型定義

**組み込み型の使用**:
```typescript
// ✅ 良い例: 組み込み型を使用
function processItems(items: string[]): Record<string, number> {
  return items.reduce((acc, item) => {
    acc[item] = (acc[item] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);
}

// ❌ 悪い例: typingモジュールからインポート
import { List, Dict } from 'typing';
function processItems(items: List[str]): Dict[str, int] { }
```

**型注釈の原則**:
```typescript
// ✅ 良い例: 明示的な型注釈
function calculateTotal(prices: number[]): number {
  return prices.reduce((sum, price) => sum + price, 0);
}

// ❌ 悪い例: 型推論に頼りすぎる
function calculateTotal(prices) {  // any型になる
  return prices.reduce((sum, price) => sum + price, 0);
}
```

**インターフェース vs 型エイリアス**:
```typescript
// インターフェース: 拡張可能なオブジェクト型
interface Task {
  id: string;
  title: string;
  completed: boolean;
}

// 拡張
interface ExtendedTask extends Task {
  priority: string;
}

// 型エイリアス: ユニオン型、プリミティブ型など
type TaskStatus = 'todo' | 'in_progress' | 'completed';
type TaskId = string;
type Nullable<T> = T | null;
```

### 命名規則

**変数・関数**:
```typescript
// 変数: camelCase、名詞
const userName = 'John';
const taskList = [];
const isCompleted = true;

// 関数: camelCase、動詞で始める
function fetchUserData() { }
function validateEmail(email: string) { }
function calculateTotalPrice(items: Item[]) { }

// Boolean: is, has, should, canで始める
const isValid = true;
const hasPermission = false;
const shouldRetry = true;
const canDelete = false;
```

**クラス・インターフェース**:
```typescript
// ✅ ユースケース: PascalCase + 動詞（ユーザーが何をしたいか）。architecture.md の命名に揃える
class CreateTask { }
class AuthenticateUser { }

// ✅ エンティティ: PascalCase + 名詞（ドメインの言葉）
class Task { }
class User { }

// ❌ 避ける: "Manager" / "Service" など何をするか叫ばない包括名
//    複数のユースケースを溜め込み、単一責務（SRP）が崩れる温床になる
// class TaskManager { }            // → CreateTask / CompleteTask に分ける
// class UserAuthenticationService  // → AuthenticateUser

// インターフェース: PascalCase（境界I/Fは use-cases 層が所有する契約）
interface TaskRepository { }
interface UserProfile { }

// 型エイリアス: PascalCase
type TaskStatus = 'todo' | 'in_progress' | 'completed';
```

**定数**:
```typescript
// UPPER_SNAKE_CASE
const MAX_RETRY_COUNT = 3;
const API_BASE_URL = 'https://api.example.com';
const DEFAULT_TIMEOUT = 5000;

// 設定オブジェクトの場合
const CONFIG = {
  maxRetryCount: 3,
  apiBaseUrl: 'https://api.example.com',
  defaultTimeout: 5000,
} as const;
```

**ファイル名**:
```typescript
// ユースケース: PascalCase + 動詞（クラス名と一致）
// CreateTask.ts
// AuthenticateUser.ts

// 境界I/Fと実装: I/Fは役割名、具象は "何で実装したか" を冠する
// TaskRepository.ts（I/F, use-cases）/ FileTaskRepository.ts（実装, infrastructure）

// 関数・ユーティリティ: camelCase
// formatDate.ts
// validateEmail.ts

// コンポーネント(React等): PascalCase
// TaskList.tsx
// UserProfile.tsx

// 定数: kebab-case または UPPER_SNAKE_CASE
// api-endpoints.ts
// ERROR_MESSAGES.ts
```

### 関数設計

**単一責務の原則**:
```typescript
// ✅ 良い例: 単一の責務
function calculateTotalPrice(items: CartItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}

function formatPrice(amount: number): string {
  return `¥${amount.toLocaleString()}`;
}

// ❌ 悪い例: 複数の責務
function calculateAndFormatPrice(items: CartItem[]): string {
  const total = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  return `¥${total.toLocaleString()}`;
}
```

**関数の長さ**:
- 目標: 20行以内
- 推奨: 50行以内
- 100行以上: リファクタリングを検討

**パラメータの数**:
```typescript
// ✅ 良い例: オブジェクトでまとめる
interface CreateTaskOptions {
  title: string;
  description?: string;
  priority?: 'high' | 'medium' | 'low';
  dueDate?: Date;
}

function createTask(options: CreateTaskOptions): Task {
  // 実装
}

// ❌ 悪い例: パラメータが多すぎる
function createTask(
  title: string,
  description: string,
  priority: string,
  dueDate: Date,
  tags: string[],
  assignee: string
): Task {
  // 実装
}
```

### エラーハンドリング

**カスタムエラークラス**:
```typescript
// エラークラスの定義
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

class NotFoundError extends Error {
  constructor(
    public resource: string,
    public id: string
  ) {
    super(`${resource} not found: ${id}`);
    this.name = 'NotFoundError';
  }
}

class DatabaseError extends Error {
  constructor(message: string, public cause?: Error) {
    super(message);
    this.name = 'DatabaseError';
    this.cause = cause;
  }
}
```

**エラーハンドリングパターン**:
```typescript
// ✅ 良い例: 適切なエラーハンドリング
async function getTask(id: string): Promise<Task> {
  try {
    const task = await repository.findById(id);

    if (!task) {
      throw new NotFoundError('Task', id);
    }

    return task;
  } catch (error) {
    if (error instanceof NotFoundError) {
      // 予期されるエラー: 適切に処理
      logger.warn(`タスクが見つかりません: ${id}`);
      throw error;
    }

    // 予期しないエラー: ラップして上位に伝播
    throw new DatabaseError('タスクの取得に失敗しました', error as Error);
  }
}

// ❌ 悪い例: エラーを無視
async function getTask(id: string): Promise<Task | null> {
  try {
    return await repository.findById(id);
  } catch (error) {
    return null; // エラー情報が失われる
  }
}
```

**エラーメッセージ**:
```typescript
// ✅ 良い例: 具体的で解決策を示す
throw new ValidationError(
  'タイトルは1-200文字で入力してください。現在の文字数: 250',
  'title',
  title
);

// ❌ 悪い例: 曖昧で役に立たない
throw new Error('Invalid input');
```

### 非同期処理

**async/await の使用**:
```typescript
// ✅ 良い例: async/await
async function fetchUserTasks(userId: string): Promise<Task[]> {
  try {
    const user = await userRepository.findById(userId);
    const tasks = await taskRepository.findByUserId(user.id);
    return tasks;
  } catch (error) {
    logger.error('タスクの取得に失敗', error);
    throw error;
  }
}

// ❌ 悪い例: Promiseチェーン
function fetchUserTasks(userId: string): Promise<Task[]> {
  return userRepository.findById(userId)
    .then(user => taskRepository.findByUserId(user.id))
    .then(tasks => tasks)
    .catch(error => {
      logger.error('タスクの取得に失敗', error);
      throw error;
    });
}
```

**並列処理**:
```typescript
// ✅ 良い例: Promise.allで並列実行
async function fetchMultipleUsers(ids: string[]): Promise<User[]> {
  const promises = ids.map(id => userRepository.findById(id));
  return Promise.all(promises);
}

// ❌ 悪い例: 逐次実行
async function fetchMultipleUsers(ids: string[]): Promise<User[]> {
  const users: User[] = [];
  for (const id of ids) {
    const user = await userRepository.findById(id); // 遅い
    users.push(user);
  }
  return users;
}
```

## コメント規約

### ドキュメントコメント

**TSDoc形式**:
```typescript
/**
 * タスクを作成する
 *
 * @param data - 作成するタスクのデータ
 * @returns 作成されたタスク
 * @throws {ValidationError} データが不正な場合
 * @throws {DatabaseError} データベースエラーの場合
 *
 * @example
 * ```typescript
 * const task = await createTask({
 *   title: '新しいタスク',
 *   priority: 'high'
 * });
 * ```
 */
async function createTask(data: CreateTaskData): Promise<Task> {
  // 実装
}
```

### インラインコメント

**良いコメント**:
```typescript
// ✅ 理由を説明
// キャッシュを無効化して最新データを取得
cache.clear();

// ✅ 複雑なロジックを説明
// Kadaneのアルゴリズムで最大部分配列和を計算
// 時間計算量: O(n)
let maxSoFar = arr[0];
let maxEndingHere = arr[0];

// ✅ TODO・FIXMEを活用
// TODO: キャッシュ機能を実装 (Issue #123)
// FIXME: 大量データでパフォーマンス劣化 (Issue #456)
// HACK: 一時的な回避策、後でリファクタリング必要
```

**悪いコメント**:
```typescript
// ❌ コードの内容を繰り返すだけ
// iを1増やす
i++;

// ❌ 古い情報
// このコードは2020年に追加された (不要な情報)

// ❌ コメントアウトされたコード
// const oldImplementation = () => { ... };  // 削除すべき
```

## セキュリティ

### 入力検証 — 責務を二層に分ける（ドメインルールを外に漏らさない）

> `architecture.md` の原則と揃える: **ドメインの不変条件はエンティティ／値オブジェクト自身が守る。**
> 自由関数（`validateEmail`）にドメインルールを二重定義しない ── いずれ片方だけ変わって食い違う。

**ドメインルール（形式・長さ）は値オブジェクトが所有する**:
```typescript
// ✅ 良い例: Email は「検証済みであること」を型で保証する値オブジェクト。
//    形式・長さという不変条件は Email 自身が守る（唯一の真実）。
class Email {
  private constructor(readonly value: string) {}

  static create(raw: string): Email {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(raw)) {
      throw new ValidationError('メールアドレスの形式が不正です', 'email', raw);
    }
    if (raw.length > 254) {
      throw new ValidationError('メールアドレスが長すぎます', 'email', raw);
    }
    return new Email(raw);
  }
}
```

**外側（adapter / infrastructure）は「信頼できない外形」だけを弾く**:
```typescript
// ✅ 良い例: ドメインに到達する前の粗いガード。型・サイズ上限のみ。
//    "254文字" や "@を含む" 等のドメインルールはここに書かない。
function assertUntrustedString(raw: unknown): string {
  if (typeof raw !== 'string') throw new ValidationError('文字列が必要です', 'input', raw);
  if (raw.length > 10_000) throw new ValidationError('入力が大きすぎます', 'input', raw); // 乱用防止
  return raw;
}

// 配線: 外形チェック → ドメインの不変条件。ルールは Email の中だけにある。
const email = Email.create(assertUntrustedString(input.email));

// ❌ 悪い例1: ドメインルールを自由関数に漏らす（Email.create と二重定義になり、いずれ食い違う）
function validateEmail(email: string): void {
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('...'); // ← Email が持つべき不変条件
}

// ❌ 悪い例2: 検証なし
function processSignup(email: string): void {
  // 検証なし
}
```

### 機密情報の管理

```typescript
// ✅ 良い例: 環境変数から読み込み
import { config } from './config';

const apiKey = process.env.API_KEY;
if (!apiKey) {
  throw new Error('API_KEY環境変数が設定されていません');
}

// ❌ 悪い例: ハードコード
const apiKey = 'sk-1234567890abcdef'; // 絶対にしない！
```

## パフォーマンス

### データ構造の選択

```typescript
// ✅ 良い例: Mapで O(1) アクセス
const userMap = new Map(users.map(u => [u.id, u]));
const user = userMap.get(userId); // O(1)

// ❌ 悪い例: 配列で O(n) 検索
const user = users.find(u => u.id === userId); // O(n)
```

### ループの最適化

```typescript
// ✅ 良い例: 不要な計算をループの外に
const length = items.length;
for (let i = 0; i < length; i++) {
  process(items[i]);
}

// ❌ 悪い例: 毎回lengthを計算
for (let i = 0; i < items.length; i++) {
  process(items[i]);
}

// ✅ より良い: for...ofを使用
for (const item of items) {
  process(item);
}
```

### メモ化

```typescript
// 計算結果のキャッシュ
const cache = new Map<string, Result>();

function expensiveCalculation(input: string): Result {
  if (cache.has(input)) {
    return cache.get(input)!;
  }

  const result = /* 重い計算 */;
  cache.set(input, result);
  return result;
}
```

## テストコード

### テストの構造 (Given-When-Then)

```typescript
// ユースケース単位でテストする（抽象=モックの TaskRepository にのみ依存）
describe('CreateTask', () => {
  it('正常なデータでタスクを作成できる', async () => {
    // Given: 準備（注入するのは I/F のモック。DBもFWも要らない）
    const useCase = new CreateTask(mockRepository);

    // When: 実行
    const output = await useCase.execute({ title: 'テストタスク' });

    // Then: 検証（境界を越えて返るのは DTO。Entity ではない）
    expect(output.id).toBeDefined();
    expect(output.title).toBe('テストタスク');
    expect(mockRepository.save).toHaveBeenCalledTimes(1);
  });

  it('タイトルが空の場合ValidationErrorをスローする', async () => {
    // Given: 準備
    const useCase = new CreateTask(mockRepository);

    // When/Then: 実行と検証（不変条件は Task.create が守る）
    await expect(
      useCase.execute({ title: '' })
    ).rejects.toThrow(ValidationError);
  });
});
```

### モックの作成

```typescript
// ✅ 良い例: インターフェースに基づくモック
const mockRepository: TaskRepository = {
  save: jest.fn(),
  findById: jest.fn(),
  findAll: jest.fn(),
  delete: jest.fn(),
};

// テストごとに動作を設定
beforeEach(() => {
  mockRepository.findById = jest.fn((id) => {
    if (id === 'existing-id') {
      return Promise.resolve(mockTask);
    }
    return Promise.resolve(null);
  });
});
```

## リファクタリング

### マジックナンバーの排除

```typescript
// ✅ 良い例: 定数を定義
const MAX_RETRY_COUNT = 3;
const RETRY_DELAY_MS = 1000;

for (let i = 0; i < MAX_RETRY_COUNT; i++) {
  try {
    return await fetchData();
  } catch (error) {
    if (i < MAX_RETRY_COUNT - 1) {
      await sleep(RETRY_DELAY_MS);
    }
  }
}

// ❌ 悪い例: マジックナンバー
for (let i = 0; i < 3; i++) {
  try {
    return await fetchData();
  } catch (error) {
    if (i < 2) {
      await sleep(1000);
    }
  }
}
```

### 関数の抽出

```typescript
// ✅ 良い例: 関数を抽出
function processOrder(order: Order): void {
  validateOrder(order);
  calculateTotal(order);
  applyDiscounts(order);
  saveOrder(order);
}

function validateOrder(order: Order): void {
  if (!order.items || order.items.length === 0) {
    throw new ValidationError('商品が選択されていません', 'items', order.items);
  }
}

function calculateTotal(order: Order): void {
  order.total = order.items.reduce(
    (sum, item) => sum + item.price * item.quantity,
    0
  );
}

// ❌ 悪い例: 長い関数
function processOrder(order: Order): void {
  if (!order.items || order.items.length === 0) {
    throw new ValidationError('商品が選択されていません', 'items', order.items);
  }

  order.total = order.items.reduce(
    (sum, item) => sum + item.price * item.quantity,
    0
  );

  if (order.coupon) {
    order.total -= order.total * order.coupon.discountRate;
  }

  repository.save(order);
}
```

## チェックリスト

実装完了前に確認:

### コード品質
- [ ] 命名が明確で一貫している
- [ ] 関数が単一の責務を持っている
- [ ] マジックナンバーがない
- [ ] 型注釈が適切に記載されている
- [ ] エラーハンドリングが実装されている

### セキュリティ
- [ ] 入力検証が実装されている
- [ ] 機密情報がハードコードされていない
- [ ] SQLインジェクション対策がされている

### パフォーマンス
- [ ] 適切なデータ構造を使用している
- [ ] 不要な計算を避けている
- [ ] ループが最適化されている

### テスト
- [ ] ユニットテストが書かれている
- [ ] テストがパスする
- [ ] エッジケースがカバーされている

### ドキュメント
- [ ] 関数・クラスにTSDocコメントがある
- [ ] 複雑なロジックにコメントがある
- [ ] TODOやFIXMEが記載されている(該当する場合)

### ツール
- [ ] Lintエラーがない
- [ ] 型チェックがパスする
- [ ] フォーマットが統一されている
