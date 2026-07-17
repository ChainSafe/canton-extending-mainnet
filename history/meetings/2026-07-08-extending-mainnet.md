# Meeting notes: Extending Mainnet (Tokenomics Alignment)

Date: 2026-07-08. Canton CIP "Extending Mainnet: Tokenomics Alignment Across the
Entire Canton Network" (Shaul Kfir, Digital Asset). ChainSafe as Super Validator
and prospective extension-synchronizer operator.

These notes capture the target design we intend to implement. Where the target
diverges from what Splice 0.6.11 does today, that is generally net-new work, and
is called out as such. Claims about current behavior are grounded in the
`splice/` submodule with `file:line` references. A companion review of the
circulated "Traffic Manager" design doc is in
[2026-07-08-traffic-manager-doc-review.md](2026-07-08-traffic-manager-doc-review.md).

## 1. Summary

Generalize Canton's single-Global-Synchronizer traffic-purchase + Burn-Mint flow
into per-synchronizer, and later per-transaction-class, discounted, optionally
staked pricing on extension synchronizers. The near-term goal is a no-discount
extension synchronizer that participates in the same Canton Coin (CC) economy as
the global synchronizer, followed by a proof-of-concept for differential
discounting and rewards.

Authoritative economic model (decided in the meeting): CC is burned on the
global synchronizer, keyed by the extension synchronizer's id, and that purchase
actually grants traffic on the extension synchronizer, per purchase, managed by a
Sync Operator Node. This is a generalization of today's global-synchronizer flow
(`AmuletRules_BuyMemberTraffic` -> `MemberTraffic` ->
`ReconcileSequencerLimitWithMemberTrafficTrigger` -> sequencer
`SetTrafficPurchased`) pointed at the extension sequencer.

## 2. Open gaps ("Missing")

Items still to be specified:

- Traffic management on a non-global synchronizer.
- How to burn CC to obtain traffic (the Splice mechanism).
- How much CC buys how much traffic (the Splice conversion).
- Transaction types: the protocol characterizes a transaction and draws traffic
  from the appropriate bucket; Splice configures the protocol with the types and
  rates. Note: this does not exist today. Canton traffic is purely byte-based
  with no transaction-class concept (`EventCostCalculator.scala:109-146`), so
  transaction-type characterization is genuinely net-new.
- Agreement to purchase traffic.
- Price of traffic.
- Commitment.
- State.

## 3. Discount types (proposed)

Two discount dimensions:

- Throughput (short-term bulk): a discount for sustained/bulk usage.
- Short duration: a short commitment window (order of one hour), repeated every
  timeslot.

## 4. Purchase sequence (proposed)

Proposed flow for buying traffic on an extension synchronizer:

1. Provider announces intent to purchase traffic.
2. SVs see it and ask for the burn.
3. Provider burns CC.
4. SVs issue a traffic coupon.
5. Provider sees the coupon and tops up traffic on the synchronizer for its
   validators, split between them as the provider sees fit.
6. Validators transact and draw down the balance in their buckets.
7. At the end of the timeslot, the provider reports back the actual traffic used,
   and makes the next purchase.

Open question: what happens if the purchase is not repeated in the next timeslot.

Note vs today: current Splice has no announce-intent / SV-asks-for-burn /
SV-issues-a-traffic-coupon handshake. Today the validator burns CC directly via
`AmuletRules_BuyMemberTraffic` (controller is the provider), which creates a
`MemberTraffic` contract; the SV then reconciles the sequencer limit. The only
coupon minted today is the `ValidatorRewardCoupon` reward byproduct of the burn
(`AmuletRules.daml:288`, `2238-2242`). The handshake and the end-of-timeslot
usage report are net-new.

## 5. Commitment

Staking + tracking + duration + a penalty if you do not draw down enough. No
staking or commitment tracking tied to traffic exists today; this is net-new.

## 6. Transaction classes and prices (proposed)

Three classes with a governance vote on a fixed discount:

- Composed across multiple apps (indicated by different provider parties, or
  composing across synchronizers): non-discounted, $1.00.
- Single app, multiple validators: $0.30.
- Internal to a named list of (max 5) validators: $0.10, capped at $500k/year.

Plus a governance vote on a fixed discount.

Note vs today: the pricing config is a single global `SynchronizerFeesConfig`
("same fees across all active decentralized synchronizers",
`DecentralizedSynchronizer.daml:25`), one `extraTrafficPrice` in $/MB, byte-linear
with no transaction-class dimension. Per-transaction-class pricing and
per-synchronizer pricing are both net-new.

## 7. Splice capabilities

What Splice provides today:

- SV node admin.
- SV Global-Synchronizer governance voting.
- CC app: minting, burning, rewards.
- Canton Name Service (CNS / ANS).
- Connectivity and upgrades.

## 8. Node anatomy (from the code)

### Validator Node
Composed of:
- Validator App (Splice)
- Participant (Canton)

(Also serves the wallet UI and the ANS/CNS UI.)

