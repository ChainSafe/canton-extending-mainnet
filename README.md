# canton-extending-mainnet

ChainSafe's working repo for implementing the Canton CIP **"Extending Mainnet: Tokenomics
Alignment Across the Entire Canton Network"** (Shaul Kfir, Digital Asset).

This is the **control center** for the initiative: it holds the **tooling, harnesses, analysis,
planning, and docs** we build to *do* the implementation, plus coordination with Digital Asset —
but almost no product code. The actual code lives in the **`splice/` submodule** (the
`ChainSafe/splice` fork). **Agents: start with [`AGENTS.md`](AGENTS.md)** — the sibling-project map
and navigation guide. Two repos are in play (a third is archived):

| Repo | Role |
|---|---|
| **ChainSafe/canton-extending-mainnet** (this, private) | Tooling + analysis + docs + planning. LocalNet harness, shadow pricing engine, CIP design docs (`docs/cip/`), work plan. Issue epics **T0** (harness/dev-env) + **T1** (analysis/DA coordination). |
| **ChainSafe/splice** (fork of `canton-network/splice`) | The real code — the Daml packages (`splice-amulet`, `splice-dso-governance`) and Scala apps. The PoC lives here as PRs #1/#2. Issue epics **E0–E10** (compile/test + the feature workstreams). |
| **ChainSafe/canton-cip-docs** | **Archived** — its CIP design docs were merged into this repo under `docs/cip/` (history preserved). |

## The feature, in one paragraph

Canton meters usage as *traffic* and today only the Global Synchronizer sells it: a validator
burns Canton Coin (CC) via `AmuletRules_BuyMemberTraffic`, which mints a `MemberTraffic` record,
and a Super-Validator trigger grants the purchased traffic on the sequencer. The CIP generalizes
this to **dedicated** (non-global) synchronizers: burn CC on the global sync **keyed by the
dedicated synchronizer's id**, and that synchronizer's **operator** grants the purchased traffic
on its own sequencer. The MVP is no-discount; later workstreams add per-synchronizer pricing,
transaction-class discounts, staking/commitment, and an operator reward model. See
`docs/design/extension-traffic-manager.md` (implementation design), `docs/cip/` (the CIP
writeups), and `docs/planning/extending-mainnet-work-plan.md` (the work breakdown).

## What's in this repo

```
AGENTS.md           Agent-facing index: sibling projects + navigation (start here)
splice/             Submodule -> ChainSafe/splice fork = THE CODE
                    (Daml daml/ + token-standard/, Scala apps/, TS frontends, vendored Canton canton/, Helm cluster/)
docs/               Architecture + design + CIP + plan
  architecture.md     how the pieces fit (map)
  design/             our implementation design for the dedicated-sync feature
  cip/internal/       CIP writeups: technical plan, kickoff, exec summary, diagrams, presenter notes
                      (merged from the archived canton-cip-docs)
  planning/           epics/issues across both repos
  localnet.md         LocalNet + e2e guide
history/            Historical records
  rfcs/               RFC-001 nixos-deploy, RFC-002 agent-apis, RFC-003 telemetry
  meetings/           decision notes
  experiments/  incidents/  CHANGELOG.md
scripts/            One-command LocalNet harness (up/down/e2e, multi-sync)
tools/              Agent-navigation helpers (navigator.sh; RFC-002)
deploy/             NixOS deployment specs (skeleton; RFC-001)
telemetry/          Observability (skeleton; RFC-003)
sync-pricing/       Parked off-ledger pricing engine + conversion harness (pure Daml)
```

## Getting started

**LocalNet** (needs Docker; raise its RAM to ~10 GB for multi-sync). Drives the `splice/` submodule
by default (override with `SPLICE_DIR=...`):
```
scripts/localnet-up.sh      # then: scripts/localnet-e2e.sh   ;   tear down: scripts/localnet-down.sh
```
Full guide: `docs/localnet.md`.

**Shadow pricing engine** (Daml SDK 3.4.8, no Splice dependency):
```
cd sync-pricing && daml test    # 14 scripts, all green
```

## Status

- **Done:** shadow pricing engine + conversion harness (green, grounded against live LocalNet
  values); one-command multi-sync LocalNet harness (verified end-to-end).
- **Drafted (unverified):** the Daml PoC — `RegisteredSynchronizer` + governance registration and
  `AmuletRules_BuyDedicatedSyncTraffic` + `DedicatedSyncTraffic` — as fork PRs #1/#2. Not yet
  compiled (needs the Nix dev shell).
- **Next:** Nix dev env → compile + test the PoC (fork) → LocalNet register→buy→grant e2e → the
  Scala reconcile/operator automation.

## Notes on the pricing engine (parked)

`sync-pricing/` validated the CIP math off-ledger **before** touching on-ledger schema. It is a
reference artifact, not on the implementation path — the MVP reuses Splice's existing
`computeSynchronizerFees` + `splitAndBurn` unchanged (no discounts). One finding is worth
carrying forward regardless: the CIP's Section 6.2 duration factor `Di * D^log2(d)` does **not**
reproduce its own Section 5 table; `Di * (1 - D)^log2(d)` (a 25% incremental discount per
doubling) does. This is encoded as a passing test (`Test/Section5Table.daml`) and tracked to raise
with Digital Asset.

## Grounding

Claims are verified against real `canton-network/splice` and `digital-asset/canton` source:
`computeSynchronizerFees` (round `trafficPrice` takes precedence over config `extraTrafficPrice`),
`splitAndBurn` mints a `ValidatorRewardCoupon`, `SynchronizerFeesConfig` in
`DecentralizedSynchronizer.daml`, and Canton's `EventCostCalculator` for the byte-cost formula.
Docs style: direct language, no em/long dashes.
