# RWR-Unraid Current State

Updated: 2026-08-31

## Working baseline

- Repository: `skullrider0/RWR-Unraid`
- Stable branch: `main`
- Known-good main checkpoint before Phase 4: `6be4af4496ef6d297cb23997d75252ac2cb52663`
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
- isolated Docker-in-Docker test-machine agent with no host Docker socket
- GitHub Actions build and GHCR publish

## Current phase

Phase 3 remains in final live closeout. Phase 4 health and observability implementation is underway; remaining live checks are documented in `ROADMAP.md`.

## Active automation

The isolated `RWR-Test-Agent` on Unraid can:

1. fetch a structured task from GitHub;
2. execute it once;
3. capture command output and system/Docker state;
4. evaluate task checks;
5. write structured results under `AGENT/outbox/` and `AGENT/history/`;
6. push results back to the task branch;
7. allow the AI to inspect those results and submit a corrective follow-up task.

The agent completed its first task successfully and runs its own Docker daemon without mounting the Unraid host Docker socket.

## Safety boundary

The test machine may be treated as disposable, but Steam credentials, GitHub credentials, and other secrets must remain outside Git history.
