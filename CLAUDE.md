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
  daml/TrafficConversion.daml      cents/tx <-> bytes <-> CC conversion (EventCostCalculator + computeSynchronizerFees port)
  daml/Test/Section5Table.daml     acceptance test reproducing the CIP Section 5 table
  daml/Test/TrafficConversionTest.daml  ground-truth test (Canton vectors + live LocalNet buy reproduction)
splice/                          Splice pinned submodule (canton-network/splice @ 0.6.11, shallow):
                                   source (AmuletRules, DecentralizedSynchronizer, EventCostCalculator)
                                   + Docker LocalNet at splice/cluster/compose/localnet
```

## Common commands

```
cd sync-pricing
daml build                       # compile the pricing library to a DAR
daml test                        # run the acceptance tests (currently 14 scripts, all green)
```

## Status & next steps

- **Done:** shadow-mode pricing engine (off-ledger, pure Daml, no Splice dependency). Reproduces the CIP Section 5 table; encodes the Section 6.2 `(1 - D)` factor fix as an executable test; three tiers (100/30/10); extension-only throughput discount; smooth + tiered modes (recommend **tiered** on-ledger to avoid Numeric rounding drift).
- **Done:** Splice pinned as a shallow submodule at `splice/` (canton-network/splice @ **0.6.11**, commit `fd93f86`). LocalNet lives at `splice/cluster/compose/localnet` and pulls published images from `ghcr.io/digital-asset/...` by `IMAGE_TAG=0.6.11` (no build step).
- **Done:** brought up Docker LocalNet (full `sv`+`app-provider`+`app-user` stack, verified 2026-07-08) and observed the real `AmuletRules_BuyMemberTraffic` -> `splitAndBurn` (mints `ValidatorRewardCoupon`) -> `SetTrafficPurchased` flow fire with no manual trigger. Runs in ~4.8 GiB of the 7.7 GiB Docker allocation. See [[splice-localnet]] memory for the exact command + observed numbers.
- **Done:** cents/tx-to-bytes conversion harness (`TrafficConversion.daml`): faithful ports of Canton's `EventCostCalculator` (integer byte cost) and Splice's `computeSynchronizerFees` (bytes -> USD -> CC), plus the inverse (CIP cents/tx -> bytes/CC). Grounded by `TrafficConversionTest.daml`, which pins Canton's own unit-test vectors AND reproduces the live LocalNet buy exactly (1,200,000 bytes -> $20.004 -> 4000.8 CC at extraTrafficPrice=$16.67/MB, scaling=4, amuletPrice=$0.005/CC, baseEventCost=0, all read from the running Scan API).
- **Next / Later (gated on Digital Asset answers):** wire per-synchronizer pricing into `AmuletConfig` (a schema change — it is a single config today, not a map), the commitment-stake + coupon-free shortfall burn, and the report-to-mint path.

## Conventions

- Grounded in real Splice/Canton source: `computeSynchronizerFees` (AmuletRules.daml; round `trafficPrice` takes precedence over config `extraTrafficPrice`), `splitAndBurn` mints a `ValidatorRewardCoupon`, `SynchronizerFeesConfig` in DecentralizedSynchronizer.daml.
- Docs style (carried from canton-cip-docs): avoid em/long dashes; direct language.

## Git Commit Rules

Never include "Co-authored-by" or any reference to Claude/Anthropic in commit messages or pull requests.
