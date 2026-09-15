# Phase 2 — One Economy (MVP)

> **Release deadlines (2026-09-15).**
> - **Daml changes: release 0.10.0, cut 29 October 2026.** Anything touching `daml/` must be
>   merged and released by this cut; Daml is on the earlier train because participants vet and
>   upgrade packages ahead of the apps that use them.
> - **Backend and deployment changes: release 0.10.3, cut 20 November 2026.** Scala apps,
>   Scan endpoints, operator node, Helm charts and docs.
>
> Working back from the Daml cut, the on-ledger surface must be feature-complete ~2 weeks
> earlier to leave room for review, upgrade-compatibility checks and package-version
> reconciliation (#114).
>
> Design basis: current Splice, the design doc's Functional Requirements table and Appendix C
> user stories, and the CIP draft v0.3 three-phase rollout.

## Goal

A dedicated synchronizer participates in the Canton Coin economy on the same terms as the
global synchronizer: its traffic is funded by burning CC on the global synchronizer at
gsync rates and it can receive an SV-voted per-synchronizer discount. Everything is
additive to current Splice and self-paced for operators (FR-30).

## In scope

| Area | Requirement |
|---|---|
| Registration + governance | On-ledger `syncId → operator` registration by SV vote, offboard lever (FR-1, FR-2) |
| CC-funded traffic | Buy path gated on registration, operator-visible purchases, must-burn invariant (FR-4..FR-8) |
| Pricing records | Purchases carry effective rate + discount so third parties can recompute (FR-9) |
| Governance discount | SV-voted per-synchronizer discount — the Phase-2 bridge lever (FR-13) |
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
| [P2-E2](phase-2-epics/P2-E2-traffic-purchase.md) | CC-funded traffic purchase | 6 |
| [P2-E4](phase-2-epics/P2-E4-governance-discount.md) | Per-synchronizer governance discount | 4 |
| [P2-E5](phase-2-epics/P2-E5-operator-node.md) | Sync Operator Node & reconciliation | 8 |
| [P2-E7](phase-2-epics/P2-E7-scan.md) | Scan & observability | 5 |
| [P2-E8](phase-2-epics/P2-E8-deployment-ops.md) | Deployment & operations | 8 |
| [P2-E9](phase-2-epics/P2-E9-testing.md) | Testing & acceptance | 4 |

## Sequencing / critical path

```
P2-E1 (registration) ──► P2-E2 (buy) ──► P2-E5 (reconcile) ──► P2-E9.2 (e2e)
                              │
             P2-E4 (discount) ┘  (lands in the buy gate)
P2-E9.1 (two-sync LocalNet) — everything integration-level needs it
P2-E7 (Scan), P2-E8 (ops) — parallel tracks off the spine
```

The Daml spine (E1 → E2 → E4 gate work) is a single stack of schema-compatible
changes (appended `Optional` fields/args only — SCU-safe); land it as stacked PRs in that
order. E5 automation can start against the E2 shape as soon as the observer field exists.

## External dependencies & open decisions

- **FR-1 settled (2026-08-19)**: registration is vote-gated in Phase 2 per the design doc's
  Appendix C; non-voted self-registration is a Phase-3 item. #80 closed.
- **FR-3** (gsync-outage negative balances) was relabeled P1→P2 (2026-08-17/18), which
  puts it in MVP scope on paper — yet it appears in no timeline. Ownership (ledger team vs
  us) and phase reality need an explicit DA answer; P2-E6 consumption data feeds its
  settlement either way.
- **Rewards settled (2026-08-24)**: FR-25 to FR-28 are relabelled P3 ("all rewards are
  P3", Itai), so consumption reporting left this milestone with them.
- **Open**: whether the discount is applied on-ledger or by the operator app at grant time
  (Appendix C traffic story, steps 5 and 6 disagree) — gates P2-E4.2.
- **Package-version reconciliation with upstream (#114)** must be solved before the 0.10.0
  Daml cut: the fork and upstream currently mint colliding versions.
- CIP ratification timeline (public posting ~September).

## Phase-3 foundations checklist

Deliberate sockets Phase 2 must leave open (each owned by a leaf below):

- Purchase records carry `effectiveRate`/`discountApplied`/reward-eligibility fields even
  while trivially derivable (P2-E2.3) — Phase-3 tiers change *values*, not schema.
- One rate-computation function in the buy path (P2-E4.3) — Phase-3 multiplies in tier and
  curve factors there, nowhere else.
- `GovernanceParameters` on the registration is one record behind one vote action, so a
  Phase-3 parameter costs no new choice (merged in fork PR #35).
- All schema changes are appended `Optional`s or new constructors (Daml 3.0 variants do
  not upgrade — new constructor, never a field on an existing one).

## Exit criteria

1. On the two-sync LocalNet: register → buy traffic at the (optionally discounted) gsync
   rate → traffic enforced on the dedicated sequencer → consume → auto-top-up fires on its
   own.
2. A validator homed only on the dedicated synchronizer cannot transact without a purchase,
   and a purchase for an unregistered synchronizer id is rejected.
3. All flows demoable from Helm-deployed components with operator docs.
4. No modification to gsync behavior; all Daml changes SCU-safe against current Splice.
