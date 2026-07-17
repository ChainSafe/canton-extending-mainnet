# canton-extending-mainnet

ChainSafe's working repo for implementing the Canton CIP **"Extending Mainnet: Tokenomics
Alignment Across the Entire Canton Network"** (Shaul Kfir, Digital Asset).

This repo is **not** the on-ledger code. It holds the **tooling, harnesses, analysis, and
planning** we build to *do* the implementation, plus the coordination with Digital Asset. The
actual Daml/Scala changes are contributed to the Splice fork. Two repos are in play (a third is now archived):

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
scripts/            One-command LocalNet harness (multi-sync, dedicated app-synchronizer)
  localnet-up.sh      bring up + wait healthy + discover synchronizer ids / DSO party
  localnet-e2e.sh     self-skipping smoke check (both syncs connected + CC tap)
  localnet-down.sh    tear down ( --wipe also drops volumes )
  localnet-common.sh  shared config + helpers
sync-pricing/       Shadow pricing engine + conversion harness (PARKED reference; pure Daml)
  daml/SyncPricing.daml          the CIP Section 6 discount curve
  daml/TrafficConversion.daml    cents/tx <-> bytes <-> CC conversion (ports Canton + Splice math)
  daml/Test/                     acceptance tests (reproduce the CIP Section 5 table + live buy)
docs/
  cip/internal/                         CIP design docs (technical plan, kickoff, exec summary,
                                        diagrams, presenter notes) - merged from the archived canton-cip-docs
  design/extension-traffic-manager.md   our implementation design for the dedicated-sync feature
  planning/extending-mainnet-work-plan.md  epics/issues across both repos
  localnet.md                           LocalNet + e2e guide
  meetings/                             decision notes
splice/             Splice pinned as a git submodule (reference / LocalNet source)
```

## Getting started

**LocalNet** (needs Docker; raise its RAM to ~10 GB for multi-sync). Drives a Splice tree at
`SPLICE_DIR` (default `/Users/s3b/Dev/splice`):
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
