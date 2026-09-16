# P2-E7 — Scan & observability

> Milestone: [Phase 2](../phase-2.md) · GitHub: #70

Public, funding-side visibility: registrations, fee states, per-synchronizer purchase
aggregates, and report/burn reconciliation are readable without operating a node.
Consumption details beyond the FR-27 aggregates stay private to the dedicated sync.

---

## P2-E7.1 — Index registrations

**Context.** Scan ingests and serves the registry: which synchronizers exist, their
operators and registration status. Ingestion must respect the
migration-id exemption for registered-sync records (P2-E1.5).

**Deliverable.** Scan store + endpoints: list registered synchronizers, get one (with fee
state); offboarded syncs marked, not hidden.

**Acceptance.** LocalNet: endpoints live; migration-simulation test proves registered
records survive.

**Depends on.** P2-E1.2, P2-E3.1.

## P2-E7.2 — Serve the registration for disclosure

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
per-member traffic balances vs limits.

**Deliverable.** Metrics in the operator app (P2-E5.2) + a reference dashboard; alert
rules for reconciliation stall, fee lapse approaching, report overdue.

**Acceptance.** Dashboard renders against LocalNet; each alert fires under its synthetic
condition.

**Depends on.** P2-E5.3, P2-E3.1, P2-E6.1.

## P2-E7.4 — `getMemberTrafficStatus` mispairs state for dedicated synchronizer ids

**Context.** The endpoint pairs two sources that only agree for the global synchronizer:
`actual` (consumed/limit) comes from the serving SV's own sequencer, while the synchronizer
id is a path parameter. Queried with a dedicated synchronizer id it returns the global
sequencer's actual state alongside the dedicated synchronizer's purchase total — HTTP 200,
plausible, wrong.

**Deliverable.** Gate the endpoint (explicit error for synchronizer ids the serving
sequencer does not serve) or supersede it for dedicated synchronizers via the
per-synchronizer endpoints, and record which.

**Acceptance.** A dedicated-synchronizer query yields an explicit error or a documented
redirect, pinned by a test.

**Depends on.** Coordinates with P2-E7.2. (Filed as #108.)

## P2-E7.5 — Per-synchronizer purchase aggregation

**Context.** Split out of P2-E7.2, which is now the disclosure endpoint only. This is the
totals half: purchased (and possibly burned) per registered synchronizer. Deliberately off
the rung that gates the buy path, because it needs a Flyway migration and the buy path does
not — the existing index leads with the member, so a per-synchronizer aggregate needs its
own, and burn figures are not index columns at all. Its one known consumer is the Phase-3
`purchasedTotal` attestation.

**Acceptance.** Purchased total per registered synchronizer in bytes, backed by an index
leading with the synchronizer; a recorded decision on whether a burned total is in scope.

**Depends on.** P2-E7.1. (Filed as #111.)
