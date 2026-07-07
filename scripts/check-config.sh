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
#   5. .claude 配下・CLAUDE.md・README.md から相対参照される .md ファイルが実在する
#      （「正本」参照の網はファイル間リンクで編まれている。リネームによる静かな断線を防ぐ）
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

echo "==> [1/5] 各スキルに SKILL.md が存在するか"
for dir in .claude/skills/*/; do
  [ -d "$dir" ] || continue
  [ -f "${dir}SKILL.md" ] || err "${dir} に SKILL.md がありません"
done

echo "==> [2/5] 参照される Skill(<name>) が実在するか（.md / .json 全体）"
while IFS= read -r name; do
  [ -z "$name" ] && continue
  [ -d ".claude/skills/${name}" ] \
    || err "Skill('${name}') が参照されていますが .claude/skills/${name}/ が存在しません"
done < <(grep -rhoE "Skill\(['\"]?[a-z0-9-]+['\"]?\)" .claude 2>/dev/null \
          | sed -E "s/Skill\(['\"]?([a-z0-9-]+)['\"]?\)/\1/" | sort -u)

echo "==> [3/5] subagent_type で指名されるエージェントが実在するか"
while IFS= read -r name; do
  [ -z "$name" ] && continue
  [ -f ".claude/agents/${name}.md" ] \
    || err "subagent_type \"${name}\" が指名されていますが .claude/agents/${name}.md が存在しません"
done < <(grep -rhoE "subagent_type[^\"']{0,4}[\"'][a-z0-9-]+[\"']" .claude 2>/dev/null \
          | sed -E "s/.*[\"']([a-z0-9-]+)[\"']$/\1/" | sort -u)

echo "==> [4/5] settings.json の allow するスキルが実在するか"
if [ -f .claude/settings.json ]; then
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    [ -d ".claude/skills/${name}" ] \
      || err "settings.json が Skill(${name}) を許可していますが該当スキルが存在しません"
  done < <(grep -oE "Skill\([a-z0-9-]+\)" .claude/settings.json 2>/dev/null \
            | sed -E "s/Skill\(([a-z0-9-]+)\)/\1/" | sort -u)
fi

echo "==> [5/5] 参照される .md への相対パスが実在するか"
# 対象: スラッシュを含む .md 参照（`./guide.md` `guides/process.md` `.claude/...` 等）。
# docs/ と .steering/ は利用者プロジェクトで生成されるプレースホルダーなので対象外。
# 解決は「参照元ファイルのディレクトリ → リポジトリルート → .claude/skills/」の順で試す。
while IFS=: read -r file ref; do
  [ -z "$ref" ] && continue
  case "$ref" in
    /*|docs/*|.steering/*) continue ;;
    # 正式版ドキュメント6種は利用者プロジェクトで生成される成果物（テンプレートには存在しない）。
    # ガイド内の「生成物からの相対リンク例」（./architecture.md 等）はこのため対象外。
    *product-requirements.md|*functional-design.md|*architecture.md|*repository-structure.md|*development-guidelines.md|*glossary.md) continue ;;
  esac
  base="$(dirname "$file")"
  if [ -f "$ref" ] || [ -f "${base}/${ref}" ] || [ -f ".claude/skills/${ref}" ]; then
    continue
  fi
  err "${file} が『${ref}』を参照していますが、ファイルとして解決できません"
done < <(grep -roE "[A-Za-z0-9_.-]*(/[A-Za-z0-9_.-]+)+\.md" .claude CLAUDE.md README.md 2>/dev/null | sort -u)

echo
if [ "$fail" -ne 0 ]; then
  echo "RESULT: ❌ 設定の不変条件に違反があります（上記を修正してください）"
  exit 1
fi
echo "RESULT: ✅ 設定の整合性チェックをパスしました"
