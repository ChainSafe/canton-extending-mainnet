# FR-3: Keeping a dedicated synchronizer sequencing through a global-synchronizer outage

Status: Proposal, to be folded into the FR-3 section of the 2026-08 Extension Traffic Manager Technical Design. Code links are pinned to canton-network/splice-multi-sync `main` at `bfb8c185`.

## Requirement

FR-3 (P2), from the requirements table of the 2026-08 Extension Traffic Manager Technical Design:

> A dedicated synchronizer continues sequencing transactions when the Global Synchronizer is unavailable; economic obligations accrue locally and settle on restoration, within a parametrized grace period. To allow this, dedicated synchronizers are allowed to accumulate negative traffic balance if the Global Synchronizer is unavailable. When reconnecting to the Global Synchronizer, the dedicated synchronizer must pay for the negative traffic balance as though it were an ongoing traffic purchase with its discounts applied.
>
> Two cases:
> - Unplanned outages of the gSync and unplanned disconnections of a dedicated synchronizer
>   - Basic model: pre-purchase at least 1 day (required) based on trailing average usage
>   - Require immediate top-up of any negative balance, then repurchase 1-day balance, when reconnecting
>   - Dedicated synchronizer must report its Validators' traffic balances upon reconnection.
>   - If disconnected for more than 1 day, possibly penalties may apply (TBD)
> - Intentional separate operation of a dedicated synchronizer for a planned period (probably Phase 3)

The [grant draft](../grants/extending-mainnet-grant-draft.md)'s Milestone 5 acceptance says the same in one line: the synchronizer keeps sequencing while the Global Synchronizer is unavailable, and settles once it returns. Its "Outage settlement" risk records that settling a true negative balance depends on the Canton ledger team delivering negative traffic balances, and it carries that settlement in Milestone 13 rather than M1 to M12.

## The problem

All traffic on a dedicated synchronizer is bought on the global synchronizer: base rate is 0, and a member can only submit against traffic its validator has purchased with `AmuletRules_BuyMemberTraffic`. When the global synchronizer is unavailable, nothing can be bought, so a member runs only as long as its prepaid remainder lasts. Today that is about one top-up. The validator's top-up buys only once the remainder falls below one top-up ([`TopupMemberTrafficTrigger.scala:259-274`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/apps/validator/src/main/scala/org/lfdecentralizedtrust/splice/validator/automation/TopupMemberTrafficTrigger.scala#L259-L274)), and a top-up covers `minTopupInterval`, 10 minutes by default. After that, the sequencer refuses the member's submissions until the global synchronizer is back and a purchase lands.