Validator App responsibilities:
1. Traffic top-ups (`TopupMemberTrafficTrigger`; disabled on SV validators).
2. Global-synchronizer sequencer connection (`ReconcileSequencerConnectionsTrigger`).
3. Reward collection. Note: this is reward *collection*
   (`ReceiveFaucetCouponTrigger`, wallet `CollectRewardsAndMergeAmuletsTrigger`),
   not "monitoring"; the reward *metric* lives in the SV app.

### Super Validator Node
Composed of all of the Validator Node, plus:
- SV App
- Scan App
- Sequencer + Mediator (bundled as one `sequencer-mediator` service; the Mediator
  was missing from the original notes)
- BFT ordering (CometBFT, or the Canton BFT sequencer)

SV App responsibilities:
- Governance (`ExecuteConfirmedActionTrigger`, `CloseVoteRequestTrigger`).
- Reward issuance / processing. Note: the CIP-104 reward *computation* pipeline
  actually runs in the Scan app (`RewardComputationTrigger`); the SV app does
  issuance/processing.
- Coupon issuance (`ReceiveSvRewardCouponTrigger` + coupon expiry/merge).
- Lifecycle (SV onboarding/offboarding; Logical Synchronizer Upgrade triggers).
- Traffic management (`ReconcileSequencerLimitWithMemberTrafficTrigger`,
  `SvOnboardingUnlimitedTrafficTrigger`, `MergeMemberTrafficContractsTrigger`).
- Same as the validator app (it runs a validator app in SV mode).

### Target: Extension Sequencer
First-part MVP is to modify SV Splice and Canton to create an "Extension
Sequencer" that is a stripped-down Global Synchronizer. What we need from the SV
side for the extension sequencer:
- From the SV App: the traffic-management functionality.
- Validator app.
- Participant.
- Sequencer + Mediator + BFT.

## 9. 2026 workstreams

### Workstream 1: MVP of a no-discount extension
- Add a sync-id field to the Daml traffic-purchase contract. Note: this is
  already present in Splice 0.6.11. `synchronizerId` and `migrationId` are
  carried end-to-end: `MemberTraffic` (`DecentralizedSynchronizer.daml:61-62`),
  `AmuletRules_BuyMemberTraffic` (`AmuletRules.daml:272-273`), `CO_BuyMemberTraffic`
  (`Install.daml:261-262`), `BuyTrafficRequest` (`BuyTrafficRequest.daml:39-40`),
  `ValidatorTopUpState` (`TopUpState.daml:21-22`). The real MVP work is
  per-synchronizer pricing and pointing traffic reconciliation at a non-global
  sequencer, not adding the field.
- Extract the traffic-management functionality from the SV app into a reusable
  module. Targets: SV side `ReconcileSequencerLimitWithMemberTrafficTrigger`,
  `SvOnboardingUnlimitedTrafficTrigger`, `MergeMemberTrafficContractsTrigger`,
  `LsuTransferTrafficTrigger`; validator side `TopupMemberTrafficTrigger` +
  wallet `TopupUtil`.
- Build a Sync Operator Node:
  - Participant connected to both the Global Synchronizer and the extension sync.
  - Centralized (single-node) sequencer.
  - Listens to traffic purchases with the correct sync id.
  - Tops up traffic on the extension sync.
  - Manages logical sync upgrades (need not be in step with those on the global
    sync).
- App rewards:
  - Figure out a model. Likely: the sync operator reports every round on total
    traffic on the extension. Note: no per-round total-traffic report exists
    today (traffic is tracked per-member as `MemberTraffic`, or per-verdict under
    CIP-104); this is net-new.
  - Rewards capped at 0.9 x burn. Note: no burn-ratio cap exists today; issuance
    is a fixed annual amount split by percentages with per-coupon USD caps
    (`Issuance.daml:18-30`). A 0.9 x burn cap is net-new.
- Validator rewards: on any traffic purchase, regardless of which sync id it is
  for. Note: confirmed correct today; `splitAndBurn` mints a
  `ValidatorRewardCoupon` on every purchase without reference to `synchronizerId`.

### Workstream 2: PoC of differential discounting and rewards
Proof-of-concept for the transaction-class discounts (Section 6) and the
associated reward model.

## Reconciliation with the circulated design doc

A second-hand "Traffic Manager" design doc was circulated. Its low-level plumbing
is largely accurate, but its central economic model is superseded: it describes a
private sync that self-funds traffic with its own coin, with the CC burn on the
global sync as a decoupled "tribute" that grants no traffic and is reported only
in aggregate. Per this meeting, the authoritative model is the CC-funded model in
Section 1: the CC burn actually grants traffic on the extension sync, per
purchase, keyed by sync id. That reverses the doc's "do not reuse MemberTraffic"
argument, since granting traffic per purchase makes the existing
`MemberTraffic` + `ReconcileSequencerLimitWithMemberTrafficTrigger` flow (pointed
at the extension sequencer) the natural basis. See
[2026-07-08-traffic-manager-doc-review.md](2026-07-08-traffic-manager-doc-review.md)
for the detailed, line-referenced review.
