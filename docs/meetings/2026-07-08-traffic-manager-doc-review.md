# Review: circulated "Traffic Manager" design doc

Date: 2026-07-08. A line-referenced review of the circulated second-hand
"Traffic Manager" design doc, checked against Splice 0.6.11 / Canton in the
`splice/` submodule. Companion to the meeting notes in
[2026-07-08-extending-mainnet.md](2026-07-08-extending-mainnet.md).

Overall: the doc's low-level plumbing is largely accurate and clearly grounded in
the code. It has one superseded core premise (below), a few factual errors, and
one significant scope underestimate.

## Banner: the central economic model is redirected

The doc is built on a decoupled-tribute model:
- the private sync self-funds its own traffic with its own coin,
- the CC burn on the global sync grants no sequencer traffic anywhere and is a
  pure economic link,
- reporting is aggregate (whole-subnet) and deliberately decoupled from burning
  (a subnet may be temporarily under-burned).

Per the meeting, this is superseded. The authoritative model is CC-funded
traffic: CC burned on the global sync, keyed by the extension sync id, actually
purchases and grants traffic on the extension sync, per purchase, via the Sync
Operator Node. This is a generalization of today's flow (`AmuletRules_BuyMemberTraffic`
-> `MemberTraffic` -> `ReconcileSequencerLimitWithMemberTrafficTrigger` ->
sequencer `SetTrafficPurchased`) pointed at the extension sequencer.

Consequence: the doc's argument for not reusing `MemberTraffic` is reversed.
Because the correct model grants traffic per purchase, the existing
`MemberTraffic` + reconcile flow (keyed by sync id, pointed at the extension
sequencer) is the natural basis. The doc's aggregate `SubnetTrafficUsage` /
`SubnetTrafficRecord` / decoupled-burn contracts model a different mechanism than
the one we are building. The redirect opens genuine design questions (how the
per-purchase grant on the extension sequencer is authorized and reconciled by the
operator, and how rewards/reporting layer on top) that should be worked through
rather than assumed; this review does not propose a replacement contract set.

The doc is also internally inconsistent on this point: the abstract says it works
for "any synchronizer that uses Canton Coin," while the terminology section says
the subnet has "its own coin."

## What held up (accurate, keep)

- `SequencerAdminConnection.listSequencerTrafficControlState` exists and returns
  per-member cumulative `extraTrafficConsumed` (`SequencerAdminConnection.scala:368`;
  `TrafficState.scala:26`; accumulation in `TrafficConsumed.scala:147`).
- The append-only journal table `seq_traffic_control_consumed_journal` exists
  (`V1_1__initial.sql:814`; `DbTrafficConsumedStore.scala:26,72`). The
  `TrafficConsumed` record has `extraTrafficConsumed` and `baseTrafficRemainder`
  (and also `member`, `sequencingTimestamp`, `lastConsumedCost`)
  (`TrafficConsumed.scala:34`).
- The pricing math is correct: `computeSynchronizerFees` does
  `trafficCostUsd = bytes/1e6 * extraTrafficPrice` then
  `/ amuletPrice` (`AmuletRules.daml:1719-1729`), and `extraTrafficPrice` ($/MB)
  is a governed value in `SynchronizerFeesConfig`.
- `splitAndBurn` is the right burn primitive and mints a `ValidatorRewardCoupon`
  over the burn (`AmuletRules.daml:2213-2256`).
- Multi-synchronizer topology is real: one participant can connect to the global
  sync and an extension sync simultaneously (LocalNet `multi-sync` profile;
  `ReconcileSequencerConnectionsTrigger`).
- Scan can index a new template and expose new endpoints; `getMemberTrafficStatus`
  is the existing analog (`ScanStore.scala:382`; `scan.yaml`;
  `HttpScanHandler.scala:2288`).
- LSU does not reset traffic (`LsuTransferTrafficTrigger` carries the sequencer
  traffic state across the upgrade); `MemberTraffic` is keyed by `migrationId`.
- The reasons given for not modeling on a real member/party via the sequencer
  reconcile side effect are technically accurate, even though the redirect above
  changes the conclusion.

## Wrong or imprecise (correct these)

