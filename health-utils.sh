#!/bin/bash

write_rwr_health_state() {
  local health_directory="$1"
  local state="$2"
  local process_id="${3:-}"
  local server_port="${4:-}"
  local temporary_file

  mkdir -p "$health_directory"

  if [ -n "$process_id" ]; then
    temporary_file="$health_directory/pid.tmp.$$"
    printf '%s\n' "$process_id" > "$temporary_file"
    mv -f "$temporary_file" "$health_directory/pid"
  else
    rm -f "$health_directory/pid"
  fi

  if [ -n "$server_port" ]; then
    temporary_file="$health_directory/port.tmp.$$"
    printf '%s\n' "$server_port" > "$temporary_file"
    mv -f "$temporary_file" "$health_directory/port"
  else
    rm -f "$health_directory/port"
  fi

  temporary_file="$health_directory/status.tmp.$$"
  printf '%s\n' "$state" > "$temporary_file"
  mv -f "$temporary_file" "$health_directory/status"
}

find_rwr_steam_build_id() {
  local server_directory="$1"
  local steamcmd_directory="$2"
  local manifest
  local build_id

  for manifest in \
    "$server_directory/steamapps/appmanifest_270150.acf" \
    "$server_directory/appmanifest_270150.acf" \
    "$steamcmd_directory/steamapps/appmanifest_270150.acf" \
    "/home/steam/Steam/steamapps/appmanifest_270150.acf"; do
    [ -s "$manifest" ] || continue
    build_id="$(awk -F'"' '$2 == "buildid" { print $4; exit }' "$manifest")"
    if [[ "$build_id" =~ ^[0-9]+$ ]]; then
      printf '%s\n' "$build_id"
      return 0
    fi
  done

  return 1
}

extract_rwr_runtime_version() {
  local console_log="$1"

  sed -nE \
    's/.*RUNNING WITH RIFLES.* ([0-9]+(\.[0-9]+)+), server build.*/\1/p' \
    "$console_log" | head -n 1
}
