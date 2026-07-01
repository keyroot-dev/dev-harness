#!/usr/bin/env bash
#
# check-config.sh — この設定リポジトリ自身の Fitness Function。
#
# このテンプレートは利用者のプロジェクトに対して「アーキテクチャ境界を文書の
# 『禁止』で終わらせず Lint/CI で機械強制せよ」と説いている。であれば、設定
# 自身の不変条件も機械的に守るべきだ。本スクリプトは以下を検査する:
#
#   1. .claude/skills/<name>/ には必ず SKILL.md がある
#   2. どこかで参照される Skill(<name>) は実在するスキルである
#   3. settings.json の allow に並ぶ Skill(<name>) は実在するスキルである
#   4. subagent_type で指名されるエージェントは .claude/agents/<name>.md として実在する
#
# 違反が1件でもあれば非ゼロ終了する（CI で落とせる）。
#
# 使い方:  bash scripts/check-config.sh

set -euo pipefail

# リポジトリルートへ移動（scripts/ の1つ上）
cd "$(dirname "$0")/.."

fail=0
err() { printf '  ❌ %s\n' "$1"; fail=1; }

# 注: `cmd | while ...` はパイプ右辺がサブシェルになり、ループ内の fail 代入が
#     親シェルへ伝わらない。そのため全ループをプロセス置換 `< <(...)` で回し、
#     fail を確実に親シェルへ反映させる。

echo "==> [1/4] 各スキルに SKILL.md が存在するか"
for dir in .claude/skills/*/; do
  [ -d "$dir" ] || continue
  [ -f "${dir}SKILL.md" ] || err "${dir} に SKILL.md がありません"
done

echo "==> [2/4] 参照される Skill(<name>) が実在するか（.md / .json 全体）"
while IFS= read -r name; do
  [ -z "$name" ] && continue
  [ -d ".claude/skills/${name}" ] \
    || err "Skill('${name}') が参照されていますが .claude/skills/${name}/ が存在しません"
done < <(grep -rhoE "Skill\(['\"]?[a-z0-9-]+['\"]?\)" .claude 2>/dev/null \
          | sed -E "s/Skill\(['\"]?([a-z0-9-]+)['\"]?\)/\1/" | sort -u)

echo "==> [3/4] subagent_type で指名されるエージェントが実在するか"
while IFS= read -r name; do
  [ -z "$name" ] && continue
  [ -f ".claude/agents/${name}.md" ] \
    || err "subagent_type \"${name}\" が指名されていますが .claude/agents/${name}.md が存在しません"
done < <(grep -rhoE "subagent_type[^\"']{0,4}[\"'][a-z0-9-]+[\"']" .claude 2>/dev/null \
          | sed -E "s/.*[\"']([a-z0-9-]+)[\"']$/\1/" | sort -u)

echo "==> [4/4] settings.json の allow するスキルが実在するか"
if [ -f .claude/settings.json ]; then
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    [ -d ".claude/skills/${name}" ] \
      || err "settings.json が Skill(${name}) を許可していますが該当スキルが存在しません"
  done < <(grep -oE "Skill\([a-z0-9-]+\)" .claude/settings.json 2>/dev/null \
            | sed -E "s/Skill\(([a-z0-9-]+)\)/\1/" | sort -u)
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "RESULT: ❌ 設定の不変条件に違反があります（上記を修正してください）"
  exit 1
fi
echo "RESULT: ✅ 設定の整合性チェックをパスしました"
