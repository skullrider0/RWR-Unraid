#!/bin/bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIRECTORY="$(mktemp -d)"
SERVER_DIRECTORY="$TEST_DIRECTORY/serverfiles"
FAILURE_SERVER_DIRECTORY="$TEST_DIRECTORY/failure-serverfiles"
HEALTH_DIRECTORY="$TEST_DIRECTORY/health"
STEAMCMD_DIRECTORY="$TEST_DIRECTORY/steamcmd"
DEFAULTS_DIRECTORY="$TEST_DIRECTORY/defaults"
MOCK_STEAMCMD="$STEAMCMD_DIRECTORY/steamcmd.sh"
COMMAND_LOG="$TEST_DIRECTORY/commands.log"
ATTEMPT_LOG="$TEST_DIRECTORY/attempts.log"
trap 'rm -rf "$TEST_DIRECTORY"' EXIT

mkdir -p "$STEAMCMD_DIRECTORY/linux32" "$DEFAULTS_DIRECTORY"
printf 'steamclient\n' > "$STEAMCMD_DIRECTORY/linux32/steamclient.so"
printf '<options />\n' > "$DEFAULTS_DIRECTORY/config.xml"
printf '<settings />\n' > "$DEFAULTS_DIRECTORY/settings.xml"

cat > "$MOCK_STEAMCMD" <<'EOF'
#!/bin/bash
printf 'attempt\n' >> "$ATTEMPT_LOG"
if [ "${STEAMCMD_FAIL:-false}" = "true" ]; then
  echo "No Connection"
  exit 1
fi

mkdir -p \
  "$SERVERDIR/media/packages/vanilla/maps/lobby" \
  "$SERVERDIR/media/packages/vanilla/scripts"
printf 'binary\n' > "$SERVERDIR/rwr_server"
printf '<package />\n' > "$SERVERDIR/media/packages/vanilla/package_config.xml"
printf '<map_config />\n' > "$SERVERDIR/media/packages/vanilla/maps/lobby/map_config.xml"
printf 'void main() {}\n' > "$SERVERDIR/media/packages/vanilla/scripts/start_invasion.as"
cat > "$SERVERDIR/launch_server" <<'SERVER'
#!/bin/bash
echo "Game loaded"
while IFS= read -r command; do
  printf '%s\n' "$command" >> "$COMMAND_LOG"
  exit 0
done
SERVER
chmod +x "$SERVERDIR/launch_server"
echo "Success! App '270150' fully installed."
EOF
chmod +x "$MOCK_STEAMCMD"

run_startup() {
  local selected_server_directory="$1"
  shift
  env \
    SERVERDIR="$selected_server_directory" \
    STEAMCMDDIR="$STEAMCMD_DIRECTORY" \
    STEAMCMD="$MOCK_STEAMCMD" \
    DEFAULTSDIR="$DEFAULTS_DIRECTORY" \
    RWR_LIBDIR="$REPOSITORY_ROOT" \
    RWR_HEALTH_DIR="$HEALTH_DIRECTORY" \
    ADMIN_RENDERER="$REPOSITORY_ROOT/render-admins.sh" \
    START_SCRIPT_RENDERER="$REPOSITORY_ROOT/render-start-script.sh" \
    COMMAND_LOG="$COMMAND_LOG" \
    ATTEMPT_LOG="$ATTEMPT_LOG" \
    MANAGE_SERVER_SETTINGS=false \
    STARTUP_TIMEOUT=5 \
    SHUTDOWN_TIMEOUT=2 \
    STEAMCMD_RETRIES=0 \
    "$@" \
    "$REPOSITORY_ROOT/start.sh"
}

run_startup "$SERVER_DIRECTORY" \
  STEAM_USER=test-user \
  STEAM_PASS=do-not-print-this-password \
  > "$TEST_DIRECTORY/first-start.log"

test -f "$SERVER_DIRECTORY/.rwr-installed"
test -f "$SERVER_DIRECTORY/config.xml"
test -f "$SERVER_DIRECTORY/settings.xml"
grep -Fxq 'start_script start_invasion.as' "$COMMAND_LOG"
[ "$(wc -l < "$ATTEMPT_LOG")" -eq 1 ]
if grep -Fq 'do-not-print-this-password' "$TEST_DIRECTORY/first-start.log"; then
  echo "Steam password was exposed by startup."
  exit 1
fi

run_startup "$SERVER_DIRECTORY" > "$TEST_DIRECTORY/restart.log"
[ "$(wc -l < "$ATTEMPT_LOG")" -eq 1 ]
grep -Fq 'SteamCMD update skipped' "$TEST_DIRECTORY/restart.log"

if run_startup "$FAILURE_SERVER_DIRECTORY" \
  STEAM_USER=test-user \
  STEAM_PASS=do-not-print-this-password \
  STEAMCMD_FAIL=true \
  > "$TEST_DIRECTORY/failure.log" 2>&1; then
  echo "Failed SteamCMD installation was accepted."
  exit 1
fi
test ! -e "$FAILURE_SERVER_DIRECTORY/.rwr-installed"
grep -Fq 'SteamCMD could not reach Steam' "$TEST_DIRECTORY/failure.log"

echo "RWR startup reliability integration tests passed."
