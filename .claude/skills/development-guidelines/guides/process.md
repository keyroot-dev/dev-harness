# プロセスガイド (Process Guide)

## 基本原則

### 1. 具体例を豊富に含める

抽象的なルールだけでなく、具体的なコード例を提示します。

**悪い例**:
```
変数名は分かりやすくすること
```

**良い例**:
```typescript
// ✅ 良い例: 役割が明確（ユースケースは動詞、実装は何で実装したか）
const authenticateUser = new AuthenticateUser(userRepository);
const taskRepository = new FileTaskRepository(storage);

// ❌ 悪い例: 曖昧
const auth = new Service();
const repo = new Repository();
```

### 2. 理由を説明する

「なぜそうするのか」を明確にします。

**例**:
```
## エラーを無視しない

理由: エラーを無視すると、問題の原因究明が困難になります。
予期されるエラーは適切に処理し、予期しないエラーは上位に伝播させて
ログに記録できるようにします。
```

### 3. 測定可能な基準を設定

曖昧な表現を避け、具体的な数値を示します。

**悪い例**:
```
コードカバレッジは高く保つこと
```

**良い例**:
```
コードカバレッジ目標:
- ユニットテスト: 80%以上
- 統合テスト: 60%以上
- E2Eテスト: 主要フロー100%
```

## Git運用ルール

### ブランチ戦略

**原則（これが正本。モデル選択はプロジェクトの詳細）**:
- **main は常にリリース可能**に保つ（壊れた状態で放置しない）
- **統合は頻繁に**行う。ブランチの寿命は短く保つ（長命ブランチ＝統合の先送り＝フィードバックの遅延）
- 統合のたびに CI（テスト・Lint・アーキ境界検査）が走り、緑を保つ
- **直接コミット禁止**: main への変更は PR を経由し、レビューとCIを必須とする
- タグでバージョンを管理する

**推奨デフォルト: トランクベース開発（短命ブランチ + PR）**:
```
main (常にリリース可能)
├── feature/xxx (数時間〜1日で main へ戻す短命ブランチ)
└── fix/yyy
```
- feature/fix ブランチは小さく切り、PRレビュー後すみやかに main へマージする
- 本テンプレートの開発リズム（1振る舞い単位のTDD・小さなPR）と整合する。分単位でテストを緑にする規律を、日単位で統合を先送りするブランチモデルで打ち消さないこと

**Git Flow 等の多段ブランチモデルについて**:
複数バージョンの並行保守や、リリース列車が固定された組織では、develop / release ブランチを持つモデル（Git Flow 等）が適することもある。ただし長命の統合ブランチは CI のフィードバックを遅らせるトレードオフを持つ。採用する場合は、その理由をプロジェクトの `docs/development-guidelines.md` に明記する（＝ブランチモデルは「遅延可能な詳細」であり、原則が正本）。

### コミットメッセージの規約

**Conventional Commitsを推奨**:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type一覧**:
```
feat: 新機能 (minor version up)
fix: バグ修正 (patch version up)
docs: ドキュメント
style: フォーマット (コードの動作に影響なし)
refactor: リファクタリング
perf: パフォーマンス改善
test: テスト追加・修正
build: ビルドシステム
ci: CI/CD設定
chore: その他 (依存関係更新など)

BREAKING CHANGE: 破壊的変更 (major version up)
```

**良いコミットメッセージの例**:

```
feat(task): 優先度設定機能を追加

ユーザーがタスクに優先度(高/中/低)を設定できるようになりました。

実装内容:
- Taskモデルにpriorityフィールド追加
- CLI に --priority オプション追加
- 優先度によるソート機能実装

破壊的変更:
- Task型の構造が変更されました
- 既存のタスクデータはマイグレーションが必要です

Closes #123
BREAKING CHANGE: Task型にpriority必須フィールド追加
```

### プルリクエストのテンプレート

**効果的なPRテンプレート**:

```markdown
## 変更の種類
- [ ] 新機能 (feat)
- [ ] バグ修正 (fix)
- [ ] リファクタリング (refactor)
- [ ] ドキュメント (docs)
- [ ] その他 (chore)

## 変更内容
### 何を変更したか
[簡潔な説明]

### なぜ変更したか
[背景・理由]

### どのように変更したか
- [変更点1]
- [変更点2]

## テスト
### 実施したテスト
- [ ] ユニットテスト追加
- [ ] 統合テスト追加
- [ ] 手動テスト実施

### テスト結果
[テスト結果の説明]

## 関連Issue
Closes #[番号]
Refs #[番号]

## レビューポイント
[レビュアーに特に見てほしい点]
```

## テスト戦略

### テストピラミッド

```
       /\
      /E2E\       少 (遅い、高コスト)
     /------\
    / 統合   \     中
   /----------\
  / ユニット   \   多 (速い、低コスト)
 /--------------\
```

**目標比率**:
- ユニットテスト: 70%
- 統合テスト: 20%
- E2Eテスト: 10%

### テストの書き方

**Given-When-Then パターン**:

```typescript
describe('CreateTask', () => {
  it('正常なデータの場合、タスクを作成できる', async () => {
    // Given: 準備（注入するのは I/F のモックだけ）
    const useCase = new CreateTask(mockRepository);

    // When: 実行
    const output = await useCase.execute({ title: 'テスト' });

    // Then: 検証（返るのは DTO）
    expect(output.id).toBeDefined();
    expect(output.title).toBe('テスト');
  });

  it('タイトルが空の場合、ValidationErrorをスローする', async () => {
    // Given: 準備
    const useCase = new CreateTask(mockRepository);

    // When/Then: 実行と検証
    await expect(
      useCase.execute({ title: '' })
    ).rejects.toThrow(ValidationError);
  });
});
```

