#!/usr/bin/env bash
# Tests template/scripts/check-file-size, check-fan-out and structure-hook in
# throwaway git repos. No network. The canonical copies and their full tests
# live in pgoell/pgoell-claude-tools, plugins/structure/.
# Run from the repo root: bash tests/check-scripts.sh
set -uo pipefail

SCRIPTS="$(cd "$(dirname "$0")/../template/scripts" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0
check() {
  if [ "$2" = "$3" ]; then
    echo "ok   $1"
    pass=$((pass + 1))
  else
    echo "FAIL $1 (exit $2, want $3)"
    fail=$((fail + 1))
  fi
}

# Writes a file of $2 bytes at path $1, creating its folders.
mkfile() {
  mkdir -p "$(dirname "$1")"
  head -c "$2" /dev/zero | tr '\0' a >"$1"
}

# Makes a fresh repo in $REPO with the scripts in scripts/.
n=0
fresh() {
  n=$((n + 1))
  REPO="$WORK/repo$n"
  mkdir -p "$REPO/scripts"
  cp "$SCRIPTS/check-file-size" "$SCRIPTS/check-fan-out" "$SCRIPTS/structure-hook" "$REPO/scripts/"
  cd "$REPO" || exit 1
  git init -q
}

# Runs scripts/$1 with the other arguments; sets RC.
run() {
  local s=$1
  shift
  bash "scripts/$s" "$@" >/dev/null 2>&1
  RC=$?
}

# Feeds the hook a Write event for path $1; sets RC.
hook() {
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1" |
    bash scripts/structure-hook >/dev/null 2>&1
  RC=$?
}

# Writes files a1 to aN in folder $2.
files() { for i in $(seq 1 "$1"); do mkfile "$2/a$i" 1; done; }

fresh
mkfile big.md 20004
mkfile small.md 20000
git add -A
run check-file-size big.md
check "file-size: over the limit fails" "$RC" 1
run check-file-size small.md
check "file-size: at the limit passes" "$RC" 0

fresh
files 8 src
files 7 lib
files 9 .github/workflows
run check-fan-out --all
check "fan-out: 8 entries fail" "$RC" 1
run check-fan-out lib/a1
check "fan-out: 7 entries pass" "$RC" 0
run check-fan-out .github/workflows/a1
check "fan-out: dot folders are skipped" "$RC" 0
echo 'src/a8' >.gitignore
run check-fan-out src/a1
check "fan-out: an ignored file does not count" "$RC" 0
rm .gitignore

fresh
files 9 src
printf '%s\n' '# accepted' 'src 9' >.fan-out-baseline
run check-fan-out src/a1
check "fan-out: the baseline absorbs today's count" "$RC" 0
mkfile src/a10 1
run check-fan-out src/a1
check "fan-out: growth past the baseline fails" "$RC" 1
run check-fan-out --update-baseline
check "fan-out: update-baseline does not raise" "$(grep -c '^src 9$' .fan-out-baseline)" 1
printf '%s\n' '# a list by design' 'src' >.fan-out-excludes
run check-fan-out src/a1
check "fan-out: an excluded folder passes" "$RC" 0

fresh
mkfile big.md 20004
hook "$REPO/big.md"
check "hook: a big file exits 2" "$RC" 2
mkfile ok.md 10
hook "$REPO/ok.md"
check "hook: a small file exits 0" "$RC" 0

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
