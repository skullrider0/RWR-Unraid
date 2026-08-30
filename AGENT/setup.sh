#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${RWR_AGENT_REPO_URL:-https://github.com/skullrider0/RWR-Unraid.git}"
REPO_DIR="${RWR_AGENT_REPO:-/opt/rwr-unraid}"
TASK_BRANCH="${RWR_AGENT_BRANCH:-agent/tasks}"
INSTALL_BIN="/usr/local/bin/rwr-lab-agent"
SERVICE="/etc/systemd/system/rwr-lab-agent.service"
TIMER="/etc/systemd/system/rwr-lab-agent.timer"

if [[ $EUID -ne 0 ]]; then
  echo "Run AGENT/setup.sh as root." >&2
  exit 1
fi

for cmd in git jq flock systemctl; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd" >&2
    exit 1
  }
done

if [[ ! -d "$REPO_DIR/.git" ]]; then
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone --branch "$TASK_BRANCH" "$REPO_URL" "$REPO_DIR"
else
  git -C "$REPO_DIR" fetch origin "$TASK_BRANCH"
  git -C "$REPO_DIR" checkout "$TASK_BRANCH"
  git -C "$REPO_DIR" reset --hard "origin/$TASK_BRANCH"
fi

install -m 0755 "$REPO_DIR/AGENT/bin/lab-agent" "$INSTALL_BIN"

cat > "$SERVICE" <<EOF
[Unit]
Description=RWR-Unraid disposable test-machine agent
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
Environment=RWR_AGENT_REPO=$REPO_DIR
Environment=RWR_AGENT_BRANCH=$TASK_BRANCH
ExecStart=$INSTALL_BIN
User=root
Group=root
Nice=5
EOF

cat > "$TIMER" <<'EOF'
[Unit]
Description=Poll GitHub for RWR-Unraid agent tasks

[Timer]
OnBootSec=30s
OnUnitActiveSec=60s
AccuracySec=10s
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now rwr-lab-agent.timer

echo "RWR lab agent installed."
echo "Repository: $REPO_DIR"
echo "Task branch: $TASK_BRANCH"
echo "Polling interval: about 60 seconds"
echo "Status: systemctl status rwr-lab-agent.timer"
