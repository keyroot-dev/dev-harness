# アーキテクチャ境界 Fitness Function スターターキット

アーキテクチャの依存性のルール（正本: `.claude/skills/architecture-design/guide.md`「依存性のルール（クリーンアーキテクチャの絶対原則）」）を、**文書の「禁止」で終わらせず Lint/CI で機械強制する**ための、言語別の最小設定サンプル集です。

AI が生成するコードは人間よりも速く・大量に積まれるため、境界違反（アーキテクチャ・ドリフト）も人間のレビューでは追いつかない速度で蓄積します。**依存方向の検査を CI に入れ、違反でビルドを落とすこと**が最も効果的な防御です。

## 使いどころ

- `/setup-project` のステップ3（Walking Skeleton）で、**自プロジェクトの言語のサンプルを1本立てて緑にする**（承認ゲート2の合格条件）
- `/add-feature` のステップ7（静的ゲート）で毎回実行される
- 実行コマンドは `docs/development-guidelines.md` に記録する（`/setup-project` が骨格から種を採る）

## 言語 → ツール対応表

| 言語 | ツール | サンプル | 配置先（プロジェクトルート） |
|---|---|---|---|
| TypeScript / JavaScript | [dependency-cruiser](https://github.com/sverweij/dependency-cruiser) | `dependency-cruiser/dependency-cruiser.cjs` | `.dependency-cruiser.cjs` |
| Python | [import-linter](https://import-linter.readthedocs.io/) | `import-linter/importlinter.ini` | `.importlinter` |
| Go | [golangci-lint (depguard)](https://golangci-lint.run/) | `go/golangci.yml` | `.golangci.yml` に統合 |
| Java / Kotlin | [ArchUnit](https://www.archunit.org/) | `java/ArchitectureTest.java` | テストソースに配置 |

上記に無い言語では、同種のツール（.NET: NetArchTest / Swift: solid-like-a-rock 等）か、最低限「禁止 import の grep を CI で回す」ことから始める。**ゼロ本は不合格、粗くても1本が合格**。

## 共通のルール内容（どの言語でも同じ3点を強制する）

```
1. entities は同一機能の entities と shared 以外を import しない（心臓部は何にも依存しない）
2. use-cases は adapters / infrastructure を import しない（依存はすべて内向き）
3. 機能領域をまたぐ import は禁止（共有は shared 経由のみ）
```

サンプルのパスパターンは `.claude/skills/repository-structure/template.md` の標準構造（`src/[機能]/entities|use-cases|adapters|infrastructure`）を前提にしている。実プロジェクトの構造に合わせて**パターンだけ**直し、ルールの意味（内向きの依存）は変えない。

## 実行コマンドと CI 断片

```bash
# TypeScript / JavaScript
npm i -D dependency-cruiser
npx depcruise src --config .dependency-cruiser.cjs

# Python
pip install import-linter
lint-imports

# Go
golangci-lint run

# Java（Gradle の例。ArchUnit はテストとして走る）
./gradlew test
```

CI には「テスト → Lint → 型チェック → **アーキテクチャ境界検査**」の1ステップとして追加する:

```yaml
# .github/workflows/ci.yml への追加例（TypeScript の場合）
      - name: アーキテクチャ境界検査（Fitness Function）
        run: npx depcruise src --config .dependency-cruiser.cjs
```

> 検査が緑である限り、`docs/architecture.md` の依存図は「絵に描いた理想」ではなく「機械が保証する現実」になる。違反を許容したくなったら、それは例外の追加ではなく意図の変更（`/change-spec`）である。
