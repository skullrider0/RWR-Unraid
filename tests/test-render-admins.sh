#!/bin/bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIRECTORY="$(mktemp -d)"
ADMINS_FILE="$TEST_DIRECTORY/admins.xml"
trap 'rm -rf "$TEST_DIRECTORY"' EXIT

ADMIN_NAMES='Ahnold, Jack Mayol,user.name-3' \
  "$REPOSITORY_ROOT/render-admins.sh" "$ADMINS_FILE" >/dev/null

cat > "$TEST_DIRECTORY/expected.xml" <<'EOF'
<admins>
	<item value="ahnold" />
	<item value="jack mayol" />
	<item value="user.name-3" />
</admins>
EOF

cmp "$TEST_DIRECTORY/expected.xml" "$ADMINS_FILE"

printf 'preserve me\n' > "$ADMINS_FILE"
ADMIN_NAMES='' "$REPOSITORY_ROOT/render-admins.sh" "$ADMINS_FILE"
grep -Fxq 'preserve me' "$ADMINS_FILE"

if ADMIN_NAMES='valid,,invalid' \
  "$REPOSITORY_ROOT/render-admins.sh" "$ADMINS_FILE" >/dev/null 2>&1; then
  echo "Empty administrator username was accepted."
  exit 1
fi

if ADMIN_NAMES='valid,bad&name' \
  "$REPOSITORY_ROOT/render-admins.sh" "$ADMINS_FILE" >/dev/null 2>&1; then
  echo "XML-unsafe administrator username was accepted."
  exit 1
fi

echo "RWR administrator rendering tests passed."
