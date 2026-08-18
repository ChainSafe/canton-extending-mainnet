# Phase 3 — Full Pricing Model

> Design-level milestone. Refined into filed issues when Phase-2 lands and the CIP's
> Phase-3 parameters ratify. Target per CIP draft: ~mid-2027.

## Goal

The competitive synchronizer market: transaction-class pricing tiers, volume/duration/
utility discounts, commitments backed by staking, the temporary org-internal cap — and
dedicated-sync activity participating in app-reward distribution, closing the
net-cost gap deliberately left open in Phase 2.

## Scope (per the FR table and CIP v0.3)

| Area | Requirement |
|---|---|
| Transaction classes | Declared per purchase, SV-verifiable: composed / app-internal / org-internal (FR-11, FR-28) |
| Pricing tiers | 200¢ composed / 150¢ app-internal / 10¢ org-internal per typical tx; gsync stays 100¢ (FR-11, FR-12) |
| Discount curves | Throughput, duration, utility — multiplicative on the tier rate (FR-14..FR-17) |
| Commitments & staking | Committed rates backed by a bond; shortfall draws forced purchases; termination burns (FR-18..FR-22) |
| Org-internal cap | $1m / 12 months incl. flat fee; lifts automatically ~2 years after Phase 3 (FR-23, FR-24) |
| App rewards | Reward eligibility at usage; per-app attribution from dedicated syncs; pools/split unchanged, no operator pool (FR-25, FR-26) |
| Outage settlement | Consumption-data-driven settlement of FR-3 negative balances (FR-3 now P2-labeled; ownership and phase reality unresolved — see phase-2.md dependencies) |

## Epics

See [phase-3-epics.md](phase-3-epics.md): P3-E1 transaction-class characterization,
P3-E2 tiered per-synchronizer pricing, P3-E3 discount curves, P3-E4 commitments &
staking, P3-E5 org-internal cap, P3-E6 app-reward distribution for dedicated syncs,
P3-E7 outage settlement.

## Phase-2 sockets this builds on

- Rate pipeline: tiers/curves compose inside the single rate function (P2-E4.3).
- Purchase records: tier id + per-discount factors + reward-eligibility flags append to
  the FR-9 pricing fields (P2-E2.3).
- Staking reuses the fee-state pattern — state contract, pull payment, proportional
  advance (P2-E3.1).
- Reward reporting extends the consumption-report contract with per-app activity records
  and commitment trees (P2-E6.1).

## Open design questions (settle before build)

1. **Distribution basis for app rewards across synchronizers**: activity records vs burn.
   With Phase-3 discounts, burn-per-record diverges across syncs; unweighted
   records-proportional distribution would let heavily discounted traffic mint the same
   rewards for a fraction of the burn (reward/burn arbitrage). Candidate resolution:
   burn-weighted records — distribute the pool per reward-eligible CC burned, use records
   only for attribution within a synchronizer. Belongs in CIP OQ-2.
2. **Fee/traffic stockpiling**: buy a year of traffic while fee-current, lapse, keep
   operating. Phase-2 accepts it; does Phase 3 need enforcement escalation (e.g., traffic
   grants contingent on fee runway)?
3. **Enforcement depth**: buy-gate economics (Phase 2) vs participant-level refusal to
   transact with lapsed/offboarded syncs (stronger, invasive). Where does Phase 3 land?
4. **Class verification**: how SVs verify declared transaction classes without seeing
   private traffic (FR-28's detectability boundary).
