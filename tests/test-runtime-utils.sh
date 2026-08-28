#!/bin/bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIRECTORY="$(mktemp -d)"
COMMAND_PIPE="$TEST_DIRECTORY/commands"
COMMAND_LOG="$TEST_DIRECTORY/commands.log"
trap 'rm -rf "$TEST_DIRECTORY"' EXIT
source "$REPOSITORY_ROOT/runtime-utils.sh"

mkfifo "$COMMAND_PIPE"
(
  while IFS= read -r command; do
    printf '%s\n' "$command" >> "$COMMAND_LOG"
    [ "$command" = "exit" ] && exit 0
  done
) < "$COMMAND_PIPE" &
FAKE_SERVER_PID=$!
exec {COMMAND_FD}> "$COMMAND_PIPE"

graceful_stop_rwr "$FAKE_SERVER_PID" "$COMMAND_FD" 2 >/dev/null
exec {COMMAND_FD}>&-
wait "$FAKE_SERVER_PID"
diff -u \
  <(printf '%s\n' save_profiles stop_server exit) \
  "$COMMAND_LOG"

echo "RWR graceful-shutdown tests passed."
