# P2-E3 — Flat platform fee

> Milestone: [Phase 2](../phase-2.md) · GitHub: not filed

Phase 2 replaces enterprise license fees with a flat, USD-denominated yearly platform fee
per dedicated synchronizer (FR-10), pro-rated, paid in CC, purely deflationary (never
reward-eligible), and enforced at the buy gate. Design basis: the accepted "Flat
Synchronizer Fee" design (Sadiq, 2026-08; Itai concurring) — `paidThrough` time purchased
by burn, lapses billed not forgiven. Known accepted leak, tracked not solved here: an
operator can stockpile traffic while current, then lapse and operate on the stockpile;
mitigations belong to Phase 3 (enforcement escalation) if needed.

---

## P2-E3.1 — `SynchronizerFeeState` + pay choice

**Context.** Fee status is per-synchronizer mutable state: `paidThrough : Time`. It lives
in a sibling contract, not on `RegisteredSynchronizer` — the fee state churns on every
payment and must not destabilize the registration's contract id. Payment is pull-based
and permissionless: anyone may pay any amount at any time; time advances proportionally
(`amount / annualFee × 1 year`) **from the existing `paidThrough`**, so arrears are
consumed before future coverage accrues.

**Deliverable.** `SynchronizerFeeState` (DSO signatory, `synchronizerId`, `paidThrough`);
`AmuletRules_PaySynchronizerFee` converting CC at the current round's USD rate and
advancing `paidThrough`; the burn routed through a no-coupon sibling of the burn helper
(mints nothing, never reward-eligible).

**Acceptance.** Daml Script: pay from bootstrap (paidThrough = registration time), pay
partial (pro-rated advance), pay while lapsed (arrears first), overpay (future coverage),
fee burn mints no coupon of any kind, zero/negative amounts rejected.

**Depends on.** P2-E1.2.

**Phase-3 foundation.** The state-contract + pull-payment + proportional-advance pattern
is the shape for Phase-3 commitments/staking.

**Refs.** FR-10; flat-fee design doc.

## P2-E3.2 — Buy-gate fee enforcement

**Context.** Enforcement is economic: a synchronizer whose fee has lapsed cannot buy more
traffic. The gate takes the fee state as a second disclosed contract and binds it to the
registration by synchronizer-id equality — preventing satisfying the gate with sync A's
registration and sync B's healthy fee state.

**Deliverable.** Buy gate (P2-E2.1) additionally requires, for registered syncs:
disclosed `SynchronizerFeeState` with `feeState.synchronizerId ==
registration.synchronizerId` and `paidThrough >= now`.

**Acceptance.** Daml Script: current sync buys; lapsed sync rejected; cross-sync
fee-state swap rejected; fee paid mid-lapse restores buying.

**Depends on.** P2-E3.1, P2-E2.1.

**Refs.** FR-10, FR-28.

## P2-E3.3 — Fee configuration + governance

**Context.** The fee amount is network governance, not operator choice:
`synchronizerFeeUsdPerYear` on `AmuletConfig` (appended `Optional Decimal`; `None` =
feature off), changed via the existing config-vote machinery.

**Deliverable.** Config field + plumbing through config schema serialization; vote path
exercised in test; `None` semantics: fee gate inactive (Phase-1 compatibility and
kill-switch).

**Acceptance.** Config vote sets/updates the fee; `None` disables gate enforcement
without schema churn; pro-ration uses the value at payment time.

**Depends on.** P2-E3.1.

## P2-E3.4 — Fee state surfacing

**Context.** Operators and validators need to see fee status without ledger spelunking:
is this sync current, until when, what would restoring cost today.

**Deliverable.** Scan endpoint for fee state per registered sync (paidThrough, current CC
cost of a year at the latest round rate); operator-side CLI/console verb to pay.

**Acceptance.** Endpoint returns live state on LocalNet; pay verb executes an on-ledger
payment end to end.

**Depends on.** P2-E3.1; lands with P2-E7.

**Refs.** FR-10.