Canton does not support negative traffic balances today: a submission is refused when the member's available traffic is below its cost. We found no public Canton or Splice material saying when that will change. Splice's traffic documentation describes refusal as the behavior ([Synchronizer Traffic Fees](https://docs.sync.global/deployment/traffic.html)), and the Canton release notes do not mention it ([releases](https://github.com/digital-asset/canton/releases)).

## What Canton and Splice already give us

The proposal below changes no Canton code. It uses five things that already exist:

1. **The sequencer accepts any limit the operator sets.** `SetTrafficPurchased` is applied if its serial is newer than the last one; the value is never checked in either direction ([`TrafficPurchasedManager.scala:141`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/canton/community/synchronizer/src/main/scala/com/digitalasset/canton/synchronizer/sequencing/traffic/TrafficPurchasedManager.scala#L141)). The operator app already uses this to grant purchases.
2. **The remainder is signed.** A member's extra-traffic remainder is purchased minus consumed ([`TrafficState.scala:32`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/canton/community/base/src/main/scala/com/digitalasset/canton/sequencing/protocol/TrafficState.scala#L32)). If the limit is set below what the member has consumed, the member is below zero and is refused until its purchases cover the difference. That is FR-3's "immediate top-up of any negative balance", enforced by the sequencer.
3. **Grants aggregate across sequencers.** A grant takes effect only once the sequencer group's threshold of active sequencers submit the same `(member, serial, total)` ([`TrafficPurchasedSubmissionHandler.scala:139-148`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/canton/community/base/src/main/scala/com/digitalasset/canton/sequencing/traffic/TrafficPurchasedSubmissionHandler.scala#L139-L148)). The message's deadline is rounded to a fixed window, `setBalanceRequestSubmissionWindowSize`, 2 minutes by default ([lines 256-274](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/canton/community/base/src/main/scala/com/digitalasset/canton/sequencing/traffic/TrafficPurchasedSubmissionHandler.scala#L256-L274)), so operators that act at different moments in the same window send identical messages. This is how SVs grant traffic on the global synchronizer today.
4. **Splice tracks synchronizer time.** `DomainTimeIngestionTrigger` asks the participant for a synchronizer time no older than the polling interval ([`DomainTimeIngestionTrigger.scala:36`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/apps/common/src/main/scala/org/lfdecentralizedtrust/splice/automation/DomainTimeIngestionTrigger.scala#L36), [`TopologyAdminConnection.scala:141`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/apps/common/src/main/scala/org/lfdecentralizedtrust/splice/environment/TopologyAdminConnection.scala#L141)), which waits for a freshly sequenced event. The validator and SV apps run it to tell when they are behind their synchronizer.
5. **The operator already observes its registration.** `RegisteredSynchronizer` has the operator as an observer ([`DecentralizedSynchronizer.daml:166`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/daml/splice-amulet/daml/Splice/DecentralizedSynchronizer.daml#L166)), so any parameter on it is on the operator's own ledger, readable while the global synchronizer, and possibly Scan, is unreachable.

## Proposal: a governed outage traffic advance

An SV-voted cap, `outageAdvance`, sits on the registration's `GovernanceParameters` beside the discount. It is set by the registration vote and changed by the set-parameters vote, in bytes per member, and 0 disables it. While the global synchronizer is unreachable, the operator app lets each member run up to that many bytes past what it has bought. When the global synchronizer returns, the app takes the advance back, so a member that used it is below zero and pays it off with its next purchase, at the registration's discount, as FR-3 asks.

**Outage signal.** The operator app runs its own `DomainTimeAutomationService` against the global synchronizer. An outage is no fresh global-synchronizer time for `outageAdvanceDelay`, counted from startup when no time has been seen yet. This covers the global synchronizer being unreachable or stalled, the operator's participant being disconnected from it, and that participant being down. In the last two cases the operator cannot grant purchases either, so members need the advance anyway. The service is kept separate from the app's own triggers because Splice triggers wait on their automation's synchronizer time before each run ([`Trigger.scala:53`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/apps/common/src/main/scala/org/lfdecentralizedtrust/splice/automation/Trigger.scala#L53)), and these triggers have to run precisely when that time is stale. Why this signal and not the participant's connection status is in the appendix.

**Advance.** During an outage, the app sets each member's limit to its purchased total in the app's store plus the cap. Only members with a purchase on record are included. It only raises limits. Using the purchased total rather than the sequencer's current limit matters for three reasons:
- The total cannot change while the global synchronizer is unreachable, so an app that restarts mid-outage computes the same target and never advances twice.
- The advance is in effect exactly when the limit equals total plus cap, so there is nothing extra to persist.
- On a synchronizer whose sequencers several organizations run, operators with up-to-date stores send the same grant. It lands once the sequencer group's threshold do, so the advance applies only when enough operators see the outage, and one operator's local connectivity problem cannot grant credit on its own.

**Take-back.** When fresh time returns, the app sets each member's limit back to its current purchased total, then raises any limit a purchase ingested during the take-back left behind. The existing reconcile trigger only ever raises a limit ([`ReconcileSequencerLimitWithMemberTrafficTriggerBase.scala:151`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/apps/common/src/main/scala/org/lfdecentralizedtrust/splice/automation/ReconcileSequencerLimitWithMemberTrafficTriggerBase.scala#L151)), so lowering is this step's job. Grants retry until the sequencer applies them and recompute on a concurrent change, as reconcile's already do ([`SequencerAdminConnection.scala:424`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/apps/common/src/main/scala/org/lfdecentralizedtrust/splice/environment/SequencerAdminConnection.scala#L424)).

**Settlement.** A member that used more than its prepaid remainder is below zero after the take-back. Its validator's top-up now buys the shortfall plus a normal top-up in one purchase, with the funds check priced for both. Before, it would buy one top-up per interval and stay blocked for several intervals. The purchase is an ordinary `AmuletRules_BuyMemberTraffic` at the registration's discount, so the network gets the burn for every byte, late.

**Cost.** Outside an outage the app does no work per member. It fetches synchronizer time once per polling interval, and it walks the members only when an outage starts and when it ends. An earlier attempt to replace event-driven reconciliation with a poll over every member (canton-network/splice-multi-sync#56) was dropped because that cost grows with the member set, so the same constraint applies here.

**Trust model.** Canton accepts any limit, so the cap binds an honest operator app, the same trust model as every grant today. What the cap adds is that the credit an operator extends is SV-voted, public on the registration, and followed by the reference implementation.

### Sizing

The cap is credit the operator extends per member, so its exposure is cap × members. The CIP's $1 per typical global-synchronizer transaction at $60/MB works out to about 16.7 KB per transaction, which is about 60 MB, or $3,600, per hour at 1 TPS. That is consistent with the CIP's figure of about $31m a year at 1 TPS.

| Member rate | 15 min | 1 h | 4 h |
|---|---|---|---|
| 1 TPS (about 16.7 KB/s) | 15 MB ($900) | 60 MB ($3,600) | 240 MB ($14,400) |

For comparison, FR-3's basic model of a required one-day prepurchase is about 1.4 GB, or $86,400, held per member at 1 TPS. The advance replaces part of that member capital with bounded operator credit. The cap defaults to 0, so SVs choose it deliberately.

## How this relates to negative balances in Canton

The advance emulates a bounded negative balance with what Canton has today. A member cannot consume past the advance, and its deficit appears only at the take-back, when the limit drops below what it consumed.

If Canton adds negative traffic balances, for example a limit on how far below zero a member's remainder may go, the governed cap carries over as that limit. The operator would then set an allowance instead of raising and lowering limits, consumption itself would run below zero during the outage, and the top-up's shortfall purchase would settle it unchanged. If that allowance has to be open only while the global synchronizer is unreachable, as FR-3 says, the outage signal is still needed. If an always-open, bounded allowance is acceptable, it is not.

We have not found Canton's plans for negative balances in any public roadmap or release notes. The [grant draft](../grants/extending-mainnet-grant-draft.md) assumes the ledger team delivers them, and its outage-settlement milestone, M13, depends on that. Confirming the status and expected shape with DA would decide whether the cap's Daml should be shaped for it now.

## Open questions

1. **Per synchronizer or network-wide.** The cap is per synchronizer because the operator carries the credit and the bytes that buy a useful runway depend on members' throughput: the same amount is minutes on a busy synchronizer and hours on a quiet one. A single network-wide rule would have to be expressed as time, say N minutes of a member's recent consumption, which means sampling every member's consumption continuously, the per-member cost the design otherwise avoids.
2. **How long an outage Phase 2 must cover.** Any bounded amount runs out. Covering an outage of any length needs negative balances in Canton. If a few hours is enough for Phase 2, a bounded advance covers it. If not, Phase 2 is prepaid runway alone, the FR-3 basic model, and longer outages wait for Canton.
3. **The signal.** Synchronizer time is Splice's existing measure of being behind a synchronizer. Its weak spot is a participant that lags while the global synchronizer is fine, which grants credit without an outage. On a multi-node synchronizer the grant threshold filters that out, and on a single-operator one it is that operator's own risk. A better signal is welcome.
4. **The grace period.** FR-3 settles "within a parametrized grace period". The take-back here is immediate, so a member that used the advance is refused until its top-up lands. Delaying the take-back would only help if a member's validator could tell an advanced limit from a purchased one, which it cannot from its traffic state alone.
5. **Reporting.** FR-3's report of validators' balances on reconnection belongs with the Phase 3 consumption reports (M7).

## Options for 0.10.0

Any cap is a Daml change, so it has to be settled by mid-October to make the 0.10.0 cut on 29 October. The backend follows on 0.10.3 on 20 November.

- **A. Prepaid runway only.** No Daml change. Validators size their top-ups for the runway they want, following the operator guide (ChainSafe/canton-extending-mainnet#37), and longer outages wait for negative balances in Canton.
- **B. Bounded advance, as proposed.** The cap ships in 0.10.0 and the operator side in 0.10.3. The scope (per synchronizer or network-wide) and unit (bytes or time) are decided here first.
- **C. Wait for Canton.** Nothing ships for Phase 2 beyond A, and the cap is designed with the Canton allowance once its shape is known.

## Status

- ChainSafe/canton-extending-mainnet#129 tracks the work.
- canton-network/splice-multi-sync#61 has the Daml half: `outageAdvance` on `GovernanceParameters`, set and shown in the SV UI. CI is green and it is under review.
- canton-network/splice-multi-sync#66 has the backend half, stacked on #61: the outage trigger, the store and config changes, the top-up shortfall purchase, and unit tests. Its integration test cuts the operator's participant off the global synchronizer and checks five things: the advance lands, survives an operator restart without being added twice, and refuses the member at the cap; it is taken back on reconnection; and one top-up covers the shortfall. CI is green and it is a draft.

## Appendix: why not the participant's connection status

`listConnectedSynchronizers()` reports a `healthy` flag per synchronizer and looks like the obvious signal. We read the Canton code behind it:

- **What sets it.** `healthy` is the participant's readiness to submit: ready, not failed, and the sequencer client not failed ([`ConnectedSynchronizer.scala:1025-1028`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/canton/community/participant/src/main/scala/com/digitalasset/canton/participant/sync/ConnectedSynchronizer.scala#L1025-L1028)). The only part that changes while connected is the health of the sequencer subscription pool.
- **When it turns false.** The pool counts live subscriptions ([`SequencerSubscriptionPoolImpl.scala:382-405`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/canton/community/base/src/main/scala/com/digitalasset/canton/sequencing/client/pool/SequencerSubscriptionPoolImpl.scala#L382-L405)):
  - at or above the trust threshold plus the liveness margin, it is healthy;
  - at or above the trust threshold alone, it is degraded, which still reads as `healthy`;
  - below the trust threshold, it has failed.
  
  Splice sets the trust threshold to f+1 and the margin to f ([`Thresholds.scala`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/apps/common/src/main/scala/org/lfdecentralizedtrust/splice/config/Thresholds.scala)). With 13 SVs, `healthy` stays true down to 5 reachable sequencers.
- **What it misses.**
  - Nothing watches whether events are still arriving: there is an open TODO for it ([`SequencerSubscription.scala:154`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/canton/community/base/src/main/scala/com/digitalasset/canton/sequencing/client/pool/SequencerSubscription.scala#L154)). So a global synchronizer that has stopped ordering while its sequencers still serve subscriptions can read as healthy. We inferred this from the code; we did not observe it.
  - Failed submissions never affect it.
- **Some failures skip it altogether.** A permission loss disconnects the synchronizer, so it disappears from the list instead of turning unhealthy. An unrecoverable error stops the participant, since `exitOnFatalFailures` defaults to true ([`SynchronizerConnectionsManager.scala:1021-1026`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/canton/community/participant/src/main/scala/com/digitalasset/canton/participant/sync/SynchronizerConnectionsManager.scala#L1021-L1026), [`CantonConfig.scala:359`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/canton/community/app-base/src/main/scala/com/digitalasset/canton/config/CantonConfig.scala#L359)).
- **Why synchronizer time is better.** Asking for a fresh synchronizer time waits for a newly sequenced event, so it also catches a synchronizer that has stopped ordering.

**Versions.** The Canton code above is the copy vendored in splice-multi-sync, at 3.5.7-SNAPSHOT, while nodes run the pinned 3.6.0 snapshot. The health path was checked against the pinned jar and matches. The traffic-grant behavior is exercised against the pinned images by the integration test in canton-network/splice-multi-sync#66.
