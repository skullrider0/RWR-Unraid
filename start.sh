#!/bin/bash
set -Eeuo pipefail
STEAMCMDDIR="${STEAMCMDDIR:-/opt/steamcmd}"
STEAMCMD="${STEAMCMD:-$STEAMCMDDIR/steamcmd.sh}"
SERVERDIR="${SERVERDIR:-/serverdata/serverfiles}"
DEFAULTSDIR="${DEFAULTSDIR:-/opt/rwr-defaults}"
RWR_LIBDIR="${RWR_LIBDIR:-/usr/local/lib/rwr}"
ADMIN_RENDERER="${ADMIN_RENDERER:-/usr/local/bin/rwr-render-admins}"
START_SCRIPT_RENDERER="${START_SCRIPT_RENDERER:-/usr/local/bin/rwr-render-start-script}"
PERSISTENCE_SCRIPT="${PERSISTENCE_SCRIPT:-/usr/local/share/rwr/rwr-unraid-persistent-invasion.as}"
MAP_VOTE_SCRIPT="${MAP_VOTE_SCRIPT:-/usr/local/share/rwr/rwr-unraid-map-vote.as}"
HEALTH_DIR="${RWR_HEALTH_DIR:-/tmp/rwr-health}"
MARKER="$SERVERDIR/.rwr-installed"
source "$RWR_LIBDIR/start-options.sh"
source "$RWR_LIBDIR/install-utils.sh"
source "$RWR_LIBDIR/runtime-utils.sh"
source "$RWR_LIBDIR/health-utils.sh"
mkdir -p "$SERVERDIR"
write_rwr_health_state "$HEALTH_DIR" starting
echo "=============================================="
echo " Running With Rifles - Unraid Docker"
echo "=============================================="
echo "Container revision: ${RWR_CONTAINER_REVISION:-development}"

UPDATE_ON_START="${UPDATE_ON_START:-false}"
VALIDATE_ON_START="${VALIDATE_ON_START:-false}"
validate_boolean UPDATE_ON_START "$UPDATE_ON_START"
validate_boolean VALIDATE_ON_START "$VALIDATE_ON_START"

RUN_STEAMCMD=false
STEAMCMD_VALIDATE=false
INSTALL_REASON=""

if [ ! -f "$MARKER" ]; then
  if validate_rwr_install "$SERVERDIR" >/dev/null 2>&1; then
    echo "Found a complete existing RWR installation without a marker."
    write_install_marker "$MARKER"
  else
    RUN_STEAMCMD=true
    STEAMCMD_VALIDATE=true
    INSTALL_REASON="First launch: installing and validating RWR"
  fi
elif ! validate_rwr_install "$SERVERDIR"; then
  echo "WARNING: The marked RWR installation is incomplete or corrupted; requesting a repair validation."
  rm -f "$MARKER"
  RUN_STEAMCMD=true
  STEAMCMD_VALIDATE=true
  INSTALL_REASON="Repairing and validating RWR"
elif is_true "$VALIDATE_ON_START"; then
  RUN_STEAMCMD=true
  STEAMCMD_VALIDATE=true
  INSTALL_REASON="Startup install validation requested"
elif is_true "$UPDATE_ON_START"; then
  RUN_STEAMCMD=true
  INSTALL_REASON="Startup update requested"
fi

if [ "$RUN_STEAMCMD" = "true" ]; then
  if [ -z "${STEAM_USER:-}" ] || [ -z "${STEAM_PASS:-}" ]; then
    echo "ERROR: $INSTALL_REASON, but Steam credentials are missing."
    echo "Set STEAM_USER and STEAM_PASS in the Unraid template, then restart the container."
    exit 1
  fi

  echo "$INSTALL_REASON (AppID $RWR_APP_ID)..."
  echo "Steam Guard may request approval through the Steam Mobile app."
  rm -f "$MARKER"
  run_steamcmd_update "$STEAMCMD" "$SERVERDIR" "$STEAMCMD_VALIDATE"

  if ! validate_rwr_install "$SERVERDIR"; then
    echo "ERROR: SteamCMD finished, but the RWR installation did not pass verification."
    exit 1
  fi
  write_install_marker "$MARKER"
  echo "RWR installation verified successfully."
