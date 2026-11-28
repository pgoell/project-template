#!/usr/bin/env bash
set -euo pipefail

# Render from a copy of the working tree, not from the repo: copier 9.19
# checks a local repo out with `--end-of-options`, which git 2.43 does not
# know, and a copy also takes changes not yet committed.
src=$(mktemp -d)
git ls-files -coz --exclude-standard | tar --null -T - -c | tar -x -C "$src"
work=$(mktemp -d)

for stack in python typescript cpp rust rust-frontend none; do
  for context in personal work; do
    out=$work/$stack-$context
    echo "=== $stack, $context"
    args=(--data project_name=sample-project --data description="Sample project.")
    args+=(--data "stack=${stack%-frontend}" --data context=$context)
    if [ "$stack" = rust-frontend ]; then args+=(--data frontend=true); fi
    if [ "$context" = work ]; then args+=(--data "approvers=alice bob"); fi
    uvx copier copy -q --defaults "${args[@]}" "$src" "$out"
    (
      cd "$out"
      git init -q -b master
      mise trust -q
      mise install -q
      mise run -q install
      # The size check judges tracked files only.
      git add -A
      if [ "$stack" != none ]; then
        mise run lint
        mise run test
        git -c user.name=render -c user.email=render@example.com commit -qm "chore: render" --no-verify
        mise exec -- scripts/check-comments origin/master
      fi
      test -f .claude/skills/verify/SKILL.md
      scripts/check-file-size
      scripts/check-fan-out --all
      actionlint
      shellcheck .github/review/*.sh scripts/*.sh scripts/check-fan-out scripts/check-file-size scripts/structure-hook
      if [ "$context" = work ] && git grep --untracked -niE 'pgoell|pascal' -- . ':!.copier-answers.yml' ':!scripts/check-fan-out' ':!scripts/check-file-size' ':!scripts/structure-hook'; then
        echo "a work render names a person" >&2
        exit 1
      fi
    )
  done
done
echo "rendered and checked: $work"
