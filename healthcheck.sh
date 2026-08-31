#!/bin/bash
set -uo pipefail

HEALTH_DIRECTORY="${RWR_HEALTH_DIR:-/tmp/rwr-health}"
PROC_NET_ROOT="${PROC_NET_ROOT:-/proc/net}"

health_failure() {
  printf 'unhealthy: %s\n' "$*"
  exit 1
}

if [ ! -r "$HEALTH_DIRECTORY/status" ]; then
  health_failure "startup controller has not published health state"
fi

HEALTH_STATE="$(head -n 1 "$HEALTH_DIRECTORY/status")"
if [ "$HEALTH_STATE" != "ready" ]; then
  health_failure "startup controller state is $HEALTH_STATE"
fi

if [ ! -r "$HEALTH_DIRECTORY/pid" ]; then
  health_failure "RWR process ID is unavailable"
fi

RWR_PROCESS_ID="$(head -n 1 "$HEALTH_DIRECTORY/pid")"
if ! [[ "$RWR_PROCESS_ID" =~ ^[1-9][0-9]*$ ]] || \
   ! kill -0 "$RWR_PROCESS_ID" 2>/dev/null; then
  health_failure "RWR server process is not running"
fi

if [ ! -r "$HEALTH_DIRECTORY/port" ]; then
  health_failure "RWR game port is unavailable"
fi

RWR_SERVER_PORT="$(head -n 1 "$HEALTH_DIRECTORY/port")"
if ! [[ "$RWR_SERVER_PORT" =~ ^[0-9]+$ ]] || \
   [ "$RWR_SERVER_PORT" -lt 1 ] || \
   [ "$RWR_SERVER_PORT" -gt 65535 ]; then
  health_failure "RWR game port is invalid"
fi

printf -v PORT_HEX '%04X' "$((10#$RWR_SERVER_PORT))"

port_is_bound() {
  local socket_file="$1"

  [ -r "$socket_file" ] || return 1
  awk -v expected_port="$PORT_HEX" '
    NR > 1 {
      split($2, address, ":")
      if (toupper(address[length(address)]) == expected_port) {
        found = 1
      }
    }
    END { exit(found ? 0 : 1) }
  ' "$socket_file"
}

if ! port_is_bound "$PROC_NET_ROOT/udp" && \
   ! port_is_bound "$PROC_NET_ROOT/udp6"; then
  health_failure "RWR is not listening on UDP port $RWR_SERVER_PORT"
fi

printf 'healthy: RWR pid %s is ready and listening on UDP %s\n' \
  "$RWR_PROCESS_ID" "$RWR_SERVER_PORT"
