[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/holyclaude-1?utm_medium=integration&utm_source=button&utm_campaign=holyclaude)

# HolyClaude on Railway

One-click [Railway](https://railway.com) template for **[HolyClaude](https://github.com/CoderLuii/HolyClaude)**, an AI coding workstation in the browser: the real Claude Code CLI with the CloudCLI web UI (chat, files, git, terminal), plus Codex, Gemini CLI, Cursor Agent, TaskMaster, headless Chromium with Playwright, and common dev tools.

> Unofficial packaging of HolyClaude by CoderLuii (MIT, see `LICENSE.upstream`). The web UI is CloudCLI (https://github.com/siteboon/claudecodeui, AGPL-3.0-or-later) as built by HolyClaude. This repo changes no application code.

## What it deploys

| Service | What it does |
|---|---|
| **HolyClaude** | HolyClaude **1.7.0** slim image `coderluii/holyclaude:1.7.0-slim@sha256:3b608cf8…` (linux/amd64), with a small Railway wrapper. Web UI on port `3001`, health check `/health`, volume at `/home/claude/.claude`. |

The `Dockerfile` drops about 1.5 GB of build cache and duplicate binaries from the upstream image and flattens it. The upstream slim image is 3.5 GB compressed; ours is about 2 GB, which stays well under Railway's 4 GB image limit on the Free and Trial plans.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `CLOUDCLI_PASSWORD` | generated (`${{secret(24)}}`) | Your web UI password (12+ characters). |
| `CLOUDCLI_USERNAME` | `admin` | Your web UI login name. |
| `ANTHROPIC_API_KEY` | empty, optional | For Claude Code. Or sign in with a Claude subscription from the web UI. |
| `PORT` | `3001` | Leave as is. |

CloudCLI normally lets the first visitor create the only account. Here the wrapper creates the login from the variables **before** anything listens, and refuses to start without a password. The variables are re-applied only when you change them, so a password changed in the web UI stays until you edit `CLOUDCLI_PASSWORD` (that is also how you reset a forgotten password). The password is removed from the environment that terminals and agents see.

Optional upstream settings (notifications such as `NOTIFY_DISCORD`, `GEMINI_API_KEY`, `OPENAI_API_KEY`, `HOLYCLAUDE_CODEX_CHAT_PERMISSION_MODE`) can be added as service variables; see the [upstream configuration docs](https://github.com/CoderLuii/HolyClaude/blob/v1.7.0/docs/configuration.md).

## After deploying

1. Open the service URL and sign in as `admin` with `CLOUDCLI_PASSWORD` (service → Variables).
2. Sign in to Claude Code from the web UI (Claude subscription or API key), or set `ANTHROPIC_API_KEY`.
3. Clone a repo into `/workspace` from the terminal and open it as a project.

## Data

The volume at `/home/claude/.claude` holds your projects (`/workspace` links into it), the CloudCLI database (login, sessions, settings), chat attachments, `CLAUDE.md`, and the Claude, Codex and Gemini logins and settings. Anything installed outside it (`apt-get`, global `npm`) is lost on redeploy.

## Memory

The web UI idles at about 250 MB, and one Claude Code chat run fits in Railway's Free plan (0.5 GB, tested). For several sessions at once, Chromium browser work or large repositories, give the service 2 GB or more. The web UI's JavaScript heap is sized from the service's memory limit, Claude Code sessions are the first OOM victims (not the web UI), git is capped for small memory (`/etc/gitconfig`), and s6-overlay restarts a crashed web UI. A failed start exits non-zero so Railway's `ON_FAILURE` policy retries it.

## Not available on Railway

Docker-in-Docker, SSH/Mosh (Railway exposes one HTTP port) and a 2 GB `/dev/shm` for Chromium. Chromium runs with `--disable-dev-shm-usage`.

## Updates

Railway shows an update notice when this repo's `main` changes. Read `CHANGELOG.md` before applying; your volume and login are kept. The CLIs' self-updaters are off; new versions come through this repo.

## License

The packaging files here are MIT. HolyClaude is MIT (`LICENSE.upstream`); CloudCLI is AGPL-3.0-or-later; Claude Code is Anthropic's proprietary CLI, used with your own account.
