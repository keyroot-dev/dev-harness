/**
 * アーキテクチャ境界 Fitness Function（TypeScript / JavaScript 用の最小サンプル）。
 *
 * 使い方（プロジェクトルートで）:
 *   cp templates/fitness/dependency-cruiser/dependency-cruiser.cjs .dependency-cruiser.cjs
 *   npm i -D dependency-cruiser
 *   npx depcruise src --config .dependency-cruiser.cjs
 *
 * ルールの意味（正本: .claude/skills/architecture-design/guide.md「依存性のルール」）:
 *   依存はすべて内向き。パスパターンは実プロジェクトの構造に合わせて直してよいが、
 *   ルールの意味（内向き）は変えない。
 */
module.exports = {
  forbidden: [
    {
      name: 'entities-は何にも依存しない',
      comment:
        'entities は同一機能の entities と shared 以外を import しない（心臓部の独立）',
      severity: 'error',
      from: { path: '^src/([^/]+)/entities' },
      to: { path: '^src', pathNot: ['^src/$1/entities', '^src/shared'] },
    },
    {
      name: 'use-cases-は外側を知らない',
      comment: 'use-cases は adapters / infrastructure を import しない（依存は内向き）',
      severity: 'error',
      from: { path: '^src/[^/]+/use-cases' },
      to: { path: '^src/[^/]+/(adapters|infrastructure)' },
    },
    {
      name: '機能間の直接依存禁止',
      comment: '機能領域をまたぐ import は禁止（共有は shared 経由のみ）',
      severity: 'error',
      from: { path: '^src/([^/]+)/' },
      to: { path: '^src/[^/]+/', pathNot: ['^src/$1/', '^src/shared'] },
    },
    {
      name: '循環依存の禁止',
      severity: 'error',
      from: {},
      to: { circular: true },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsPreCompilationDeps: true,
  },
};
