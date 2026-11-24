#!/bin/bash
# Prepares HolyClaude for Railway, then hands over to upstream's entrypoint
# (which ends with `exec /init`, making s6-overlay PID 1).
# Any failure here exits non-zero, so Railway's restart policy applies.
set -euo pipefail
cd /

STATE=/home/claude/.claude          # the Railway volume
log() { echo "[railway] $*"; }

# ---- Login variables: refuse to expose the web UI without them -------------
: "${CLOUDCLI_USERNAME:=admin}"
if [ "${#CLOUDCLI_USERNAME}" -lt 3 ] || [ "${#CLOUDCLI_PASSWORD:-}" -lt 12 ]; then
  log "CLOUDCLI_USERNAME (3+ characters) and CLOUDCLI_PASSWORD (12+ characters) must be set in the service Variables."
  log "Refusing to start: the web UI gives a full shell and your AI provider logins."
  exit 1
fi
export CLOUDCLI_USERNAME

# ---- Volume layout -----------------------------------------------------------
# Upstream needs ~/.claude to be a real directory and the image-owned Claude Code
# binary under ~/.local, so the volume is mounted at ~/.claude and everything
# durable lives there: CLI state, the CloudCLI database and your projects.
mkdir -p "$STATE"
rmdir "$STATE/lost+found" 2>/dev/null || true
chown claude:claude "$STATE"
for d in workspace .cloudcli .cloudcli/assets; do
  [ -d "$STATE/$d" ] || install -d -o claude -g claude "$STATE/$d"
done

# /workspace (upstream's project root) becomes a link into the volume.
if [ ! -L /workspace ]; then
  rmdir /workspace 2>/dev/null || true
  if [ -e /workspace ]; then
    log "/workspace exists and is not empty; refusing to replace it"; exit 1
  fi
  ln -s "$STATE/workspace" /workspace
fi

# Chat attachments live in ~/.cloudcli/assets; keep them on the volume too.
install -d -o claude -g claude /home/claude/.cloudcli
if [ ! -L /home/claude/.cloudcli/assets ]; then
  rmdir /home/claude/.cloudcli/assets 2>/dev/null || true
  [ -e /home/claude/.cloudcli/assets ] || ln -s "$STATE/.cloudcli/assets" /home/claude/.cloudcli/assets
fi

# ---- Create or update the single CloudCLI login before anything listens ----
runuser -u claude -- env HOME=/home/claude DATABASE_PATH="$DATABASE_PATH" \
  CLOUDCLI_USERNAME="$CLOUDCLI_USERNAME" CLOUDCLI_PASSWORD="$CLOUDCLI_PASSWORD" \
  node /usr/local/lib/holyclaude-railway/sync-login.mjs
# The web login stays out of the environment that terminals and agents inherit.
unset CLOUDCLI_PASSWORD

# ---- Memory ------------------------------------------------------------------
LIMIT=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo max)
log "memory limit: ${LIMIT} bytes; volume: $(df -h "$STATE" | awk 'NR==2{print $2" total, "$4" free"}')"

exec /usr/local/bin/entrypoint.sh "$@"
