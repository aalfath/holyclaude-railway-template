# Deploy and Host HolyClaude on Railway

HolyClaude is an open-source AI coding workstation in one container: the real Claude Code CLI with CloudCLI, a browser UI for chat, files, git and a terminal, plus Codex, Gemini CLI, Cursor Agent, TaskMaster, a headless Chromium with Playwright, and common developer tools. You use your own Claude subscription or API key.

## About Hosting HolyClaude

This template runs HolyClaude 1.7.0 (slim image) as one Railway service with a volume, built from a public GitHub repo that pins the official image by digest. The volume at `/home/claude/.claude` holds everything that must last: your projects (`/workspace`), the CloudCLI login database, chat history, and the Claude, Codex and Gemini logins. Your login is created from generated variables before the public URL opens, so nobody else can claim the workstation. After deploying, open the URL and sign in as `admin` with `CLOUDCLI_PASSWORD` from the service's Variables tab, then sign in to Claude Code (subscription or API key). Updates arrive as Railway update notices when the repo is bumped.

## Common Use Cases

* Run Claude Code on a server you control and pick up the same session from a laptop, tablet or phone
* Keep long agent tasks, builds and tests running after you close your laptop
* Try Claude Code, Codex, Gemini CLI and Cursor Agent on the same repository without installing anything locally

## Dependencies for HolyClaude Hosting

* A Claude Pro/Max subscription (sign in from the web UI) or an Anthropic API key from console.anthropic.com
* Optional: keys or logins for the other CLIs (OpenAI, Gemini, Cursor), added in the web UI or as service variables

### Deployment Dependencies

* HolyClaude source and docs: https://github.com/CoderLuii/HolyClaude (MIT), release v1.7.0: https://github.com/CoderLuii/HolyClaude/releases/tag/v1.7.0
* Official image: `coderluii/holyclaude:1.7.0-slim` on Docker Hub
* Web UI: CloudCLI (https://github.com/siteboon/claudecodeui, AGPL-3.0-or-later), as built by HolyClaude
* Template repo: https://github.com/aalfath/holyclaude-railway-template

### Implementation Details

**Services.** One service, `HolyClaude`: the web UI on port 3001, health check `/health`, one volume at `/home/claude/.claude`. No database service is needed (CloudCLI uses SQLite on the volume).

**Variables.** `CLOUDCLI_PASSWORD` is generated for you; `CLOUDCLI_USERNAME` defaults to `admin`. `ANTHROPIC_API_KEY` is optional: leave it empty to sign in with a Claude subscription in the web UI. A password you change in the web UI (Settings) stays until you edit `CLOUDCLI_PASSWORD`; editing it and redeploying resets the login and signs every browser out. The service refuses to start without a password of 12 or more characters.

**Memory.** The web UI idles at about 250 MB and one Claude Code chat run fits in Railway's 0.5 GB Free plan (tested). For several sessions at once, Chromium browser work or large repositories, give the service 2 GB or more. If memory runs out, the kernel ends the agent session first, not the web UI, and the supervisor restarts anything that crashes. The image is about 2 GB to download, so the first deploy takes a few minutes.

**Security.** The web UI gives a full shell and holds your AI logins, so keep the generated password. Docker-in-Docker, SSH and Mosh are not available on Railway; the slim image installs extra tools on demand (`sudo apt-get`, `npm`, `pip`), and anything outside the volume is lost on redeploy.

**Updates.** Railway shows an update notice when the template repo moves to a new HolyClaude release. Read the repo's `CHANGELOG.md` first; the volume and your login are kept.

## Why Deploy HolyClaude on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying HolyClaude on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
