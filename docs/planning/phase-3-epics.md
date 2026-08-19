# Phase 3 — Epics (design-level)

> Milestone: [Phase 3](phase-3.md) · Not filed. Leaf sketches only; each epic starts with
> a design note that cuts real issues.

## P3-E1 — Transaction-class characterization

Purchases (and eventually consumption reports) carry a declared class: composed /
app-internal / org-internal. Leaves: class declaration on the purchase path (appends to
P2-E2.3 fields); SV verification approach (detectability model, FR-28); class defaults
and dispute/reclassification governance. Refs: FR-11, FR-28.

## P3-E2 — Tiered per-synchronizer pricing

The 200/150/10¢ tier structure enters the rate pipeline. Leaves: tier schedule as
governed config (per-class USD rates, gsync pinned 100¢ — FR-12); rate function extension
(P2-E4.3 socket); per-synchronizer pricing schema if per-sync overrides survive design;
recomputability proof extended to tiers (FR-9). Refs: FR-11, FR-12.

## P3-E3 — Discount curves

Throughput, duration, and utility discounts, multiplicative on the tier rate. Leaves:
curve definitions as governed config; measurement inputs (throughput needs consumption
history — P2-E6 data); curve application in the rate function; anti-gaming bounds
(caps, floors, FR-14..FR-17). Refs: FR-14..FR-17.

## P3-E4 — Commitments & staking

Committed traffic rates backed by a staked bond (reuses the P2-E3.1 state pattern).
Leaves: commitment contract (rate, duration, bond); shortfall handling (bond draws as
forced purchases of committed traffic); termination (remaining bond burns, no credits);
bond top-up and return; interaction with discounts (duration discount presumes
commitment). Refs: FR-18..FR-22 (note: FR-18/19 numbering duplicated in the source
table — cite by text until fixed).

## P3-E5 — Org-internal cap

$1m per 12 months including the flat fee, per organization; automatic sunset (~2 years
after Phase 3, parametrized, no vote — FR-24). Leaves: cap accounting (whose burn counts,
org identity); cap enforcement at purchase; sunset automation; interaction with the
10¢ org-internal tier. Refs: FR-23, FR-24.

## P3-E6 — App-reward distribution for dedicated syncs

Dedicated-sync activity earns app rewards, closing the Phase-2 net-cost gap. Extends the
consumption-report contract (P2-E6.1) with per-app activity records under a commitment
scheme; SV-side integration mints via the CIP-104 RewardCouponV2 pipeline; operator-side
expansion automation; the vote-gated start-processing flow with attested purchase bounds.
Leaves cut after the distribution-basis question (burn-weighting, phase-3.md open
question 1) settles. Refs: FR-25, FR-26; CIP OQ-2.

## P3-E7 — Outage settlement

Implementation of FR-3's negative-balance settlement on reconnection, consuming P2-E6
consumption data — contingent on the ledger-team's Phase-1 delivery of negative traffic
balances. Leaves: settlement pricing (discounted per FR-3), grace-period config,
reconciliation-trigger behavior across outage windows. Refs: FR-3.
