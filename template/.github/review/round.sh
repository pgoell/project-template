#!/usr/bin/env bash
# shellcheck disable=SC2153 # ROUND and FROM come from the environment
set -euo pipefail

marker="<!-- ci-review:$KIND"

case $1 in
  plan)
    # The comment this workflow wrote, not one a person pasted the marker into.
    found=$(gh api --paginate "repos/$GITHUB_REPOSITORY/issues/$PR/comments" \
      --jq ".[] | select(.user.login == \"github-actions[bot]\") | select(.body | startswith(\"$marker\")) | [.id, .body] | @tsv" | tail -1)
    round=1
    from=$BASE_SHA
    comment_id=
    rerun=false
    if [ -n "$found" ]; then
      comment_id=${found%%$'\t'*}
      last_sha=$(sed -nE 's/.*sha=([0-9a-f]{40}).*/\1/p' <<<"$found")
      last_round=$(sed -nE 's/.*round=([0-9]+).*/\1/p' <<<"$found")
      round=$((last_round + 1))
      if [ "$last_sha" = "$HEAD_SHA" ]; then rerun=true; fi
      if git merge-base --is-ancestor "$last_sha" "$HEAD_SHA" 2>/dev/null; then
        from=$last_sha
      fi
    fi
    stop=$rerun
    {
      echo "round=$round"
      echo "from=$from"
      echo "comment_id=$comment_id"
      echo "stop=$stop"
      echo "rerun=$rerun"
    } >>"$GITHUB_OUTPUT"
    ;;
  record)
    text="**${KIND^}** round $ROUND covered \`${FROM:0:7}..${HEAD_SHA:0:7}\`."
    body="$marker sha=$HEAD_SHA round=$ROUND -->
$text"
    if [ -n "$COMMENT_ID" ]; then
      gh api -X PATCH "repos/$GITHUB_REPOSITORY/issues/comments/$COMMENT_ID" -f body="$body" >/dev/null
    else
      gh api "repos/$GITHUB_REPOSITORY/issues/$PR/comments" -f body="$body" >/dev/null
    fi
    ;;
esac
