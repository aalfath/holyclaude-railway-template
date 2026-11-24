# HolyClaude on Railway: https://github.com/CoderLuii/HolyClaude
# Thin wrapper around the official slim image, pinned by version and digest
# (linux/amd64 manifest of coderluii/holyclaude:1.7.0-slim).
FROM coderluii/holyclaude:1.7.0-slim@sha256:3b608cf8d587ca1565131135a189518fb144c5fd175bff65db2d751bca7d37fe

USER root

# Railway wrapper: volume layout, login, port and memory settings.
COPY railway/railway-entrypoint.sh /usr/local/bin/railway-entrypoint
COPY railway/sync-login.mjs /usr/local/lib/holyclaude-railway/sync-login.mjs
COPY railway/claude-oom-wrapper.sh /usr/local/bin/holyclaude-claude
COPY railway/gitconfig /etc/gitconfig
# Upstream's CloudCLI service with the port taken from PORT and the Node heap
# sized from the service's memory limit.
COPY railway/cloudcli-run /etc/s6-overlay/s6-rc.d/cloudcli/run
RUN chmod 755 /usr/local/bin/railway-entrypoint /usr/local/bin/holyclaude-claude /etc/s6-overlay/s6-rc.d/cloudcli/run \
 && chmod 644 /usr/local/lib/holyclaude-railway/sync-login.mjs /etc/gitconfig

# DATABASE_PATH puts CloudCLI's account database on the volume (upstream keeps
# it in ~/.cloudcli, which is not on the volume). CLAUDE_CLI_PATH makes chat
# sessions start Claude Code through a wrapper that volunteers it as the first
# OOM victim, so a memory spike ends one session, not the web UI.
# S6_BEHAVIOUR_IF_STAGE2_FAILS=2 makes a failed start exit non-zero, so
# Railway's restart policy applies.
ENV PORT=3001 \
    DATABASE_PATH=/home/claude/.claude/.cloudcli/auth.db \
    CLAUDE_CLI_PATH=/usr/local/bin/holyclaude-claude \
    DISABLE_AUTOUPDATER=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    TZ=UTC

EXPOSE 3001
WORKDIR /
ENTRYPOINT ["/usr/local/bin/railway-entrypoint"]
