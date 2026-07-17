# RFC-002: Agent-navigation APIs / services

**Status:** Draft. Skeleton: `tools/navigator.sh`.

## Motivation

This is an AI-native project spanning many sibling repos (see `AGENTS.md`). Agents waste effort
rediscovering where things live and what's running. Provide small, uniform services that answer
"what exists, where is X, what's its status" — so any agent can orient in one call.

## Scope (full build)

Thin services (not a new platform) exposing:
- **Sibling map** — the `AGENTS.md` table as structured data (repos, roles, paths, links).
- **Where-is-X resolver** — map a symbol / feature / doc to its repo + path (e.g.
  `AmuletRules_BuyDedicatedSyncTraffic` → `splice/daml/.../AmuletRules.daml`).
- **Cross-project status** — submodule pointer, open PRs/issues per sibling, LocalNet health, CI state.

## Design sketch

Build **over `canton-mcp-server`** (the org MCP for Canton dev) rather than a new stack: add MCP
tools backed by the GitHub API, the submodule state, and LocalNet discovery. `tools/navigator.sh`
is the CLI seed (prints the sibling map + `git submodule status` + LocalNet health); it graduates
into MCP tools as they land.

## Open questions

- What belongs in `canton-mcp-server` (shared) vs here (initiative-specific).
- Auth/secrets for the GitHub API in agent contexts.
- Keep the map in sync with `AGENTS.md` (generate one from the other).
