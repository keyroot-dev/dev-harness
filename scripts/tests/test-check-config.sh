# test-check-config.sh — check-config.sh（設定リポジトリ自身の Fitness Function）の回帰テスト。
# run-tests.sh から source される。7検査それぞれが「壊れた入力で確実に❌になる」ことを守る。

# 全検査をパスする最小の正常構成をサンドボックスに種まきする。
# 各テストはここから1点だけ壊し、対象の検査だけが落ちることを確認する。
seed_valid_config() {
  mkdir -p "$SB/.claude/skills/foo" "$SB/.claude/agents" "$SB/.claude/rules"
  cat > "$SB/.claude/skills/foo/SKILL.md" <<'EOF'
---
name: foo
description: テスト用スキル
---

# foo

本文。`Skill('foo')` を利用し、subagent_type: "bar" を起動する。
EOF
  cat > "$SB/.claude/agents/bar.md" <<'EOF'
---
name: bar
description: テスト用エージェント
tools: Read
model: sonnet
---

# bar
EOF
  cat > "$SB/.claude/rules/sample.md" <<'EOF'
---
paths:
  - "docs/**"
---

# サンプル規律

`.claude/skills/foo/SKILL.md` を参照する。
EOF
  cat > "$SB/.claude/settings.json" <<'EOF'
{ "permissions": { "allow": ["Skill(foo)"] } }
EOF
}

test_case "check-config: 最小の正常構成をパスする"
sandbox cc-ok
seed_valid_config
run check-config.sh
assert 0 "✅"

test_case "check-config: [1] SKILL.md の無いスキルディレクトリを検出する"
sandbox cc-noskillmd
seed_valid_config
mkdir -p "$SB/.claude/skills/empty"
run check-config.sh
assert 1 "SKILL.md がありません"

test_case "check-config: [2] 実在しないスキルへの Skill() 参照を検出する"
sandbox cc-ghostskill
seed_valid_config
printf '\n`Skill('"'"'ghost'"'"')` も使う。\n' >> "$SB/.claude/skills/foo/SKILL.md"
run check-config.sh
assert 1 "ghost"

test_case "check-config: [3] 実在しない subagent_type の指名を検出する"
sandbox cc-ghostagent
seed_valid_config
printf '\nsubagent_type: "phantom" を起動する。\n' >> "$SB/.claude/skills/foo/SKILL.md"
run check-config.sh
assert 1 "phantom"

test_case "check-config: [4] settings.json が実在しないスキルを allow していたら検出する"
sandbox cc-ghostallow
seed_valid_config
cat > "$SB/.claude/settings.json" <<'EOF'
{ "permissions": { "allow": ["Skill(foo)", "Skill(vanished)"] } }
EOF
run check-config.sh
assert 1 "vanished"

test_case "check-config: [5] 解決できない .md 相対参照（断線）を検出する"
sandbox cc-brokenref
seed_valid_config
printf '\n詳細は `guides/nothing.md` を参照。\n' >> "$SB/.claude/rules/sample.md"
run check-config.sh
assert 1 "解決できません"

test_case "check-config: [6] 閉じていないフロントマターを検出する"
sandbox cc-openfm
seed_valid_config
cat > "$SB/.claude/skills/foo/SKILL.md" <<'EOF'
---
name: foo
description: 閉じの --- が無い

# foo
EOF
run check-config.sh
assert 1 "閉じていません"

test_case "check-config: [6] フロントマターの未知キー（タイポ）を検出する"
sandbox cc-unknownkey
seed_valid_config
cat > "$SB/.claude/rules/sample.md" <<'EOF'
---
pathes:
  - "docs/**"
---

# サンプル規律
EOF
run check-config.sh
assert 1 "未知のキー"

test_case "check-config: [7] 参照先に無い見出し（見出しリネームの断線）を検出する"
sandbox cc-brokenheading
seed_valid_config
printf '\n`.claude/skills/foo/SKILL.md`「存在しない見出し」に従う。\n' >> "$SB/.claude/rules/sample.md"
run check-config.sh
assert 1 "該当する見出しがありません"

test_case "check-config: [7] 実在する見出しへの参照はパスする"
sandbox cc-okheading
seed_valid_config
printf '\n`.claude/skills/foo/SKILL.md`「foo」に従う。\n' >> "$SB/.claude/rules/sample.md"
run check-config.sh
assert 0 "✅"
