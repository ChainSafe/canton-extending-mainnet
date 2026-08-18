# P2-E4 — Per-synchronizer governance discount

> Milestone: [Phase 2](../phase-2.md) · GitHub: not filed

The single Phase-2 pricing lever (FR-13): Super Validators can vote a discount on the
traffic price for a specific dedicated synchronizer — the governance bridge ahead of the
Phase-3 pricing model. No curves, no tiers, no operator self-service: one voted factor
per synchronizer.

---

## P2-E4.1 — Discount configuration + vote action

**Context.** The discount is per-synchronizer mutable governance state. Same cid-stability
reasoning as the fee: it lives where updates don't churn the registration — either a
config sibling keyed by `synchronizerId` or (if updates are rare enough to tolerate
recreate-on-vote) on the registration. Decide with the vote-blocking trade-off explicit.

**Deliverable.** Discount factor (0 < f ≤ 1, default 1) attached per registered sync; new
`SRARC_*` vote action to set/update it; bounds validated on-ledger.

**Acceptance.** Daml Script: vote sets factor; update replaces; out-of-bounds rejected;
absence = 1.0.

**Depends on.** P2-E1.2.

**Refs.** FR-13.

## P2-E4.2 — Buy path honors the discount

**Context.** The buy computes CC to burn from USD price × discount factor at the round's
conversion. The applied factor and effective rate are recorded on the purchase (P2-E2.3)
so the burn is recomputable.

**Deliverable.** Gate reads the discount (disclosed alongside registration + fee state),
applies it in rate computation, records factor + effective rate.

**Acceptance.** Daml Script: discounted buy burns proportionally less CC; recorded fields
recompute exactly; discount for sync A never applies to sync B; no discount → identical
to gsync rate.

**Depends on.** P2-E4.1, P2-E2.1, P2-E2.3.

**Refs.** FR-9, FR-13.

## P2-E4.3 — Single rate-computation function (Phase-3 socket)

**Context.** Phase 3 multiplies tiers and three discount curves into pricing. Phase 2
concentrates all rate math in one pure Daml function (base rate → factors → effective
rate) so Phase 3 changes one function and its inputs, not N call sites.

**Deliverable.** `computeTrafficRate` (or equivalent) as the only place effective rate is
derived; buy path and any UI/Scan estimation call it; documented as the Phase-3 extension
point.

**Acceptance.** Grep-level: exactly one rate derivation; unit tests over factor
composition; property: factor 1.0 reproduces current gsync pricing bit-for-bit.

**Depends on.** P2-E4.2.

**Phase-3 foundation.** Tier and curve factors compose here (FR-11, FR-14..FR-22).
