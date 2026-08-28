#!/bin/bash

SERVER_ARGUMENTS=()

parse_server_arguments() {
  local raw_arguments="${1:-}"
  local argument

  SERVER_ARGUMENTS=()
  if [ -z "$raw_arguments" ]; then
    return 0
  fi

  read -r -a SERVER_ARGUMENTS <<< "$raw_arguments"
  for argument in "${SERVER_ARGUMENTS[@]}"; do
    if [[ ! "$argument" =~ ^[A-Za-z0-9][A-Za-z0-9._=:/,+-]*$ ]]; then
      echo "ERROR: SERVER_ARGS contains an unsupported argument."
      return 1
    fi
  done
}

validate_start_command() {
  local command="${1:-}"

  if [ -z "$command" ]; then
    return 0
  fi

  if [[ ! "$command" =~ ^[A-Za-z0-9][A-Za-z0-9._=:/,+\ -]*$ ]]; then
    echo "ERROR: START_COMMAND contains unsupported characters."
    return 1
  fi
}
