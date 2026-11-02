#!/usr/bin/env bash
# Tests template/scripts/check-file-size, check-fan-out and structure-hook in
# throwaway git repos, and tests/check-drift.sh and the shellcheck line of
# tests/render.sh on planted faults. No network. Needs shellcheck, so run it
# through mise. The canonical copies and their full tests
# live in pgoell/pgoell-claude-tools, plugins/structure/.
# Run from the repo root: mise run test-scripts
set -uo pipefail

SCRIPTS="$(cd "$(dirname "$0")/../template/scripts" && pwd)"
TESTS="$(cd "$(dirname "$0")" && pwd)"
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

# The fix of #324 in pgoell/pgoell-claude-tools: the hook obeys no config of the
# edited repo, so core.fsmonitor there runs nothing.
fresh
printf '#!/bin/sh\ntouch "%s/pwned"\n' "$REPO" >pwn.sh
chmod +x pwn.sh
git config core.fsmonitor "$REPO/pwn.sh"
mkfile note.md 10
hook "$REPO/note.md"
check "hook: core.fsmonitor of the edited repo does not run" "$([ -e pwned ] && echo ran || echo clean)" clean

# Runs the drift test against a canonical folder on disk; sets RC.
drift() {
  CANONICAL="file://$1" bash "$TESTS/check-drift.sh" >/dev/null 2>&1
  RC=$?
}

CANON="$WORK/canon"
mkdir "$CANON"
cp "$SCRIPTS/check-file-size" "$SCRIPTS/check-fan-out" "$SCRIPTS/structure-hook" "$CANON/"
drift "$CANON"
check "drift: equal copies pass" "$RC" 0
for name in check-file-size check-fan-out structure-hook; do
  echo '# one more line' >>"$CANON/$name"
  drift "$CANON"
  check "drift: a changed canonical $name fails" "$RC" 1
  cp "$SCRIPTS/$name" "$CANON/$name"
  rm "$CANON/$name"
  drift "$CANON"
  check "drift: a canonical $name gone fails" "$RC" 1
  cp "$SCRIPTS/$name" "$CANON/$name"
done
drift "$WORK/nowhere"
check "drift: no answer from the canonical repo fails" "$RC" 1
# A copy of the test beside a copy of the scripts, so no real file loses its bit.
mkdir -p "$WORK/modes/tests" "$WORK/modes/template"
cp "$TESTS/check-drift.sh" "$WORK/modes/tests/"
cp -r "$SCRIPTS" "$WORK/modes/template/scripts"
chmod -x "$WORK/modes/template/scripts/structure-hook"
CANONICAL="file://$CANON" bash "$WORK/modes/tests/check-drift.sh" >/dev/null 2>&1
check "drift: a copy that lost its executable bit fails" "$?" 1

# Runs the shellcheck line of tests/render.sh in a folder laid out like a render,
# with a fault planted in scripts/$1 (none when $1 is empty); sets RC.
line=$(grep -E '^ *shellcheck ' "$TESTS/render.sh" | sed 's/^ *//')
lint() {
  fresh
  mkdir -p .github/review
  printf '#!/bin/sh\necho ok\n' >.github/review/a.sh
  printf '#!/bin/sh\necho ok\n' >scripts/a.sh
  printf '#!/bin/sh\necho ok\n' | tee scripts/check-file-size scripts/check-fan-out scripts/structure-hook >/dev/null
  if [ -n "$1" ]; then printf 'echo $1 $2\n' >>"scripts/$1"; fi
  eval "$line" >/dev/null 2>&1
  RC=$?
}
lint ''
check "shellcheck: clean scripts pass" "$RC" 0
for name in check-file-size check-fan-out structure-hook a.sh; do
  lint "$name"
  check "shellcheck: a fault in $name fails" "$RC" 1
done

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
