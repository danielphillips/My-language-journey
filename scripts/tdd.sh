#!/usr/bin/env bash
# Runs the core test suite and appends the tail of the output to docs/TDD-LOG.md
# as evidence for a RED or GREEN step.
# Usage: scripts/tdd.sh "<RED|GREEN|REFACTOR>: <description>" [swift test --filter pattern]
set -uo pipefail
label="$1"; filter="${2:-}"
root="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/opt/swift/usr/bin:$PATH"
cd "$root/Packages/MyRussianCore"
args=(test)
[[ -n "$filter" ]] && args+=(--filter "$filter")
out="$(swift "${args[@]}" 2>&1 | sed "s/\x1b\[[0-9;]*m//g")"; status=$?
summary="$(printf '%s\n' "$out" | grep -E "error:|✘|Test run with|Suite .* (passed|failed)|recorded an issue" | grep -v "^\s*$" | tail -n 25)"
{
  echo
  echo "### $label"
  echo
  echo "\`swift test${filter:+ --filter $filter}\` → exit $status"
  echo
  echo '```'
  printf '%s\n' "$summary"
  echo '```'
} >> "$root/docs/TDD-LOG.md"
printf '%s\n' "$summary"
exit $status