else
  echo "RWR installation verified; SteamCMD update skipped."
fi

RWR_STEAM_BUILD_ID="$(find_rwr_steam_build_id "$SERVERDIR" "$STEAMCMDDIR" || true)"
if [ -n "$RWR_STEAM_BUILD_ID" ]; then
  echo "RWR Steam build ID: $RWR_STEAM_BUILD_ID"
else
  echo "RWR Steam build ID: unavailable (Steam manifest not found)"
fi

for config_file in config.xml settings.xml; do
  if [ ! -f "$SERVERDIR/$config_file" ]; then
    echo "Creating default RWR $config_file..."
    install -m 0644 "$DEFAULTSDIR/$config_file" "$SERVERDIR/$config_file"
  fi
done

"$ADMIN_RENDERER" "$SERVERDIR/admins.xml"

STEAMCLIENT="$STEAMCMDDIR/linux32/steamclient.so"
if [ ! -f "$STEAMCLIENT" ]; then
  echo "Initializing Steam runtime..."
  "$STEAMCMD" +quit
fi
if [ ! -f "$STEAMCLIENT" ]; then
  echo "ERROR: Steam runtime did not provide $STEAMCLIENT"
  exit 1
fi
mkdir -p "$HOME/.steam/sdk32"
ln -sf "$STEAMCLIENT" "$HOME/.steam/sdk32/steamclient.so"

SERVER_BIN="$(find_rwr_server_binary "$SERVERDIR" || true)"
if [ -z "$SERVER_BIN" ]; then
  echo "ERROR: Could not find the RWR server executable after installation verification."
  exit 1
fi
echo "Launching RWR server with: $SERVER_BIN"
cd "$(dirname "$SERVER_BIN")"

AUTO_START="${AUTO_START:-true}"
START_SCRIPT="${START_SCRIPT:-start_invasion.as}"
START_COMMAND="${START_COMMAND:-}"
STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-180}"
SHUTDOWN_TIMEOUT="${SHUTDOWN_TIMEOUT:-7}"
SERVER_PORT="${SERVER_PORT:-1240}"
MANAGE_SERVER_SETTINGS="${MANAGE_SERVER_SETTINGS:-true}"
parse_server_arguments "${SERVER_ARGS:-}"
validate_start_command "$START_COMMAND"

case "$AUTO_START" in
  true|1|yes) ;;
  false|0|no)
    echo "Automatic game-mode startup disabled."
    write_rwr_health_state "$HEALTH_DIR" manual
    exec "$SERVER_BIN" "${SERVER_ARGUMENTS[@]}"
    ;;
  *)
    echo "ERROR: AUTO_START must be true or false."
    exit 1
    ;;
esac

case "$START_SCRIPT" in
  ""|*[!A-Za-z0-9._/-]*)
    echo "ERROR: START_SCRIPT contains unsupported characters."
    exit 1
    ;;
esac

