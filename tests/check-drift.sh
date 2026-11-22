#!/usr/bin/env bash
set -uo pipefail

CANONICAL=${CANONICAL:-https://raw.githubusercontent.com/pgoell/pgoell-claude-tools/master/plugins/structure/skills/setting-up-the-checks/assets}
SCRIPTS="$(cd "$(dirname "$0")/../template/scripts" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

failed=0
for name in check-fan-out check-file-size structure-hook; do
  if ! curl -fsSL --max-time "${DRIFT_SECONDS:-30}" "$CANONICAL/$name" -o "$WORK/$name"; then
    echo "FAIL $name: cannot fetch $CANONICAL/$name"
    failed=1
  elif ! cmp -s "$WORK/$name" "$SCRIPTS/$name"; then
    echo "FAIL $name: differs from $CANONICAL/$name; copy those bytes to template/scripts/$name"
    failed=1
  elif [ ! -x "$SCRIPTS/$name" ]; then
    echo "FAIL $name: template/scripts/$name is not executable"
    failed=1
  else
    echo "ok   $name"
  fi
done
[ "$failed" -eq 0 ]
