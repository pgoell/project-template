#!/usr/bin/env bash
# Anyone may comment on a public pull request; a stranger's comment must not
# reach the reviewer as if it were part of the task.
set -euo pipefail

mkdir -p .review
author=$(gh api "repos/$GITHUB_REPOSITORY/pulls/$PR" --jq .user.login)
# shellcheck disable=SC2086 # APPROVERS splits into one login per word
trusted=$(jq -cn '$ARGS.positional' --args "github-actions[bot]" "$author" $APPROVERS)
{
  gh api "repos/$GITHUB_REPOSITORY/pulls/$PR" \
    --jq "if (.user.login | IN(${trusted}[])) then \"# \" + .title + \"\n\n\" + (.body // \"\") else \"# \" + .title end"
  for n in $(gh api "repos/$GITHUB_REPOSITORY/pulls/$PR" --jq '.body // ""' |
    grep -oiE '(closes|fixes|resolves|part of) #[0-9]+' | grep -oE '[0-9]+' | sort -u); do
    echo
    gh api "repos/$GITHUB_REPOSITORY/issues/$n" \
      --jq "if (.user.login | IN(${trusted}[])) then \"## Issue #$n: \" + .title + \"\n\n\" + (.body // \"\") else \"## Issue #$n (by someone else, not shown)\" end" ||
      echo "## Issue #$n (not found)"
  done
  echo
  echo "## Earlier review threads"
  gh api --paginate "repos/$GITHUB_REPOSITORY/pulls/$PR/comments" \
    --jq ".[] | select(.user.login | IN(${trusted}[])) | \"\n### \" + .path + \":\" + ((.line // .original_line) | tostring) + \" (\" + .user.login + \")\n\" + .body"
  echo
  echo "## Earlier summaries"
  gh api --paginate "repos/$GITHUB_REPOSITORY/issues/$PR/comments" \
    --jq '.[] | select(.user.login == "github-actions[bot]") | select(.body | startswith("**Review**") or startswith("**Security**")) | "\n" + .body'
} >.review/context.md
