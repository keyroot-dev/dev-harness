# プロダクトバックログ

> **行の存在と優先度は「意図」**（`docs/product-requirements.md` から導出・人が舵を握る）。
> **状態列だけは「描写」**であり、`/add-feature` が着手時（`[-] 実装中`）・完了時（`[x] 完了`）に機械的に更新する。**手で `[x]` にしない。**
> 状態の記法は tasklist.md と同じ3値: `[ ]` 未着手 → `[-]` 実装中 → `[x]` 完了。
> 集計・鮮度検査は `bash scripts/progress.sh`、PM向け報告は `/progress-report`。

| # | 機能 | 優先度 | 状態 | steering |
|---|------|--------|------|----------|
| 1 | {機能名（PRDのコア機能から導出）} | 高 | [ ] 未着手 | - |
| 2 | {機能名} | 中 | [ ] 未着手 | - |

## 運用ルール

- **機能の追加・優先度の変更は意図の変更** — ユーザーが決める。実装フローが勝手に行った場合はスコープ変更として完了報告で明示する
- 状態列の正規更新経路は `bash scripts/backlog-state.sh start "<機能名>" "<steering名>"`（着手）／ `bash scripts/backlog-state.sh done "<機能名>"`（完了）。`/add-feature` はこれを実行する。該当行が無ければ start が行を追加する。Edit による状態マーカーの直接変更は hooks がブロックする
- **完了の定義**: 該当 steering の tasklist.md が全タスク `[x]`（規律の正本は steering スキル モード2「タスク完遂規律」）。backlog の `[x]` と tasklist の実態の乖離は `scripts/progress.sh` が機械検出する
