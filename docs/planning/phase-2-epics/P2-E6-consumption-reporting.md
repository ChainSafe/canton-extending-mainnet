# P2-E6 — Consumption reporting (enforcement)

> Milestone: [Phase 2](../phase-2.md) · GitHub: not filed
>
> **Phase label contested.** FR-27/28 carry P2 labels, but FR-28's substance (declared
> rates/discounts/classes) is Phase 3, its P2 clause (no capacity without burn) is
> enforced by construction (base rate 0 + gated reconciliation), and the self-signed
> report cannot catch a lying operator — while every data consumer of the report
> (throughput discounts, reward bounds, FR-3 settlement) is Phase 3 or disputed.
> The design doc's own Appendix-B timeline includes no reporting item. Raised with DA;
> if confirmed P3, this epic merges into P3-E6's reporting foundation.
>
> **Component note:** the report-*submission* automation (reading the sequencer's traffic
> states, exercising the report choice on cadence) is Sync Operator Node functionality,
> hosted by P2-E5.2's app. The epic stays separate because its leaves span splice-amulet
> Daml (E6.1/E6.2) and Scan (E6.3), and because the contested phase label makes a
> severable epic cleaner to migrate wholesale if DA confirms P3.

The burn side of the economy is on-ledger and public; the consumption side happens on a
private synchronizer the SVs cannot see. FR-27 closes the loop: the SO party reports
aggregate consumption (total transactions, average TPS, total traffic consumed) over a
parametrized timeframe, signed on-ledger, reconcilable against settled burn. This is an
enforcement artifact (FR-28 — detectability + governance response), not a reward input;
it also becomes the data source for gsync-outage settlement (FR-3 — now P2-labeled, ownership unresolved).

---

## P2-E6.1 — Per-synchronizer report state + report choice

**Context.** Same state-contract pattern as the fee: a DSO-signed per-sync contract with
an operator-controlled report choice. "Signed by the SO party" = the operator exercises
the choice; the ledger is the signature. Reports append immutable snapshots (or emit
per-window report contracts) so history is auditable; the mutable accumulator, if any,
lives on the state contract whose id churn nothing votes on.

**Deliverable.** Report state template + `ReportConsumption` choice recording
`{windowStart, windowEnd, txCount, avgTps, trafficConsumed}`; monotonic window
enforcement (no overlaps, no gaps beyond the cadence policy).

**Acceptance.** Daml Script: report, sequential windows enforced, non-operator cannot
report, offboarded sync's state inert.

**Depends on.** P2-E1.2.

**Phase-3 foundation.** Per-app activity records and commitment trees (reward
distribution) append to this shape as new fields/choices — the Phase-3 reward reporting
extends, not replaces, this contract.

**Refs.** FR-27, FR-28.

## P2-E6.2 — Cadence parametrization + validation rules

**Context.** FR-27 says "a parametrized timeframe": the reporting window is network
config, not operator choice. Late/missing reports are themselves signals.

**Deliverable.** Window length as config (AmuletConfig or per-sync governance state);
on-ledger validation of window bounds against the config; staleness definition (a sync
whose last report is > N windows old is "silent") queryable.

**Acceptance.** Config change adjusts accepted windows; overdue detection exercised in
test.

**Depends on.** P2-E6.1.

## P2-E6.3 — Reconciliation view: reported consumption vs settled burn

**Context.** The report is only useful if someone compares it to burn. Phase 2 requires
the comparison to be *available* (audit view), with automated SV-side alerting as
stretch: consumed-to-date vs purchased-to-date per synchronizer, flagged when consumption
exceeds purchases beyond tolerance.

**Deliverable.** Scan (or SV app) view joining report history against summed
registered-sync purchases per synchronizer; discrepancy metric; documentation of the
governance response path (offboard vote, FR-2).

**Acceptance.** LocalNet: consume, report, view shows reconciled totals; synthetic
over-consumption shows a discrepancy.

**Depends on.** P2-E6.1, P2-E7.2.

**Refs.** FR-27, FR-28, FR-2.
