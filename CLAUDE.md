# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

**canton-extending-mainnet** is ChainSafe's implementation work for the Canton CIP **"Extending Mainnet: Tokenomics Alignment Across the Entire Canton Network"** (Shaul Kfir, Digital Asset). It generalizes Canton's single Global-Synchronizer traffic-purchase + Burn-Mint flow into per-synchronizer, per-transaction-class, discount-curve, optionally-staked pricing across all extension synchronizers.

**This is a standalone project. It is NOT related to `canton-middleware`** (a separate ChainSafe repo). Do not reference, import from, or write to canton-middleware.

- **Design docs / analysis (source of truth):** the GitHub repo `ChainSafe/canton-cip-docs` (technical plan, kickoff, diagrams, external review memo). This repo is the *code*.
- **ChainSafe's role:** as a Super Validator and prospective extension-synchronizer operator, co-designing and piloting the CIP with Digital Asset.

## Stack

Match Splice's stack:
- **Daml** for on-ledger contracts (developed against Daml SDK **3.4.8**).
- **Scala/JVM** for apps + automation (later, matching Splice's SV/validator triggers).
- **Docker LocalNet** for local end-to-end testing (Splice's Docker-based local network).
- Splice source: `canton-network/splice` (mirror: `hyperledger-labs/splice`); Canton: `digital-asset/canton`.

## Layout

```
sync-pricing/                    Daml package: the shadow-mode pricing engine
  daml/SyncPricing.daml            the CIP Section 6 discount curve
  daml/Test/Section5Table.daml     acceptance test reproducing the CIP Section 5 table
splice/                          Splice pinned submodule (canton-network/splice @ 0.6.11, shallow):
                                   source (AmuletRules, DecentralizedSynchronizer, EventCostCalculator)
                                   + Docker LocalNet at splice/cluster/compose/localnet
```

## Common commands

```
cd sync-pricing
daml build                       # compile the pricing library to a DAR
daml test                        # run the Section 5 acceptance test (currently 8 scripts, all green)
```

## Status & next steps

- **Done:** shadow-mode pricing engine (off-ledger, pure Daml, no Splice dependency). Reproduces the CIP Section 5 table; encodes the Section 6.2 `(1 - D)` factor fix as an executable test; three tiers (100/30/10); extension-only throughput discount; smooth + tiered modes (recommend **tiered** on-ledger to avoid Numeric rounding drift).
- **Done:** Splice pinned as a shallow submodule at `splice/` (canton-network/splice @ **0.6.11**, commit `fd93f86`). LocalNet lives at `splice/cluster/compose/localnet` and pulls published images from `ghcr.io/digital-asset/...` by `IMAGE_TAG=0.6.11` (no build step).
- **Next:** bring up Splice **Docker LocalNet** (`splice/cluster/compose/localnet`; profiles `sv`/`app-user`/`console`; requires `IMAGE_TAG`, `LOCALNET_DIR`, `PARTY_HINT`); the validator auto-tops-up traffic every 1m (`TARGET_TRAFFIC_THROUGHPUT=20000`, `MIN_TRAFFIC_TOPUP_INTERVAL=1m`), which exercises the real `AmuletRules_BuyMemberTraffic` -> `splitAndBurn` -> `MemberTraffic` -> `SetTrafficPurchased` flow with no manual trigger. Then build the cents/tx-to-bytes conversion harness (`byteSize * (1 + recipients * readVsWriteScalingFactor/10000) + baseEventCost`).
- **Later (gated on Digital Asset answers):** wire per-synchronizer pricing into `AmuletConfig` (a schema change — it is a single config today, not a map), the commitment-stake + coupon-free shortfall burn, and the report-to-mint path.

## Conventions

- Grounded in real Splice/Canton source: `computeSynchronizerFees` (AmuletRules.daml; round `trafficPrice` takes precedence over config `extraTrafficPrice`), `splitAndBurn` mints a `ValidatorRewardCoupon`, `SynchronizerFeesConfig` in DecentralizedSynchronizer.daml.
- Docs style (carried from canton-cip-docs): avoid em/long dashes; direct language.

## Git Commit Rules

Never include "Co-authored-by" or any reference to Claude/Anthropic in commit messages or pull requests.