### カバレッジ目標

**測定可能な目標**:

```json
// jest.config.js
{
  "coverageThreshold": {
    "global": {
      "branches": 80,
      "functions": 80,
      "lines": 80,
      "statements": 80
    },
    "**/{entities,use-cases}/**": {
      "branches": 90,
      "functions": 90,
      "lines": 90,
      "statements": 90
    }
  }
}
```

**理由**:
- 重要なビジネスロジック(entities / use-cases)は高いカバレッジを要求
- adapters / infrastructure（詳細）は低めでも許容
- 100%を目指さない (コストと効果のバランス)

## コードレビュープロセス

### レビューの目的

1. **品質保証**: バグの早期発見
2. **知識共有**: チーム全体でコードベースを理解
3. **学習機会**: ベストプラクティスの共有

### 効果的なレビューのポイント

**レビュアー向け**:

1. **建設的なフィードバック**
```markdown
## ❌ 悪い例
このコードはダメです。

## ✅ 良い例
この実装だと O(n²) の時間計算量になります。
Map を使うと O(n) に改善できます:

```typescript
const taskMap = new Map(tasks.map(t => [t.id, t]));
const result = ids.map(id => taskMap.get(id));
```
```

2. **優先度の明示**
```markdown
[必須] セキュリティ: パスワードがログに出力されています
[推奨] パフォーマンス: ループ内でのDB呼び出しを避けましょう
[提案] 可読性: この関数名をもっと明確にできませんか？
[質問] この処理の意図を教えてください
```

3. **ポジティブなフィードバックも**
```markdown
✨ この実装は分かりやすいですね！
👍 エッジケースがしっかり考慮されています
💡 このパターンは他でも使えそうです
```

**レビュイー向け**:

1. **セルフレビューを実施**
   - PR作成前に自分でコードを見直す
   - 説明が必要な箇所にコメントを追加

2. **小さなPRを心がける**
   - 1PR = 1機能
   - 変更ファイル数: 10ファイル以内を推奨
   - 変更行数: 300行以内を推奨

3. **説明を丁寧に**
   - なぜこの実装にしたか
   - 検討した代替案
   - 特に見てほしいポイント

### レビュー時間の目安

- 小規模PR (100行以下): 15分
- 中規模PR (100-300行): 30分
- 大規模PR (300行以上): 1時間以上

**原則**: 大規模PRは避け、分割する

## 自動化の推進（該当する場合）

### 品質チェックの自動化

**自動化したい項目**（採用ツールはプロジェクトの言語に合わせて選定する）:

1. **Lintチェック** — コーディング規約の統一・潜在バグの検出
2. **コードフォーマット** — スタイルの自動整形でレビューの議論を削減
3. **型チェック**（型のある言語の場合） — 型エラーをビルドと独立して検証
4. **テスト実行** — カバレッジ測定を含む
5. **ビルド確認**（該当する場合）
6. **アーキテクチャ境界検査** — 依存方向（依存はすべて内向き）の違反を静的解析で検出。
   `architecture.md` のルールを `dependency-cruiser` / ArchUnit / import-linter 等で強制し、
   違反でCIを落とす（設定は `development-guidelines.md` の「アーキテクチャ境界の強制」を参照）

各項目に対し、言語のエコシステムで標準的なツールを選ぶ。

> **例（TypeScript / Node.js の場合）**
> - Lint: ESLint + @typescript-eslint（`eslint.config.js`）
> - フォーマット: Prettier（`eslint-config-prettier`で競合回避）
> - 型チェック: `tsc --noEmit`（`tsconfig.json`）
> - テスト: Vitest（カバレッジは @vitest/coverage-v8）
> - ビルド: `tsc`
>
> 他言語の例: Python なら ruff + mypy + pytest、Go なら golangci-lint + go vet + go test など。

**実装方法**:

**1. CI/CD（例: GitHub Actions）**

push / pull_request をトリガーに、Lint → 型チェック → テスト → ビルド を順に実行する。下記は Node.js の例。プロジェクトの言語に合わせて `setup-*` アクションとコマンドを差し替える。

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # 例（Node.js）:
      - uses: actions/setup-node@v4
        with:
          node-version: '24'
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm run test
      - run: npm run build
      - run: npm run arch:check   # 例: depcruise --validate .dependency-cruiser.js src
```

**2. Pre-commit フック**

コミット前に Lint・フォーマット・（型チェック）を走らせ、不具合コードの混入を防ぐ。言語に応じたツールを使う（例: Node.js なら Husky + lint-staged、汎用なら pre-commit フレームワーク）。

**導入効果**:
- コミット前に自動チェックが走り、不具合コードの混入を防止
- PR作成時に自動でCI実行され、マージ前に品質を担保
- 早期発見により、修正コストを大きく削減

**この構成を選ぶ際の観点**:
- そのエコシステムで標準的かつモダンな構成を選ぶ
- ツール間の互換性が高く、設定の衝突が少ないこと
- 開発体験と実行速度のバランス

## チェックリスト

- [ ] ブランチ戦略が決まっている
- [ ] コミットメッセージ規約が明確である
- [ ] PRテンプレートが用意されている
- [ ] テストの種類とカバレッジ目標が設定されている
- [ ] コードレビュープロセスが定義されている
- [ ] CI/CDパイプラインが構築されている
- [ ] アーキテクチャ境界（依存方向）がLint/CIで機械的に強制されている
