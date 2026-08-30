# RWR-Unraid Project State

This file is deeper project memory for automated and AI-assisted development. Read `CURRENT_STATE.md` first for the short operational handoff and `ROADMAP.md` for milestone status.

## Architecture decisions

- Keep RWR server files persistent under `/serverdata`.
- On Unraid, use a direct pool-backed host path such as `/mnt/cache/appdata/rwr-server`; `/mnt/user/...` caused OGRE resource-enumeration failures.
- Prefer RWR's `launch_server` wrapper rather than invoking `rwr_server` directly so bundled libraries load correctly.
- Do not invent unsupported password settings. RWR 1.98.1 uses username-based administrator access.
- Do not modify the upstream `start_invasion.as` in place. Render a managed copy for Unraid settings and managed persistence/map-voting behavior.
- Preserve credential-free normal restarts once the persistent installation is verified.
- Never expose Steam credentials in logs or Git history.

## Important failures already solved

- Incorrect game port mapping caused connection timeouts; vanilla dedicated Invasion uses TCP/UDP 1240.
- Direct execution of the server binary missed bundled runtime libraries; use the launcher wrapper.
- Unraid `/mnt/user` FUSE allowed file access but broke OGRE resource enumeration; use a direct pool path.
- First-run persistence could receive an empty saved-data response; initialization must tolerate that and start a fresh rotation.
- Concurrent GitHub image builds could overwrite `latest` out of order; workflow concurrency protection was added.

## Automation direction

The development workflow is moving from human copy/paste loops to a GitHub-backed disposable test-machine agent.

The intended loop is:

`goal -> task JSON -> test machine -> execute/test/inspect -> structured result -> GitHub -> AI diagnosis -> corrective task`

Human involvement should be exception-based for MFA, credentials, physical interaction, or genuinely ambiguous destructive scope.

## Verification philosophy

A successful command is not automatically a successful task. Validate the desired outcome using tests, Docker/container state, RWR logs, network behavior, and explicit acceptance checks.
