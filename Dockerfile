# HolyClaude on Railway: https://github.com/CoderLuii/HolyClaude
# Thin wrapper around the official slim image, pinned by version and digest
# (linux/amd64 manifest of coderluii/holyclaude:1.7.0-slim).
FROM coderluii/holyclaude:1.7.0-slim@sha256:3b608cf8d587ca1565131135a189518fb144c5fd175bff65db2d751bca7d37fe AS upstream

# The published image is 3.5 GB compressed (8.3 GB unpacked), close to Railway's
# 4 GB image limit on the Free and Trial plans. Drop what never runs here and
# flatten it into one layer:
# - the 1.5 GB npm download cache left in /root/.npm by the image build,
# - the node-gyp header cache,
# - the musl build of the Claude Agent SDK binary (this is a glibc system),
# - the macOS and Windows Codex binaries bundled inside task-master-ai,
# - a second copy of the Claude Code binary (replaced by a link to the first).
USER root
RUN set -eux; \
    N=/usr/local/lib/node_modules; \
    rm -r /root/.npm/_cacache /home/claude/.cache/node-gyp; \
    rm -r $N/@cloudcli-ai/cloudcli/node_modules/@anthropic-ai/claude-agent-sdk-linux-x64-musl; \
    rm -r $N/task-master-ai/node_modules/@openai/codex/vendor/*-apple-darwin \
          $N/task-master-ai/node_modules/@openai/codex/vendor/*-pc-windows-msvc; \
    TM=$N/task-master-ai/node_modules/@anthropic-ai/claude-code-linux-x64/claude; \
    CC=$(readlink -f /home/claude/.local/bin/claude); \
    cmp "$TM" "$CC" && rm "$TM" && ln -s "$CC" "$TM"; \
    claude --version

FROM scratch
COPY --from=upstream / /

# Upstream's image settings, restated because FROM scratch drops them.
ENV PATH=/home/claude/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    NODE_VERSION=26.13.1 \
    DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    DISPLAY=:99 \
    DBUS_SESSION_BUS_ADDRESS=disabled: \
    CHROMIUM_FLAGS="--no-sandbox --disable-gpu --disable-dev-shm-usage" \
    CHROME_PATH=/usr/bin/chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    NODE_PATH=/usr/local/lib/node_modules


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
