#!/bin/bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIRECTORY="$(mktemp -d)"
MOCK_DOCKER="$TEST_DIRECTORY/docker"
SERVERDATA_DIRECTORY="$TEST_DIRECTORY/serverdata"
trap 'rm -rf "$TEST_DIRECTORY"' EXIT

mkdir -p "$SERVERDATA_DIRECTORY/serverfiles"
touch "$SERVERDATA_DIRECTORY/serverfiles/.rwr-installed"

cat > "$MOCK_DOCKER" <<'EOF'
#!/bin/bash
set -u

case "$1" in
  inspect)
    if [ "${2:-}" != "--format" ]; then
      exit 0
    fi
    case "$3" in
      '{{.State.Status}}') printf 'running\n' ;;
      '{{.Config.Image}}') printf 'ghcr.io/skullrider0/rwr-unraid:latest\n' ;;
      '{{.State.StartedAt}}') printf '2026-08-30T00:00:00Z\n' ;;
      '{{range .Mounts}}{{if eq .Destination "/serverdata"}}{{.Source}}{{end}}{{end}}') printf '%s\n' "$MOCK_SERVERDATA" ;;
      '{{range .Config.Env}}{{println .}}{{end}}') printf 'SERVER_PORT=1240\nVALIDATE_ON_START=false\n' ;;
      '{{index .Config.Labels "net.unraid.docker.icon"}}') printf 'https://example.invalid/rwr.jpg\n' ;;
      *) exit 1 ;;
    esac
    ;;
  port)
    case "$3" in
      1240/tcp|1240/udp) printf '0.0.0.0:1240\n' ;;
      *) exit 1 ;;
    esac
    ;;
  logs)
    printf '%s\n' \
      'RWR installation verified; SteamCMD update skipped.' \
      'Game loaded' \
      'Starting RWR game mode with script: rwr_unraid_start_invasion.as' \
      'RWR server stopped cleanly.'
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$MOCK_DOCKER"

MOCK_SERVERDATA="$SERVERDATA_DIRECTORY" \
DOCKER_BIN="$MOCK_DOCKER" \
UNRAID_MNT_ROOT="$TEST_DIRECTORY" \
  "$REPOSITORY_ROOT/phase3-live-check.sh" test-rwr \
  > "$TEST_DIRECTORY/success.log"

grep -Fq 'Automated Phase 3 checks passed.' "$TEST_DIRECTORY/success.log"
grep -Eq 'Summary: [0-9]+ passed, 0 warning\(s\), 0 failed\.' "$TEST_DIRECTORY/success.log"

rm -f "$SERVERDATA_DIRECTORY/serverfiles/.rwr-installed"
if MOCK_SERVERDATA="$SERVERDATA_DIRECTORY" \
  DOCKER_BIN="$MOCK_DOCKER" \
  UNRAID_MNT_ROOT="$TEST_DIRECTORY" \
  "$REPOSITORY_ROOT/phase3-live-check.sh" test-rwr \
  > "$TEST_DIRECTORY/failure.log"; then
  echo "Missing install marker was incorrectly accepted."
  exit 1
fi
grep -Fq 'FAIL: Verified-install marker is missing' "$TEST_DIRECTORY/failure.log"

echo "Phase 3 live-check tests passed."
