# Running With Rifles - Unraid Docker

GitHub-ready Docker repository for a Running With Rifles dedicated server on Unraid.

## Features

- SteamCMD installs/updates RWR AppID `270150`
- Persistent `/serverdata`
- Steam credentials configured in the Unraid template
- Optional update on container startup
- Server data survives container recreation/restarts

## Unraid

Recommended mapping:

`/mnt/user/appdata/rwr-server` -> `/serverdata`

Environment variables:

- `STEAM_USER` - Steam account username
- `STEAM_PASS` - Steam account password
- `UPDATE_ON_START` - `false` normally; `true` to update before startup

Use a dedicated Steam account that owns RWR rather than your primary account.

## GitHub / GHCR

1. Create a GitHub repository named `RWR-Unraid`.
2. Upload this repository's files.
3. Replace `skullrider0` in `templates/RunningWithRifles.xml` with your GitHub username.
4. Enable GitHub Actions package permissions if needed.
5. Build/publish the image as `ghcr.io/skullrider0/rwr-unraid:latest`.
6. Add the raw template URL to Unraid's template repository list.

The included template uses TCP/UDP port 1238 by default. Change it if your RWR server configuration uses another port.

## Development Roadmap

See [`ROADMAP.md`](ROADMAP.md) for current project status, priorities, future milestones, and instructions for continuing development in future ChatGPT sessions.