if ! [[ "$STARTUP_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: STARTUP_TIMEOUT must be a positive number of seconds."
  exit 1
fi
if ! [[ "$SHUTDOWN_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: SHUTDOWN_TIMEOUT must be a positive number of seconds."
  exit 1
fi

echo "Startup diagnostics: update=$UPDATE_ON_START validate=$VALIDATE_ON_START auto_start=$AUTO_START"
echo "Startup diagnostics: server_arguments=${#SERVER_ARGUMENTS[@]} startup_timeout=${STARTUP_TIMEOUT}s shutdown_timeout=${SHUTDOWN_TIMEOUT}s"

case "$MANAGE_SERVER_SETTINGS" in
  true|1|yes)
    if [ "$START_SCRIPT" = "start_invasion.as" ]; then
      SOURCE_START_SCRIPT="$SERVERDIR/media/packages/vanilla/scripts/start_invasion.as"
      MANAGED_START_SCRIPT="$SERVERDIR/media/packages/vanilla/scripts/rwr_unraid_start_invasion.as"
      MANAGED_PERSISTENCE_SCRIPT="$SERVERDIR/media/packages/vanilla/scripts/rwr_unraid_persistent_invasion.as"
      MANAGED_MAP_VOTE_SCRIPT="$SERVERDIR/media/packages/vanilla/scripts/rwr_unraid_map_vote.as"
      install -m 0644 "$PERSISTENCE_SCRIPT" "$MANAGED_PERSISTENCE_SCRIPT"
      install -m 0644 "$MAP_VOTE_SCRIPT" "$MANAGED_MAP_VOTE_SCRIPT"
      "$START_SCRIPT_RENDERER" "$SOURCE_START_SCRIPT" "$MANAGED_START_SCRIPT"
      START_SCRIPT="$(basename "$MANAGED_START_SCRIPT")"
      echo "Configured managed RWR startup script: $START_SCRIPT"
    else
      echo "Managed server settings skipped for custom game-mode script: $START_SCRIPT"
    fi
    ;;
  false|0|no) ;;
  *)
    echo "ERROR: MANAGE_SERVER_SETTINGS must be true or false."
    exit 1
    ;;
esac

RUNTIME_DIR="$(mktemp -d)"
COMMAND_PIPE="$RUNTIME_DIR/rwr-commands"
CONSOLE_LOG="$RUNTIME_DIR/rwr-console.log"
SERVER_PID=""
SHUTDOWN_REQUESTED=false
mkfifo "$COMMAND_PIPE"
touch "$CONSOLE_LOG"

cleanup() {
  exec 3>&- 2>/dev/null || true
  rm -rf "$RUNTIME_DIR"
}

forward_shutdown() {
  if [ "$SHUTDOWN_REQUESTED" = "true" ]; then
    return
  fi
  SHUTDOWN_REQUESTED=true
  write_rwr_health_state "$HEALTH_DIR" stopping "$SERVER_PID" "$SERVER_PORT"
  if [ -n "$SERVER_PID" ]; then
    graceful_stop_rwr "$SERVER_PID" 3 "$SHUTDOWN_TIMEOUT"
  fi
}

trap cleanup EXIT
trap forward_shutdown TERM INT

"$SERVER_BIN" "${SERVER_ARGUMENTS[@]}" <"$COMMAND_PIPE" > >(tee "$CONSOLE_LOG") 2>&1 &
SERVER_PID=$!
write_rwr_health_state "$HEALTH_DIR" starting "$SERVER_PID" "$SERVER_PORT"
exec 3>"$COMMAND_PIPE"

SERVER_READY=false
for ((second = 0; second < STARTUP_TIMEOUT; second++)); do
  if grep -q "Game loaded" "$CONSOLE_LOG"; then
    SERVER_READY=true
    break
  fi

  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    write_rwr_health_state "$HEALTH_DIR" failed
    echo "ERROR: RWR exited before reaching the game console."
    wait "$SERVER_PID" || true
    exit 1
  fi

  sleep 1
done

if [ "$SERVER_READY" != "true" ]; then
  write_rwr_health_state "$HEALTH_DIR" failed "$SERVER_PID" "$SERVER_PORT"
  echo "ERROR: RWR did not reach the game console within ${STARTUP_TIMEOUT} seconds."
  kill -TERM "$SERVER_PID" 2>/dev/null || true
  wait "$SERVER_PID" || true
  exit 1
fi

if [ -n "$START_COMMAND" ]; then
  echo "Starting RWR game mode with a custom console command."
  printf '%s\n' "$START_COMMAND" >&3
else
  echo "Starting RWR game mode with script: $START_SCRIPT"
  printf 'start_script %s\n' "$START_SCRIPT" >&3
fi

RWR_RUNTIME_VERSION="$(extract_rwr_runtime_version "$CONSOLE_LOG")"
echo "Runtime diagnostics: rwr_version=${RWR_RUNTIME_VERSION:-unknown} steam_build_id=${RWR_STEAM_BUILD_ID:-unknown}"
write_rwr_health_state "$HEALTH_DIR" ready "$SERVER_PID" "$SERVER_PORT"

set +e
wait "$SERVER_PID"
SERVER_STATUS=$?
set -e
if [ "$SHUTDOWN_REQUESTED" = "true" ]; then
  write_rwr_health_state "$HEALTH_DIR" stopped
  exit 0
fi
write_rwr_health_state "$HEALTH_DIR" failed
exit "$SERVER_STATUS"
