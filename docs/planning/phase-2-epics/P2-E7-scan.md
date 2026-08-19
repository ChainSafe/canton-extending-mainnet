# P2-E7 — Scan & observability

> Milestone: [Phase 2](../phase-2.md) · GitHub: #70

Public, funding-side visibility: registrations, fee states, per-synchronizer purchase
aggregates, and report/burn reconciliation are readable without operating a node.
Consumption details beyond the FR-27 aggregates stay private to the dedicated sync.

---

## P2-E7.1 — Index registrations and fee states

**Context.** Scan ingests and serves the registry: which synchronizers exist, their
operators, registration status, fee `paidThrough`. Ingestion must respect the
migration-id exemption for registered-sync records (P2-E1.5).

**Deliverable.** Scan store + endpoints: list registered synchronizers, get one (with fee
state); offboarded syncs marked, not hidden.

**Acceptance.** LocalNet: endpoints live; migration-simulation test proves registered
records survive.

**Depends on.** P2-E1.2, P2-E3.1.

## P2-E7.2 — Per-synchronizer purchase aggregation

**Context.** The public economics: how much CC has been burned for traffic on each
dedicated synchronizer, at what effective rates (P2-E2.3 fields). This is the "settled
burn" leg of FR-27 reconciliation and the recomputability surface of FR-9.

**Deliverable.** Endpoint: per-sync purchase totals over time windows, with effective
rate/discount breakdown.

**Acceptance.** Totals match ledger truth on LocalNet across merge operations; discount
shows up in the breakdown.

**Depends on.** P2-E2.3.

**Refs.** FR-9, FR-27.

## P2-E7.3 — Operator metrics & dashboards

**Context.** Operating the loop needs: reconciliation lag (purchase seen → limit set),
per-member traffic balances vs limits, fee runway (`paidThrough - now`), report cadence
compliance.

**Deliverable.** Metrics in the operator app (P2-E5.2) + a reference dashboard; alert
rules for reconciliation stall, fee lapse approaching, report overdue.

**Acceptance.** Dashboard renders against LocalNet; each alert fires under its synthetic
condition.

**Depends on.** P2-E5.3, P2-E3.1, P2-E6.1.
