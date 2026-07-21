# AGENTS.md — canton-extending-mainnet control center

This repo is the **control center** for ChainSafe's work on the Canton CIP "Extending Mainnet"
(dedicated-synchronizer traffic). It holds little product code; it orchestrates, documents, and
navigates the work. The actual code lives in the `splice/` submodule (the `ChainSafe/splice` fork).

Agents (Claude Code, Codex, etc.) start here — this is the agent-agnostic index. `CLAUDE.md` adds
Claude-specific notes and defers to this file.

## Sibling projects

| Project | Where | Role |
|---|---|---|
| splice (fork) | `splice/` submodule → github.com/ChainSafe/splice | **THE CODE.** Monorepo: Daml (`daml/`, `token-standard/`), Scala (`apps/`), TS frontends, vendored Canton (`canton/`), Helm (`cluster/`). All CIP feature changes land here (PoC on `daml-poc-buy-traffic`). |
| canton-x402-facilitator / -sdk | github.com/ChainSafe/canton-x402-* | x402 payment facilitator + SDK; source of our LocalNet harness pattern. |
| canton-mcp-server | github.com/ChainSafe/canton-mcp-server | MCP server for Canton dev — integration point for agent-navigation tooling (RFC-002). |
| canton-burn-snapshotter | github.com/ChainSafe/canton-burn-snapshotter | Tracks Canton burn for traffic decisions — adjacent to our traffic feature. |
| canton-chainsafe-platform | github.com/ChainSafe/canton-chainsafe-platform | Internal Canton platform docs (org-level; cross-reference). |
| canton-middleware | github.com/ChainSafe/canton-middleware | Separate ChainSafe Canton service (not part of this initiative). |
| canton-cip-docs | ARCHIVED → `docs/cip/` | Former CIP design docs; merged into this repo. |

## Map of this repo

- `splice/` — the code (submodule). Edit here, commit + push to the fork, then bump the gitlink.
- `docs/` — architecture (`architecture.md`), implementation design (`design/`), CIP writeups (`cip/`), work plan (`planning/`), LocalNet guide (`localnet.md`).
- `history/` — RFCs (`rfcs/`), meeting notes (`meetings/`), `experiments/`, `incidents/`, `CHANGELOG.md`.
- `scripts/` — LocalNet harness (up/down/e2e, multi-sync).
- `tools/` — agent-navigation helpers (`navigator.sh`; RFC-002).
- `deploy/` — NixOS deployment specs (skeleton; RFC-001).
- `telemetry/` — observability (skeleton; RFC-003).
- `sync-pricing/` — parked off-ledger pricing analysis.

## Navigation / common tasks

- **Understand the feature:** `docs/design/extension-traffic-manager.md` + `docs/cip/`.
- **What to build & who tracks it:** `docs/planning/extending-mainnet-work-plan.md`. Issues are split — code in `ChainSafe/splice` (epics E0–E10), tooling/analysis here (epics T0/T1).
- **Run LocalNet:** `scripts/localnet-up.sh` (uses the `splice/` submodule) → `scripts/localnet-e2e.sh`.
- **Work on the code:** `cd splice`, work on a branch, push to the fork, then `git add splice` here to bump the pointer. **Push the submodule before the superproject.**
- **Set up your environment:** see `docs/development.md` — clone with the submodule, the Nix/direnv dev shell, and the build/test commands.
- **Test a change:** see `docs/testing.md` — 3 tiers (Daml Script + Scala integration in the fork; black-box LocalNet e2e here).
- **Get a PR through CI:** see `docs/splice-ci.md`: the CI gates (`[ci]`/DCO/release-line), the Daml static checks (warts, docs), the Stale-file-handle flake, and the no-force-push PR workflow.
- **Orient quickly:** `tools/navigator.sh`.

## Conventions

- Never reference Claude/Anthropic (or any AI tool) in commit messages or PRs.
- Docs style: direct language; no em/long dashes.
- Two-repo split: real Splice/Canton code → the fork; harness/tooling/analysis/docs → here.
