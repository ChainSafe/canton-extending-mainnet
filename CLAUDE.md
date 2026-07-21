# CLAUDE.md

Guidance for Claude Code when working in this repository. **Read [`AGENTS.md`](AGENTS.md) first** — it is the agent-agnostic index (sibling projects + how to navigate this control-center repo); this file adds Claude-specific notes.

## Project

**canton-extending-mainnet** is ChainSafe's implementation work for the Canton CIP **"Extending Mainnet: Tokenomics Alignment Across the Entire Canton Network"** (Shaul Kfir, Digital Asset). It generalizes Canton's single Global-Synchronizer traffic-purchase + Burn-Mint flow into per-synchronizer, per-transaction-class, discount-curve, optionally-staked pricing across all extension synchronizers.

**This is a standalone project. It is NOT related to `canton-middleware`** (a separate ChainSafe repo). Do not reference, import from, or write to canton-middleware.

- **Repo roles:** this repo (`ChainSafe/canton-extending-mainnet`, private) is the **tooling / analysis / docs / planning** hub. The actual on-ledger + app **code** changes live in the Splice fork `ChainSafe/splice` (PoC PRs #1/#2; issue epics E0-E10). See `README.md`.
- **Design docs / analysis:** now in this repo under `docs/cip/` (technical plan, kickoff, diagrams, exec summary, presenter notes) - merged in from the former `ChainSafe/canton-cip-docs`, which is **archived**. Working design + planning live under `docs/design/` and `docs/planning/`.
- **ChainSafe's role:** as a Super Validator and prospective dedicated-synchronizer operator, co-designing and piloting the CIP with Digital Asset.

## Stack

Match Splice's stack:
- **Daml** for on-ledger contracts (developed against Daml SDK **3.4.8**).
- **Scala/JVM** for apps + automation (later, matching Splice's SV/validator triggers).
- **Docker LocalNet** for local end-to-end testing (Splice's Docker-based local network).
- Splice source: `canton-network/splice` (mirror: `hyperledger-labs/splice`); Canton: `digital-asset/canton`.

## Layout

This is a "control center" repo — see [`AGENTS.md`](AGENTS.md) for the full map + sibling projects. In brief:
- `splice/` — submodule -> **`ChainSafe/splice` fork** (the code: Daml + Scala + TS + vendored Canton). Work in it, push to the fork, then `git add splice` in this repo to bump the pointer. Push the submodule before the superproject.
- `docs/` — `architecture.md`, `design/`, `cip/` (merged from the archived canton-cip-docs), `planning/`, `localnet.md`.
- `history/` — `rfcs/`, `meetings/`, `experiments/`, `incidents/`, `CHANGELOG.md`.
- `scripts/` LocalNet harness · `tools/` navigator · `deploy/` deployment overlays (RFC-001) · `telemetry/` (RFC-003) · `sync-pricing/` parked pricing analysis.

## Common commands

```
cd sync-pricing
daml build                       # compile the pricing library to a DAR
daml test                        # run the acceptance tests (currently 14 scripts, all green)
```

## Status & next steps

- **Done:** shadow-mode pricing engine (off-ledger, pure Daml, no Splice dependency). Reproduces the CIP Section 5 table; encodes the Section 6.2 `(1 - D)` factor fix as an executable test; three tiers (100/30/10); extension-only throughput discount; smooth + tiered modes (recommend **tiered** on-ledger to avoid Numeric rounding drift).
- **Done:** `splice/` submodule now points at the **`ChainSafe/splice` fork** (full history, branch `daml-poc-buy-traffic` carrying the PoC). LocalNet lives at `splice/cluster/compose/localnet`; the harness (`scripts/localnet-*.sh`) pulls published `ghcr.io/digital-asset/...` images by `IMAGE_TAG` (default 0.6.13).
- **Done:** brought up Docker LocalNet (full `sv`+`app-provider`+`app-user` stack, verified 2026-07-08) and observed the real `AmuletRules_BuyMemberTraffic` -> `splitAndBurn` (mints `ValidatorRewardCoupon`) -> `SetTrafficPurchased` flow fire with no manual trigger. Runs in ~4.8 GiB of the 7.7 GiB Docker allocation. See [[splice-localnet]] memory for the exact command + observed numbers.
- **Done:** cents/tx-to-bytes conversion harness (`TrafficConversion.daml`): faithful ports of Canton's `EventCostCalculator` (integer byte cost) and Splice's `computeSynchronizerFees` (bytes -> USD -> CC), plus the inverse (CIP cents/tx -> bytes/CC). Grounded by `TrafficConversionTest.daml`, which pins Canton's own unit-test vectors AND reproduces the live LocalNet buy exactly (1,200,000 bytes -> $20.004 -> 4000.8 CC at extraTrafficPrice=$16.67/MB, scaling=4, amuletPrice=$0.005/CC, baseEventCost=0, all read from the running Scan API).
- **Next / Later (gated on Digital Asset answers):** wire per-synchronizer pricing into `AmuletConfig` (a schema change — it is a single config today, not a map), the commitment-stake + coupon-free shortfall burn, and the report-to-mint path.

## Conventions

- Grounded in real Splice/Canton source: `computeSynchronizerFees` (AmuletRules.daml; round `trafficPrice` takes precedence over config `extraTrafficPrice`), `splitAndBurn` mints a `ValidatorRewardCoupon`, `SynchronizerFeesConfig` in DecentralizedSynchronizer.daml.
- Docs style (carried from canton-cip-docs): avoid em/long dashes; direct language.

## Git Commit Rules

Never include "Co-authored-by" or any reference to Claude/Anthropic in commit messages or pull requests.
