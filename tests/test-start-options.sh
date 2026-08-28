#!/bin/bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/start-options.sh"

parse_server_arguments "pipes map=media/packages/vanilla/maps/lobby server_port=1240"

[ "${#SERVER_ARGUMENTS[@]}" -eq 3 ]
[ "${SERVER_ARGUMENTS[0]}" = "pipes" ]
[ "${SERVER_ARGUMENTS[1]}" = "map=media/packages/vanilla/maps/lobby" ]
[ "${SERVER_ARGUMENTS[2]}" = "server_port=1240" ]

parse_server_arguments ""
[ "${#SERVER_ARGUMENTS[@]}" -eq 0 ]

if parse_server_arguments 'map=lobby;exit' >/dev/null 2>&1; then
  echo "Unsafe SERVER_ARGS value was accepted."
  exit 1
fi

validate_start_command "start_script start_minimodes.as"
validate_start_command "metagame_selfstart start_invasion.as media/packages/vanilla"

if validate_start_command $'start_script start_invasion.as\nexit' >/dev/null 2>&1; then
  echo "Multiline START_COMMAND was accepted."
  exit 1
fi

if validate_start_command 'start_script foo.as;exit' >/dev/null 2>&1; then
  echo "Unsafe START_COMMAND was accepted."
  exit 1
fi

echo "RWR startup-option tests passed."
