#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${RWR_AGENT_BASE:-/mnt/cache/appdata/rwr-test-agent}"
CONTAINER_NAME="${RWR_AGENT_CONTAINER:-RWR-Test-Agent}"
IMAGE_NAME="${RWR_AGENT_IMAGE:-rwr-test-agent:local}"
REPO_URL="https://github.com/skullrider0/RWR-Unraid.git"
TASK_BRANCH="agent/tasks"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run this installer from the Unraid terminal as root." >&2
  exit 1
fi

command -v docker >/dev/null 2>&1 || { echo "Docker is required." >&2; exit 1; }

mkdir -p "$BASE_DIR/build" "$BASE_DIR/workspace" "$BASE_DIR/docker-data" "$BASE_DIR/secrets"
chmod 700 "$BASE_DIR/secrets"

TOKEN_FILE="$BASE_DIR/secrets/github-token"
if [[ ! -s "$TOKEN_FILE" ]]; then
  if [[ ! -r /dev/tty ]]; then
    echo "An interactive terminal is required to enter the GitHub token." >&2
    exit 1
  fi
  printf 'GitHub fine-grained token for RWR-Unraid (Contents: Read and write): ' > /dev/tty
  IFS= read -r -s token < /dev/tty
  printf '\n' > /dev/tty
  if [[ -z "$token" ]]; then
    echo "A GitHub token is required so the agent can push result commits." >&2
    exit 1
  fi
  printf '%s' "$token" > "$TOKEN_FILE"
  unset token
  chmod 600 "$TOKEN_FILE"
fi

cat > "$BASE_DIR/build/Dockerfile" <<'DOCKERFILE'
FROM docker:28-dind
RUN apk add --no-cache bash git jq util-linux coreutils curl openssh-client python3
COPY entrypoint.sh /usr/local/bin/rwr-agent-entrypoint
RUN chmod +x /usr/local/bin/rwr-agent-entrypoint
ENTRYPOINT ["/usr/local/bin/rwr-agent-entrypoint"]
DOCKERFILE

cat > "$BASE_DIR/build/entrypoint.sh" <<'ENTRYPOINT'
#!/usr/bin/env bash
set -u

REPO_DIR=/workspace/RWR-Unraid
TASK_BRANCH="${RWR_AGENT_BRANCH:-agent/tasks}"
TOKEN_FILE=/run/secrets/github-token
export RWR_AGENT_REPO="$REPO_DIR"

/usr/local/bin/dockerd-entrypoint.sh dockerd > /var/log/dockerd.log 2>&1 &
dockerd_pid=$!

cleanup() {
  kill "$dockerd_pid" 2>/dev/null || true
  wait "$dockerd_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

for _ in $(seq 1 120); do
  if docker info >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! docker info >/dev/null 2>&1; then
  echo "[rwr-agent] inner Docker daemon did not become ready" >&2
  tail -100 /var/log/dockerd.log >&2 || true
  exit 1
fi

if [[ ! -s "$TOKEN_FILE" ]]; then
  echo "[rwr-agent] GitHub token secret is missing" >&2
  exit 1
fi

cat > /tmp/rwr-git-askpass <<'ASKPASS'
#!/usr/bin/env sh
case "$1" in
  *Username*) printf '%s\n' 'x-access-token' ;;
  *) cat /run/secrets/github-token ;;
esac
ASKPASS
chmod 700 /tmp/rwr-git-askpass
export GIT_ASKPASS=/tmp/rwr-git-askpass
export GIT_TERMINAL_PROMPT=0

mkdir -p /workspace
if [[ ! -d "$REPO_DIR/.git" ]]; then
  rm -rf "$REPO_DIR"
  git clone --branch "$TASK_BRANCH" https://github.com/skullrider0/RWR-Unraid.git "$REPO_DIR"
fi

cd "$REPO_DIR"
git remote set-url origin https://github.com/skullrider0/RWR-Unraid.git
git fetch origin "$TASK_BRANCH" --quiet || true
if git show-ref --verify --quiet "refs/heads/$TASK_BRANCH"; then
  git checkout "$TASK_BRANCH" --quiet || true
else
  git checkout -b "$TASK_BRANCH" "origin/$TASK_BRANCH" --quiet || true
fi

printf '[rwr-agent] isolated Docker daemon ready; polling %s every 60 seconds\n' "$TASK_BRANCH"
while true; do
  cd "$REPO_DIR"
  bash AGENT/bin/lab-agent || true
  sleep 60
done
ENTRYPOINT
chmod +x "$BASE_DIR/build/entrypoint.sh"

echo "Building isolated RWR test-agent image..."
docker build -t "$IMAGE_NAME" "$BASE_DIR/build"

if docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
  docker rm -f "$CONTAINER_NAME" >/dev/null
fi

echo "Starting $CONTAINER_NAME..."
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  --privileged \
  --network bridge \
  -e RWR_AGENT_BRANCH="$TASK_BRANCH" \
  -e RWR_AGENT_REPO="/workspace/RWR-Unraid" \
  -v "$BASE_DIR/workspace:/workspace" \
  -v "$BASE_DIR/docker-data:/var/lib/docker" \
  -v "$TOKEN_FILE:/run/secrets/github-token:ro" \
  "$IMAGE_NAME" >/dev/null

sleep 3

echo
echo "RWR isolated test agent is installed."
echo "Container: $CONTAINER_NAME"
echo "Persistent data: $BASE_DIR"
echo "Host Docker socket mounted: NO"
echo
echo "Current status:"
docker ps --filter "name=^/${CONTAINER_NAME}$" --format '  {{.Names}}  {{.Status}}  {{.Image}}'
echo
echo "Recent agent log:"
docker logs --tail 25 "$CONTAINER_NAME" 2>&1 || true
