#!/bin/bash

RWR_APP_ID="${RWR_APP_ID:-270150}"

validate_boolean() {
  local name="$1"
  local value="$2"

  case "$value" in
    true|false|1|0|yes|no) return 0 ;;
    *)
      echo "ERROR: $name must be true or false."
      return 1
      ;;
  esac
}

is_true() {
  case "${1:-}" in
    true|1|yes) return 0 ;;
    *) return 1 ;;
  esac
}

find_rwr_server_binary() {
  local server_directory="$1"
  local candidate

  for candidate in \
    "$server_directory/launch_server" \
    "$server_directory/rwr_gameserver/launch_server" \
    "$server_directory/rwr_server" \
    "$server_directory/rwr_gameserver/rwr_server"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  candidate="$(find "$server_directory" -maxdepth 4 -type f -name 'launch_server' -perm -u+x -print -quit 2>/dev/null || true)"
  if [ -n "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  candidate="$(find "$server_directory" -maxdepth 4 -type f -name 'rwr_server' -perm -u+x -print -quit 2>/dev/null || true)"
  if [ -n "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

repair_rwr_executable_permissions() {
  local server_directory="$1"
  local candidate
  local repaired=0

  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    if [ ! -x "$candidate" ]; then
      chmod u+x "$candidate"
      repaired=$((repaired + 1))
    fi
  done < <(find "$server_directory" -maxdepth 4 -type f \
    \( -name 'launch_server' -o -name 'rwr_server' \) -print 2>/dev/null)

  if [ "$repaired" -gt 0 ]; then
    echo "Repaired executable permissions on $repaired RWR file(s)."
  fi
}

validate_rwr_install() {
  local server_directory="$1"
  local required_path
  local binary_path
  local missing=0

  for required_path in \
    "media/packages/vanilla/package_config.xml" \
    "media/packages/vanilla/maps/lobby/map_config.xml" \
    "media/packages/vanilla/scripts/start_invasion.as"; do
    if [ ! -s "$server_directory/$required_path" ]; then
      echo "ERROR: RWR installation is missing required file: $required_path"
      missing=1
    fi
  done

  if [ ! -s "$server_directory/rwr_server" ] && \
     [ ! -s "$server_directory/rwr_gameserver/rwr_server" ]; then
    echo "ERROR: RWR installation is missing the rwr_server binary."
    missing=1
  fi

  if [ "$missing" -ne 0 ]; then
    return 1
  fi

  repair_rwr_executable_permissions "$server_directory"
  binary_path="$(find_rwr_server_binary "$server_directory" || true)"
  if [ -z "$binary_path" ]; then
    echo "ERROR: RWR server files exist, but no executable launch path is available."
    return 1
  fi
}

steamcmd_failure_kind() {
  local log_file="$1"

  if grep -Eiq 'Steam Guard|two-factor|Waiting for confirmation' "$log_file"; then
    printf 'steam_guard\n'
  elif grep -Eiq 'Invalid Password|Login Failure|Invalid account|password check failed' "$log_file"; then
    printf 'authentication\n'
  elif grep -Eiq 'No subscription|missing license|does not own|not subscribed' "$log_file"; then
    printf 'license\n'
  elif grep -Eiq 'No Connection|connection[^[:alnum:]]+failed|timed out|timeout|CM client.*failed' "$log_file"; then
    printf 'network\n'
  elif grep -Eiq "ERROR! Failed to install app|App '$RWR_APP_ID'.*state" "$log_file"; then
    printf 'installation\n'
  else
    printf 'unknown\n'
  fi
}

steamcmd_log_has_failure() {
  local log_file="$1"

  grep -Eiq \
    "ERROR! Failed to install app|FAILED \(|Login Failure|Invalid Password|No subscription|missing license|No Connection|App '$RWR_APP_ID'.*state" \
    "$log_file"
}

report_steamcmd_failure() {
  local kind="$1"

  case "$kind" in
    steam_guard)
      echo "ERROR: Steam Guard confirmation was not completed. Approve the login in the Steam Mobile app, then restart the container."
      ;;
    authentication)
      echo "ERROR: Steam rejected the account credentials. Check STEAM_USER and STEAM_PASS without posting them in logs."
      ;;
    license)
      echo "ERROR: The configured Steam account does not appear to own Running With Rifles (AppID $RWR_APP_ID)."
      ;;
    network)
      echo "ERROR: SteamCMD could not reach Steam. Check DNS and internet connectivity from the Unraid host."
      ;;
    installation)
      echo "ERROR: SteamCMD could not install or update Running With Rifles (AppID $RWR_APP_ID)."
      ;;
    *)
      echo "ERROR: SteamCMD failed. Review the SteamCMD output above for the non-secret error details."
      ;;
  esac
}

run_steamcmd_update() {
  local steamcmd_path="$1"
  local server_directory="$2"
  local validation_mode="$3"
  local retry_count="${STEAMCMD_RETRIES:-1}"
  local retry_delay="${STEAMCMD_RETRY_DELAY:-10}"
  local attempt=0
  local maximum_attempts
  local command_status
  local failure_kind
  local log_file
  local had_errexit=false
  local -a steamcmd_arguments

  if ! [[ "$retry_count" =~ ^[0-5]$ ]]; then
    echo "ERROR: STEAMCMD_RETRIES must be a number from 0 through 5."
    return 1
  fi
  if ! [[ "$retry_delay" =~ ^[0-9]+$ ]]; then
    echo "ERROR: STEAMCMD_RETRY_DELAY must be a non-negative number of seconds."
    return 1
  fi

  maximum_attempts=$((retry_count + 1))
  steamcmd_arguments=(
    +force_install_dir "$server_directory"
    +login "$STEAM_USER" "$STEAM_PASS"
    +app_update "$RWR_APP_ID"
  )
  if [ "$validation_mode" = "true" ]; then
    steamcmd_arguments+=(validate)
  fi
  steamcmd_arguments+=(+quit)

  log_file="$(mktemp)"
  trap 'rm -f "$log_file"' RETURN

  while [ "$attempt" -lt "$maximum_attempts" ]; do
    attempt=$((attempt + 1))
    echo "SteamCMD attempt $attempt of $maximum_attempts for AppID $RWR_APP_ID."
    : > "$log_file"

    [[ $- == *e* ]] && had_errexit=true
    set +e
    "$steamcmd_path" "${steamcmd_arguments[@]}" 2>&1 | tee "$log_file"
    command_status=${PIPESTATUS[0]}
    if [ "$had_errexit" = "true" ]; then
      set -e
    fi

    if [ "$command_status" -eq 0 ] && ! steamcmd_log_has_failure "$log_file"; then
      trap - RETURN
      rm -f "$log_file"
      return 0
    fi

    failure_kind="$(steamcmd_failure_kind "$log_file")"
    report_steamcmd_failure "$failure_kind"

    case "$failure_kind" in
      steam_guard|authentication|license|installation)
        break
        ;;
    esac

    if [ "$attempt" -lt "$maximum_attempts" ]; then
      echo "Retrying SteamCMD in $retry_delay second(s)..."
      sleep "$retry_delay"
    fi
  done

  trap - RETURN
  rm -f "$log_file"
  return 1
}

write_install_marker() {
  local marker_file="$1"
  local temporary_marker="${marker_file}.tmp.$$"

  printf 'appid=%s\nverified_at=%s\n' \
    "$RWR_APP_ID" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$temporary_marker"
  mv -f "$temporary_marker" "$marker_file"
}
