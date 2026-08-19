# P2-E9 — Testing & acceptance

> Milestone: [Phase 2](../phase-2.md) · GitHub: #72

The integration substrate and the milestone's proof: a two-synchronizer LocalNet, the
end-to-end acceptance scenario that is Phase 2's exit criterion, and CI hygiene so the
suites gate every change.

---

## P2-E9.1 — Two-synchronizer LocalNet topology

**Context.** Nearly every integration test in this milestone needs: gsync (SV, Scan,
validator) + one dedicated synchronizer (own sequencer/mediator, dual-homed operator
participant, one homed validator). Build it once, early — it is the substrate for
P2-E2..E8 acceptance.

**Deliverable.** LocalNet profile with both synchronizers, wired to the bootstrap
scripts (P2-E8.1); fixture support in the Scala integration-test harness; developer doc.

**Acceptance.** CI job boots the topology and runs a smoke test (participant on each sync
can transact); fixture usable from a scalatest suite.

**Depends on.** P2-E8.1 (co-developed).

## P2-E9.2 — End-to-end acceptance scenario

**Context.** The milestone exit test, as one scripted scenario: bootstrap → register →
pay fee → vote discount → buy traffic (wallet path) → limit enforced on the dedicated
sequencer → consume → report consumption → reconciliation view squares report against
burn → fee lapses → buy blocked → arrears paid → buy restored → offboard → everything
inert.

**Deliverable.** Integration suite implementing the full arc, plus the negative
variants (unregistered buy, cross-sync fee swap, non-operator report).

**Acceptance.** Green on the two-sync LocalNet in CI; each exit criterion in
[phase-2.md](../phase-2.md) mapped to an assertion.

**Depends on.** Everything on the spine (P2-E1..E6); build incrementally as rungs land.

## P2-E9.3 — CI integration

**Context.** The suites above join the repo's CI with pragmatic sharding and log-gate
hygiene, so flake noise does not erode trust in the signal.

**Deliverable.** CI wiring for the two-sync jobs; canton-log ignore patterns audited for
the new components (version-agnostic patterns — no pinned patch versions); flake
quarantine process documented.

**Acceptance.** Suites run per-PR; a deliberate red fails the gate; one week of runs
with no infra-red requiring manual rerun.

**Depends on.** P2-E9.1, P2-E9.2.
