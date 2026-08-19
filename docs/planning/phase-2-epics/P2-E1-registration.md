# P2-E1 — On-ledger registration & governance

> Milestone: [Phase 2](../phase-2.md) · GitHub: not filed

The DSO maintains an on-ledger registry mapping a dedicated synchronizer id to its Sync
Operator (SO) party. Registration is the authorization anchor for everything downstream:
the buy gate, fee binding, discount, reconciliation, and reporting all key off it. The
registry must be publicly readable (FR-1) and governance must hold an offboard lever
(FR-2). Splice surface: new template in `splice-amulet` (or `splice-dso-governance`),
vote actions in `DsoRules`.

---

## P2-E1.1 — Decision: registration authorization model (vote vs self-service)

**Context.** FR-1 (relabeled P1→P2 on 2026-08-17/18) says a synchronizer is registered by
its SO party *without* an SV vote, publicly readable — making this an MVP-scope decision. The CIP's governance posture and FR-2's offboard lever suggest
the DSO stays in the loop. These compose two candidate models: (a) SV-vote-gated create
(`SRARC_RegisterSynchronizer`), or (b) operator self-service create with governance
holding only offboard. The choice moves authorization, uniqueness, and spam-control
design.

**Deliverable.** Decision recorded with DA (design-doc thread), captured here, and
P2-E1.3 re-scoped accordingly.

**Acceptance.** A written answer from DA on FR-1's intent for the on-ledger registry;
P2-E1.2/E1.3 bodies updated; uniqueness story (P2-E1.4) consistent with the answer.

**Depends on.** Nothing — raise immediately; blocks P2-E1.3 finalization only.

**Refs.** FR-1, FR-2; design doc "Register the dedicated synchronizer".

## P2-E1.2 — `RegisteredSynchronizer` template + public read path

**Context.** The registry entry: synchronizer id, SO party, DSO signatory. Contract id
stability matters — downstream vote actions pin contract ids at proposal time, so the
registration must not churn on unrelated activity (mutable operational state lives in
sibling contracts, never on the registration itself).

**Deliverable.** `RegisteredSynchronizer` template (DSO signatory, `synchronizerId`,
`operator : Party`), fetch path usable by any party via disclosed contracts, and a
stable-id policy documented on the template: the registration archives only on offboard.

**Acceptance.** Daml Script tests: create, public fetch via disclosure, id/operator
fields immutable; a mutable-state sibling can be recreated without touching the
registration's contract id.

**Depends on.** P2-E1.1 for the create-authorization shape (template itself is invariant).

**Phase-3 foundation.** Discount (P2-E4) and any Phase-3 per-sync pricing config attach as
siblings keyed by `synchronizerId`, preserving cid stability.

**Refs.** FR-1, FR-2.

## P2-E1.3 — Governance actions: register and offboard

**Context.** Whatever P2-E1.1 decides for create, offboard is a vote in all models
(FR-2): the DSO must be able to eject a misbehaving synchronizer. Offboard archives the
registration only — operational residue (fee state, report state) becomes inert and is
cleaned up by DSO automation via implicit signatory archival, avoiding vote-blocking on
churning contract ids.

**Deliverable.** `DsoRules` action(s): `SRARC_RegisterSynchronizer` (if vote-gated) and
`SRARC_OffboardSynchronizer`. Offboard matches on operator AND synchronizer id.

**Acceptance.** Daml Script tests: register (per decided model); offboard archives the
registration and nothing else; post-offboard buy attempts fail at the gate; duplicate
registrations are individually offboardable (recovery path).

**Depends on.** P2-E1.1, P2-E1.2.

**Refs.** FR-1, FR-2.

## P2-E1.4 — Registry uniqueness

**Context.** Daml has no unique keys across this shape; on-ledger consume-once registries
add churn and vote-blocking. Uniqueness is enforced off-ledger at proposal/creation time,
with offboard as the recovery path for a duplicate that slips through.

**Deliverable.** Duplicate check in the SV UI / proposal tooling (vote-gated model) or in
the operator onboarding tooling (self-service model); documented recovery: offboard the
duplicate.

**Acceptance.** Attempting to propose/create a duplicate `synchronizerId` is rejected in
tooling with a clear message; test covers the recovery flow.

**Depends on.** P2-E1.1, P2-E1.3.

## P2-E1.5 — Migration-id policy for dedicated synchronizers

**Context.** Migration ids are a gsync legacy (hard-migration counter). Dedicated
synchronizers upgrade via LSU and never hard-migrate, so purchases for them pin
`migrationId = 0` permanently. Ingestion and stores must not filter dedicated-sync
records by the gsync's current migration id — the gsync migrating must not orphan
dedicated-sync state.

**Deliverable.** `migrationId == 0` enforced for registered-sync purchases at the buy
gate; store/ingestion paths that filter on migration id are audited to exempt
registered-sync records.

**Acceptance.** Daml Script: non-zero migration id for a registered sync is rejected.
Scala: store tests prove registered-sync purchases survive a simulated gsync migration.

**Depends on.** P2-E1.2; coordinates with P2-E2.1 (gate) and P2-E7.1 (ingestion).

**Refs.** design doc "Upgrading via LSU".
