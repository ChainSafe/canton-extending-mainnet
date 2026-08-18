# Phase 2 — One Economy (MVP)

> Milestone target: **release cut end of October 2026** for MainNet before end of year
> (Itai, 2026-08-15). Design basis: current Splice (0.6.x, CIP-104 live), the design doc's
> Functional Requirements table, and the CIP draft v0.3 three-phase rollout.

## Goal

A dedicated synchronizer participates in the Canton Coin economy on the same terms as the
global synchronizer: its traffic is funded by burning CC on the global synchronizer at
gsync rates, it pays a flat platform fee, it can receive an SV-voted per-synchronizer
discount, and its consumption is reported and reconcilable against its burn. Everything is
additive to current Splice and self-paced for operators (FR-30).

## In scope

| Area | Requirement |
|---|---|
| Registration + governance | On-ledger `syncId → operator` registration, offboard lever (FR-1 pending clarification, FR-2) |
| CC-funded traffic | Buy path gated on registration, operator-visible purchases, must-burn invariant (FR-4..FR-8) |
| Pricing records | Purchases carry effective rate + discount so third parties can recompute (FR-9) |
| Flat platform fee | USD-denominated yearly fee, pro-rated, pure burn, buy-gate enforced (FR-10) |
| Governance discount | SV-voted per-synchronizer discount — the Phase-2 bridge lever (FR-13) |
| Consumption reporting | SO-party-signed totals, reconcilable against settled burn (FR-27, FR-28) |
| Operator node + reconciliation | Purchases become enforced sequencer traffic on the dedicated sync; base rate 0 |
| Ops | Bootstrapping, permissioned-from-day-one, Helm + docs, LSU runbook, P1→P2 migration |
| Test | Two-synchronizer LocalNet, end-to-end acceptance |

## Out of scope (Phase 3)

App-reward distribution for dedicated-sync activity (confirmed out 2026-08-17; FR-25/27
labels pending correction), pricing tiers (200¢/150¢/10¢), throughput/duration/utility
discount curves, commitments/staking, org-internal cap. Phase 2 lays their sockets — see
"Phase-3 foundations" below.

Known consequence, accepted: Phase-2 dedicated-sync burn is gross-cost-identical to gsync
but not net-cost-identical (gsync usage recirculates ~90% via rewards at BME; dedicated
usage nets 100% of gross until Phase 3). The CIP should state this explicitly.

## Epics

| Epic | Title | Leaves |
|---|---|---|
| [P2-E1](phase-2-epics/P2-E1-registration.md) | On-ledger registration & governance | 5 |
| [P2-E2](phase-2-epics/P2-E2-traffic-purchase.md) | CC-funded traffic purchase | 5 |
| [P2-E3](phase-2-epics/P2-E3-flat-fee.md) | Flat platform fee | 4 |
| [P2-E4](phase-2-epics/P2-E4-governance-discount.md) | Per-synchronizer governance discount | 3 |
| [P2-E5](phase-2-epics/P2-E5-operator-node.md) | Sync Operator Node & reconciliation | 5 |
| [P2-E6](phase-2-epics/P2-E6-consumption-reporting.md) | Consumption reporting (enforcement) | 3 |
| [P2-E7](phase-2-epics/P2-E7-scan.md) | Scan & observability | 3 |
| [P2-E8](phase-2-epics/P2-E8-deployment-ops.md) | Deployment & operations | 6 |
| [P2-E9](phase-2-epics/P2-E9-testing.md) | Testing & acceptance | 3 |

## Sequencing / critical path

```
P2-E1 (registration) ──► P2-E2 (buy) ──► P2-E5 (reconcile) ──► P2-E9.2 (e2e)
                              │
             P2-E3 (fee) ─────┤  (fee + discount both land in the buy gate;
             P2-E4 (discount) ┘   sequence E3 before E4 to keep gate churn linear)
P2-E9.1 (two-sync LocalNet) — start immediately; everything integration-level needs it
P2-E6 (reporting), P2-E7 (Scan), P2-E8 (ops) — parallel tracks off the spine
```

The Daml spine (E1 → E2 → E3 → E4 gate work) is a single stack of schema-compatible
changes (appended `Optional` fields/args only — SCU-safe); land it as stacked PRs in that
order. E5 automation can start against the E2 shape as soon as the observer field exists.

## External dependencies & open decisions

- **FR-1**: registration with or without SV vote (question raised on the design doc).
  Blocks the final shape of P2-E1.1/E1.3; the template design (P2-E1.2) is invariant.
- **FR-3** (gsync-outage negative balances) was relabeled P1→P2 (2026-08-17/18), which
  puts it in MVP scope on paper — yet it appears in no timeline. Ownership (ledger team vs
  us) and phase reality need an explicit DA answer; P2-E6 consumption data feeds its
  settlement either way.
- **FR-25 thread**: confirms whether any reward-eligibility *rule* work lands in P2
  (definition only) or all of it moves to P3. Currently assumed: all P3.
- Upstream Splice sync cadence for the feature branch; CIP ratification timeline (public
  posting ~September).

## Phase-3 foundations checklist

Deliberate sockets Phase 2 must leave open (each owned by a leaf below):

- Purchase records carry `effectiveRate`/`discountApplied`/reward-eligibility fields even
  while trivially derivable (P2-E2.3) — Phase-3 tiers change *values*, not schema.
- One rate-computation function in the buy path (P2-E4.3) — Phase-3 multiplies in tier and
  curve factors there, nowhere else.
- Fee-state pattern (state contract, `paidThrough`, pull payment) reusable for
  commitments/staking (P2-E3.1).
- Consumption-report state contract extensible by appended fields/choices to per-app
  activity records + commitment trees (P2-E6.1).
- All schema changes are appended `Optional`s or new constructors (Daml 3.0 variants do
  not upgrade — new constructor, never a field on an existing one).

## Exit criteria

1. On the two-sync LocalNet: register → pay fee → buy traffic at (optionally discounted)
   gsync rate → traffic enforced on the dedicated sequencer → consume → report → reported
   consumption reconciles against on-ledger burn.
2. A synchronizer that has not paid its fee cannot buy traffic; one that lapses can pay
   arrears and resume.
3. All flows demoable from Helm-deployed components with operator docs.
4. No modification to gsync behavior; all Daml changes SCU-safe against current Splice.
