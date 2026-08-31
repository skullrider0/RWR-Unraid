# Running With Rifles - Unraid Docker

GitHub-ready Docker repository for a Running With Rifles dedicated server on Unraid.

## Features

- SteamCMD installs/updates RWR AppID `270150`
- Persistent `/serverdata`
- Steam credentials configured in the Unraid template
- Optional update on container startup
- Optional SteamCMD validation/repair mode with transient-network retries
- Verifies required RWR files before trusting the persistent install marker
- Repairs executable permissions after SteamCMD changes
- Automatically provisions default RWR `config.xml` and `settings.xml`
- Automatically starts the vanilla invasion script after RWR finishes loading
- Saves and restores vanilla Invasion mission progress
- Lets players vote for the next unfinished Invasion map after each victory
- Gracefully saves and stops RWR through its console before escalating to process signals
- Reports Docker health from RWR readiness, the server process, and its UDP listener
- Logs the container revision, RWR runtime version, and Steam build ID when available
- Preserves existing configuration files and server data across container recreation/restarts

## Unraid

Required mapping for the default cache pool:

`/mnt/cache/appdata/rwr-server` -> `/serverdata`

If your pool has another name, replace `cache` with that pool name. Do not use `/mnt/user/appdata/rwr-server` for the server files. RWR uses an older OGRE resource loader that can open individual files through Unraid's FUSE user-share path but fails to enumerate required resources such as `map_config.xml`. The direct pool path was validated on a real Unraid installation.

Environment variables:

- `STEAM_USER` - Steam account username; required for first install, update, or validation
- `STEAM_PASS` - Steam account password; required for first install, update, or validation
- `UPDATE_ON_START` - `false` normally; `true` to update before startup
- `VALIDATE_ON_START` - `false` normally; `true` to run SteamCMD validation/repair before startup
- `STEAMCMD_RETRIES` - transient Steam network retries; defaults to `1`, allowed range `0` through `5`
- `STEAMCMD_RETRY_DELAY` - delay between transient retries in seconds; defaults to `10`
- `AUTO_START` - `true` to start a game mode when the RWR console is ready
- `START_SCRIPT` - game-mode script; defaults to `start_invasion.as`
- `START_COMMAND` - optional advanced RWR console command used instead of `start_script`; blank by default
- `SERVER_ARGS` - optional whitespace-separated arguments passed directly to the RWR executable
- `STARTUP_TIMEOUT` - optional console-readiness timeout in seconds; defaults to `180`
- `SHUTDOWN_TIMEOUT` - seconds allowed for console shutdown before SIGTERM; defaults to `7`
- `SERVER_NAME` - public/direct-connect server name; defaults to `MyInvasion`
- `SERVER_COMMENT` - short server-list description; defaults to `Coop campaign`
- `SERVER_URL` - optional server website URL; blank by default
- `SERVER_PORT` - port written into the vanilla invasion script; defaults to `1240`
- `MAX_PLAYERS` - player limit; defaults to `32`
- `PUBLIC_SERVER` - `true` to register in the RWR server list; `false` for direct-connect only
- `FACTION` - client faction: `0` greenbelts, `1` graycollars, or `2` brownpants
- `PERSISTENCY` - profile persistence mode: `forever` (default) or `forever_and_match`
- `MISSION_PERSISTENCE` - `true` (default) to autosave and restore vanilla Invasion mission progress
- `MAP_VOTING` - `true` (default) to wait for a player majority to choose the next unfinished Invasion map
- `ADMIN_NAMES` - optional comma-separated RWR usernames granted administrator access

Use a dedicated Steam account that owns RWR rather than your primary account. Credentials are not required for an ordinary restart after a complete installation has been verified, but they are required whenever SteamCMD must install, update, validate, or repair the game.

On startup, missing configuration files are copied to:

- `/serverdata/serverfiles/config.xml`
- `/serverdata/serverfiles/settings.xml`

Existing files at those paths are never overwritten. The default settings select the vanilla lobby map required for the server to initialize.

### Installation verification and recovery

The container verifies the RWR server binary, vanilla package configuration, lobby map configuration, and invasion startup script before launching. It also repairs missing execute permissions on `launch_server` and `rwr_server`. The persistent marker `/serverdata/serverfiles/.rwr-installed` is created only after these checks succeed.

If a marked installation is incomplete, the marker is removed and SteamCMD runs a repair validation. Set `VALIDATE_ON_START=true` to request that validation on every start; leave it `false` for faster normal restarts. `UPDATE_ON_START=true` requests a normal update without forcing a full file validation.

SteamCMD retries transient connection failures according to `STEAMCMD_RETRIES`, but it does not repeatedly retry bad credentials, incomplete Steam Guard approval, missing game ownership, or a definite installation failure. Logs provide a targeted error without printing the configured password. Steam Guard approval can still be completed through the Steam Mobile app when SteamCMD requests it.

