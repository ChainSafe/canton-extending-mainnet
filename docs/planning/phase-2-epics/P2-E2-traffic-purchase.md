# P2-E2 — CC-funded traffic purchase

> Milestone: [Phase 2](../phase-2.md) · GitHub: not filed

Traffic on a dedicated synchronizer is funded by burning CC on the global synchronizer via
the existing purchase flow: `AmuletRules_BuyMemberTraffic` names the synchronizer id and
member, burns CC, and creates/merges a `MemberTraffic` record. This epic extends that flow
to registered dedicated synchronizers at unchanged (gsync) rates — the must-burn invariant
(FR-4): a participant's traffic balance on a dedicated synchronizer increases only via CC
burned on mainnet for that participant on that synchronizer. All changes are appended
`Optional`s (SCU-safe).

---

## P2-E2.1 — Buy gate: accept registered synchronizers

**Context.** Today the buy path authorizes only the global synchronizer's own ids
(`requiredSynchronizers`). It gains an alternative authorization: a disclosed
`RegisteredSynchronizer` whose `synchronizerId` matches the purchase's target. Gate
ordering is a contract: authorization is checked before economic floors (min-topup), so a
request that is wrong both ways fails with the authorization error.

**Deliverable.** `AmuletRules_BuyMemberTraffic` accepts an appended
`optRegisteredSynchronizer : Optional (ContractId RegisteredSynchronizer)`; disclosed
fetch, id match, `migrationId == 0` (P2-E1.5); unified input validation with the
authorization-before-floor ordering pinned by test.

**Acceptance.** Daml Script: registered-sync buy succeeds at gsync rates; unregistered
sync id fails; mismatched registration fails; existing gsync buys unaffected (no
regression in wallet suites); precedence test (wrong sync + below floor → authorization
error).

**Depends on.** P2-E1.2.

**Refs.** FR-4, FR-5, FR-6, FR-12.

## P2-E2.2 — Operator visibility: observer on `MemberTraffic`

**Context.** The dedicated synchronizer's operator must see purchases for its
synchronizer to reconcile them onto its sequencer (P2-E5) — without polling Scan or
trusting off-ledger feeds. The purchase record itself carries the operator as observer.

**Deliverable.** `MemberTraffic` gains appended `operator : Optional Party` +
`observer (optionalToList operator)`; the buy path populates it from the registration;
the merge choice asserts operator consistency and carries it. The existing
checked-fetch key semantics used by validator top-up state are preserved untouched.

**Acceptance.** Daml Script: operator sees purchases for its sync only; merge of records
with inconsistent operators rejected; gsync purchases carry `None` and are invisible to
operators.

**Depends on.** P2-E2.1.

**Refs.** FR-6, FR-8.

## P2-E2.3 — Purchase pricing record (recomputability)

**Context.** FR-9: every purchase must be recomputable by third parties — what price,
which discounts, what effective rate. In Phase 2 the values are near-trivial (gsync base
rate, at most the governance discount) but the *fields* must exist now so Phase-3 tiers
and curves change values, not schema.

**Deliverable.** Purchase records carry appended fields: effective USD/MB rate applied,
discount factor applied (1.0 default), and the round's CC/USD conversion used. Decide and
document: fields on `MemberTraffic` vs a purchase-record sibling (weigh merge semantics —
merged records must aggregate or list per-purchase pricing).

**Acceptance.** For any purchase, a third party can recompute burned CC from recorded
fields + public config; merge behavior for pricing fields defined and tested.

**Depends on.** P2-E2.1; feeds P2-E4.2 (discount records into these fields), P2-E7.2.

**Phase-3 foundation.** Tier id and per-discount factors append here later; reward
eligibility flags (FR-25) attach to the same record.

**Refs.** FR-9.

## P2-E2.4 — Wallet path: buy for a registered synchronizer

**Context.** Validator operators buy traffic through the wallet
(`CO_BuyMemberTraffic`). The wallet operation must carry the registration reference.
Daml 3.0 constraint: variants do not upgrade by adding fields to an existing constructor
— this is a new appended constructor on the wallet's operation variant, not a field
change.

**Deliverable.** New appended constructor (registered-sync buy) on the wallet operation
variant; wallet handler resolves and discloses the registration; existing constructor
untouched.

**Acceptance.** Wallet integration test: end-user buy for a registered sync lands a
`MemberTraffic` with operator observer; legacy constructor still exercisable.

**Depends on.** P2-E2.1, P2-E2.2.

## P2-E2.5 — Merge automation: operator-aware grouping

**Context.** SV automation merges `MemberTraffic` contracts to bound contract count. With
operator-carrying records in the mix, merge groups must partition by (member,
synchronizer, operator) so records for different syncs/operators never merge.

**Deliverable.** Merge trigger groups by the full key including operator; property test
over mixed populations.

**Acceptance.** Simulated mixed population (gsync + two dedicated syncs) merges within
groups only; totals preserved per group.

**Depends on.** P2-E2.2.