1. "Purchasing is done via a DAML transaction that lets the DSO burn the coin."
   Wrong. The controller of `AmuletRules_BuyMemberTraffic` is the
   provider/validator, who burns from its own balance inside the DSO-signed
   `AmuletRules` contract. The DSO is the signatory of the contract, not the
   burner. The doc contradicts itself later ("burns CC from the caller's own
   balance"). The proposed `AmuletRules_BuySubnetTraffic` correctly uses
   `controller burner`.

2. "Enforcement: if total_purchased < total_consumed, the submission is rejected."
   Imprecise. The real rule is: reject when `availableTraffic < eventCost`, where
   `availableTraffic = (extraTrafficPurchased - extraTrafficConsumed) +
   baseTrafficRemainder` (`TrafficConsumed.scala:168-172`; `TrafficState.scala:32-35`).
   It includes the free base-rate allowance and compares against the event cost,
   not a bare purchased-vs-consumed.

3. "A free base-rate allowance that replenishes when a member is idle (~20
   minutes)." Partial. The ~20-minute window is Splice's deployment config
   (`baseRateBurstWindowMins: 20`, `domainFees.ts:19-20`); Canton's built-in
   default is 10 minutes (`TrafficControlParameters.scala:90`). State it as
   Splice's configured value, not a protocol constant.

4. "Purchased traffic ... typically reset only during an HDM." Historical. Hard
   Domain Migrations are no longer supported in 0.6.11 (`release_notes.rst:211`);
   `migrationId` is now frozen and LSU uses a separate serial id. The data-model
   claim (a `migrationId` bump zeroes the purchased-traffic sum) is still true,
   but HDM is not a current runtime path.

## Feasibility gap (scope underestimate)

The doc proposes that an SV governance vote "creates the `SubnetRegistration`
contract and the zero-initialized `SubnetTrafficRecord`," and frames the
mainnet work as a `splice-amulet` change plus a new Traffic Manager DAR.

That understates the scope. Governance votes can only dispatch a closed set of
actions: `ActionRequiringConfirmation` is a fixed sum type
(`DsoRules.daml:68-80`), dispatched by a fixed matcher
(`executeActionRequiringConfirmation`, `DsoRules.daml:1772-1807`); the extension
placeholder is a no-op. A vote cannot create an arbitrary new app contract.
Creating a contract by vote is only done through dedicated, hardcoded choices,
each tied to its own `SRARC_` variant (for example
`DsoRules_CreateExternalPartyAmuletRules`, `DsoRules.daml:1607`).

So registering a subnet by vote requires a new `SRARC_CreateSubnet...` variant, a
matching `DsoRules_CreateSubnetRegistration` choice, and a dispatch arm, all
inside the core `splice-dso-governance` package. That is a second governed Daml
upgrade the doc does not account for (it flags the `splice-amulet` upgrade for the
burn choice, but not the `splice-dso-governance` upgrade for vote-driven
registration).

Related internal inconsistency: the proposed `AmuletRules_BuySubnetTraffic` calls
`splitAndBurn`, which always mints a `ValidatorRewardCoupon` for the burner, yet
the doc's open questions ask whether to mint one. The code as written answers
"yes"; suppressing it would require a different burn primitive. This should be a
deliberate design decision, not an open question against code that already
decides it.

## The doc's open questions, with code-grounded answers

- "Can we use contract keys yet?" Splice generally avoids contract keys in these
  packages today; the singleton archive-and-recreate pattern the doc uses is the
  current idiom. Treat contract keys as future work, consistent with the doc's
  own hedging.
- "Should we create a `ValidatorRewardCoupon` for the CC burned on mainnet?" As
  written (via `splitAndBurn`) it already does. This is a design choice, not an
  open question: keep it (reuse `splitAndBurn`) or write a burn primitive that
  does not mint the coupon.
- "Do we need to report free (base-rate) traffic?" The base-rate allowance is
  real and configured (Section on base rate above); excluding it and counting
  only `extraTrafficConsumed` is a reasonable v1 simplification, but note it
  undercounts true consumption by the base-rate amount.
- "Three more governance vote / UI works (setup, edit, archive
  `SubnetRegistration`)?" Given the feasibility gap above, each of these is not
  just a UI/vote addition but a new core-package governance action, which raises
  the effort estimate.

## Bottom line

Keep the plumbing (sequencer APIs, journal/record, pricing math, `splitAndBurn`,
Scan indexing, multi-sync topology, LSU behavior). Redirect the economic model to
CC-funded traffic. Fix the DSO-burns, enforcement, base-rate, and HDM statements.
Re-estimate the governance-registration work as a core `splice-dso-governance`
change. Decide the `ValidatorRewardCoupon` question deliberately.
