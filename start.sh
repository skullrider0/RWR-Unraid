#!/bin/bash
set -e
STEAMCMD="/opt/steamcmd/steamcmd.sh"
STEAMCMDDIR="/opt/steamcmd"
SERVERDIR="/serverdata/serverfiles"
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
exec "$SERVER_BIN"
