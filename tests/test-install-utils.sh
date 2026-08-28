#!/bin/bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIRECTORY="$(mktemp -d)"
SERVER_DIRECTORY="$TEST_DIRECTORY/serverfiles"
MOCK_STEAMCMD="$TEST_DIRECTORY/steamcmd.sh"
trap 'rm -rf "$TEST_DIRECTORY"' EXIT
source "$REPOSITORY_ROOT/install-utils.sh"

mkdir -p \
  "$SERVER_DIRECTORY/media/packages/vanilla/maps/lobby" \
  "$SERVER_DIRECTORY/media/packages/vanilla/scripts"
printf 'binary\n' > "$SERVER_DIRECTORY/rwr_server"
printf '#!/bin/sh\n' > "$SERVER_DIRECTORY/launch_server"
printf '<package />\n' > "$SERVER_DIRECTORY/media/packages/vanilla/package_config.xml"
printf '<map_config />\n' > "$SERVER_DIRECTORY/media/packages/vanilla/maps/lobby/map_config.xml"
printf 'void main() {}\n' > "$SERVER_DIRECTORY/media/packages/vanilla/scripts/start_invasion.as"

validate_rwr_install "$SERVER_DIRECTORY"
[ -x "$SERVER_DIRECTORY/rwr_server" ]
[ -x "$SERVER_DIRECTORY/launch_server" ]
[ "$(find_rwr_server_binary "$SERVER_DIRECTORY")" = "$SERVER_DIRECTORY/launch_server" ]

mv "$SERVER_DIRECTORY/media/packages/vanilla/maps/lobby/map_config.xml" \
  "$TEST_DIRECTORY/map_config.xml"
if validate_rwr_install "$SERVER_DIRECTORY" >/dev/null 2>&1; then
  echo "Incomplete RWR installation was accepted."
  exit 1
fi
mv "$TEST_DIRECTORY/map_config.xml" \
  "$SERVER_DIRECTORY/media/packages/vanilla/maps/lobby/map_config.xml"

cat > "$MOCK_STEAMCMD" <<'EOF'
#!/bin/bash
count=0
[ ! -f "$MOCK_COUNT_FILE" ] || count="$(cat "$MOCK_COUNT_FILE")"
count=$((count + 1))
printf '%s\n' "$count" > "$MOCK_COUNT_FILE"

case "$MOCK_MODE" in
  retry)
    if [ "$count" -lt 3 ]; then
      echo "No Connection"
      exit 1
    fi
    echo "Success! App '270150' fully installed."
    ;;
  guard)
    echo "Steam Guard confirmation required. Waiting for confirmation..."
    exit 1
    ;;
  *)
    echo "Success! App '270150' fully installed."
    ;;
esac
EOF
chmod +x "$MOCK_STEAMCMD"

export STEAM_USER='test-user'
export STEAM_PASS='do-not-print-this-password'
export MOCK_COUNT_FILE="$TEST_DIRECTORY/attempts"
export STEAMCMD_RETRIES=2
export STEAMCMD_RETRY_DELAY=0

export MOCK_MODE=retry
run_steamcmd_update "$MOCK_STEAMCMD" "$SERVER_DIRECTORY" true \
  > "$TEST_DIRECTORY/retry.log"
[ "$(cat "$MOCK_COUNT_FILE")" -eq 3 ]
if grep -Fq "$STEAM_PASS" "$TEST_DIRECTORY/retry.log"; then
  echo "Steam password was exposed in startup diagnostics."
  exit 1
fi

rm -f "$MOCK_COUNT_FILE"
export MOCK_MODE=guard
if run_steamcmd_update "$MOCK_STEAMCMD" "$SERVER_DIRECTORY" true \
  > "$TEST_DIRECTORY/guard.log" 2>&1; then
  echo "Steam Guard failure was accepted."
  exit 1
fi
[ "$(cat "$MOCK_COUNT_FILE")" -eq 1 ]
grep -Fq 'Steam Guard confirmation was not completed' "$TEST_DIRECTORY/guard.log"

write_install_marker "$SERVER_DIRECTORY/.rwr-installed"
grep -Fxq 'appid=270150' "$SERVER_DIRECTORY/.rwr-installed"
grep -Eq '^verified_at=[0-9]{4}-[0-9]{2}-[0-9]{2}T' \
  "$SERVER_DIRECTORY/.rwr-installed"

echo "RWR installation reliability tests passed."
