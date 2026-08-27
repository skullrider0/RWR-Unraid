# Running With Rifles - Unraid Docker

GitHub-ready Docker repository for a Running With Rifles dedicated server on Unraid.

## Features

- SteamCMD installs/updates RWR AppID `270150`
- Persistent `/serverdata`
- Steam credentials configured in the Unraid template
- Optional update on container startup
- Automatically provisions default RWR `config.xml` and `settings.xml`
- Automatically starts the vanilla invasion script after RWR finishes loading
- Preserves existing configuration files and server data across container recreation/restarts

## Unraid

Required mapping for the default cache pool:

`/mnt/cache/appdata/rwr-server` -> `/serverdata`

If your pool has another name, replace `cache` with that pool name. Do not use `/mnt/user/appdata/rwr-server` for the server files. RWR uses an older OGRE resource loader that can open individual files through Unraid's FUSE user-share path but fails to enumerate required resources such as `map_config.xml`. The direct pool path was validated on a real Unraid installation.

Environment variables:

- `STEAM_USER` - Steam account username
- `STEAM_PASS` - Steam account password
- `UPDATE_ON_START` - `false` normally; `true` to update before startup
- `AUTO_START` - `true` to start a game mode when the RWR console is ready
- `START_SCRIPT` - game-mode script; defaults to `start_invasion.as`
- `STARTUP_TIMEOUT` - optional console-readiness timeout in seconds; defaults to `180`
- `SERVER_NAME` - public/direct-connect server name; defaults to `MyInvasion`
- `SERVER_COMMENT` - short server-list description; defaults to `Coop campaign`
- `SERVER_URL` - optional server website URL; blank by default
- `SERVER_PORT` - port written into the vanilla invasion script; defaults to `1240`
- `MAX_PLAYERS` - player limit; defaults to `32`
- `PUBLIC_SERVER` - `true` to register in the RWR server list; `false` for direct-connect only
- `FACTION` - client faction: `0` greenbelts, `1` graycollars, or `2` brownpants
- `PERSISTENCY` - profile persistence mode: `forever` (default) or `forever_and_match`

Use a dedicated Steam account that owns RWR rather than your primary account.

On startup, missing configuration files are copied to:

- `/serverdata/serverfiles/config.xml`
- `/serverdata/serverfiles/settings.xml`

Existing files at those paths are never overwritten. The default settings select the vanilla lobby map required for the server to initialize.

The bundled vanilla `start_invasion.as` script starts its game server on port `1240`. Publish both TCP and UDP port `1240` from the container. If players connect over the internet, forward port `1240` to the Unraid server in the router and allow it through any host firewall.

After the lobby reaches `Game loaded`, the startup controller sends:

```text
start_script start_invasion.as
```

Set `AUTO_START=false` if you intentionally want the RWR console to remain in the lobby without starting a game-mode script.

### Managed vanilla server settings

When `START_SCRIPT=start_invasion.as`, the container copies the installed vanilla script to `rwr_unraid_start_invasion.as` and applies the verified Unraid settings above: name, comment, website URL, port, player limit, server-list visibility, client faction, and profile persistence. The original game-provided `start_invasion.as` is never modified. The managed copy is regenerated after updates and on every container start, so changes made through the template remain consistent.

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
