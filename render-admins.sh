#!/bin/bash
set -euo pipefail

DESTINATION_FILE="${1:?Usage: rwr-render-admins DESTINATION}"
ADMIN_NAMES="${ADMIN_NAMES:-}"

if [ -z "$ADMIN_NAMES" ]; then
  exit 0
fi

TEMP_FILE="${DESTINATION_FILE}.tmp.$$"
trap 'rm -f "$TEMP_FILE"' EXIT

printf '<admins>\n' > "$TEMP_FILE"

IFS=',' read -r -a ADMIN_ENTRIES <<< "$ADMIN_NAMES"
ADMIN_COUNT=0

for raw_name in "${ADMIN_ENTRIES[@]}"; do
  name="${raw_name#"${raw_name%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"
  name="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"

  if [ -z "$name" ]; then
    echo "ERROR: ADMIN_NAMES contains an empty username."
    exit 1
  fi

  if [ "${#name}" -gt 64 ] || [[ ! "$name" =~ ^[a-z0-9][a-z0-9._\ -]*$ ]]; then
    echo "ERROR: ADMIN_NAMES contains an unsupported username."
    exit 1
  fi

  printf '\t<item value="%s" />\n' "$name" >> "$TEMP_FILE"
  ADMIN_COUNT=$((ADMIN_COUNT + 1))
done

printf '</admins>\n' >> "$TEMP_FILE"
mv -f "$TEMP_FILE" "$DESTINATION_FILE"
trap - EXIT

echo "Configured $ADMIN_COUNT RWR administrator(s)."
