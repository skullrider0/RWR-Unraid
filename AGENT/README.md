# RWR Test-Machine Agent

This directory implements the GitHub-backed automation protocol for a disposable RWR-Unraid development machine.

## Files

- `inbox/NEXT_TASK.json` — current requested task.
- `outbox/LAST_RESULT.json` — structured result from the most recently processed task.
- `outbox/LAST_RESULT.md` — concise human/AI-readable result.
- `outbox/LAST_OUTPUT.txt` — combined task/acceptance output.
- `state/completed_tasks.txt` — task IDs already processed on this machine.
- `state/current_task.json` — local current-task snapshot; ignored by Git where appropriate.
- `history/tasks/<task-id>/` — timestamped result history.
- `bin/lab-agent` — task runner.
- `setup.sh` — installs the runner as a systemd service/timer on a disposable Linux test machine.

## Task format

```json
{
  "task_id": "20260830-0001",
  "goal": "Build the RWR image and verify repository tests pass.",
  "max_attempts": 1,
  "steps": [
    "bash tests/test-start-options.sh",
    "docker build -t rwr-unraid:test ."
  ],
  "acceptance": [
    "docker image inspect rwr-unraid:test >/dev/null"
  ]
}
```

`steps` and `acceptance` are shell commands executed with `bash -lc`. A non-zero step stops execution. Acceptance commands are all attempted so the result records every failed check.

Tasks should remain focused and should not contain credentials. Credentials required by SteamCMD or GitHub belong in the test machine's local environment/credential store.

## One-time execution

A task ID is recorded after processing. Pulling, rebooting, or restarting the agent will therefore not execute the same task again.

To intentionally repeat work, submit a new task ID.

## Git workflow

The initial model uses a dedicated branch, normally `agent/tasks`:

1. AI or maintainer writes `AGENT/inbox/NEXT_TASK.json` to `agent/tasks`.
2. Test machine polls that branch.
3. `lab-agent` executes unseen task IDs.
4. Agent writes results and history.
5. Agent commits/pushes result files back to `agent/tasks`.
6. AI reads the result and either reports success or writes a new corrective task ID.

The agent does not merge development changes to `main` in this bootstrap version. Source changes can continue through focused branches/PRs until automated merge gates are deliberately enabled.
