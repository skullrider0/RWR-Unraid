# RWR-Unraid Current State

Updated: 2026-08-30

## Working baseline

- Repository: `skullrider0/RWR-Unraid`
- Stable branch: `main`
- Known-good checkpoint before automation bootstrap: `98d5a3abc760e9a2e6735ac4acc331173ebfd9b7`
- GitHub Actions run #32 passed for that checkpoint.
- Published image path: `ghcr.io/skullrider0/rwr-unraid:latest`
- RWR dedicated server version observed during live testing: `1.98.1`
- Normal RWR port: TCP/UDP `1240`
- Persistent container path: `/serverdata`
- Validated Unraid host mapping uses a direct pool path such as `/mnt/cache/appdata/rwr-server`, not `/mnt/user/...`.

## Current capabilities

- SteamCMD install/update/validate flow
- persistent install marker and incomplete-install recovery
- managed vanilla Invasion startup
- configurable server settings
- username-based admin allowlist
- graceful console shutdown
- mission persistence
- post-victory map voting
- Phase 3 read-only live validation helper
- GitHub Actions build and GHCR publish

## Current phase

Phase 3 is in closeout. Remaining live checks are documented in `ROADMAP.md`.

Automation bootstrap is being added on branch `agent/bootstrap-autonomy` so machine execution and structured result reporting can be introduced without destabilizing the known-good `main` branch.

## Immediate automation goal

Create a disposable test-machine agent that can:

1. fetch a structured task from GitHub;
2. execute it once;
3. capture command output and system/Docker state;
4. evaluate task checks;
5. write structured results under `AGENT/outbox/` and `AGENT/history/`;
6. push results back to the task branch;
7. allow the AI to inspect those results and submit a corrective follow-up task.

## Safety boundary

The test machine may be treated as disposable, but Steam credentials, GitHub credentials, and other secrets must remain outside Git history.