When Unraid stops the container, the startup controller sends `save_profiles`, `stop_server`, and then `exit` through the RWR console. Stopping the game mode runs its final managed mission save before the surrounding console exits. It waits up to `SHUTDOWN_TIMEOUT` seconds, then uses SIGTERM and finally SIGKILL only if RWR does not exit. The seven-second default plus its short signal fallback fits inside Docker's normal ten-second stop window.

### Phase 3 live validation

After pulling or force-updating the current image, run the read-only closeout checker from the Unraid terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/skullrider0/RWR-Unraid/main/phase3-live-check.sh | bash
```

The checker inspects `RunningWithRifles` by default. Pass another container name as the first argument if needed. It verifies the running image, direct-pool `/serverdata` mount, install marker, TCP/UDP publication, icon label, current-start logs, normal SteamCMD skip or requested validation, known fatal errors, and any recorded clean console shutdown. It does not stop, restart, or modify the container.

To finish the shutdown check, use Unraid's **Stop** and **Start** controls on the same container and rerun the command. To finish install validation, temporarily set `VALIDATE_ON_START=true`, supply the Steam credentials, restart once, wait for `Game loaded`, run the checker, then return the setting to `false`. The last manual Phase 3 check is completing a map and confirming that a majority `/vote` advances to the selected unfinished map.

### Container health and startup diagnostics

The image includes a Docker healthcheck that requires all three of these signals:

1. the startup controller reached RWR's `Game loaded` console state and issued the configured game-mode command;
2. the exact RWR child process recorded by the controller is still running;
3. RWR is listening on the configured UDP game port.

This means a living shell or stalled lobby is not enough to report healthy. During installation and loading, Unraid may show `health: starting`. After the game mode binds its port, the status changes to `healthy`. A first installation is given a 45-minute Docker start period so downloading, validation, Steam Guard approval, and RWR's initial load do not consume healthcheck retries.

Check the current result from the Unraid terminal:

```bash
docker inspect RunningWithRifles \
  --format 'status={{.State.Health.Status}} failures={{.State.Health.FailingStreak}}'

