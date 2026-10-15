# FR-3: Keeping a dedicated synchronizer sequencing through a global-synchronizer outage

Status: Decided on 2026-10-05, and updated on 2026-10-12 to follow the implementation review in canton-network/splice-multi-sync#71. To be folded into the FR-3 section of the 2026-08 Extension Traffic Manager Technical Design. This replaces the earlier proposal in this document, an SV-voted cap with automatic outage detection (canton-network/splice-multi-sync#61 and #66, both closed). Code links are pinned to canton-network/splice-multi-sync `main` at `bfb8c185`.

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

The [Phase 1 grant proposal](../grants/universal-burn-phase-1-proposal.md)'s Milestone 3 acceptance says the same in one line: the synchronizer continues processing through a Global Synchronizer outage on prepaid traffic and then on the operator-set allowance, and settles any advance once the Global Synchronizer returns.

## The problem

All traffic on a dedicated synchronizer is bought on the global synchronizer: base rate is 0, and a member can only submit against traffic bought for it with `AmuletRules_BuyMemberTraffic`. Traffic is kept per member and per synchronizer, so each member draws on its own balance. When the global synchronizer is unavailable, nothing can be bought, so each member runs only as long as its own prepaid remainder lasts. With default settings that is about one top-up: the validator's top-up buys only once the remainder falls below one top-up ([`TopupMemberTrafficTrigger.scala:259-274`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/apps/validator/src/main/scala/org/lfdecentralizedtrust/splice/validator/automation/TopupMemberTrafficTrigger.scala#L259-L274)), and a top-up covers `minTopupInterval`, 10 minutes by default. After that, the sequencer refuses the member's submissions until the global synchronizer is back and a purchase lands.

Canton does not support negative traffic balances: a submission is refused when the member's available traffic is below its cost. DA confirmed on 2026-10-01 that negative balances at the Canton level are unlikely on current timelines and can be left out of scope for the MVP.

## Decision: an operator-set outage traffic allowance

During an outage, the operator sets an allowance in the sync operator app's local config, following the runbook. While it is set, each member may run up to that many bytes past what has been bought for it. Once the global synchronizer is back, the operator removes it, again following the runbook, and each member's limit returns to what has been bought for it. Nothing detects the outage automatically, nothing about it is on-ledger, and it needs no Daml change.

**Setting it.** The operator adds the allowance to the app's config and restarts the app. It is a single value in bytes, applied to every participant on the synchronizer, including any that join while it is set. The app keeps each participant's limit at exactly its purchased total, or 0 if it has none, plus the allowance, so setting a smaller value and restarting lowers the limits again.

**While it is set.** The global synchronizer may come back before the operator removes the allowance. A purchase that lands in that time raises the member's limit to its new purchased total plus the allowance, so every participant keeps the full allowance on top of what it has bought until the allowance is removed.

**Removing it.** The operator removes the allowance and restarts the app. The app sets each participant's limit back to its purchased total, the aggregate of its purchases on the global synchronizer.

**Settlement.** A member that used more than its prepaid remainder is below zero once the allowance is removed, and the sequencer refuses it until its purchases cover what it consumed. That is FR-3's "immediate top-up of any negative balance". The validator's top-up buys that shortfall together with a normal top-up in one purchase, with the funds check priced for both. If the validator's wallet does not cover both, it buys the top-up alone, which still pays the shortfall down one interval at a time. Before this change, it bought one top-up per interval and left the member blocked for several intervals. The purchase is an ordinary `AmuletRules_BuyMemberTraffic` at the registration's discount, so the network gets the burn for every byte, late.

**No warnings yet.** The app logs nothing specific while the allowance is set, so removing it once the global synchronizer is back is a runbook step. Warnings can be added once operators have run it and the usage patterns are clearer.

**How the app keeps the limits.** On a dedicated synchronizer, the sync operator app reconciles traffic by polling. Each poll reads the traffic state of every member on its sequencer and every purchased total, and sets each participant's limit to its target wherever the two differ. Mediators keep their unlimited traffic, and sequencers are not charged traffic. Reading every member on each poll is fine for the few members of a dedicated synchronizer; the global synchronizer keeps its event-driven reconciliation.

**Before the operator acts.** Until the allowance is set, members run on their prepaid remainder. Members that want to ride out the gap without being refused hold a larger remainder, as in FR-3's basic model. To keep about a day in hand, the top-up amount has to be a day's usage while the interval stays short, for example a one-hour `minTopupInterval` with `targetThroughput` at 24 times the member's real rate. The validator's wallet then needs a day's traffic in CC at each top-up, because the funds check prices the whole amount.

### What Canton and Splice already give us

