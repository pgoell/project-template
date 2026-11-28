#!/usr/bin/env bash
set -uo pipefail

SCRIPTS="$(cd "$(dirname "$0")/../template/scripts" && pwd)"
TESTS="$(cd "$(dirname "$0")" && pwd)"
CI="$TESTS/../template/.github/workflows/ci.yml.jinja"
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

mkfile() {
  mkdir -p "$(dirname "$1")"
  head -c "$2" /dev/zero | tr '\0' a >"$1"
}

n=0
fresh() {
  n=$((n + 1))
  REPO="$WORK/repo$n"
  mkdir -p "$REPO/scripts"
  cp "$SCRIPTS/check-file-size" "$SCRIPTS/check-fan-out" "$SCRIPTS/structure-hook" "$SCRIPTS/check-comments" "$REPO/scripts/"
  cd "$REPO" || exit 1
  git init -q
  git config user.email test@example.com
  git config user.name test
}

run() {
  local s=$1
  shift
  case $s in
  check-comments) python3 "scripts/$s" "$@" >/dev/null 2>&1 ;;
  *) bash "scripts/$s" "$@" >/dev/null 2>&1 ;;
  esac
  RC=$?
}

hook() {
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1" |
    bash scripts/structure-hook >/dev/null 2>&1
  RC=$?
}

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

: >"$WORK/global.toml"
(cd "$TESTS/.." && MISE_GLOBAL_CONFIG_FILE=$WORK/global.toml mise which jq) >/dev/null 2>&1
check "hook: the root mise.toml gives the tests their jq" "$?" 0

fresh
printf '#!/bin/sh\ntouch "%s/pwned"\n' "$REPO" >pwn.sh
chmod +x pwn.sh
git config core.fsmonitor "$REPO/pwn.sh"
mkfile note.md 10
hook "$REPO/note.md"
check "hook: core.fsmonitor of the edited repo does not run (pgoell/pgoell-claude-tools#324)" "$([ -e pwned ] && echo ran || echo clean)" clean

staged() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" >"$1"
  git add "$1"
  run check-comments
}

fresh
staged src/a.py 'x = 1  # set x'
check "comments: a Python comment fails" "$RC" 1
staged src/a.py 'x = "# in a string"'
check "comments: a hash in a Python string passes" "$RC" 0
staged src/a.py "$(printf '#!/usr/bin/env python3\nx = 1  # noqa: E501\ny = 2  # https://example.com/issue/1\n# SPDX-License-Identifier: MIT')"
check "comments: a shebang, directive, link and license pass" "$RC" 0
staged src/a.ts 'let a = 1; // narrate'
check "comments: a TypeScript line comment fails" "$RC" 1
staged src/a.ts "$(printf '/** Public. */\nconst s = "// no";\nconst t = `${"/*"} x`;')"
check "comments: a doc comment and slashes in strings pass" "$RC" 0
staged src/a.cpp "$(printf 'auto r = R"x(// )" no)x";\nint n = 1'"'"'000;\n}  // namespace demo')"
check "comments: a raw string, digit separators and a namespace end pass" "$RC" 0
staged src/a.cpp "$(printf '/* block\n   prose */\nint n = 1;')"
check "comments: a C++ block comment fails" "$RC" 1
staged notes.sh '# shell is not checked'
git rm -q --cached src/a.cpp
run check-comments
check "comments: other languages pass" "$RC" 0
staged src/a.rs 'let a = 1; // narrate'
check "comments: a Rust line comment fails" "$RC" 1
staged src/a.rs "$(printf '/* outer /* inner */ still prose */\nfn f() {}')"
check "comments: a nested Rust block comment fails" "$RC" 1
staged src/a.rs "$(printf '//! Crate docs.\n/// Item docs.\nfn f<'"'"'a>(s: &'"'"'a str) -> char {\n    let _ = r#"// "no" /* "#;\n    let _ = "a \\" // b";\n    let _ = b'"'"'"'"'"';\n    // SAFETY: nothing unsafe here\n    '"'"'/'"'"'\n}')"
check "comments: Rust docs, lifetimes, chars, strings and SAFETY pass" "$RC" 0

fresh
printf 'x = 1  # old\n' >a.py
git add a.py
git commit -qm one
printf 'x = 1  # old\ny = 2\n' >a.py
git add a.py
run check-comments
check "comments: an old comment in a changed file passes" "$RC" 0
git commit -qm two
git branch base
printf 'x = 1  # old\ny = 2\nz = 3  # new\n' >a.py
git commit -qam three
run check-comments base
check "comments: a comment added since the base fails" "$RC" 1
run check-comments origin/nowhere
check "comments: an unknown base checks every line" "$RC" 1
printf '%s\n' '# generated' 'a.py' >.comments-excludes
run check-comments base
check "comments: an excluded path passes" "$RC" 0

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
mkdir -p "$WORK/modes/tests" "$WORK/modes/template"
cp "$TESTS/check-drift.sh" "$WORK/modes/tests/"
cp -r "$SCRIPTS" "$WORK/modes/template/scripts"
chmod -x "$WORK/modes/template/scripts/structure-hook"
CANONICAL="file://$CANON" bash "$WORK/modes/tests/check-drift.sh" >/dev/null 2>&1
check "drift: a copy that lost its executable bit fails" "$?" 1

python3 -c 'import socket,time; s=socket.socket(); s.bind(("127.0.0.1",0)); s.listen(); print(s.getsockname()[1],flush=True); time.sleep(30)' >"$WORK/port" &
stall=$!
until [ -s "$WORK/port" ]; do sleep 0.1; done
CANONICAL="http://127.0.0.1:$(cat "$WORK/port")" DRIFT_SECONDS=1 timeout 15 bash "$TESTS/check-drift.sh" >/dev/null 2>&1
check "drift: a server that never answers fails in time" "$?" 1
kill "$stall"

check "ci: the Lint job sets timeout-minutes" "$(sed -n '/^  lint:$/,/^    steps:$/p' "$CI" | grep -c '^    timeout-minutes: ')" 1
check "ci: a draft marked ready starts a run, so it gets the reviews it skipped" "$(grep -c '^    types: \[opened, synchronize, reopened, ready_for_review\]$' "$CI")" 1
check "ci: no workflow runs on pull_request_target, where a fork would meet the secrets" "$(cat "$TESTS"/../template/.github/workflows/* | grep -c pull_request_target)" 0
check "ci: the review checkout keeps no credentials" "$(grep -c '^          persist-credentials: false$' "$CI")" 1
check "ci: the reviewer's commands run without the tokens" "$(grep -c '^          CLAUDE_CODE_SUBPROCESS_ENV_SCRUB: 1$' "$CI")" 1
check "ci: the reviewer may not read .git, which holds a token" "$(grep -cF -- '--disallowedTools "Read(./.git/**)"' "$CI")" 1
check "ci: the reviewer's tools are the fixed list" "$(grep -cF -- '--allowedTools "Read(./**),Write(./.review/summary.md),Edit(./.review/summary.md),Bash(git diff:*),Bash(git log:*),Bash(git show:*),Bash(git grep:*),Bash(git ls-files:*),mcp__github_inline_comment__create_inline_comment"' "$CI")" 1

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
