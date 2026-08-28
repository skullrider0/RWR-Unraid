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

  echo "Saving profiles and stopping RWR through its console..."
  printf 'save_profiles\n' >&"$command_fd" 2>/dev/null || true
  printf 'stop_server\n' >&"$command_fd" 2>/dev/null || true

  local exit_delay=1
  local remaining_timeout="$shutdown_timeout"
  if [ "$shutdown_timeout" -gt "$exit_delay" ]; then
    if wait_for_process_exit "$process_id" "$exit_delay"; then
      echo "RWR server stopped cleanly."
      return 0
    fi
    remaining_timeout=$((shutdown_timeout - exit_delay))
  fi

  # stop_server lets the invasion script run uninit(), whose managed save()
  # persists mission state. exit then closes the surrounding RWR console.
  printf 'exit\n' >&"$command_fd" 2>/dev/null || true
  if wait_for_process_exit "$process_id" "$remaining_timeout"; then
    echo "RWR server stopped cleanly."
    return 0
  fi

  echo "RWR did not stop within $shutdown_timeout second(s); sending SIGTERM."
  kill -TERM "$process_id" 2>/dev/null || true
  if wait_for_process_exit "$process_id" 2; then
    return 0
  fi

  echo "RWR did not respond to SIGTERM; sending SIGKILL."
  kill -KILL "$process_id" 2>/dev/null || true
}
