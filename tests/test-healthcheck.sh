#!/bin/bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIRECTORY="$(mktemp -d)"
HEALTH_DIRECTORY="$TEST_DIRECTORY/health"
PROC_NET_DIRECTORY="$TEST_DIRECTORY/proc-net"
trap 'kill "${RWR_TEST_PID:-}" 2>/dev/null || true; rm -rf "$TEST_DIRECTORY"' EXIT

mkdir -p "$HEALTH_DIRECTORY" "$PROC_NET_DIRECTORY"
sleep 60 &
RWR_TEST_PID=$!

printf 'ready\n' > "$HEALTH_DIRECTORY/status"
printf '%s\n' "$RWR_TEST_PID" > "$HEALTH_DIRECTORY/pid"
printf '1240\n' > "$HEALTH_DIRECTORY/port"
printf '%s\n' \
  '  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt uid timeout inode' \
  '17535: 00000000:04D8 00000000:0000 07 00000000:00000000 00:00000000 00000000 99 0 15838' \
  > "$PROC_NET_DIRECTORY/udp"
: > "$PROC_NET_DIRECTORY/udp6"

RWR_HEALTH_DIR="$HEALTH_DIRECTORY" \
PROC_NET_ROOT="$PROC_NET_DIRECTORY" \
  "$REPOSITORY_ROOT/healthcheck.sh" \
  > "$TEST_DIRECTORY/healthy.log"
grep -Fq 'healthy: RWR pid' "$TEST_DIRECTORY/healthy.log"
grep -Fq 'listening on UDP 1240' "$TEST_DIRECTORY/healthy.log"

printf 'starting\n' > "$HEALTH_DIRECTORY/status"
if RWR_HEALTH_DIR="$HEALTH_DIRECTORY" \
  PROC_NET_ROOT="$PROC_NET_DIRECTORY" \
  "$REPOSITORY_ROOT/healthcheck.sh" \
  > "$TEST_DIRECTORY/starting.log"; then
  echo "Starting state was incorrectly reported as healthy."
  exit 1
fi
grep -Fq 'startup controller state is starting' "$TEST_DIRECTORY/starting.log"

printf 'ready\n' > "$HEALTH_DIRECTORY/status"
: > "$PROC_NET_DIRECTORY/udp"
if RWR_HEALTH_DIR="$HEALTH_DIRECTORY" \
  PROC_NET_ROOT="$PROC_NET_DIRECTORY" \
  "$REPOSITORY_ROOT/healthcheck.sh" \
  > "$TEST_DIRECTORY/no-port.log"; then
  echo "Missing UDP listener was incorrectly reported as healthy."
  exit 1
fi
grep -Fq 'not listening on UDP port 1240' "$TEST_DIRECTORY/no-port.log"

printf '%s\n' \
  '  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt uid timeout inode' \
  '17535: 00000000000000000000000000000000:04D8 00000000000000000000000000000000:0000 07 00000000:00000000 00:00000000 00000000 99 0 15838' \
  > "$PROC_NET_DIRECTORY/udp6"
RWR_HEALTH_DIR="$HEALTH_DIRECTORY" \
PROC_NET_ROOT="$PROC_NET_DIRECTORY" \
  "$REPOSITORY_ROOT/healthcheck.sh" >/dev/null

kill "$RWR_TEST_PID"
wait "$RWR_TEST_PID" 2>/dev/null || true
if RWR_HEALTH_DIR="$HEALTH_DIRECTORY" \
  PROC_NET_ROOT="$PROC_NET_DIRECTORY" \
  "$REPOSITORY_ROOT/healthcheck.sh" \
  > "$TEST_DIRECTORY/dead-process.log"; then
  echo "Stopped RWR process was incorrectly reported as healthy."
  exit 1
fi
grep -Fq 'RWR server process is not running' "$TEST_DIRECTORY/dead-process.log"

echo "RWR healthcheck tests passed."
