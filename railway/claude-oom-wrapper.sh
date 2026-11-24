#!/bin/sh
# Claude Code started by the web UI. If the service runs out of memory, the
# kernel should end this session, not the web UI, so it volunteers as the
# first OOM victim.
echo 900 > /proc/self/oom_score_adj 2>/dev/null || true
exec /home/claude/.local/bin/claude "$@"
