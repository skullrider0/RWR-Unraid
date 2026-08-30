#!/bin/bash
set -uo pipefail

CONTAINER_NAME="${1:-${CONTAINER_NAME:-RunningWithRifles}}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
UNRAID_MNT_ROOT="${UNRAID_MNT_ROOT:-/mnt}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS: %s\n' "$*"
}

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  printf 'WARN: %s\n' "$*"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL: %s\n' "$*"
}

docker_value() {
  local format="$1"
  "$DOCKER_BIN" inspect --format "$format" "$CONTAINER_NAME" 2>/dev/null || true
}

printf 'RWR Phase 3 live check: %s\n\n' "$CONTAINER_NAME"

if ! command -v "$DOCKER_BIN" >/dev/null 2>&1; then
  fail "Docker command not found: $DOCKER_BIN"
  exit 1
fi

if ! "$DOCKER_BIN" inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  fail "Container does not exist. Install or recreate $CONTAINER_NAME from the current template first."
  exit 1
fi

CONTAINER_STATUS="$(docker_value '{{.State.Status}}')"
CONTAINER_IMAGE="$(docker_value '{{.Config.Image}}')"
STARTED_AT="$(docker_value '{{.State.StartedAt}}')"
SERVERDATA_SOURCE="$(docker_value '{{range .Mounts}}{{if eq .Destination "/serverdata"}}{{.Source}}{{end}}{{end}}')"
ENVIRONMENT="$(docker_value '{{range .Config.Env}}{{println .}}{{end}}')"
ICON_LABEL="$(docker_value '{{index .Config.Labels "net.unraid.docker.icon"}}')"
SERVER_PORT="$(printf '%s\n' "$ENVIRONMENT" | sed -n 's/^SERVER_PORT=//p' | tail -n 1)"
VALIDATE_ON_START="$(printf '%s\n' "$ENVIRONMENT" | sed -n 's/^VALIDATE_ON_START=//p' | tail -n 1)"
SERVER_PORT="${SERVER_PORT:-1240}"
VALIDATE_ON_START="${VALIDATE_ON_START:-false}"

if [ "$CONTAINER_STATUS" = "running" ]; then
  pass "Container is running."
else
  fail "Container state is '$CONTAINER_STATUS', expected 'running'."
fi

case "$CONTAINER_IMAGE" in
  ghcr.io/skullrider0/rwr-unraid:latest|ghcr.io/skullrider0/rwr-unraid@sha256:*)
    pass "Container uses the published RWR-Unraid image ($CONTAINER_IMAGE)."
    ;;
  *)
    warn "Container image is '$CONTAINER_IMAGE', not the documented latest image."
    ;;
esac

case "$SERVERDATA_SOURCE" in
  "$UNRAID_MNT_ROOT"/user/*)
    fail "/serverdata uses the incompatible Unraid user-share path: $SERVERDATA_SOURCE"
    ;;
  "$UNRAID_MNT_ROOT"/*)
    pass "/serverdata uses a direct pool/disk path: $SERVERDATA_SOURCE"
    ;;
  "")
    fail "No host mount was found for /serverdata."
    ;;
  *)
    warn "/serverdata uses an unexpected host path: $SERVERDATA_SOURCE"
    ;;
esac

if [ -n "$SERVERDATA_SOURCE" ] && [ -f "$SERVERDATA_SOURCE/serverfiles/.rwr-installed" ]; then
  pass "Verified-install marker exists in persistent storage."
else
  fail "Verified-install marker is missing from persistent storage."
fi

TCP_BINDING="$("$DOCKER_BIN" port "$CONTAINER_NAME" "$SERVER_PORT/tcp" 2>/dev/null || true)"
UDP_BINDING="$("$DOCKER_BIN" port "$CONTAINER_NAME" "$SERVER_PORT/udp" 2>/dev/null || true)"

if [ -n "$TCP_BINDING" ]; then
  pass "TCP $SERVER_PORT is published ($TCP_BINDING)."
else
  fail "TCP $SERVER_PORT is not published."
fi

if [ -n "$UDP_BINDING" ]; then
  pass "UDP $SERVER_PORT is published ($UDP_BINDING)."
else
  fail "UDP $SERVER_PORT is not published."
fi

if [ -n "$ICON_LABEL" ] && [ "$ICON_LABEL" != "<no value>" ]; then
  pass "Unraid icon label is present."
else
  warn "The running container has no Unraid icon label; force-update/recreate it from the current template."
fi

CURRENT_LOGS="$("$DOCKER_BIN" logs --since "$STARTED_AT" "$CONTAINER_NAME" 2>&1 || true)"
ALL_LOGS="$("$DOCKER_BIN" logs "$CONTAINER_NAME" 2>&1 || true)"

if printf '%s\n' "$CURRENT_LOGS" | grep -Fq 'Game loaded'; then
  pass "RWR reached the game console during the current start."
else
  fail "The current start has not logged 'Game loaded'."
fi

if printf '%s\n' "$CURRENT_LOGS" | grep -Fq 'Starting RWR game mode with script:'; then
  pass "Managed game-mode startup was issued."
else
  warn "Managed game-mode startup was not found in the current logs."
fi

case "$VALIDATE_ON_START" in
  true|1|yes)
    if printf '%s\n' "$CURRENT_LOGS" | grep -Fq 'RWR installation verified successfully.'; then
      pass "VALIDATE_ON_START completed successfully during the current start."
    else
      fail "VALIDATE_ON_START is enabled but successful validation was not found in the current logs."
    fi
    ;;
  *)
    if printf '%s\n' "$CURRENT_LOGS" | grep -Fq 'RWR installation verified; SteamCMD update skipped.'; then
      pass "Normal restart skipped SteamCMD."
    else
      warn "The current start does not prove that a normal restart skipped SteamCMD."
    fi
    ;;
esac

if printf '%s\n' "$CURRENT_LOGS" | grep -Eq '!!!EXECUTION HALTED!!!|An exception has occurred!|ERROR: RWR exited before reaching the game console'; then
  fail "A fatal RWR startup message appears in the current logs."
else
  pass "No known fatal RWR startup message appears in the current logs."
fi

if printf '%s\n' "$ALL_LOGS" | grep -Fq 'RWR server stopped cleanly.'; then
  pass "A clean RWR console shutdown is recorded in this container's logs."
else
  warn "No clean shutdown record is available yet. Stop and start this same container once, then rerun the check."
fi

printf '\nSummary: %d passed, %d warning(s), %d failed.\n' \
  "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi

printf 'Automated Phase 3 checks passed. Confirm one successful post-victory map vote in-game before marking the phase complete.\n'
