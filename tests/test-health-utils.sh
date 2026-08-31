#!/bin/bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIRECTORY="$(mktemp -d)"
HEALTH_DIRECTORY="$TEST_DIRECTORY/health"
SERVER_DIRECTORY="$TEST_DIRECTORY/serverfiles"
STEAMCMD_DIRECTORY="$TEST_DIRECTORY/steamcmd"
trap 'rm -rf "$TEST_DIRECTORY"' EXIT
source "$REPOSITORY_ROOT/health-utils.sh"

write_rwr_health_state "$HEALTH_DIRECTORY" starting 1234 1240
grep -Fxq 'starting' "$HEALTH_DIRECTORY/status"
grep -Fxq '1234' "$HEALTH_DIRECTORY/pid"
grep -Fxq '1240' "$HEALTH_DIRECTORY/port"

write_rwr_health_state "$HEALTH_DIRECTORY" failed
grep -Fxq 'failed' "$HEALTH_DIRECTORY/status"
test ! -e "$HEALTH_DIRECTORY/pid"
test ! -e "$HEALTH_DIRECTORY/port"

mkdir -p "$STEAMCMD_DIRECTORY/steamapps"
printf '%s\n' \
  '"AppState"' \
  '{' \
  '  "appid" "270150"' \
  '  "buildid" "1785799152"' \
  '}' \
  > "$STEAMCMD_DIRECTORY/steamapps/appmanifest_270150.acf"

[ "$(find_rwr_steam_build_id "$SERVER_DIRECTORY" "$STEAMCMD_DIRECTORY")" = "1785799152" ]

printf '%s\n' \
  'RUNNING WITH RIFLES (c) Osumia Games 2023, 1.98.1, server build' \
  > "$TEST_DIRECTORY/console.log"
[ "$(extract_rwr_runtime_version "$TEST_DIRECTORY/console.log")" = "1.98.1" ]

echo "RWR health-state and version-info tests passed."
