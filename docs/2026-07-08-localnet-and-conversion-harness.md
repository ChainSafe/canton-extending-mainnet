# LocalNet bring-up + cents/tx-to-bytes conversion harness

Progress summary, 2026-07-08. Standalone project **canton-extending-mainnet**
(ChainSafe's implementation work for the Canton CIP "Extending Mainnet:
Tokenomics Alignment Across the Entire Canton Network").

## Why we are doing this

The CIP generalizes Canton's single Global-Synchronizer traffic-purchase +
Burn-Mint flow into per-synchronizer, per-transaction-class, discount-curve,
optionally-staked pricing across all extension synchronizers. Before touching
any on-ledger schema, we are building a **shadow-mode pricing engine**: pure
off-ledger Daml that reproduces the CIP's math and can be checked against the
real protocol.

For that shadow engine to be credible it has to speak the same units the live
protocol speaks. The CIP prices a transaction in **USD cents** (per class, per
sustained TPS, per commitment length). The live Canton/Splice protocol prices a
transaction in **bytes of synchronizer traffic**, which are then converted to
USD and to Canton Coin (CC / Amulet). This session did two things:

1. Stood up a real Splice network locally and **confirmed the actual
   traffic-purchase + burn-mint flow runs**, so we have live, trustworthy numbers.
2. Built and tested a **conversion harness** that bridges cents/tx <-> bytes <->
   CC, grounded in the real Canton and Splice source and validated against the
   live numbers from step 1.

## The conversion chain (the core idea)

A transaction's cost travels through three stages. All three are faithful ports
of real source, not invented formulas:

```
  transaction  --(1)-->  bytes  --(2)-->  USD  --(3)-->  Canton Coin (CC)
```

1. **transaction -> bytes** ` Canton EventCostCalculator` (protocol v34+),
   integer arithmetic. For each envelope in the batch:
   - `writeCost = payload size in bytes`
   - `readCost  = floor(writeCost * recipients * scalingFactor / 10000)`
   - `finalCost = writeCost + readCost`

   and the event cost is `sum(finalCost) + baseEventCost`. `scalingFactor` is the
   `readVsWriteScalingFactor` (parts per 10,000). Source:
   `splice/canton/community/base/src/main/scala/com/digitalasset/canton/sequencing/traffic/EventCostCalculator.scala`.

2. **bytes -> USD** ` Splice computeSynchronizerFees`:
   `usd = bytes / 1e6 * extraTrafficPrice` (bytes/1e6 = megabytes;
   `extraTrafficPrice` is $/MB). The open mining round's `trafficPrice` takes
   precedence over the config `extraTrafficPrice` when set. Source:
   `splice/daml/splice-amulet/daml/Splice/AmuletRules.daml:1719`.

3. **USD -> CC** ` same function`: `amulet = usd / amuletPrice`, where
   `amuletPrice` ($/CC) comes from the open mining round.

The CIP formula given in the plan, `byteSize * (1 + recipients *
readVsWriteScalingFactor/10000) + baseEventCost`, is the single-envelope,
real-valued form of stage 1. The on-ledger truth **floors** the read cost per
envelope; the harness matches that integer semantics exactly (it matters: at the
live scaling factor of 4, a 1000-byte single-recipient message has
`floor(1000*1*4/10000) = 0` read cost).

## Part 1: Splice LocalNet, verified

Brought up the full Docker LocalNet stack for Splice 0.6.11 (pinned submodule at
`splice/`). Images pull from `ghcr.io/digital-asset/decentralized-canton-sync/`
by `IMAGE_TAG`; no build step.

Command (from `splice/cluster/compose/localnet/`, with `LOCALNET_DIR=$PWD`,
`IMAGE_TAG=0.6.11`, `PARTY_HINT=cs-localnet-1`):

```bash
docker compose --env-file $LOCALNET_DIR/compose.env \
               --env-file $LOCALNET_DIR/env/common.env \
               -f $LOCALNET_DIR/compose.yaml \
               -f $LOCALNET_DIR/resource-constraints.yaml \
               --profile sv --profile app-provider --profile app-user up -d
```

**Result: 11/11 containers healthy in ~1-2 minutes.** LocalNet runs all three
participants inside one `canton` container and all three validators inside one
`splice` container (ports fan out 4xxx=sv / 3xxx=app-provider / 2xxx=app-user),
which is why the whole stack fits comfortably in the constrained Docker VM.

**Resource footprint** (against a 7.7 GiB Docker allocation): about **4.8 GiB**
used at steady state, so no need to drop profiles.

| Container | Memory | Limit |
| --- | --- | --- |
| canton | 2.34 GiB | 4 GiB |
| postgres | 1.12 GiB | 2 GiB |
| splice | 1.23 GiB | 3 GiB |
| web UIs + nginx | < 150 MiB total | small |

### The traffic-purchase + burn-mint flow fired on its own

The validators are configured (`env/splice.env`) with
`TARGET_TRAFFIC_THROUGHPUT=20000` and `MIN_TRAFFIC_TOPUP_INTERVAL=1m`, so each
validator auto-tops-up traffic. Within ~40 seconds of the stack going healthy,
the full loop ran for both the app-user and app-provider validators, with no
manual trigger. From the splice logs:

1. `TopupMemberTrafficTrigger` fires and enqueues a `CO_BuyMemberTraffic` op to
   buy **1,200,000 bytes** of traffic on `global-domain`.
2. `TreasuryService` executes the batch, exercising **`AmuletRules_BuyMemberTraffic`**
   on-ledger.
3. In the same transaction: `AmuletRules_DevNet_Tap` taps 4000.8 CC, then
   `AmuletRules_BuyMemberTraffic` spends **-4000.8000000000 CC**.
4. `splitAndBurn` mints a **`ValidatorRewardCoupon`** (payload `Numeric 4000.8`,
   round 1).
5. Outcome `COO_BuyMemberTraffic(...)`: "Successfully bought extra traffic".
6. On the SV side, `ReconcileSequencerLimitWithMemberTrafficTrigger` calls
   **`SetTrafficPurchased`** on the sequencer admin API (`succeeded(OK)`), so the
   sequencer's traffic limit is reconciled.

This is exactly the `AmuletRules_BuyMemberTraffic -> splitAndBurn ->
MemberTraffic -> SetTrafficPurchased` path the plan set out to exercise.

### Live config, read from the running node

Pulled from the Scan API (`http://scan.localhost:4000/api/scan`) of the running
stack:

| Parameter | Live value | Source |
| --- | --- | --- |
| `extraTrafficPrice` | $16.67 / MB | AmuletRules config (`/v0/dso`) |
| `readVsWriteScalingFactor` | 4 (per 10,000) | AmuletRules config |
| `minTopupAmount` | 200,000 bytes | AmuletRules config |
| `amuletPrice` | $0.005 / CC | open mining round |
| round `trafficPrice` | null (so config wins) | open mining round |
| `baseEventCost` | 0 | Canton sequencer default; LocalNet does not override |

These reproduce the observed buy exactly:
`1,200,000 / 1e6 * $16.67 = $20.004`, and `$20.004 / $0.005 = 4000.8 CC`.

## Part 2: the conversion harness

New pure-Daml code in the `sync-pricing` package (no Splice dependency, same as
the existing shadow engine):

- **`daml/TrafficConversion.daml`** the harness. Ports of `EventCostCalculator`
  (`envelopeReadCost`, `envelopeCost`, `eventCostBytes`) and
  `computeSynchronizerFees` (`bytesToUsd`, `usdToAmulet`, `bytesToUsdCents`,
  `effectiveTrafficPrice`), an end-to-end `txCost`, and the inverse direction
  (`usdCentsToBytes`, `usdCentsToAmulet`) plus a bridge to the CIP curve in
  `SyncPricing.daml` (`cipPriceBytes`, `cipPriceAmulet`) which answers "if the
  CIP says this tx should cost N cents, how many traffic bytes / CC is that under
  today's protocol pricing?".
- **`daml/Test/TrafficConversionTest.daml`** the ground-truth test.

One Daml note worth recording: this SDK (3.4.8) does not expose integer `div` for
`Int`, so the flooring read-cost division is done as
`truncate (intToDecimal product / 10000.0)`. The product fits in Int64 and
`product/10000` has at most 4 decimals, so the Decimal division is exact and
`truncate` (toward zero, = floor for non-negatives) reproduces Canton's Long
division bit-for-bit.

### Results: all tests green

`daml test` runs **14 scripts, all passing** (8 pre-existing Section 5 curve
tests + 6 new conversion tests):

| Test | What it pins |
| --- | --- |
| `testEventCostVectors` | Canton's own `EventCostCalculatorTest` vectors: `(5B, 2 recip, mult 5000) -> finalCost 10`; `(25000B, 500 recip, mult 200) -> 275000`; `baseEventCost 350 + 10 -> 360` |
| `testLiveFlooring` | Integer floor at the live scaling factor of 4 (unicast pays 0 read cost, broadcast does not) |
| `testLiveBuyReproduction` | **Reproduces the observed on-ledger buy exactly: 1,200,000 bytes -> $20.004 -> 4000.8 CC** |
| `testRoundPricePrecedence` | Round `trafficPrice` overrides config `extraTrafficPrice` when set |
| `testInversionRoundTrip` | cents <-> bytes and cents -> CC invert cleanly |
| `testCipBridge` | CIP class prices map to traffic bytes/CC (Regular 100c = 200 CC = ~59,988 bytes at the live price; OrgInternal 10c = 20 CC) |

Reproduce with:

```bash
cd sync-pricing
daml build      # compile to DAR
daml test       # 14 scripts, all green
```

## Where this fits, and what is next

The shadow engine (`SyncPricing.daml`) now has a validated bridge to the real
metering mechanism. We can take any real transaction shape (envelope sizes +
recipient counts), compute what the live protocol charges, and compare it to what
the CIP discount curve says it *should* charge, all in the same units, with the
conversion pinned to numbers observed on a running node.

Still off-ledger and gated on answers from Digital Asset:

- Wire per-synchronizer pricing into `AmuletConfig` (a schema change: it is a
  single config today, not a per-synchronizer map).
- The commitment-stake + coupon-free shortfall burn.
- The report-to-mint path.

## Files touched this session

- `sync-pricing/daml/TrafficConversion.daml` (new)
- `sync-pricing/daml/Test/TrafficConversionTest.daml` (new)
- `CLAUDE.md` (status + layout updated)
- `docs/2026-07-08-localnet-and-conversion-harness.md` (this file)
