# P2-E8 — Deployment & operations

> Milestone: [Phase 2](../phase-2.md) · GitHub: #71

Everything an operator needs to stand up and run a dedicated synchronizer in the economy:
scripted bootstrap, permissioned-from-day-one, Helm packaging, upgrade runbook, and the
migration path for synchronizers that started in Phase 1.

---

## P2-E8.1 — Synchronizer bootstrapping

**Context.** How a dedicated synchronizer comes into existence: sequencer/mediator
bring-up, initial topology, dynamic parameters (incl. base rate 0), operator participant
dual-homing. Decide the app/console split: what the Sync Operator Node automates vs what
runs once through the Canton console.

**Deliverable.** Scripted, documented bring-up producing a synchronizer ready for
registration; consumed by the LocalNet topology (P2-E9.1) so tests and docs cannot drift.

**Acceptance.** One command (or documented short sequence) yields a functioning dedicated
sync on LocalNet; re-running is idempotent or fails cleanly.

**Depends on.** Nothing; feeds P2-E5.4, P2-E9.1.

## P2-E8.2 — Permissioned from day one

**Context.** Dedicated synchronizers start permissioned (`onboardingRestriction =
RestrictedOpen` at bootstrap). Splice exposes the switch on the gsync path only; the
dedicated-sync bring-up needs the equivalent. MVP: the operator permissions nodes
manually.

**Deliverable.** Bootstrap sets RestrictedOpen; operator flow (console verb or app
endpoint) to admit a participant; documented MVP limitation (manual admission) for DA
validation.

**Acceptance.** Un-admitted participant cannot join on LocalNet; admission flow admits;
restriction survives restart.

**Depends on.** P2-E8.1.

## P2-E8.3 — Helm charts + operator documentation

**Context.** The operator stack (operator app, sequencer, mediator, participant,
dashboards) ships as Helm charts with an operator guide covering bootstrap, registration,
fee payment, top-up config, reporting duties, and the offboard/recovery story.

**Deliverable.** Charts + guide; base rate and permissioning documented as dynamic
parameters (not chart values) with the bootstrap owning them.

**Acceptance.** Fresh cluster → running dedicated sync in the economy following only the
guide.

**Depends on.** P2-E5.2, P2-E8.1, P2-E8.2.

## P2-E8.4 — LSU upgrade runbook

**Context.** Dedicated synchronizers upgrade in place via LSU (no hard migrations, no
migration-id bumps — P2-E1.5). The runbook covers sequencer/mediator/participant upgrade
order, traffic-state preservation (limits survive), and reconciliation behavior across
the upgrade window.

**Deliverable.** Tested runbook; reconciliation trigger behavior during upgrade defined
(pause/resume, no double-grants).

**Acceptance.** LocalNet LSU exercise: traffic limits and fee/report state intact after
upgrade; reconciliation resumes cleanly.

**Depends on.** P2-E5.3, P2-E8.1.

## P2-E8.5 — Phase-1 → Phase-2 migration path

**Context.** A synchronizer running in Phase 1 (dedicated, no economy) must join Phase 2
without a rebuild: registration, fee state, discount, and reporting attach to an existing
synchronizer; bring-up performed in Phase 1 should already be permissioned and carrying
traffic-control parameters so the delta is purely on-ledger.

**Deliverable.** Documented migration: register existing sync → pay fee → flip base rate
per policy → enable reconciliation; Phase-1 bring-up guidance updated so new Phase-1
syncs are Phase-2-ready.

**Acceptance.** LocalNet scenario: sync bootstrapped "Phase-1 style" joins the economy
with no data loss and no re-bootstrap.

**Depends on.** P2-E1.3, P2-E3.1, P2-E5.3, P2-E8.1.

## P2-E8.6 — Air-gapped validators: standing attestation proxy (parking lot)

**Context.** Requirement from DA (2026-08-04): validators without open-internet access
need a proxy attesting that the dedicated synchronizer they use is in good standing;
assume at least one dual-connected validator, not all. Phase assignment unconfirmed —
parked here so it is tracked.

**Deliverable (when activated).** Design note: what "good standing" comprises
(registration active, fee current, reports on cadence), how the attestation is served and
verified offline.

**Acceptance.** Phase confirmed with DA; design note reviewed.

**Depends on.** P2-E3.1, P2-E6.1 (data sources).
