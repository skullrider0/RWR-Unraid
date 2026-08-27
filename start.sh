#!/bin/bash
set -e
STEAMCMD="/opt/steamcmd/steamcmd.sh"
STEAMCMDDIR="/opt/steamcmd"
SERVERDIR="/serverdata/serverfiles"
DEFAULTSDIR="/opt/rwr-defaults"
MARKER="$SERVERDIR/.rwr-installed"
mkdir -p "$SERVERDIR"
echo "=============================================="
echo " Running With Rifles - Unraid Docker"
echo "=============================================="
if [ -z "${STEAM_USER:-}" ] || [ -z "${STEAM_PASS:-}" ]; then echo "ERROR: Set STEAM_USER and STEAM_PASS in the Unraid template."; exit 1; fi
if [ ! -f "$MARKER" ]; then
  echo "First launch: installing/updating RWR (AppID 270150)..."
  "$STEAMCMD" +force_install_dir "$SERVERDIR" +login "$STEAM_USER" "$STEAM_PASS" +app_update 270150 validate +quit
  touch "$MARKER"
elif [ "${UPDATE_ON_START:-false}" = "true" ]; then
  echo "Startup update requested..."
  "$STEAMCMD" +force_install_dir "$SERVERDIR" +login "$STEAM_USER" "$STEAM_PASS" +app_update 270150 +quit
fi

for config_file in config.xml settings.xml; do
  if [ ! -f "$SERVERDIR/$config_file" ]; then
    echo "Creating default RWR $config_file..."
    install -m 0644 "$DEFAULTSDIR/$config_file" "$SERVERDIR/$config_file"
  fi
done

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

SERVER_BIN=""
for candidate in "$SERVERDIR/launch_server" "$SERVERDIR/rwr_gameserver/launch_server" "$SERVERDIR/rwr_server" "$SERVERDIR/rwr_gameserver/rwr_server"; do
  if [ -x "$candidate" ]; then SERVER_BIN="$candidate"; break; fi
done
if [ -z "$SERVER_BIN" ]; then SERVER_BIN="$(find "$SERVERDIR" -maxdepth 4 -type f -name 'launch_server' -perm -111 2>/dev/null | head -n 1 || true)"; fi
if [ -z "$SERVER_BIN" ]; then SERVER_BIN="$(find "$SERVERDIR" -maxdepth 4 -type f -name 'rwr_server' -perm -111 2>/dev/null | head -n 1 || true)"; fi
if [ -z "$SERVER_BIN" ]; then echo "ERROR: Could not find the RWR server executable."; find "$SERVERDIR" -maxdepth 3 -type f | head -n 100; exit 1; fi
echo "Launching RWR server with: $SERVER_BIN"
cd "$(dirname "$SERVER_BIN")"

AUTO_START="${AUTO_START:-true}"
START_SCRIPT="${START_SCRIPT:-start_invasion.as}"
STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-180}"
MANAGE_SERVER_SETTINGS="${MANAGE_SERVER_SETTINGS:-true}"

case "$AUTO_START" in
  true|1|yes) ;;
  false|0|no)
    echo "Automatic game-mode startup disabled."
    exec "$SERVER_BIN"
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

case "$MANAGE_SERVER_SETTINGS" in
  true|1|yes)
    if [ "$START_SCRIPT" = "start_invasion.as" ]; then
      SOURCE_START_SCRIPT="$SERVERDIR/media/packages/vanilla/scripts/start_invasion.as"
      MANAGED_START_SCRIPT="$SERVERDIR/media/packages/vanilla/scripts/rwr_unraid_start_invasion.as"
      /usr/local/bin/rwr-render-start-script "$SOURCE_START_SCRIPT" "$MANAGED_START_SCRIPT"
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
mkfifo "$COMMAND_PIPE"
touch "$CONSOLE_LOG"

cleanup() {
  exec 3>&- 2>/dev/null || true
  rm -rf "$RUNTIME_DIR"
}

forward_shutdown() {
  echo "Stopping RWR server..."
  printf 'stop_server\n' >&3 2>/dev/null || true
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill -TERM "$SERVER_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT
trap forward_shutdown TERM INT

"$SERVER_BIN" <"$COMMAND_PIPE" > >(tee "$CONSOLE_LOG") 2>&1 &
SERVER_PID=$!
exec 3>"$COMMAND_PIPE"

SERVER_READY=false
for ((second = 0; second < STARTUP_TIMEOUT; second++)); do
  if grep -q "Game loaded" "$CONSOLE_LOG"; then
    SERVER_READY=true
    break
  fi

  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "ERROR: RWR exited before reaching the game console."
    wait "$SERVER_PID" || true
    exit 1
  fi

  sleep 1
done

if [ "$SERVER_READY" != "true" ]; then
  echo "ERROR: RWR did not reach the game console within ${STARTUP_TIMEOUT} seconds."
  kill -TERM "$SERVER_PID" 2>/dev/null || true
  wait "$SERVER_PID" || true
  exit 1
fi

echo "Starting RWR game mode with script: $START_SCRIPT"
printf 'start_script %s\n' "$START_SCRIPT" >&3

set +e
wait "$SERVER_PID"
SERVER_STATUS=$?
set -e
exit "$SERVER_STATUS"
