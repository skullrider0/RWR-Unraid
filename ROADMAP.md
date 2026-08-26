# RWR-Unraid Development Roadmap

This file is the project handoff and development roadmap for **RWR-Unraid**.

Future ChatGPT sessions and contributors should read this file before making changes so completed work is not repeated and the next useful milestone is clear.

## Project Goal

Provide a reliable, easy-to-install **Running With Rifles dedicated server Docker container for Unraid**, built automatically with GitHub Actions and published through GitHub Container Registry (GHCR).

## Current Status

**Foundation: working**

- [x] Repository structure corrected
- [x] `Dockerfile` at repository root
- [x] `start.sh` at repository root
- [x] Unraid XML template under `templates/RunningWithRifles.xml`
- [x] GitHub Actions workflow under `.github/workflows/docker-image.yml`
- [x] GitHub Actions detects the workflow
- [x] Docker image builds successfully in GitHub Actions
- [x] SteamCMD included in the image
- [x] Persistent `/serverdata` design
- [x] First-run RWR installation logic
- [x] Optional update-on-start logic
- [x] RWR executable discovery logic

Last major foundation milestone: **GitHub Actions build succeeded on August 26, 2026.**

---

# Phase 1 — Validate Real Unraid Deployment

**Priority: NOW**

Goal: prove that a fresh Unraid installation can pull the image, install RWR, launch the dedicated server, persist its files, and restart cleanly.

- [ ] Pull `ghcr.io/skullrider0/rwr-unraid:latest` on Unraid
- [ ] Install container using `templates/RunningWithRifles.xml`
- [ ] Confirm `/mnt/user/appdata/rwr-server` persists to `/serverdata`
- [ ] Confirm Steam authentication works
- [ ] Confirm SteamCMD installs AppID `270150`
- [ ] Confirm the correct RWR server executable is located automatically
- [ ] Confirm RWR dedicated server reaches a stable running state
- [ ] Confirm TCP/UDP port `1238` works with the server configuration
- [ ] Restart container and verify no unnecessary reinstall occurs
- [ ] Recreate container and verify server data survives
- [ ] Test `UPDATE_ON_START=true`
- [ ] Record any required RWR-specific launch arguments or configuration files

### Definition of Done

A new Unraid user can install the template, provide Steam credentials, start the container, and get a functioning persistent RWR server without manually entering the container.

---

# Phase 2 — Server Configuration Support

Goal: make common RWR server settings configurable from Unraid rather than requiring manual file editing.

Investigate the actual RWR dedicated-server configuration format first. Do not invent environment variables until they are mapped to real RWR settings.

Potential settings:

- [ ] Server name
- [ ] Server password
- [ ] Admin password
- [ ] Player limit
- [ ] Game mode / campaign
- [ ] Map / rotation settings
- [ ] Server port
- [ ] Public/private visibility
- [ ] Additional RWR launch parameters
- [ ] Optional raw `SERVER_ARGS` environment variable for advanced users

### Design rule

Keep advanced configuration optional. A default installation should remain simple.

---

# Phase 3 — Startup and Reliability Improvements

Goal: make failures obvious and container behavior predictable.

- [ ] Improve SteamCMD error reporting
- [ ] Handle Steam Guard / authentication failures clearly
- [ ] Detect incomplete or corrupted installs
- [ ] Avoid creating `.rwr-installed` unless installation really succeeded
- [ ] Verify executable permissions after SteamCMD updates
- [ ] Add graceful SIGTERM/shutdown handling if RWR requires it
- [ ] Improve server executable detection using verified RWR install paths
- [ ] Add useful startup diagnostics without exposing passwords
- [ ] Add optional install validation mode
- [ ] Determine whether automatic retry behavior is useful for transient Steam failures

### Security rule

Never print `STEAM_PASS`, authentication tokens, or other secrets into container logs or GitHub Actions logs.

---

# Phase 4 — Container Health and Observability

Goal: make it easy for Unraid to tell whether the server is actually healthy.

- [ ] Research a reliable RWR health signal
- [ ] Add Docker `HEALTHCHECK` if a trustworthy signal exists
- [ ] Show useful version/build information at startup
- [ ] Log RWR install/update version where possible
- [ ] Document expected startup time for a first installation
- [ ] Document common log messages and known failure states

Avoid a fake healthcheck that only tests whether the shell process exists.

---

# Phase 5 — GitHub Actions and Image Releases

Goal: move from only `latest` to predictable releases.

