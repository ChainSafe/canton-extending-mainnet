# canton-extending-mainnet

**Control center** for ChainSafe's work on the Canton CIP *"Extending Mainnet: Tokenomics
Alignment Across the Entire Canton Network"* (Shaul Kfir, Digital Asset).

This repo has **almost no product code**. It **orchestrates, documents, and navigates** the
initiative: the plans, the architecture, the LocalNet harness, the analysis, the deployment specs,
and the coordination with Digital Asset. The actual code lives in the **`splice/` submodule** —
Digital Asset's **`canton-network/splice-multi-sync`** feature fork, where the PoC is up as draft
PRs so it runs DA's CI.

**Start here:** [`AGENTS.md`](AGENTS.md) — the sibling-project map and navigation guide.

## What we're building

Generalize Canton's Global-Synchronizer traffic purchase to **dedicated** (non-global)
synchronizers: burn Canton Coin on the global sync keyed by a dedicated sync id, and that sync's
**operator** grants the purchased traffic on its own sequencer. MVP is no-discount; later come
per-synchronizer pricing, transaction-class discounts, staking, and operator rewards.

Details: [`docs/architecture.md`](docs/architecture.md) (the map) · [`docs/design/`](docs/design)
(implementation design) · [`docs/cip/`](docs/cip) (CIP writeups) ·
[`docs/planning/`](docs/planning) (the work breakdown).

## Control-center layout

The repo follows a deliberate control-center pattern — a small, uniform structure so any agent or
teammate can orient fast:

| # | Element | Here |
|---|---|---|
| 0 | **Sibling-project map** | [`AGENTS.md`](AGENTS.md) — what the sibling repos are + how to navigate |
| 1 | **Architecture / docs** | [`docs/`](docs) — `architecture.md`, `design/`, `cip/`, `planning/`, `localnet.md` |
| 2 | **Deployment (executable specs)** | [`deploy/`](deploy) — NixOS descriptions *(skeleton; [RFC-001](history/rfcs/RFC-001-nixos-deployment.md))* |
| 3 | **Agent-navigation APIs/services** | [`tools/`](tools) — `navigator.sh` *(skeleton; [RFC-002](history/rfcs/RFC-002-agent-navigation-apis.md))* |
| 4 | **Centralized telemetry** | [`telemetry/`](telemetry) — analytics/logging/telemetry *(skeleton; [RFC-003](history/rfcs/RFC-003-telemetry.md))* |
| 5 | **Historical records** | [`history/`](history) — `rfcs/`, `meetings/`, `experiments/`, `incidents/`, `CHANGELOG.md` |

Plus the working pieces: **`splice/`** (submodule → the code), **`scripts/`** (LocalNet harness),
**`sync-pricing/`** (parked off-ledger pricing analysis).

## Repos in play

| Repo | Role |
|---|---|
| **canton-extending-mainnet** (this, private) | The control center: docs, plans, harness, analysis, coordination. Issue epics **T0** (harness/dev-env) + **T1** (analysis/DA). |
| **canton-network/splice-multi-sync** (DA's fork; the `splice/` submodule) | **The code** — DA's multi-sync feature fork of `canton-network/splice` (monorepo: Daml `daml/` + `token-standard/`, Scala `apps/`, TS frontends, vendored Canton `canton/`, Helm `cluster/`). PoC on `multi-sync-poc-buy-traffic`; draft PRs #1/#2 there run DA's CI. Issue epics **E0–E10**. (Originally developed on the `ChainSafe/splice` fork — now superseded by this one.) |
| **ChainSafe/canton-cip-docs** | Archived — CIP design docs merged here under `docs/cip/`. |

See [`AGENTS.md`](AGENTS.md) for the full sibling list (x402 facilitator, MCP server, burn
snapshotter, platform docs, …).

## Quick start

- **Orient:** read [`AGENTS.md`](AGENTS.md), or run `tools/navigator.sh`.
- **Set up + build/test:** [`docs/development.md`](docs/development.md) — Nix/direnv env + the `sbt damlBuild`/`damlTest` commands (start here to run the tests).
- **Run LocalNet** (Docker; ~10 GB RAM for multi-sync) — drives the `splice/` submodule:
  ```
  scripts/localnet-up.sh      # then scripts/localnet-e2e.sh   ;   tear down: scripts/localnet-down.sh
  ```
  Full guide: [`docs/localnet.md`](docs/localnet.md).
- **Work on the code:** `cd splice`, work on a branch, push to `canton-network/splice-multi-sync`
  (the submodule's `origin`), then `git add splice` here to bump the pointer. **Push the submodule
  before the superproject.**
- **Pricing analysis** (parked; pure Daml, SDK 3.4.8): `cd sync-pricing && daml test`.

## Status

- **Done:** the Daml PoC **compiles and all Daml Script tests pass** — governance registration
  (`RegisteredSynchronizer` + `DsoRules_RegisterSynchronizer`) and CC-funded buy
  (`AmuletRules_BuyDedicatedSyncTraffic` + `DedicatedSyncTraffic`), including negative tests. Ported
  to `canton-network/splice-multi-sync` as draft PRs #1/#2 to run DA's CI. Plus: the multi-sync
  LocalNet harness (verified) and the shadow pricing engine (green).
- **Next:** confirm DA's CI is green on the multi-sync PRs → the Scala reconcile/operator automation
  → a LocalNet register→buy→grant e2e. Tracked in [`docs/planning/`](docs/planning).

Conventions: never reference Claude/Anthropic in commits or PRs; direct-language docs (no em/long
dashes). The pricing engine is a parked reference (the MVP reuses Splice's `computeSynchronizerFees`
+ `splitAndBurn` unchanged); it also surfaced a CIP Section 6.2 formula bug tracked to raise with DA
(see [`docs/`](docs) / [`sync-pricing/`](sync-pricing)).
