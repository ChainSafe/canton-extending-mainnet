# P2-E5 — Sync Operator Node & reconciliation

> Milestone: [Phase 2](../phase-2.md) · GitHub: #68

The operator-side runtime: a dual-homed deployment (participant on both the global and the
dedicated synchronizer) that watches on-ledger purchases for its synchronizer and turns
them into enforced sequencer traffic limits on the dedicated synchronizer
(`SetTrafficPurchased`), with the sequencer's free base rate set to zero so the burn is
the only source of capacity. Splice surface: the SV app's existing
reconciliation/merge/top-up triggers generalize; the operator node reuses them against its
own sequencer.

---

## P2-E5.1 — Reusable traffic-reconciliation trigger base

**Context.** The SV app already reconciles `MemberTraffic` into sequencer limits for the
global synchronizer. The logic is target-agnostic except for four things: target
synchronizer id, sequencer admin connection, purchased-total lookup, and the traffic-limit
offset. Extract a base parameterized on exactly those, so SV and operator apps are thin
subclasses.

**Deliverable.** Abstract trigger base in `apps/common` with the four hooks; SV subclass
preserves existing behavior, config keys, and metric labels; foreign-contract skip is a
local comparison (no per-contract RPC); a warn-once tripwire fires when the connected
sequencer does not serve the configured target (both in the skip path and the
target-vs-served mismatch path).

**Acceptance.** SV behavior byte-identical (existing suites); base unit-tested with a fake
connection; tripwire covered for both miswiring shapes.

**Depends on.** Nothing (pure refactor); P2-E5.3 consumes it.

## P2-E5.2 — Operator app skeleton

**Context.** The operator needs a long-running app (the Sync Operator Node): stores
ingesting `MemberTraffic` where it is observer (P2-E2.2), connections to its own
sequencer admin API, automation host, and config. Ingestion must not filter
registered-sync records by the gsync migration id (P2-E1.5).

**Deliverable.** App scaffold (config, stores, automation service, health), ingesting
operator-visible purchases and exposing them to triggers; deployable standalone.

**Acceptance.** On the two-sync LocalNet: app boots, ingests a purchase for its sync,
ignores foreign purchases; survives a simulated gsync migration without dropping
registered-sync records.

**Depends on.** P2-E2.2, P2-E1.5.

## P2-E5.3 — Reconcile purchases onto the dedicated sequencer

**Context.** The core loop: operator-observed purchased totals per member →
`SetTrafficPurchased` on the dedicated synchronizer's sequencer(s), idempotent and
monotonic. MVP assumes a single sequencer admin connection; the base's hook shape must
keep the BFT extension open (reconcile against every sequencer of the synchronizer).

**Deliverable.** Operator subclass of P2-E5.1 wired to P2-E5.2's store; documented BFT
extension point.

**Acceptance.** LocalNet e2e slice: buy on gsync → member's traffic limit rises on the
dedicated sequencer; repeat purchase merges and re-reconciles; restart-safe (no
double-grant); foreign members untouched.

**Depends on.** P2-E5.1, P2-E5.2.

**Refs.** FR-6, FR-8.

## P2-E5.4 — Dedicated sequencer base rate = 0

**Context.** With a non-zero free base rate the must-burn invariant is false. Base rate
is a dynamic synchronizer parameter (not a Helm value): set at bootstrap, verified at
runtime, alarmed on drift.

**Deliverable.** Bootstrap sets base rate 0 via dynamic synchronizer parameters; operator
app verifies on startup and periodically; deviation surfaces as an alert/metric.

**Acceptance.** LocalNet: member with zero purchases cannot sequence (beyond protocol
minimums); parameter drift triggers the alarm.

**Depends on.** P2-E8.1 (bootstrap flow).

**Refs.** FR-4.

## P2-E5.5 — Validator auto-top-up on dedicated synchronizers

**Context.** Validators keep traffic topped up automatically on gsync
(`TopupMemberTrafficTrigger` + `ValidatorTopUpState`). Validators homed on a dedicated
synchronizer need the same loop, buying against the registered sync (P2-E2.4 path),
pinning `migrationId = 0`, and preserving the existing checked-fetch key semantics of the
top-up state.

**Deliverable.** Top-up trigger generalized to a configured set of target synchronizers;
per-sync top-up state; fee-lapse behavior defined (skip + warn, do not crash-loop).

**Acceptance.** LocalNet: validator on the dedicated sync auto-tops-up through the wallet
path; gsync top-up unchanged; lapsed-fee sync → skip with warning, resumes when current.

**Depends on.** P2-E2.4, P2-E3.2.

## P2-E5.6 — Per-synchronizer validator top-up configuration

**Context.** There was nowhere to say "top up dedicated synchronizer X at N bytes/sec":
extra-synchronizer config carried only `(alias, url)`, while the config holding
`buyExtraTraffic` was singular and global-synchronizer shaped. Without it P2-E5.5's
fan-out had no input.

**Deliverable.** `buyExtraTraffic` on each extra-synchronizer entry, reusing the existing
type, plus a derived `topupTargets` accessor (global first, zero targets omitted). The
global synchronizer stays a distinguished field rather than becoming a map entry, because
several call sites rely on it being present and would turn into fallible lookups.

**Acceptance.** An extra synchronizer carries its own buy settings; existing entries parse
unchanged; `grpc-deadline` on an extra entry is rejected at load; Helm chart and schema
expose the key.

**Depends on.** None; consumed by P2-E5.5. (Filed as #110, merged in fork PR #28.)

## P2-E5.7 — Store partition generation for the operator app

**Context.** `SyncOperatorApp` constructs its store with a hardcoded partition id of 0
rather than the resolved network value. The reasoning holds for a dedicated synchronizer
(LSU, never a hard migration) and the ingestion filter is immune to the migration-id
mechanism because it pins `payload.migrationId == 0` directly — but the store reads a
*global-synchronizer* ledger whose generation can advance independently, and nothing
exercises that.

**Deliverable.** A store test at a non-zero network generation, plus a recorded decision on
whether the partition tracks the global synchronizer's generation or stays pinned, and
what happens to ingested offsets when that synchronizer hard-migrates.

**Acceptance.** The test exists and passes; the decision is written down.

**Depends on.** P2-E5.2. (Filed as #115.)

## P2-E5.8 — Traffic bought before a member joins is never granted

**Context.** The reconcile trigger fires once per `MemberTraffic` contract. If the member
has no traffic state on the dedicated sequencer yet — which is the case until its trust
certificate has been sequenced there — the trigger logs and marks the contract done.
Nothing revisits it, so that purchase is only honoured when the member buys again. Buying
traffic before joining is a natural onboarding order, so this is a real first-run trap.

**Deliverable.** Make the grant durable across a member that is not yet known: retry, or
re-drive from purchases when a member appears.

**Acceptance.** A purchase made before the member joins results in the granted balance once
it does, covered by a test.

**Depends on.** P2-E5.3. (Filed as #116.)
