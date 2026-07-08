# canton-extending-mainnet

ChainSafe implementation work for the Canton CIP **"Extending Mainnet: Tokenomics Alignment Across the Entire Canton Network"** (Shaul Kfir, Digital Asset). Design docs live in `ChainSafe/canton-cip-docs`; this repo is the code.

## Status

**Track A — shadow-mode pricing engine: done and green.** An off-ledger, pure-Daml implementation of the CIP Section 6 discount curve that reproduces the CIP Section 5 pricing table. No dependency on Splice — it validates the math before any on-ledger wiring.

Not yet started (need a Nix-based Splice dev environment; see below):
- Vendoring a working Splice (pinned) to build/run against.
- LocalNet smoke test of the real `AmuletRules_BuyMemberTraffic` -> `splitAndBurn` -> `MemberTraffic` -> `SetTrafficPurchased` flow.
- The cents/tx to bytes conversion harness (needs LocalNet to measure real sequenced byte costs).

## Layout

```
sync-pricing/                 Daml package: the shadow-mode pricing engine
  daml/SyncPricing.daml         the curve: PriceClass, SyncPricingConfig, priceCents
  daml/Test/Section5Table.daml  acceptance test: reproduces the CIP Section 5 table
```

## Build & test

Requires the Daml SDK (developed against 3.4.8).

```
cd sync-pricing
daml build      # compiles the pricing library to a DAR
daml test       # runs the Section 5 table acceptance test (8 scripts, all green)
```

## What the pricing engine establishes

- **Reproduces the CIP Section 5 table.** `priceCents cfg class tps years` returns the gross cents/tx. Tiered mode reproduces the tabulated points *exactly* (integer decade / doubling exponents, pure Decimal math); smooth mode uses `DA.Math` `exp`/`log` and matches within a 0.05c tolerance.
- **Fixes the Section 6.2 factor bug.** The CIP writes the duration factor as `Di * D^log2(d)`, which gives 12.5c at a 2-year commitment where the table needs 37.5c. The engine uses `Di * (1 - D)^log2(d)` (a 25% *incremental* discount per doubling), which reproduces the table. `testSection62FactorBug` asserts both the correct value and the buggy one, so the discrepancy is executable, not just prose.
- **Three tiers + extension-only throughput discount.** Base prices regular 100c / app-internal 30c / org-internal 10c; the throughput discount is forced to identity when `isExtensionSynchronizer = False` (the Global Synchronizer), matching CIP Section 6.1 and worked Example 4.
- **Smooth vs tiered.** Both are implemented behind `DiscountMode`. Recommendation for the eventual on-ledger version: **tiered**, to avoid Daml `Numeric` (10 dp) rounding drift from `exp`/`log`.

## Next steps (Track A remainder + Track B)

1. **Splice dev env (needs Nix).** Install Nix, add Splice as a pinned submodule (a released 3.5.x, not `main`), build the `splice-amulet` DAR, and bring up LocalNet. Splice's stack: Daml (on-ledger) + Scala/JVM (apps + automation) + TypeScript (frontends) + Nix/LocalNet (dev env).
2. **LocalNet smoke test.** Execute `AmuletRules_BuyMemberTraffic` and observe burn + `MemberTraffic` + `SetTrafficPurchased`.
3. **cents/tx to bytes harness.** Sequence a simple transfer vs a multi-party/DvP-style tx, read the actual byte cost (`byteSize * (1 + recipients * readVsWriteScalingFactor/10000) + baseEventCost`), derive per-class `avgBytesPerTx`, and write up the conversion (or "per-tx billing unit") note for the DA session.
4. **Later (post-DA):** wire per-synchronizer pricing into `AmuletConfig` (a schema change: `decentralizedSynchronizer` is a single config today, not a map), the commitment-stake + coupon-free shortfall burn, and the report-to-mint path. These are gated on the DA questions (GATE-1..5).

## Provenance / grounding

The curve and the upstream references were verified against the current `canton-network/splice` and `digital-asset/canton` source:
`computeSynchronizerFees` (AmuletRules.daml:1727; round `trafficPrice` takes precedence over config `extraTrafficPrice`), `splitAndBurn` mints a `ValidatorRewardCoupon` (AmuletRules.daml:2246), `SynchronizerFeesConfig` (DecentralizedSynchronizer.daml:36), and Canton's `EventCostCalculator` for the byte formula.
