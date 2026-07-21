# Architecture

How the pieces of the Extending Mainnet initiative fit together. This is the map; the detailed
design is in `design/` and `cip/`.

## The feature

Generalize Canton's Global-Synchronizer traffic purchase to **dedicated** (non-global)
synchronizers: burn CC on the global sync keyed by a dedicated sync id; the sync's operator grants
the purchased traffic on its own sequencer. See `design/extension-traffic-manager.md`.

## Repos & where code lives

- **Code:** the `splice/` submodule (`ChainSafe/splice` fork) — Daml (`daml/splice-amulet`,
  `daml/splice-dso-governance`), Scala apps (`apps/sv`, `apps/validator`, `apps/scan`), Helm
  (`cluster/`), vendored Canton (`canton/`). One monorepo; no other fork needed.
- **Control center (this repo):** docs, plans, harness, analysis. Little product code.

## On-ledger PoC (in the fork)

- `RegisteredSynchronizer` + `DsoRules_RegisterSynchronizer` — governance registration.
- `AmuletRules_BuyDedicatedSyncTraffic` + `DedicatedSyncTraffic` — CC-funded buy; reuses
  `computeSynchronizerFees` + `splitAndBurn`. PoC on branch `daml-poc-buy-traffic` (PRs #1/#2).

## Off-ledger (planned)

Reconcile trigger (`DedicatedSyncTraffic` → `SetTrafficPurchased`), operator node, validator
auto-topup, Scan endpoints. See `planning/extending-mainnet-work-plan.md` (WS1).

## Docs map

- `design/` — our implementation design.
- `cip/` — CIP technical plan, kickoff, exec summary, diagrams, presenter notes (merged from the
  archived `canton-cip-docs`).
- `planning/` — epics/issues across both repos.
- `localnet.md` — how to run the local end-to-end environment.
- `testing.md` — the 3-tier testing strategy (Daml Script + Scala integration in the fork; LocalNet e2e here).
- `../history/` — RFCs, meetings, experiments, incidents, changelog.

## Deployment & ops (target)

- `../deploy/` — deployment overlays: consume Splice compose/Helm + operator-node overlay (RFC-001).
- `../telemetry/` — uniform observability (RFC-003).
- `../tools/` — agent-navigation helpers (RFC-002).