docker exec RunningWithRifles /usr/local/bin/rwr-healthcheck
```

`AUTO_START=false` intentionally leaves the health state unsupported/unhealthy because no game mode is started and no game port is expected to listen. Docker records an unhealthy state but does not automatically restart a container solely because a healthcheck fails.

Startup logs identify the image and installed game where the available metadata permits it:

```text
Container revision: <Git commit SHA>
RWR Steam build ID: <Steam build ID or unavailable>
Runtime diagnostics: rwr_version=<version> steam_build_id=<ID or unknown>
```

The first launch downloads and validates roughly 2.5 GB of RWR data. On a normal broadband connection, allow approximately 5–20 minutes after Steam Guard approval; slower storage, Steam service delays, or validation can take longer. A restart with a verified installation skips SteamCMD and normally reaches the game console within the configured three-minute `STARTUP_TIMEOUT`.

Common messages:

| Log message | Meaning / action |
| --- | --- |
| `RWR installation verified; SteamCMD update skipped.` | Normal credential-free restart; the persistent installation passed checks. |
| `Startup install validation requested` | `VALIDATE_ON_START=true`; Steam credentials and possibly Steam Guard approval are required. |
| `Game loaded` followed by `Starting RWR game mode` | The lobby console became ready and the configured game mode was issued. |
| `Runtime diagnostics: rwr_version=...` | Runtime version/build summary used for support reports. |
| `health: starting` | Installation or RWR/game-mode startup is still in progress. |
| `unhealthy: RWR is not listening on UDP port ...` | The process reached the controller's ready state but the game server did not bind its configured port. |
| `CHECK: map_config element not found` | `/serverdata` probably uses the incompatible `/mnt/user` FUSE path; use a direct pool path. |
| `An exception has occurred!` or `!!!EXECUTION HALTED!!!` | Fatal RWR startup failure; inspect nearby `rwr_server.log` lines for the first cause. |
| `RWR server stopped cleanly.` | Docker stop completed through the RWR console and final managed save path. |

The bundled vanilla `start_invasion.as` script starts its game server on port `1240`. Publish both TCP and UDP port `1240` from the container. If players connect over the internet, forward port `1240` to the Unraid server in the router and allow it through any host firewall.

After the lobby reaches `Game loaded`, the startup controller sends:

```text
start_script start_invasion.as
```

Set `AUTO_START=false` if you intentionally want the RWR console to remain in the lobby without starting a game-mode script.

### Game modes and advanced startup

`START_SCRIPT` is the normal game-mode control. The verified default is `start_invasion.as`; the current RWR depot also contains dedicated AngelScript entry points such as `start_deathmatch_server.as` and `start_minimodes.as`. Non-invasion modes own their configuration and map rotation, so the container does not rewrite those scripts.

For modes that require another RWR console verb, set `START_COMMAND` to one safe, single-line command. When it is set, the container sends it instead of `start_script START_SCRIPT`. `SERVER_ARGS` passes advanced whitespace-separated arguments directly to the server process without shell evaluation. Shell operators, command substitution, quoted multi-word arguments, and newlines are rejected; neither value is printed in full to the container log.

RWR 1.98.1 does not expose a normal game-server join-password or admin-password setting in its dedicated-server command interface. `PUBLIC_SERVER=false` makes a server unlisted but does not password-protect it. Administrative access is username-based through RWR's `admins.xml`, not a shared admin password.

Set `ADMIN_NAMES` to a comma-separated list such as `playerone,player two`. The container trims surrounding spaces, converts names to lowercase as required by RWR, validates them, and writes `/serverdata/serverfiles/admins.xml`. When `ADMIN_NAMES` is blank, an existing `admins.xml` is left untouched. When it is set, the template value becomes the managed source of truth and the file is regenerated at startup.

### Managed vanilla server settings

When `START_SCRIPT=start_invasion.as`, the container copies the installed vanilla script to `rwr_unraid_start_invasion.as` and applies the verified Unraid settings above: name, comment, website URL, port, player limit, server-list visibility, client faction, and profile persistence. The original game-provided `start_invasion.as` is never modified. The managed copy is regenerated after updates and on every container start, so changes made through the template remain consistent.

Vanilla dedicated Invasion leaves its metagame `save()` and `load()` methods empty. With `MISSION_PERSISTENCE=true`, the managed script uses RWR's campaign serialization flow for the map rotation, unlocks, special vehicles, item-delivery objectives, and user settings. RWR's existing Invasion autosaver invokes this about every five minutes, and the game mode saves once more during a graceful container stop. Data remains under `/serverdata/serverfiles/savegames` with the rest of the persistent server files. The save restores campaign/mission state; it is not a frame-perfect snapshot of every active soldier and projectile.

Set `MISSION_PERSISTENCE=false` only when you intentionally want vanilla dedicated Invasion to start fresh. This setting applies to the managed `start_invasion.as` mode; custom game-mode scripts retain their own save behavior.

With `MAP_VOTING=true`, each successful map opens an indefinite ballot containing up to three unfinished maps. Players use `/vote 1`, `/vote 2`, or `/vote 3`; `/maps` repeats the available choices privately. The server remains on the completed map until one choice receives more than half of the currently connected players. A solo player therefore advances with one vote, players may change their votes, and disconnected-player votes are ignored. An administrator or moderator can still use RWR's `/warp <index>` command to override an active vote.

Map voting applies only to the managed vanilla `start_invasion.as` mode. Set `MAP_VOTING=false` to restore the normal Invasion map-selection behavior.

If you change `SERVER_PORT`, update the TCP and UDP container mappings and router forwarding to the same port. Managed settings are intentionally skipped when `START_SCRIPT` points to a custom game-mode script because other scripts may use a different configuration structure.

### Unraid FUSE startup failure

If the server ends with the following messages, verify that the container path uses `/mnt/cache/...` or another direct pool path rather than `/mnt/user/...`:

```text
loading map config
CHECK: map_config element not found
!!!EXECUTION HALTED!!!
```

This error can occur even when the files are present and readable. It was resolved on the test system by changing only the host mapping from `/mnt/user/appdata/rwr-server` to `/mnt/cache/appdata/rwr-server`.

### Connection timeout with no server log entry

If RWR reaches `Game loaded` but a client times out and the server logs no connection attempt, verify that the container publishes TCP/UDP port `1240`. The vanilla `start_invasion.as` shipped with RWR hard-codes `server_port='1240'`; publishing another container port will not reach the server.

## GitHub / GHCR

1. Create a GitHub repository named `RWR-Unraid`.
2. Upload this repository's files.
3. Replace `skullrider0` in `templates/RunningWithRifles.xml` with your GitHub username.
4. Enable GitHub Actions package permissions if needed.
5. Build/publish the image as `ghcr.io/skullrider0/rwr-unraid:latest`.
6. Add the raw template URL to Unraid's template repository list.

The included template publishes TCP/UDP port `1240`, matching the bundled vanilla `start_invasion.as` script. Change both the RWR script and container mapping together if you intentionally configure another port.

## Development Roadmap

See [`ROADMAP.md`](ROADMAP.md) for current project status, priorities, future milestones, and instructions for continuing development in future ChatGPT sessions.
