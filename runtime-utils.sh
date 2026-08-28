#!/bin/bash

wait_for_process_exit() {
  local process_id="$1"
  local timeout_seconds="$2"
  local second

  for ((second = 0; second < timeout_seconds; second++)); do
    if ! kill -0 "$process_id" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done

  ! kill -0 "$process_id" 2>/dev/null
}

graceful_stop_rwr() {
  local process_id="$1"
  local command_fd="$2"
  local shutdown_timeout="$3"

  if ! kill -0 "$process_id" 2>/dev/null; then
    return 0
  fi

  echo "Stopping RWR server through its console..."
  printf 'stop_server\n' >&"$command_fd" 2>/dev/null || true
  if wait_for_process_exit "$process_id" "$shutdown_timeout"; then
    echo "RWR server stopped cleanly."
    return 0
  fi

  echo "RWR did not stop within $shutdown_timeout second(s); sending SIGTERM."
  kill -TERM "$process_id" 2>/dev/null || true
  if wait_for_process_exit "$process_id" 5; then
    return 0
  fi

  echo "RWR did not respond to SIGTERM; sending SIGKILL."
  kill -KILL "$process_id" 2>/dev/null || true
}