- [ ] Keep build-on-push for development
- [ ] Add manual `workflow_dispatch` if useful
- [ ] Publish semantic/versioned tags
- [ ] Publish `latest` only from the intended stable branch/release path
- [ ] Add Docker image metadata/labels
- [ ] Add build caching where useful
- [x] Add workflow concurrency protection if duplicate builds become a problem
- [ ] Verify GHCR package visibility and pull instructions
- [ ] Document image tags in README

Possible future tags:

```text
latest
main
v1.0.0
v1.1.0
```

---

# Phase 6 — Automated Validation

Goal: catch broken Dockerfiles and startup scripts before publishing them.

- [ ] Shell syntax validation for `start.sh`
- [ ] ShellCheck for `start.sh`
- [ ] Docker build validation in CI
- [ ] XML validation for the Unraid template
- [ ] Verify expected files exist in the built image
- [ ] Test container startup behavior without exposing real Steam credentials
- [ ] Add tests for executable-discovery logic
- [ ] Add tests for first-run vs restart behavior where practical

A full RWR installation test may require authenticated Steam access and should not expose credentials in public CI.

---

# Phase 7 — Unraid Template Polish

Goal: make installation clear to someone who has never used this repository.

- [ ] Verify every XML field against a real Unraid installation
- [ ] Improve descriptions/help text
- [ ] Add project/support links
- [ ] Add an icon if licensing allows
- [ ] Clearly label required vs optional variables
- [ ] Make persistent storage mapping obvious
- [ ] Document Steam-account ownership requirement
- [ ] Document Steam Guard behavior
- [ ] Verify template works when installed from its raw GitHub URL

---

# Phase 8 — Documentation

Goal: README should be enough for normal users; ROADMAP should be enough for development continuation.

- [ ] Add complete Unraid installation instructions
- [ ] Add first-start walkthrough
- [ ] Add port-forwarding notes
- [ ] Add configuration examples
- [ ] Add update instructions
- [ ] Add backup/restore instructions
- [ ] Add troubleshooting section
- [ ] Add common SteamCMD errors
- [ ] Add common RWR startup errors
- [ ] Document where RWR files are stored under `/serverdata`
- [ ] Add upgrade notes when behavior changes

---

# Phase 9 — Release 1.0

Target requirements for **v1.0.0**:

- [ ] Confirmed working on a clean Unraid deployment
- [ ] Reliable first-run install
- [ ] Reliable restart/recreate persistence
- [ ] Core server configuration documented
- [ ] Stable image published to GHCR
- [ ] Functional Unraid template
- [ ] Clear README installation instructions
- [ ] Common failures documented
- [ ] No plaintext secrets committed to the repository

When all of these are complete, create the first stable GitHub release/tag.

---

# Future / Optional Ideas

These are not required for v1.0.

- [ ] Multiple RWR server instances from the same image
- [ ] Backup helper or documented scheduled backups
- [ ] Automatic update scheduling
- [ ] Discord/webhook server status notifications
- [ ] RCON/admin tooling if RWR provides a supported interface
- [ ] Mod/workshop support if technically applicable
- [ ] Additional architecture support if RWR binaries support it
- [ ] Unraid Community Applications submission

---

# Rules for Future Development Chats

When starting a new ChatGPT conversation about this repository:

1. Give ChatGPT the repository URL: `https://github.com/skullrider0/RWR-Unraid`.
2. Ask it to read `ROADMAP.md` first.
3. Have it inspect the current `README.md`, `Dockerfile`, `start.sh`, `templates/RunningWithRifles.xml`, and `.github/workflows/docker-image.yml` before modifying anything.
4. Check the latest GitHub Actions result before diagnosing an old build failure.
5. Work on the earliest unfinished roadmap phase unless a current bug takes priority.
6. Do not redo checked-off work unless regression evidence shows it is broken.
7. After completing a roadmap item, update this file in the same change when practical.
8. Preserve `/serverdata` compatibility unless a migration is explicitly documented.
9. Never commit Steam passwords, tokens, cookies, or other secrets.
10. Prefer small, testable commits with descriptive commit messages.

## Suggested prompt for a future chat

> Open `https://github.com/skullrider0/RWR-Unraid`, read `ROADMAP.md`, inspect the current repository and latest GitHub Actions run, then continue from the highest-priority unfinished item. Preserve working functionality and update the roadmap as tasks are completed.

---

# Development Log

Use this section for major milestones rather than every small commit.

### 2026-08-26

- Repository reorganized into the correct root-level structure.
- GitHub Actions workflow moved to `.github/workflows/docker-image.yml`.
- `start.sh` stored as an executable file in Git.
- `Build and Publish Docker Image` workflow completed successfully.
- Development roadmap created.
- Fixed overlapping workflow runs overwriting `latest` with an older image and added concurrency protection.
