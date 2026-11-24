# Changelog

Breaking changes are listed first in each entry.

## 1.7.0 (2026-11-24)

- First release: HolyClaude 1.7.0, slim image `coderluii/holyclaude:1.7.0-slim@sha256:3b608cf8d587ca1565131135a189518fb144c5fd175bff65db2d751bca7d37fe` (Claude Code 2.1.325, CloudCLI 1.37.3, Codex 0.169.0, Gemini CLI 0.68.0, Cursor Agent 2026.09.15, TaskMaster 0.43.1).
- Image slimmed to about 2 GB compressed (upstream slim is 3.5 GB) by dropping build caches and duplicate binaries, so it fits Railway's 4 GB image limit on every plan.
- `~/.claude.json` (Claude Code settings and project trust) is owned by the `claude` user and kept on the volume.
- Login created from `CLOUDCLI_USERNAME`/`CLOUDCLI_PASSWORD` before the public port opens; all state on the `/home/claude/.claude` volume.
