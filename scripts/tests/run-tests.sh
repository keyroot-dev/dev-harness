#!/usr/bin/env bash
#
# run-tests.sh — scripts/ 配下のスクリプト自身の回帰テスト・ランナー。
#
# このテンプレートの Fitness Function（check-config.sh / progress.sh 等）は
# 規律を機械強制する要であり、これ自体が静かに壊れると規律全体が壊れる。
# 特に progress.sh は docs/backlog.md の列位置（$5=状態, $6=steering）に
# 暗黙依存しており、テンプレート変更で気づかず壊れやすい。ここで回帰を検出する。
#
# 設計: 外部フレームワーク（bats 等）に依存しない純 bash（言語非依存・依存最小
# 主義に合わせる）。各テストは一時サンドボックスに「ミニ・リポジトリ」を組み立て、
# 検査対象スクリプトをコピーして実行し、終了コードと出力を検証する。
# 入力データはテスト内のヒアドキュメントで自己完結させる（テストと入力を1画面で読める）。
#
# 使い方:  bash scripts/tests/run-tests.sh            # 全テスト
#          bash scripts/tests/run-tests.sh progress   # 名前に一致するテストファイルのみ

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TESTS_DIR="$ROOT/scripts/tests"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
CURRENT=""
SB=""
OUT=""
RC=0

# ── テストヘルパー（各 test-*.sh から使う） ──────────────────────────

# test_case <名前>: 以後のアサーションが属するテスト名を宣言する
test_case() { CURRENT="$1"; }

# sandbox <名前>: ミニ・リポジトリを新設し、scripts/*.sh をコピーして SB に設定する
sandbox() {
  SB="$TMP/$1-$RANDOM"
  mkdir -p "$SB/scripts"
  cp "$ROOT"/scripts/*.sh "$SB/scripts/"
  if [ -d "$ROOT/scripts/hooks" ]; then
    mkdir -p "$SB/scripts/hooks"
    cp "$ROOT"/scripts/hooks/*.sh "$SB/scripts/hooks/" 2>/dev/null || true
  fi
}

# run <scripts/ 内のスクリプト名> [引数...]: サンドボックス内で実行し OUT / RC に格納
run() {
  local script="$1"
  shift || true
  OUT="$(cd "$SB" && bash "scripts/$script" "$@" 2>&1)"
  RC=$?
}

# run_stdin <stdin文字列> <スクリプトパス> [引数...]: stdin を与えて実行（hooks 用）
run_stdin() {
  local stdin="$1" script="$2"
  shift 2 || true
  OUT="$(cd "$SB" && printf '%s' "$stdin" | bash "$script" "$@" 2>&1)"
  RC=$?
}

_ok() { PASS=$((PASS + 1)); printf '  ✅ %s\n' "$CURRENT"; }
_ng() {
  FAIL=$((FAIL + 1))
  printf '  ❌ %s\n     %s\n' "$CURRENT" "$1"
  printf '%s\n' "$OUT" | sed 's/^/     | /'
}

# 注: メッセージ内の変数は必ず ${var} と波括弧で書く。bash 3.2（macOS 標準）は
#     "$var" の直後にマルチバイト文字（『』・全角括弧）が続くと変数名の解釈を誤る。

# assert_rc <期待終了コード>
assert_rc() {
  if [ "$RC" -eq "$1" ]; then _ok; else _ng "終了コード: 期待 ${1} / 実際 ${RC}"; fi
}

# assert <期待終了コード> <出力に含まれるべき文字列>
assert() {
  if [ "$RC" -eq "$1" ] && printf '%s' "$OUT" | grep -qF "$2"; then
    _ok
  else
    _ng "期待: 終了コード ${1} かつ出力に『${2}』（実際の終了コード: ${RC}）"
  fi
}

# assert_not_contains <期待終了コード> <出力に含まれてはいけない文字列>
assert_not_contains() {
  if [ "$RC" -eq "$1" ] && ! printf '%s' "$OUT" | grep -qF "$2"; then
    _ok
  else
    _ng "期待: 終了コード ${1} かつ出力に『${2}』を含まない（実際の終了コード: ${RC}）"
  fi
}

# ── テストファイルの実行 ─────────────────────────────────────────────

filter="${1:-}"
found=0
for tf in "$TESTS_DIR"/test-*.sh; do
  [ -f "$tf" ] || continue
  if [ -n "$filter" ] && ! printf '%s' "$(basename "$tf")" | grep -qF "$filter"; then
    continue
  fi
  found=1
  echo "==> $(basename "$tf")"
  # shellcheck source=/dev/null
  . "$tf"
done

if [ "$found" -eq 0 ]; then
  echo "実行対象のテストがありません（filter: ${filter:-なし}）"
  exit 1
fi

echo
if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: ❌ ${FAIL} 件失敗（成功 ${PASS} 件）"
  exit 1
fi
echo "RESULT: ✅ 全 ${PASS} 件成功"
