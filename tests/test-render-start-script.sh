#!/bin/bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIRECTORY="$(mktemp -d)"
SOURCE_SCRIPT="$TEST_DIRECTORY/start_invasion.as"
RENDERED_SCRIPT="$TEST_DIRECTORY/rwr_unraid_start_invasion.as"
trap 'rm -rf "$TEST_DIRECTORY"' EXIT

printf '%s\n' \
  '#include "gamemode_invasion.as"' \
  'void main(dictionary@ inputData) {' \
  '  UserSettings settings;' \
  '  settings.m_startServerCommand = """' \
  "<command class='start_server'" \
  "  server_name='MyInvasion'" \
  "  server_port='1240'" \
  "  comment='Coop campaign'" \
  "  url=''" \
  "  register_in_serverlist='1'" \
  "  persistency='forever'" \
  "  max_players='32'>" \
  "  <client_faction id='0' />" \
  '</command>' \
  '""";' \
  '  GameModeInvasion metagame(settings);' \
  '}' \
  > "$SOURCE_SCRIPT"

SOURCE_CHECKSUM="$(sha256sum "$SOURCE_SCRIPT" | awk '{print $1}')"

SERVER_NAME='Test Server' \
SERVER_COMMENT='Test campaign' \
SERVER_URL='https://example.com/rwr' \
SERVER_PORT=1250 \
MAX_PLAYERS=40 \
PUBLIC_SERVER=false \
FACTION=2 \
PERSISTENCY=forever_and_match \
  "$REPOSITORY_ROOT/render-start-script.sh" "$SOURCE_SCRIPT" "$RENDERED_SCRIPT"

grep -Fq "server_name='Test Server'" "$RENDERED_SCRIPT"
grep -Fq "comment='Test campaign'" "$RENDERED_SCRIPT"
grep -Fq "url='https://example.com/rwr'" "$RENDERED_SCRIPT"
grep -Fq "server_port='1250'" "$RENDERED_SCRIPT"
grep -Fq "register_in_serverlist='0'" "$RENDERED_SCRIPT"
grep -Fq "persistency='forever_and_match'" "$RENDERED_SCRIPT"
grep -Fq "max_players='40'" "$RENDERED_SCRIPT"
grep -Fq "<client_faction id='2' />" "$RENDERED_SCRIPT"
grep -Fq '#include "rwr_unraid_persistent_invasion.as"' "$RENDERED_SCRIPT"
grep -Eq 'RwrUnraidPersistentInvasion[[:space:]]+metagame\(settings\);' "$RENDERED_SCRIPT"

PERSISTENCE_SOURCE="$REPOSITORY_ROOT/rwr-unraid-persistent-invasion.as"
grep -Fq 'class RwrUnraidPersistentInvasion : GameModeInvasion' "$PERSISTENCE_SOURCE"
grep -Fq 'settings.m_continue = true;' "$PERSISTENCE_SOURCE"
grep -Fq 'commandRoot.setStringAttribute("class", "save_data");' "$PERSISTENCE_SOURCE"
grep -Fq 'if (root !is null) {' "$PERSISTENCE_SOURCE"
grep -Fq 'persistent invasion metagame not found; starting fresh' "$PERSISTENCE_SOURCE"
grep -Fq 'm_mapRotator.save(root);' "$PERSISTENCE_SOURCE"
grep -Fq 'm_mapRotator.load(root);' "$PERSISTENCE_SOURCE"

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

if PERSISTENCY=invalid \
  "$REPOSITORY_ROOT/render-start-script.sh" "$SOURCE_SCRIPT" "$TEST_DIRECTORY/invalid-persistency.as" \
  >/dev/null 2>&1; then
  echo "Invalid PERSISTENCY was accepted."
  exit 1
fi

MISSION_PERSISTENCE=false \
  "$REPOSITORY_ROOT/render-start-script.sh" "$SOURCE_SCRIPT" "$TEST_DIRECTORY/nonpersistent.as"
if grep -Fq 'rwr_unraid_persistent_invasion.as' "$TEST_DIRECTORY/nonpersistent.as"; then
  echo "Mission persistence was enabled when explicitly disabled."
  exit 1
fi

if MISSION_PERSISTENCE=invalid \
  "$REPOSITORY_ROOT/render-start-script.sh" "$SOURCE_SCRIPT" "$TEST_DIRECTORY/invalid-persistence.as" \
  >/dev/null 2>&1; then
  echo "Invalid MISSION_PERSISTENCE was accepted."
  exit 1
fi

if SERVER_URL='https://example.com/?a=1&b=2' \
  "$REPOSITORY_ROOT/render-start-script.sh" "$SOURCE_SCRIPT" "$TEST_DIRECTORY/invalid-url.as" \
  >/dev/null 2>&1; then
  echo "Unsafe SERVER_URL was accepted."
  exit 1
fi

echo "RWR startup-script rendering tests passed."
