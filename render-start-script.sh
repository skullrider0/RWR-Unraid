#!/bin/bash
set -euo pipefail

SOURCE_SCRIPT="${1:?Usage: rwr-render-start-script SOURCE DESTINATION}"
DESTINATION_SCRIPT="${2:?Usage: rwr-render-start-script SOURCE DESTINATION}"

SERVER_NAME="${SERVER_NAME:-MyInvasion}"
SERVER_PORT="${SERVER_PORT:-1240}"
MAX_PLAYERS="${MAX_PLAYERS:-32}"
PUBLIC_SERVER="${PUBLIC_SERVER:-true}"
FACTION="${FACTION:-0}"

validate_text() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._:,/\ -]*$ ]]; then
    echo "ERROR: $name contains unsupported characters."
    exit 1
  fi
}

validate_number() {
  local name="$1"
  local value="$2"
  local minimum="$3"
  local maximum="$4"

  if [[ ! "$value" =~ ^[0-9]+$ ]] || ((10#$value < minimum || 10#$value > maximum)); then
    echo "ERROR: $name must be between $minimum and $maximum."
    exit 1
  fi
}

validate_text SERVER_NAME "$SERVER_NAME"
validate_number SERVER_PORT "$SERVER_PORT" 1 65535
validate_number MAX_PLAYERS "$MAX_PLAYERS" 1 256

case "$PUBLIC_SERVER" in
  true|1|yes) REGISTER_IN_SERVERLIST=1 ;;
  false|0|no) REGISTER_IN_SERVERLIST=0 ;;
  *)
    echo "ERROR: PUBLIC_SERVER must be true or false."
    exit 1
    ;;
esac

case "$FACTION" in
  0|1|2) ;;
  *)
    echo "ERROR: FACTION must be 0, 1, or 2."
    exit 1
    ;;
esac

if [ ! -f "$SOURCE_SCRIPT" ]; then
  echo "ERROR: RWR startup script not found: $SOURCE_SCRIPT"
  exit 1
fi

TEMP_SCRIPT="${DESTINATION_SCRIPT}.tmp.$$"
trap 'rm -f "$TEMP_SCRIPT"' EXIT
cp "$SOURCE_SCRIPT" "$TEMP_SCRIPT"

sed -E -i \
  -e "s|server_name='[^']*'|server_name='$SERVER_NAME'|" \
  -e "s|server_port='[0-9]+'|server_port='$SERVER_PORT'|" \
  -e "s|register_in_serverlist='[01]'|register_in_serverlist='$REGISTER_IN_SERVERLIST'|" \
  -e "s|max_players='[0-9]+'|max_players='$MAX_PLAYERS'|" \
  -e "s|<client_faction id='[0-9]+' */>|<client_faction id='$FACTION' />|" \
  "$TEMP_SCRIPT"

for expected_setting in \
  "server_name='$SERVER_NAME'" \
  "server_port='$SERVER_PORT'" \
  "register_in_serverlist='$REGISTER_IN_SERVERLIST'" \
  "max_players='$MAX_PLAYERS'" \
  "<client_faction id='$FACTION' />"; do
  if ! grep -Fq "$expected_setting" "$TEMP_SCRIPT"; then
    echo "ERROR: Could not apply RWR setting: $expected_setting"
    exit 1
  fi
done

mv -f "$TEMP_SCRIPT" "$DESTINATION_SCRIPT"
trap - EXIT
