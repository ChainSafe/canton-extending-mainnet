# Design Note: Dedicated Synchronizer Rewards (Operator Reward Model)

Status: Proposal; on-ledger half PoC-implemented on fork PRs
[#8](https://github.com/canton-network/splice-multi-sync/pull/8) and
[#12](https://github.com/canton-network/splice-multi-sync/pull/12) (awaiting DA review)

This note captures the reward model for dedicated synchronizers (the DA deck's standard term; the
code identifiers still say "extension"). It is the reward counterpart to the funding/grant design in
[extension-traffic-manager.md](extension-traffic-manager.md): that document covers how traffic on a
dedicated synchronizer is paid for (burn CC on the global synchronizer); this document covers how
the resulting activity earns rewards back to the operator and its users.

It belongs to Workstream 2, Epic E10 in the
[work plan](../planning/extending-mainnet-work-plan.md), broken down as issues #47 (Daml PoC,
implemented), #57 (SV-side automation), #58 (operator-side automation), plus #61 (trigger filter
defect). The funding path (Workstream 1) does not depend on it.

Sources, in order of authority: the DA deck
(https://dach-ny.github.io/presentation-extending-mainnet/) is the policy source of truth but is
silent on this mechanism; the shipped PoC code on fork PRs #8/#12 is the mechanism source; the
original DA "Reward Integration" notes are preserved verbatim in Appendix A so both can be audited
against the source. Code references are `file:line`; references into the PoC are marked "PR head"
(branches `multi-sync-poc-reward-reporting` / `multi-sync-poc-registration-lifecycle`, verified
2026-08-06); unmarked references are the pinned `splice/` submodule.

## 1. The core idea: a parallel entry into the CIP-104 reward machinery

The design does not invent a new minting mechanism. It reuses the CIP-104 reward-processing
machinery that already ships in Splice, adding a per-synchronizer dimension to it. One correction to
earlier drafts of this note: the extension flow does **not** run through `CalculateRewardsV2` and
`CRARC_StartProcessingRewardsV2`; it is a **parallel entry point** into the same `ProcessRewardsV2`
expansion tree, and `CalculateRewardsV2` is untouched.

Two facts frame the design:

- Activity on a dedicated synchronizer is not visible to the Super Validators (SVs). On the global
  synchronizer, CIP-104 derives app activity from mediator verdicts and sequencer traffic summaries,
  so every SV independently recomputes the round's Merkle root and confirms an exact match. The SVs
  do not run the dedicated sequencer or mediator, so no recomputation is available there: the
  activity must be self-reported by the operator and then **bounded, not verified**.
- The machinery that turns a Merkle tree of reward entries into coupons already exists on-ledger:
  `ProcessRewardsV2` tracks outstanding processing keyed by a `batchHash`;
  `ProcessRewardsV2_ProcessBatch` checks the supplied batch against the committed hash and either
  fans out child `ProcessRewardsV2` contracts (internal node) or creates one `RewardCouponV2` per
  `MintingAllowance` (leaf), with the amount denominated in CC
  (`RewardAccountingV2.daml:61,75,86,95`; `RewardCouponV2` lives in `Amulet.daml:425`).

The reward loop is global today: every round, coupon, and processing contract keys on the DSO party
and the round, never on a synchronizer. The only synchronizer-scoped state near the reward path is
`MemberTraffic` (`synchronizerId`, `totalPurchased`, `DecentralizedSynchronizer.daml:58`). The PoC
threads the synchronizer dimension in through new report-side contracts and three `Optional` fields
on `ProcessRewardsV2`, leaving the global path byte-for-byte unchanged when they are `None`.

## 2. Reporting model (implemented, PR #8)

Each dedicated synchronizer is represented by one party (`operator`; the notes say "a single
(decentralized) party", but nothing in the code enforces or models decentralization). Its reporting
state lives on a `DedicatedSynchronizerState` contract (PR head
`DecentralizedSynchronizer.daml:171`): `signatory dso`, `observer operator`, carrying
`lastReportedRound : Optional Round` and the running `totalActivityReported : Decimal`. The
"possibly in registry contract" alternative from the notes was rejected to keep
`RegisteredSynchronizer` stable; registration creates the state contract (PR #12), so a registered
synchronizer can report from day one.

The operator-controlled, consuming choice `DedicatedSynchronizerState_ReportActivity` (`:189`)
records a per-round report of `(round, activityRootHash, totalActivity)`:

- rounds must be strictly increasing (one report per round, no back-filling a skipped or timed-out
  round),
- the running total accumulates,
- a per-round `ExtensionActivityReport` contract (`:212`) is created for the SV side to act on.

`totalActivity` is a sum of activity weights (a `Decimal`), not a count of records. The root hash
commits to the weighted Merkle tree of per-provider activity (Section 3).

## 3. Report-to-mint (implemented, PR #8)

The flow from report to coupons:

1. An SV vote dispatches `CRARC_StartProcessingExtensionRewardsV2` (PR head `DsoRules.daml:99`,
   dispatch `:1834`) to `AmuletRules_StartProcessingExtensionRewardsV2` (PR head
   `AmuletRules.daml:761-803`). The choice consumes the `ExtensionActivityReport` and enforces three
   on-ledger gates:
   - the report must match a live `RegisteredSynchronizer` (same synchronizer id and operator,
     `:786`) so an offboarded synchronizer's pending reports are inert (this gate was added after
     review on PR #12 surfaced the offboarding hole);
   - `issuancePerActivityUnit` must be positive (`:783`), so a 0% rate is not expressible;
   - `report.totalActivity <= intToDecimal purchasedTotal` (`:789-790`), the reported-vs-purchased
     bound. `purchasedTotal : Int` is supplied by the vote (SV-attested), not fetched from
     `MemberTraffic` on-ledger.
2. The choice creates the root `ProcessRewardsV2` for the extension's tree with three `Optional`
   fields appended to the template (PR head `RewardAccountingV2.daml`): `expander : Optional Party`
   (`:86`) set to the operator, who becomes an observer (`:103`) and the
   `ProcessRewardsV2_ProcessBatch` controller (`controller fromOptional dso expander`, `:111`);
   `issuancePerActivityUnit : Optional Decimal` (`:91`); and `weightBudget : Optional Decimal`
   (`:95`) set to the reported total.
3. The operator expands its own tree (it holds the batch pre-images off-ledger). A new `Batch`
   variant `BatchOfWeightedBatches [WeightedBatchRef]` (`:56,64`) commits each internal node to its
   children's weights, and the budget is threaded down: every subtree's declared weights must fit
   within its budget, weighted and unweighted trees are mutually exclusive per path, and a leaf's
   coupons are minted at `amount = weight x issuancePerActivityUnit` (`:170`). A wrong pre-image
   fails the hash check exactly as on the global path.

The resulting on-ledger bound chain: **CC minted <= sum of committed weights <= reported
`totalActivity` <= `purchasedTotal`**.

This is why the notes say coupons "get created with actual CC amount": `RewardCouponV2` carries a
resolved CC amount, computed at expansion time from the reported weight and the vote-supplied rate,
unlike the pre-CIP-104 coupons whose issuance rate resolves at claim time.

## 4. What stays off-ledger, and the tranche split

Deliberately not on-ledger (SV-side automation, issue #57): splitting the per-round app-reward
tranche across synchronizers by burn proportion; the SV-voted per-synchronizer weight; computing
`issuancePerActivityUnit` from tranche, weight, and reported totals; sourcing `purchasedTotal` and
comparing as of round end; flagging violators (on-ledger a breach simply fails the vote); and the
report timeout (not reported one tick after round close counts as zero; `CalculateRewardsV2` is
untouched and carries no timeout). All of these collapse, on-ledger, into the single vote-attested
scalar rate.

The tranche itself is the existing app-reward tranche, sized per round from `appRewardPercentage` in
`computeIssuingRoundParameters` (`Issuance.daml:91,143`). "Ingest MemberTraffic into tcs" from the
notes: the temporal contract store is `TcsStore` / `DbTcsStore`
(`apps/common/.../store/TcsStore.scala:14`, `DbTcsStore.scala:28`), consumed on the Scan side by
`ScanRewardsReferenceStore`; it is explicitly single-synchronizer today (`DbTcsStore.scala:21-28`),
so holding per-synchronizer `MemberTraffic` in it is itself a change. (Earlier drafts of this note
called it "ScanTcsStore"; no such identifier exists.)

The deck's only statements on rewards: rewards accrue "to the app and validator pools on that
synchronizer"; "the pools are unchanged by this CIP" (the strongest signal yet that extension
rewards are drawn from the existing issuance rather than additive, though not decisive); and
org-internal traffic and the flat platform fee are explicitly not reward-eligible.

Operator-side automation (issue #58): computing per-round activity records from the dedicated
synchronizer's own sequencer and mediator data; building and durably storing the Merkle tree (a lost
pre-image makes a round unexpandable); reporting within the timeout; running the expansion trigger.

## 5. Featured apps and the per-synchronizer weight

- The operator decides which apps are featured on its own synchronizer, and inheriting the global
  synchronizer's featured-app rights must be supported as the default mode. Neither is implemented;
  today a `FeaturedAppRight` is granted DSO-wide (`Amulet.daml:281` in the pin; note the
  `activityWeight` field and `FeaturedAppRight_Update` are post-0.6.11 additions).
- The SV-voted per-synchronizer weight (structural precedent: `SRARC_UpdateSvRewardWeight`,
  `DsoRules.daml:112`) is applied to reported activity before the tranche split, entirely SV-side.
  The notes' "a suspected malicious dedicated sync can be set to 0%" is **not expressible in the
  shipped choice** (the rate must be positive); the on-ledger off switch is offboarding:
  `SRARC_ArchiveSynchronizerRegistration` (PR #12, PR head `DsoRules.daml:135`, choice
  `:1726-1743`) archives the registration, which makes later reports unprocessable via the
  registration gate.

## 6. Anti-fraud: bounded, not verified

Because the SVs cannot recompute a dedicated synchronizer's activity, an SV confirming a report
attests a bound, not correctness:

- The reported total cannot exceed purchased traffic, enforced on-ledger at start-processing
  (Section 3). Purchased is authoritative because every purchase burned CC on the global
  synchronizer (`MemberTraffic.totalPurchased`, `DecentralizedSynchronizer.daml:58`, summed per
  synchronizer via `getTotalPurchasedMemberTraffic`, `SvDsoStore.scala:949`); in the shipped choice,
  though, the figure is a vote-attested scalar rather than an on-ledger fetch.
- The unit mismatch is real and open: `purchasedTotal` is an `Int` of traffic bytes, compared via
  `intToDecimal` against a `Decimal` weight sum with no conversion. The notes' closing TODO ("need
  to reweight reported amount by purchase price") belongs exactly here: without reweighting, a
  discounted synchronizer earns the same reward weight per unit of reported activity as a full-rate
  one.
- The internal distribution of a reported total is unconstrained: the operator authors the tree, and
  its own cut is just a leaf whose provider is the operator (Section 7).
- The timeout (one tick after round close, count as zero) is SV-side and unimplemented; strict round
  monotonicity on the report choice already prevents back-filling a skipped round on-ledger.
- Lifecycle edges: offboarding archives only the registration and deliberately leaves
  `DedicatedSynchronizerState` alive; re-registering the same synchronizer without cleaning up the
  old state would allow the same round to be reported twice (documented in PR #12, unenforced). A
  stale doc comment at the SRARC constructor still says offboarding archives "registration and
  reporting state" (PR head `DsoRules.daml:137`).
- Known automation defect (issue #61): the SV `ProcessRewardsTrigger` and `RewardMetricsTrigger`
  pick up extension `ProcessRewardsV2` contracts they can neither serve nor control; they need an
  `expander is null` filter.

## 7. Operator cut and validator rewards

- Operator cut: the operator can include some percentage of activity for itself, computed while
  authoring the activity records; on-ledger this is nothing more than a self-attributed leaf, with
  no policy template or check. Permitted policies (including any floor for end users) are open.
  For onward sharing, `RewardCoupon_AssignBeneficiaries` on the `RewardCoupon` interface (which
  `RewardCouponV2` implements) reassigns minting rights to a weighted beneficiary set.
- Validator rewards: the purchase-time `ValidatorRewardCoupon` (`splitAndBurn`) covers dedicated
  synchronizers as-is. A separate CIP in flight moves validator rewards to traffic-based issuance,
  the same shift CIP-104 made for app rewards (per Simon Meier's review comment, 2026-07-27); when
  it lands, dedicated synchronizers integrate through the same report-driven principle, and its
  relationship to the purchase-time coupon (replacement or reconciliation) is open. DA has also
  signalled the MVP needs no operator rewards at all (Itai Segall, 2026-07-09), consistent with the
  Workstream 2 scoping.

## 8. Open questions (carried, not resolved here)

- Issuance basis: drawn from the existing issuance or additive to it. The deck's "the pools are
  unchanged by this CIP" plus splitting a fixed tranche lean drawn-from; not stated in so many
  words. The largest open tokenomics question.
- Purchase-price reweighting (the notes' TODO): unresolved, absent from the code, and located
  exactly at the bytes-vs-weights comparison in start-processing.
- The attested bound: should `purchasedTotal` be fetched on-ledger rather than vote-attested, and is
  the comparison per round or cumulative.
- The weight: cold-start value for a newly registered synchronizer, vote cadence, any emergency
  path; and the fact that 0% is inexpressible on-ledger (offboarding is the only kill switch).
- The timeout tick, and commit-then-abandon: what bounds an operator that reports (or starts
  processing) and never expands its tree, since expansion is operator-controlled.
- Operator-cut policy bounds.
- Validator rewards: integration with the in-flight CIP that moves validator rewards to
  traffic-based issuance, and its relationship to the buy-time coupon (replacement or
  reconciliation, avoiding double pay).
- Upgrade compatibility: the PoC appends `Optional` fields (shape-compatible) but ships **no package
  version bump** anywhere in the stack, and `BatchOfWeightedBatches` is a **new variant constructor
  on a released type**, a stronger upgrade claim that is unaddressed.
- Whether DA accepts the PoC shape at all: no DA reviewer has looked at #8 or #12 yet.

## 9. Grounding: notes term to shipped mechanism

| Notes term | Shipped mechanism | Reference |
|---|---|---|
| single (decentralized) party per extension | `DedicatedSynchronizerState.operator` (plain party) | PR head `DecentralizedSynchronizer.daml:171` |
| per-round report, commitment to root hash + total | `DedicatedSynchronizerState_ReportActivity` -> `ExtensionActivityReport {activityRootHash, totalActivity}` | PR head `DecentralizedSynchronizer.daml:189,212` |
| total ever reported (possibly in registry) | `totalActivityReported` on the state contract; registry option rejected | PR head `DecentralizedSynchronizer.daml:171` |
| noting that party on the ProcessRewardsV2 contracts | `expander : Optional Party`, observer + ProcessBatch controller | PR head `RewardAccountingV2.daml:86,103,111` |
| push issuance per activity record into process rewards | `issuancePerActivityUnit`; leaf `amount = weight x rate` | PR head `RewardAccountingV2.daml:91,170` |
| (tree integrity, implied) | `BatchOfWeightedBatches` / `WeightedBatchRef` + `weightBudget` threading | PR head `RewardAccountingV2.daml:56,64,95` |
| svs compute issuance / start processing | vote-dispatched `CRARC_StartProcessingExtensionRewardsV2` -> `AmuletRules_StartProcessingExtensionRewardsV2` | PR head `DsoRules.daml:99`; `AmuletRules.daml:761` |
| reported vs purchased, flag + cap | `require reported <= purchased` at start-processing (vote-attested `purchasedTotal`; no on-ledger flag) | PR head `AmuletRules.daml:789-790` |
| set to 0% | not expressible (rate positive, `:783`); off switch = `SRARC_ArchiveSynchronizerRegistration` | PR head `DsoRules.daml:135,1726` |
| tranche split by burn proportion; per-sync weight | SV-side, collapsed into the vote's rate scalar | issue #57 |
| ingest MemberTraffic into tcs | `TcsStore` / `DbTcsStore` (single-synchronizer today) | `DbTcsStore.scala:21-28` |
| timeout on CalculateRewards | superseded: parallel entry; timeout is SV-side | issue #57 |
| operator cut | self-attributed leaf; no on-ledger policy | PR #8 test `TestExtensionRewardReporting.daml` |
| featured on their synchronizer / default GSync FA rights | unimplemented (operator-side default deferred) | issue #58 |
| validator rewards after validator-based app rewards | unimplemented; double-count question open | Section 7 |
| TODO: reweight reported amount by purchase price | absent; belongs at the bytes-vs-weights comparison | Section 6 |

## References

- The DA deck, policy source of truth (pricing, staking, phases, terminology; silent on this
  mechanism): https://dach-ny.github.io/presentation-extending-mainnet/
- Fork PRs implementing the on-ledger half: [#8](https://github.com/canton-network/splice-multi-sync/pull/8)
  (reporting + expansion), [#12](https://github.com/canton-network/splice-multi-sync/pull/12)
  (registration lifecycle). Tracking issues: #47 (Daml PoC), #57 (SV-side), #58 (operator-side),
  #61 (trigger filter).
- [CIP-0104](https://github.com/canton-foundation/cips/blob/main/cip-0104/cip-0104.md) and the DA
  design "Traffic-Weighted App Rewards": the pipeline this design enters in parallel.
- [extension-traffic-manager.md](extension-traffic-manager.md), the funding/grant design this reward
  model sits on top of.

## Appendix A: DA "Reward Integration" notes (verbatim)

> Reward Integration
> mainnet extensions tbar
> each extension is represented by a single (decentralized) party
> each round that party reports activity on extension synchronizer on global synchronizer in Daml
> commitment to root hash and total activity records
> updates a total ever reported (possibly in registry contract)
> extension party expands root hash (after svs compute issuance per activity record) on global synchronizer (requires noting that party on the ProcessRewardsV2 contracts)
> an extension that wants to take a cut can include some percentage of activity to themselves
> computed as part of ingesting the activity records
> policies for what you are allowed to do there tbd
> app reward tranche is split across synchronizers based on the proportion of burn in that round
> for each synchronizer then issue coupons based on activity like we do for global atm
> the dedicated synchronizer operator can decide who gets featured on their synchronizer
> default mode of using the FA rights from GSync must be supported
> push issuance per activity record into process rewards => coupons get created with actual CC amount
> as for the featured apps, a dedicated sync weight is managed by the SVs via voting
> that weight is applied to the reported total activity before splitting the app rewards tranche across synchronizers => a suspected malicious dedicated sync can be set to 0%
> svs compare total purchased against total reported for an extension as of round end, if reported > purchased, flag extension as potentially malicious and cap rewards
> ingest MemberTraffic into tcs
> track total of activity reported on a DedicatedSynchronizerState contract
> need some timeout mechanism if extension does not report in time
> e.g. if not reported on-ledger 1 tick after round close, count as zero
> timeout on CalculateRewards
> validator rewards: only makes sense after validator-based app rewards, otherwise same principle
> TODO from discussion
> need to reweight reported amount by purchase price