1. **The sequencer accepts any limit the operator sets.** `SetTrafficPurchased` is applied if its serial is newer than the last one; the value is never checked in either direction ([`TrafficPurchasedManager.scala:141`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/canton/community/synchronizer/src/main/scala/com/digitalasset/canton/synchronizer/sequencing/traffic/TrafficPurchasedManager.scala#L141)). The operator app already uses this to grant purchases.
2. **The remainder is signed.** A member's extra-traffic remainder is purchased minus consumed ([`TrafficState.scala:32`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/canton/community/base/src/main/scala/com/digitalasset/canton/sequencing/protocol/TrafficState.scala#L32)). Setting the limit below what the member has consumed leaves it below zero and refused until its purchases cover the difference.
3. **Grants aggregate across sequencers.** A grant takes effect only once the sequencer group's threshold of active sequencers submit the same `(member, serial, total)` ([`TrafficPurchasedSubmissionHandler.scala:139-148`](https://github.com/canton-network/splice-multi-sync/blob/bfb8c185186e48cd2ad1e687cc32479289ff2321/canton/community/base/src/main/scala/com/digitalasset/canton/sequencing/traffic/TrafficPurchasedSubmissionHandler.scala#L139-L148)).

### Synchronizers run by several organizations

Because of the aggregation in point 3, an allowance applies only once enough of the synchronizer's operators send the same limit. Each organization's app reads the allowance from its own config, so every operator has to set the same value, and later remove it, at about the same time. The runbook covers that coordination. Until a threshold of operators agree, nothing changes, and a single operator setting it alone has no effect.

### Trust model

The allowance is the operator's own credit decision. It is local, not governed by SVs and not visible on-ledger. An operator could always grant traffic nobody paid for, since Canton accepts any limit. The allowance makes that a defined, bounded procedure whose deficits are paid back by on-ledger purchases.

### Sizing

The allowance is credit the operator extends per participant, so its exposure is allowance × participants, including any that join while it is set. The CIP's $1 per typical global-synchronizer transaction at $60/MB works out to about 16.7 KB per transaction, which is about 60 MB, or $3,600, per hour at 1 TPS.

| Member rate | 15 min | 1 h | 4 h | 1 day |
|---|---|---|---|---|
| 1 TPS (about 16.7 KB/s) | 15 MB ($900) | 60 MB ($3,600) | 240 MB ($14,400) | 1.4 GB ($86,400) |

The last column is also what one member holds prepaid at all times under FR-3's basic model.

## Alternatives considered

- **Prepaid runway only.** No operator action and no code: every member holds at least a day of its own traffic, configured as above, and longer outages block members until the global synchronizer returns. This stays the recommended way to cover the gap before the operator acts. On its own, it locks up a day of each member's spend at all times.
- **An SV-voted cap with automatic outage detection** (canton-network/splice-multi-sync#61 and #66, closed on 2026-10-05). The cap sat on the registration's `GovernanceParameters`, and the operator app applied it once the global synchronizer's time had gone stale for a configured delay. It was dropped because it put a credit amount that runs out anyway under SV governance, and because the outage signal was indirect.
- **Negative balances in Canton.** These would let consumption itself run below zero during an outage. DA confirmed they are unlikely on current timelines.
- **Turning off `enforceRateLimiting` during an outage.** This dynamic synchronizer parameter switches traffic control off entirely: submissions are accepted without being metered, so there would be nothing to settle afterwards.

## Open points

1. **The grace period.** FR-3 settles "within a parametrized grace period". With a manual removal, the runbook can have the operator wait a grace period after the global synchronizer returns before removing the allowance, so members can buy back what they used before their limits drop. The operator carries the credit meanwhile.
2. **Reporting.** FR-3's report of validators' balances on reconnection belongs with the consumption reports in the [Phase 2 grant proposal](../grants/universal-burn-phase-2-proposal.md), Milestones 1 and 2.
3. **If Canton adds negative balances later,** the allowance would map onto Canton's below-zero allowance, and the operator would no longer raise and lower limits.

## Implementation

There is no Daml change, so it all ships in 0.10.3 on 20 November. It is implemented in canton-network/splice-multi-sync#71 and tracked by ChainSafe/canton-extending-mainnet#129:

- **Sync operator app:**
  - the allowance setting;
  - a polling reconcile trigger that keeps each participant's limit at its purchased total, or 0, plus the allowance while it is set.
- **Validator top-up:** buying the shortfall plus a normal top-up in one purchase, or the top-up alone if the wallet does not cover both.
- **Operator documentation** (ChainSafe/canton-extending-mainnet#37): the runbook steps to set and remove the allowance, how operators coordinate on a synchronizer run by several organizations, and the guidance for members' prepaid runway.

**Versions.** The Canton code above is the copy vendored in splice-multi-sync, at 3.5.7-SNAPSHOT, while nodes run the pinned 3.6.0 snapshot. The traffic-grant behavior this design relies on is exercised against the pinned images by the integration tests in canton-network/splice-multi-sync#71.
