# AgentsApp

Personal multi-agent Claude Code orchestrator desktop app for [@DIMAXXX123](https://github.com/DIMAXXX123).

Forked from [baryhuang/claude-code-by-agents](https://github.com/baryhuang/claude-code-by-agents) (MIT) — itself originally a fork of [sugyan/claude-code-webui](https://github.com/sugyan/claude-code-webui) (MIT). All upstream attribution preserved in `LICENSE`.

## Stack

- Electron 37 + React 19 + Vite + TypeScript
- Node.js / Hono backend with `@anthropic-ai/claude-code` SDK
- SQLite (`openmemory.sqlite`) for persistence
- OAuth via Claude subscription (no API key needed)

## Quick start

```bash
git clone https://github.com/DIMAXXX123/AgentsApp.git
cd AgentsApp
npm install
npm run electron:dev   # Electron + dev frontend on :3000
```

In a separate terminal, run the backend:

```bash
cd backend
deno task dev          # or: npm run dev — backend on :8080
```

## Build distributables

```bash
npm run build          # builds frontend
npm run dist:win       # Windows portable + zip
npm run dist:mac       # macOS dmg (x64 + arm64)
npm run dist:linux     # AppImage
```

## Authentication

Uses Claude Code OAuth via your existing subscription:

```bash
claude auth login
```

The Electron app handles OAuth flow internally; no API keys required.

## Roadmap (future iterations)

These are intentionally **not** in the initial drop — features land in subsequent PRs:

- Obsidian vault sync (`~/Documents/Obsidian-Vault/`)
- Memory crystallization (3× rule)
- Per-agent git worktree isolation
- Voice input (whisper.cpp)
- Cron scheduler
- Telegram bridge (cc-connect adapter)
- MCP server registry

## License

MIT — see [LICENSE](./LICENSE). Upstream copyright preserved.

## Acknowledgements

- [baryhuang/claude-code-by-agents](https://github.com/baryhuang/claude-code-by-agents) — direct upstream
- [sugyan/claude-code-webui](https://github.com/sugyan/claude-code-webui) — original
- Anthropic — for Claude Code
