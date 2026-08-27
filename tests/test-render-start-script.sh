#!/bin/bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIRECTORY="$(mktemp -d)"
SOURCE_SCRIPT="$TEST_DIRECTORY/start_invasion.as"
RENDERED_SCRIPT="$TEST_DIRECTORY/rwr_unraid_start_invasion.as"
trap 'rm -rf "$TEST_DIRECTORY"' EXIT

printf '%s\n' \
  'void main(dictionary@ inputData) {' \
  '  settings.m_startServerCommand = """' \
  "<command class='start_server'" \
  "  server_name='MyInvasion'" \
  "  server_port='1240'" \
  "  register_in_serverlist='1'" \
  "  max_players='32'>" \
  "  <client_faction id='0' />" \
  '</command>' \
  '""";' \
  '}' \
  > "$SOURCE_SCRIPT"

SOURCE_CHECKSUM="$(sha256sum "$SOURCE_SCRIPT" | awk '{print $1}')"

SERVER_NAME='Test Server' \
SERVER_PORT=1250 \
MAX_PLAYERS=40 \
PUBLIC_SERVER=false \
FACTION=2 \
  "$REPOSITORY_ROOT/render-start-script.sh" "$SOURCE_SCRIPT" "$RENDERED_SCRIPT"

grep -Fq "server_name='Test Server'" "$RENDERED_SCRIPT"
grep -Fq "server_port='1250'" "$RENDERED_SCRIPT"
grep -Fq "register_in_serverlist='0'" "$RENDERED_SCRIPT"
grep -Fq "max_players='40'" "$RENDERED_SCRIPT"
grep -Fq "<client_faction id='2' />" "$RENDERED_SCRIPT"

if [ "$SOURCE_CHECKSUM" != "$(sha256sum "$SOURCE_SCRIPT" | awk '{print $1}')" ]; then
  echo "Source RWR script was modified."
  exit 1
fi

if SERVER_PORT=0 \
  "$REPOSITORY_ROOT/render-start-script.sh" "$SOURCE_SCRIPT" "$TEST_DIRECTORY/invalid.as" \
  >/dev/null 2>&1; then
  echo "Invalid SERVER_PORT was accepted."
  exit 1
fi

echo "RWR startup-script rendering tests passed."

