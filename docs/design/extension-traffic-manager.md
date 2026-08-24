<!-- Synced from the shared Google Doc "Dedicated Synchronizer Traffic Manager" on 2026-08-24.
     Converted from the .docx export, so this is the doc's current text, not the repo's earlier
     edit of it. The Google Doc remains the live artifact; 87 open comments are NOT captured here
     (see the comment extract). Rendered diagram images dropped; the mermaid sources they
     duplicate are kept. -->

# Dedicated Synchronizer Traffic Manager

This document describes how a dedicated synchronizer (a synchronizer stood up with the Splice software and run by an operator such as a Super Validator) can participate in the Canton Coin (CC) economy of the global synchronizer.

Claims about current behavior are grounded in Splice 0.6.11 / Canton.

## 1. Summary

Traffic on a dedicated synchronizer is funded by burning CC on the global synchronizer. Each purchase names the dedicated synchronizer’s id, and the participant (memberId) for which traffic credits are purchased, and that burn grants real, enforced sequencer traffic on the dedicated synchronizer.

This generalizes the existing global-synchronizer flow. Today a validator burns CC via AmuletRules_BuyMemberTraffic, a MemberTraffic record is created, and a Super Validator reconciles it into the member's sequencer traffic limit. This proposal applies that same flow to a dedicated synchronizer: the burn happens on the global synchronizer, and the traffic grant is applied on the dedicated synchronizer by its operator, which reconciles it onto the sequencer (its 'Sync Operator Node').

## 2. Motivation

There are two motivations, near-term and longer-term.

Near-term, economic alignment. A dedicated synchronizer run by a separate operator has no economic link to the global CC economy. Transactions on it consume sequencer traffic, but nothing is burned in CC on the global synchronizer, so the dedicated synchronizer does not contribute economically to the network. We want dedicated synchronizer traffic to be funded in CC, in the same way global synchronizer traffic is, so every dedicated synchronizer is economically aligned with the rest of the Canton network. This is the no-discount MVP (Workstream 1); it reuses machinery that largely exists today.

Longer-term, a competitive market for synchronizers. Once traffic across all synchronizers is funded in CC, differential discount tokenomics (throughput, commitment length, and transaction class) let synchronizer operators compete on price and terms to host synchronizers. Operators can offer different rates and discounts; clients and users choose the synchronizer that best fits their needs and can move between synchronizers freely as those needs change. The discounts are the market mechanism, not just a pricing convenience: they let a free market of operators form around a common, CC-denominated settlement layer. This is the differential-discounting PoC (Workstream 2), built on top of the MVP.

The analogy is synchronizers are like ISPs: users of Canton will be able to choose which synchronizer to connect to, operators will compete for that connectivity on price and service, and users will switch providers freely as their needs change, all while paying for the service in the same underlying currency (CC).

## Functional Requirements

### Synchronizer lifecycle

<table>
<colgroup>
<col style="width: 9%" />
<col style="width: 8%" />
<col style="width: 69%" />
<col style="width: 12%" />
</colgroup>
<thead>
<tr>
<th style="text-align: left;">#</th>
<th style="text-align: left;">Phase</th>
<th style="text-align: left;">Requirement</th>
<th style="text-align: left;">Fulfilled by User Story</th>
</tr>
<tr>
<th>FR-1</th>
<th>P2</th>
<th>A dedicated synchronizer may be registered on Mainnet by its Synchronizer Operations (SO) party without a Super Validator vote, and the registration is publicly readable.</th>
<th>conflict</th>
</tr>
<tr>
<th>FR-2</th>
<th>P2</th>
<th>A Validator may connect to the Global Synchronizer and to one or more dedicated synchronizers concurrently, with traffic on each synchronizer metered and priced under that synchronizer's own parameters.</th>
<th>1.6, 1.7, 1.8</th>
</tr>
<tr>
<th>FR-3</th>
<th>P2</th>
<th><p>A dedicated synchronizer continues sequencing transactions when the Global Synchronizer is unavailable; economic obligations accrue locally and settle on restoration, within a parametrized grace period. To allow this, dedicated synchronizers are allowed to accumulate negative traffic balance if the Global Synchronizer is unavailable. When reconnecting to the Global Synchronizer, the dedicated synchronizer must pay for the negative traffic balance as though it were an ongoing traffic purchase with its discounts applied.<br />
<br />
Two cases:</p>
<ul>
<li><p>Unplanned outages of the gSync and unplanned disconnections of a dedicated synchronizer</p>
<ul>
<li><p>Basic model: pre-purchase at least 1 day (required) based on trailing average usage</p></li>
<li><p>Require immediate top-up of any negative balance, then repurchase 1-day balance, when reconnecting</p></li>
<li><p>Dedicated synchronizer must report its Validators’ traffic balances upon reconnection.</p></li>
<li><p>If disconnected for more than 1 day, possibly penalties may apply (TBD)</p></li>
</ul></li>
<li><p>Intentional separate operation of a dedicated synchronizer for a planned period (probably Phase 3)</p></li>
</ul></th>
<th>missing</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

### Traffic purchase and consumption

| # | Phase | Requirement | Fulfilled by User Story |
|----|----|----|----|
| FR-4 | P2 | To increase the traffic balance assigned to a given Validator for use on a given dedicated synchronizer, a party must burn CC on the Global Synchronizer in the name of that Validator and that dedicated synchronizer. | 2.4, 2.5 |
| FR-5 | P2 | The SO party may purchase traffic on behalf of any Validator linked to a given dedicated synchronizer, and record that traffic balance on the sequencer of that dedicated synchronizer in the name of that Validator. Any linked Validator may also purchase its own traffic directly on the Global Synchronize use on a dedicated synchronizer, and any party may act as paymaster for another. | 2.4, 2.5 |
| FR-6 | P2 | Every dedicated synchronizer tracks consumption of traffic assigned to that synchronizer for any Validator linked to it. | 2.6, 2.7 |
| FR-7 | P2 | Traffic may be purchased at a discount based on transaction rates, but it is still metered on the sequencer in terms of megabytes sequenced. Transaction rates serve as input to discount calculations, but not for traffic metering. | 2.6, 2.7 |
| FR-8 | P2 | Canton Coin is burned at the prevailing conversion rate from the existing SV-generated price feed. | 2.5 |
| FR-9 | P2 | Each purchase records the synchronizer, tier, base rate, discounts applied, and the resulting effective rate; the Canton Coin burned for the purchase, and whether the purchase is reward-eligible — sufficient for any third party to recompute the price from chain data. | Unclear / 2.5 |

### Flat fee and tiers

| # | Phase | Requirement | Fulfilled by User Story |
|----|----|----|----|
| FR-10 | P2 | Every dedicated synchronizer burns a parametrized flat platform fee, initially $250K per year, pro-rated by time registered. The flat fee is a pure burn: no traffic credits, no reward eligibility, and it counts toward the org-internal cap. Stated otherwise, the cap is $750k in traffic: $1 million, less this base fee, | 4.1 - 4.4, and 5.1 - 5.4 |
| FR-11 | P3 | Traffic on a dedicated synchronizer is charged at one of three tiers — composed, app-internal, or org-internal — each a separately governed rate, initially calibrated to 200¢, 150¢ and 10¢. Org internal traffic involves traffic among Validators controlled by the same organization that controls the dedicated synchronizer. App-internal traffic involves Validators all using the same app to process a given transaction, via a synchronizer controlled by the app provider. Composed transactions involve Daml models provided by more than one app provider. |  |
| FR-12 | P3 | The Global Synchronizer keeps a single rate for all traffic, with no tiers, no discounts, no flat fee and no commitments. |  |

### Discounts

| # | Phase | Requirement | Fulfilled by User Story |
|----|----|----|----|
| FR-13 | P2 | Super Validator governance may set a fixed percentage discount for a named dedicated synchronizer by configuration vote. It never applies to the Global Synchronizer, defaults to zero, and takes effect prospectively. | Missing |
| FR-14 | P3 | A throughput discount multiplies price by 0.5 ^ log10(sustained TPS) — every 10× of sustained throughput halves the price — measured as a trailing average over a parametrized window, initially one week. |  |
| FR-15 | P3 | A duration discount multiplies price by 0.5 × 0.75 ^ log2(years) for an opt-in commitment of one year or more: 50% off at one year, a further 25% off per doubling of term. |  |
| FR-16 | P3 | Throughput discounts are calculated based on trailing activity, while duration discounts depend on a committed throughput over the specified duration. The pure throughput discount and the duration discount apply separately, with the duration discount multiplied by the current throughput discount based on recent activity history. A high burst in throughput may lead to a higher short-term throughput discount without altering the duration discount. (To remove any possible uncertainty: org-intenal transactions must not count toward throughput discounts for app-internal or composing traffic purchases). |  |
| FR-17 | P3 | List price requires no commitment and no stake. |  |
| FR-18 | P3 | A commitment may be aggregated across multiple dedicated synchronizers. For example, if an operator runs four dedicated synchronizers, and expects to average 25 tps on each, that operator may make a commitment of 100 tps, which will result in a discount at the 100 tps level that is applied to all four of these dedicated synchronizers. |  |
| FR-19 | P3 | Duration commitments may be increased during the commitment period, but not reduced. For example: an operator who commits to 50 tps for 1 year may, at any given month, choose to increase their commitment, and related stake, to 100 tps, but they may not reduce their commitment to 25 tps during the commitment period. |  |

### Commitments and staking

| # | Phase | Requirement |  |
|----|----|----|----|
| FR-18 | P3 | A duration-based commitment requires staking Canton Coin worth 20% of committed spend, with the Canton Coin amount fixed at commitment time. |  |
| FR-19 | P3 | For a duration-based discount, when traffic meets the committed rate for the time period, the stake is untouched. Below the committed rate, the stake automatically purchases the missing traffic at the committed throughput rate, creating a forced purchase rather than a penalty. |  |
| FR-20 | P3 | If traffic stays below 80% of the committed rate for more than one week the commitment terminates. The discount ends and the remaining stake burns at the committed rate, generating no traffic credits and no rewards. At term end, any unburned committed stake is returned to the operator. |  |
| FR-21 | P3 | An operator may raise or extend a commitment mid-term by staking the increment, re-priced prospectively. |  |
| FR-22 | P3 | Commitment terms, stake, trailing throughput and status are publicly readable, so committed future burn and total value locked are computable from chain data. |  |

### Org-internal cap

| # | Phase | Requirement | Fulfilled by User Story |
|----|----|----|----|
| FR-23 | P3 | Org-internal spend, including the flat platform fee, is capped at a parametrized amount — initially $1M per rolling 12 months. Beyond the cap, org-internal traffic is free. |  |
| FR-24 | P3 | The cap lifts automatically at a parametrized interval after the full pricing model takes effect on Mainnet, default value two years, with no vote and no operator action. The start date and the expiration for this cap will be set via an onchain vote made by the Global Synchronizer Super Validators at the start of Phase 3. |  |

### Rewards and enforcement

| # | Phase | Requirement | Fulfilled by User Story |
|----|----|----|----|
| FR-25 | P2 | Reward eligibility attaches when traffic credits are used, not when they are purchased. The flat platform fee and all org-internal traffic are excluded from reward eligibility and are purely deflationary. | Missing/move to Phase 3? |
| FR-26 | P2 | Burn-mint recirculation and the four reward pools (DevFund, SVs, validators and apps) are unchanged. An operator cannot override the reward split on its own synchronizer, and no pool is created for or reallocated to dedicated synchronizer operators. | Missing/move to Phase 3? |
| FR-27 | P2 | A dedicated synchronizer reports total transactions, average transactions per second, and total traffic consumed to the Super Validators of the Global Synchronizer over a parametrized timeframe. This report is signed by the dedicated SO party and reconcilable against settled burn. | Missing/move to Phase 3? |
| FR-28 | P2 | A dedicated synchronizer operator cannot obtain sequencing capacity without the corresponding burn, or alter the reward rates, discounts or transaction type (org-internal, app-internal, composed) that are declared by the synchronizer operator and verified by the Global Synchronizer Super Validators, without patching the software. Where a SO circumvents the code, the on-chain record makes the discrepancy detectable. | Missing/move to Phase 3? |

### Governance and compatibility

| # | Phase | Requirement | Fulfilled by User Story |
|----|----|----|----|
| FR-29 | P2 | Every rate, discount curve constant, stake percentage, threshold, cap, window and cadence in this model is an on-chain governance parameter amendable by Super Validator configuration vote, effective prospectively, with no bilateral negotiation. | Missing |
| FR-30 | P2 | Global Synchronizer users see no change to price, reward mechanics or purchase flow; all changes for dedicated synchronizers are additive, and existing deployments migrate on their own schedule rather than by a forced date. | Missing |

## 3. Background: the traffic model today

Validators burn CC ahead of time to accrue a purchased traffic balance before they can submit transactions to a sequencer.

- Purchasing is a DAML transaction. The buyer (the provider ) burns CC from its own balance inside the DSO-signed AmuletRules contract; the DSO is the signatory of AmuletRules but does not itself burn the coin. The choice is AmuletRules_BuyMemberTraffic (AmuletRules.daml:266-306, controller = provider), which burns CC and creates a MemberTraffic contract. The payer (provider, a party) and the credited participant (memberId, a participant id) are separate arguments, with nothing tying them together. So one party can buy traffic for a participant it does not operate. In the common self-service case, the provider is the operator party of the participant.

- Purchased traffic is monotonically increasing. It is preserved across a Logical Synchronizer Upgrade (LsuTransferTrafficTrigger carries the sequencer traffic state to the successor) and is scoped per migrationId (a new migration id starts fresh).

- The sequencer accumulates consumed traffic (bytes) per member. Consumed traffic is not on-ledger; it lives in the sequencer database, but is guaranteed to be consistent between sequencers in a decentralized synchronizer setting such as the global synchronizer (append-only table seq_traffic_control_consumed_journal, exposed via the TrafficConsumed record with extraTrafficConsumed, baseTrafficRemainder, and lastConsumedCost, TrafficConsumed.scala:34).

- Enforcement: a submission is rejected when availableTraffic < eventCost, where availableTraffic = (extraTrafficPurchased - extraTrafficConsumed) + baseTrafficRemainder (TrafficConsumed.scala:168-172, TrafficState.scala:32-35). The base-rate remainder is a free allowance that replenishes over time; on the global sync its purpose is to avoid a top-up lockout, where a member has too little traffic to submit its own buy-traffic transaction. It is a per-synchronizer Canton parameter (maxbaseTrafficAmount, fed from the Amulet baseRateTrafficLimits); the fill window is a Splice deployment config (baseRateBurstWindowMins: 20), while Canton's own default is 10 minutes (TrafficControlParameters.scala:90).

- On the SV side, MergeMemberTrafficContractsTrigger compacts many MemberTraffic contracts via DsoRules_MergeMemberTrafficContracts, and ReconcileSequencerLimitWithMemberTrafficTrigger reads MemberTraffic, sums getTotalPurchasedMemberTraffic(memberId, synchronizerId), and calls the sequencer admin API SetTrafficPurchased (an absolute new total limit).

Two properties of the current code make the dedicated case small:

- AmuletRules_BuyMemberTraffic is structurally multi-synchronizer aware: it accepts any synchronizerId in requiredSynchronizers (validateBuyMemberTrafficInputs, AmuletRules.daml:1710-1716). There is a caveat, requiredSynchronizers holds only the global sync today, and since dedicated synchronizers register in a separate template (Section 8) rather than being added to it, the choice’s gate needs a splice-amulet change (Section 7).

- getTotalPurchasedMemberTraffic is already keyed per (member, synchronizer, migrationId) (DbSvDsoStore.scala:1649-1671), so summing purchases does not over-count across synchronizers.

## 4. Proposed design: CC-funded dedicated traffic

1.  A buyer (a validator on the dedicated synchronizer, or the Sync Operator (the dedicated synchronizer's operator) buying on behalf of its validators) burns CC on the global synchronizer via AmuletRules_BuyMemberTraffic, passing the dedicated synchronizer's id as synchronizerId and the credited member’s (global) participant id as memberId. memberIds are global participant identities, not synchronizer-specific; it is the synchronizerId argument that scopes the purchase to the dedicated synchronizer (which is why MemberTraffic keys on both).

    Each purchase funds a single member; there is no bulk-buy-and-split (the payer may differ from that member, Section 3). The choice mints the buyer's ValidatorRewardCoupon (via splitAndBurn, AmuletRules.daml:288, 2238-2242) and creates a MemberTraffic record keyed by (memberId, syncId, migrationId), signed by the global DSO.

2.  The Sync Operator observes the purchase and applies it on the dedicated synchronizer's sequencer: it reads the per-member purchased total for the dedicated sync id and calls SetTrafficPurchased.

3.  The member transacts on the dedicated synchronizer’s sequencers, drawing down its dedicated sequencer traffic. Enforcement is local to the dedicated sequencer, using the same availableTraffic >= eventCost rule as any Canton sequencer. On the dedicated synchronizer the base rate is set to zero (no free allowance), so availableTraffic = extraTrafficPurchased - extraTrafficConsumed.
    The global sync's base rate exists only to avoid a top-up lockout; that does not apply here, because dedicated top-ups are granted by the operator through the sequencer admin API (SetTrafficPurchased), not submitted as a member transaction to the dedicated synchronizer. Initial onboarding traffic is likewise granted by the operator rather than drawn from a base rate.

The economic link is intrinsic: dedicated traffic is paid for in CC on the global synchronizer. There is no reporting step in the funding path at all. The per-round activity report belongs to the rewards design (Section 10); it reports activity weights under a root-hash commitment, not aggregate consumed traffic.

**Out of MVP scope (revisit post-MVP / Workstream 2):**

- Decentralizing the dedicated synchronizer. MVP runs a single sequencer + mediator (one operator); BFT (multiple sequencers/mediators, an operator set) is a non-trivial addition left out, though the design should not preclude it.

- Per-synchronizer pricing and transaction-class discounts (Section 9, Workstream 2).

- Commitment / staking and draw-down penalties (Workstream 2).

- The operator app-reward path (Section 10, Workstream 2): the on-ledger reporting and expansion contracts, and the SV-side and operator-side automation around them. None of it is MVP.

- The elaborate announce → SV-approve → coupon → report purchase handshake (Appendix A.D); the MVP uses the direct-burn flow (Section 6).

## 5. Architecture and topology

- For the MVP the dedicated synchronizer is centralized: a single sequencer and mediator, run by a single operator (the "Sync Operator"). The operator runs a participant connected to both the global and the dedicated synchronizer, plus a traffic-management component (the "Sync Operator Node"). Decentralizing it into a BFT synchronizer (multiple sequencers/mediators run by an operator set, mirroring the global synchronizer's SVs, with each operator reconciling its own sequencer) is optional and out of MVP scope; the design does not preclude it, but the MVP does not assume it.

- Connecting one participant to multiple synchronizers is a supported Canton/Splice capability: LocalNet's multi-sync profile cross-connects the app-provider and app-user participants to a second synchronizer while they remain on the global one (cluster/compose/localnet/conf/console/[app-synchronizer.sc:10](http://app-synchronizer.sc:10)), and Canton's integration tests connect a single participant to two synchronizers via connect_local (MultiSynchronizerPingIntegrationTests.scala; cross-synchronizer reassignment in multisynchronizer/ReassignmentSubmissionIntegrationTest.scala requires the same).

- The Sync Operator's participant is onboarded to the global synchronizer as an ordinary validator and holds a CC balance there, so it can buy traffic and pay fees.

## 6. Purchase-to-grant flow

```mermaid
sequenceDiagram
participant B as Buyer (global sync)
participant G as Global ledger
participant S as Sync Operator Node
participant E as Dedicated sequencer
B->>G: AmuletRules_BuyMemberTraffic (synchronizerId = extSyncId)
Note over G: splitAndBurn (CC)<br/>+ ValidatorRewardCoupon<br/>+ MemberTraffic (member, extSyncId)
G-->>S: MemberTraffic (operator = observer), ingested on-ledger (no Scan polling)
S->>E: SetTrafficPurchased (member, newTotalLimit)
```


The MVP has a single operator and sequencer, as shown. If the synchronizer is later decentralized (BFT, out of MVP scope), each operator would run the same step against its own sequencer, replicating the grant across sequencers.

Sourcing the purchased total: the purchase record names the registered operator party as an observer, so the operator’s node ingests it on-ledger, event-driven, with no polling. The observer party comes from the narrow registration mapping ( syncId -> operator party , Section 8); the buy choice looks it up and sets it, so the operator reliably sees every purchase for its sync. Today MemberTraffic is signatory-dso-only with no observers (DecentralizedSynchronizer.daml:57-76), so adding the operator observer is the splice-amulet changed the MVP introduces. The global Scan API getMemberTrafficStatus(...) returns target.total_purchased (scan.yaml:280-316; HttpScanHandler.scala:2288-2325) and remains available for inspection and reconciliation, but the funding path does not poll it.

## 7. Components: reuse and new work

Reused as-is (no core-package change):

- The burn machinery: splitAndBurn (burns CC and mints the ValidatorRewardCoupon, Section 10) and the MemberTraffic record it creates.

- The purchased-total query, already per-(member, synchronizer).

- Scan's getMemberTrafficStatus for inspection and reconciliation (not the primary sourcing path).

New work:

- **Buy-choice gate:** AmuletRules_BuyMemberTraffic today accepts only synchronizerId ∈ requiredSynchronizers (validateBuyMemberTrafficInputs), which is currently just the global sync. Since dedicated synchronizers are registered in a separate template (Section 8), not added to requiredSynchronizers, the choice needs a splice-amulet change to accept registered synchronizers and to set the registered operator as an observer on the MemberTraffic it creates (Section 6). The submitter supplies the RegisteredSynchronizer contract via explicit disclosure so the choice can read the operator party.

- **Reconcile trigger:** generalize ReconcileSequencerLimitWithMemberTrafficTrigger (today hard-wired to the SV's own local sequencer, guarded to the connected domain, skipping SV members) so the Sync Operator runs a variant that (a) targets the dedicated sequencer's admin connection, (b) filters to the dedicated sync id, (c) sources purchased totals from the operator observer on the traffic record (Section 6), and (d) calls SetTrafficPurchased. It should not hard-wire a single sequencer, so a later BFT synchronizer can run one reconciler per sequencer as on the global sync (out of MVP scope).

- **Sync-id parse hardening:** both traffic triggers parse the sync id with a throwing tryFromString; make them skip-not-fail. MergeMemberTrafficContractsTrigger already scopes merges per (member, synchronizerId) (MergeMemberTrafficContractsTrigger.scala:56-59), so this hardening is all it needs (no merge rework).

- **Register the dedicated synchronizer:** a governed syncId -> operator party mapping (Section 8), and set that operator as an observer on the traffic record (Section 6). A splice-amulet / splice-dso-governance change.

- **Operational (MVP):** Helm charts for a non-global synchronizer and operator docs; and LSU management on the dedicated sync by the operator node (its logical upgrades need not track the global sync's).

- **Per-synchronizer pricing and rewards** paths are separate from the MVP (Sections 9, 10; Appendix B). The reward path splits into the on-ledger half (report state, start-processing gates, weighted expansion; Section 10) and the automation half (SV-side tranche split, weight, rate, timeout, and reported-vs-purchased sourcing; operator-side activity records, durable tree storage, report and expansion triggers).

## 8. Registration and governance

A dedicated synchronizer is registered once, by governance, before traffic can be funded for it. Registration splits into two parts:

- **Narrow registration (MVP)**: a governed syncId -> operator party mapping (plus lifecycle state). This is the minimum the funding path needs. The buy choice reads the operator party from the RegisteredSynchronizer contract (attached to the purchase transaction via explicit disclosure) and sets it as the observer on the traffic record (Section 6), so each operator reliably ingests every purchase for its sync, and reward attribution has a trusted operator identity. It is a one-time per-synchronizer onboarding vote.

- **Rate/discount governance (Workstream 2)**: the governed per-synchronizer rate. Not needed for the no-discount MVP (Section 9).

Why a mapping and not just the sync id: a synchronizer id has the form name::namespace, where the namespace is the fingerprint of the operator's (often decentralized) signing key, so the operator is identifiable from the id. But a namespace fingerprint is not a usable Daml Party, and you need a concrete party to set as an observer or to credit rewards. The mapping supplies that. It does not belong in the purchase: a buyer-supplied operator party could be wrong or spoofed, breaking delivery and rewards.

Mechanics: track a registered synchronizer in a dedicated template, not by reusing requiredSynchronizers. That field means "the synchronizers Amulet and ANS users should be connected to" (DecentralizedSynchronizer.daml:22) and code likely relies on that meaning, so overloading it for "synchronizers that support traffic purchases" is risky. Instead, a dedicated RegisteredSynchronizer template holds the registered synchronizer's id, operator party, and lifecycle state, updated through a dedicated governance voting flow rather than by editing an AmuletConfig struct field. Splice already has a governed per-synchronizer map on the DSO side (DsoDecentralizedSynchronizerConfig.synchronizers, lifecycle state only, no operator party), but every synchronizer there is DSO-operated; the net-new piece is this operator-party registry. Because governance votes dispatch a closed set of actions (ActionRequiringConfirmation, DsoRules.daml:68-80; dispatch :1772-1807), the registry template plus a new voting action (a new SRARC_-style variant and choice) live in the core splice-dso-governance package. A submitter obtains a sync's operator party from Scan and attaches the RegisteredSynchronizer contract to the purchase transaction via explicit disclosure, so the buy choice can read the operator party (and confirm the sync is registered) without the submitter being a stakeholder. This is the same disclosed-choice-context pattern Scan already provides for token-standard choices.

**Offboarding.** Registration is reversible by the same route it was granted: a governance vote archives the RegisteredSynchronizer. Because the buy choice and the reward start-processing choice both read a live registration, archiving it stops both paths at once: no further traffic can be purchased for that synchronizer, and any activity report it has already filed, or files afterwards, becomes unprocessable (Section 10). Offboarding is therefore also the reward path's kill switch.

The reporting state (DedicatedSynchronizerState, Section 11) deliberately survives the archive, so the running total ever reported is retained for audit rather than destroyed by an offboard vote. That leaves one operational rule: **clean up the old reporting state before re-registering the same synchronizer.** Registration creates a fresh state contract, so re-registering while the previous one is still live leaves the operator holding two states for the same synchronizer, and the per-round monotonicity check is enforced per state, which would let the same round be reported twice. Nothing on-ledger prevents this today; it is a DSO automation responsibility.

## 9. Pricing

The fee config is a single global SynchronizerFeesConfig on AmuletDecentralizedSynchronizerConfig.fees ("same fees across all active decentralized synchronizers", DecentralizedSynchronizer.daml:25), with one extraTrafficPrice in $/MB shared across all requiredSynchronizers. The byte to CC conversion is computeSynchronizerFees:

trafficCostUsd = bytes / 1e6 * extraTrafficPrice

trafficCostAmulet = trafficCostUsd / amuletPrice



(AmuletRules.daml:1719-1729; the round's trafficPrice overrides the config price when set.)

For the no-discount MVP, the dedicated synchronizer uses the existing single global extraTrafficPrice, and the MVP(narrow) registration records no rate. Per-synchronizer pricing (a governed per-sync rate) is the rate/discount half of registration (Section 8) and, with the transaction-class discounts, belongs to the differential-discounting workstream. It would require making fees per-synchronizer (a splice-amulet schema change).

## 10. Rewards

There are two reward paths: validator rewards, which the existing purchase flow already provides, and app rewards, which need the reporting design below.

- Validator reward: AmuletRules_BuyMemberTraffic mints a ValidatorRewardCoupon on every purchase, regardless of synchronizer id (the ValidatorRewardCoupon creation inside splitAndBurn, AmuletRules.daml). A dedicated-synchronizer purchase goes through that same choice (Section 4), so it mints this coupon like any other purchase; validator rewards at purchase time need no new mechanism.

<!-- -->

- Why app rewards need their own path: activity on a dedicated synchronizer is invisible to the SVs. On the global synchronizer, app activity is derived from mediator verdicts and sequencer traffic summaries, so every SV independently recomputes the result and confirms an exact match. The SVs do not run the dedicated sequencer or mediator, so no recomputation is available; the activity is reported by the operator and bounded rather than verified.

- Reporting model: each dedicated synchronizer has a DedicatedSynchronizerState contract, signed by the DSO with the operator as observer, carrying the last reported round and a running total of all activity ever reported. An operator-controlled choice records a per-round report of (round, activityRootHash, totalActivity): a Merkle root hash committing to the round's per-provider activity, plus the round's total activity as a sum of weights. Rounds must be strictly increasing (one report per round, no back-filling a skipped round), the running total accumulates, and each report produces a per-round ExtensionActivityReport contract for the SV side to act on. Registration creates the state contract, so a registered synchronizer can report from day one. (net-new: no per-round activity report and no such state contract exist today.)

- Start-processing: a governance vote consumes the report and creates the root reward-processing contract for the synchronizer's tree. The vote's choice enforces three gates on-ledger: the report must match a live RegisteredSynchronizer (same synchronizer id and operator, so an offboarded synchronizer's pending reports are inert); the issuance rate must be positive; and reported activity must not exceed purchased traffic. The purchased figure is supplied by the vote as an SV-attested value rather than fetched from MemberTraffic inside the choice.

- Expansion to coupons: this reuses the reward-processing machinery that exists today (ProcessRewardsV2 and its batch expansion, RewardAccountingV2.daml:61,75) as a parallel entry point; CalculateRewardsV2 and the global path are untouched. ProcessRewardsV2 gains three optional fields, appended last so that absent values preserve today's behavior exactly: the expander party (the operator, who becomes observer and expansion controller), the issuance rate per activity unit, and a weight budget. A new weighted batch variant lets each internal tree node commit to its children's weights, the budget is threaded down the tree so every subtree's declared weights must fit within it, and a leaf's coupons are minted at amount = activity weight x issuance rate. The operator expands its own tree, since it holds the batch pre-images; a wrong pre-image fails the hash check exactly as on the global path. (net-new: today only the DSO party acts on reward-processing contracts, and no weighted batch variant exists.)

- The bound chain this yields, end to end: CC minted <= sum of committed weights <= reported total activity <= purchased traffic. The operator controls the internal attribution of its reported activity but cannot mint more than its synchronizer's users paid for in burned CC.

- SV-side responsibilities (off-ledger automation, not contracts): splitting the per-round app-reward tranche across synchronizers by burn proportion; applying an SV-voted per-synchronizer weight; computing the issuance rate from tranche, weight, and reported totals; sourcing the purchased figure and comparing as of round end; flagging violators (on-ledger a breach simply fails the vote); and the report timeout: a synchronizer that has not reported one tick after round close counts as zero for that round. Because the start-processing gate requires a positive rate, a 0% rate is not expressible; the kill switch for a suspect synchronizer is offboarding, which archives its registration (Section 8) and makes its reports unprocessable. The existing global-synchronizer reward automation must also skip reward-processing contracts that carry an expander, since it can neither serve nor control them; without that guard it retries them indefinitely.

- Operator-side responsibilities (off-ledger automation): computing per-round activity records from the dedicated synchronizer's own sequencer and mediator data; building and durably storing the Merkle tree (a lost pre-image makes a round unexpandable, as does a malformed commitment such as a zero-weight leaf or a node that declares more weight than its budget); reporting within the timeout; and running the expansion. The operator's own cut is expressed by self-attributing activity (a leaf whose provider is the operator); no on-ledger policy constrains the internal distribution, and the permitted policies remain to be decided.

- Featured apps (proposed, not settled): the intent is that the dedicated synchronizer's operator decides which apps are featured on its own synchronizer, with inheriting the global synchronizer's featured-app rights supported as the default mode. Featuring only affects how a reported total is attributed inside a synchronizer, so it is bounded by the same open question as the operator cut: what internal-distribution policy is permitted (Section 14). (net-new: featuring is DSO-wide today.)

- Reward eligibility boundaries: org-internal traffic and the flat platform fee (Section 9, Appendix C) are pure burn and earn no rewards. Reward pools themselves are unchanged: this design extends who participates in them, which also implies the extension reward flow draws from the existing issuance rather than adding to it (an open point, Section 14).

- Validator rewards: the purchase-time ValidatorRewardCoupon (first bullet) covers dedicated synchronizers as-is. A separate CIP in flight moves validator rewards to traffic-based issuance ([CIP reference to be added]), the same shift already made for app rewards; when it lands, dedicated synchronizers integrate with it through the same report-driven principle, and its relationship to the purchase-time coupon (replacement or reconciliation) is open (Section 14).

The SV-side and operator-side automation above belongs to the differential-discounting workstream. The source notes for this design are in Appendix A.H.

## 11. Data model

- MemberTraffic (DecentralizedSynchronizer.daml:57-76) is the purchase record, keyed by (memberId, synchronizerId, migrationId). Its reconcile side effect (turning a purchase into a sequencer traffic grant) is exactly what we want, applied to the dedicated sequencer.

- Visibility: the MVP adds the registered operator as an observer on the traffic record (a splice-amulet change), so each operator ingests its purchases on-ledger without polling; the operator party comes from the registration mapping (Section 8). Scan remains for inspection.

- The reward path adds its own contracts, separate from the funding path: DedicatedSynchronizerState (per synchronizer, DSO-signed, operator observer; carries the last reported round and the running total ever reported; created by registration), the per-round ExtensionActivityReport, and three optional fields appended to ProcessRewardsV2 (expander party, issuance rate, weight budget) plus a weighted batch tree variant. Absent values in the new fields preserve today's global-synchronizer behavior exactly. (net-new: none of these exist today.)

## 12. Trust model

The global side records that CC was actually burned (authoritative, via splitAndBurn) and the purchased amount. The dedicated synchronizer's operator honors the purchase by granting the corresponding traffic on its sequencer, and consumption is enforced locally there. For the MVP the operator is a single trusted party (the synchronizer is centralized). If it is later decentralized (BFT, out of MVP scope), trust moves to the operator set represented using a decentralized operator party, exactly as the global synchronizer trusts its SVs; the design supports that but the MVP does not require it. Because the purchase is CC-funded and the grant is a real sequencer limit, the funding path has no under-provisioning reconciliation problem.

The funding path and the reward path do not share a trust model. Funding is authoritative on the global side, because the burn is recorded there and the purchased total is on-ledger. The reward path is not: activity on the dedicated synchronizer is invisible to the SVs, so they cannot recompute a reported figure and can only bound it. The bound chain is: CC minted <= the weights committed in the report's tree <= the reported total <= purchased traffic, with the last comparison made against an SV-attested figure at vote time, plus governance offboarding as the off switch (Section 10).

## 13. Observability (Scan)

- getMemberTrafficStatus(domain_id, member_id) returns actual (live total_consumed, total_limit from the sequencer) and target (total_purchased) (scan.yaml:280-316; HttpScanHandler.scala:2288-2325). Its actual fields read from the sequencer that Scan is attached to, so for a dedicated sync global Scan can serve only target.total_purchased (from the MemberTraffic on the global ledger); total_consumed/total_limit live on the dedicated sequencer, which the global DSO does not run and the operator may keep private.

- Dedicated-oriented Scan endpoints (net-new) expose only the global ledger *funding) side and OMIT consumed: list registered synchronizers, per-sync purchased/burned totals, and the RegisteredSynchronizer mapping / disclosed contract a buyer attaches to a purchase. Standard extension pattern: register the template in the ACS filter and add endpoints (ScanStore.scala:382; scan.yaml; HttpScanHandler.scala). The funding path is driven by the on-ledger observer (Section 6).

- Consumption visibility is the dedicated synchronizer operator's choice: it may expose consumed traffic read from its own sequencer, or keep it private; it is not available from global Scan. The reward path does not depend on it. What the SVs bound a report against is purchased traffic, which is already on the global ledger, and the report itself (root hash, per-round total, running total) is also on the global ledger, so reported-vs-purchased is publicly checkable per synchronizer (Section 10).

## 14. Open questions

- Operator party representation: the operator is registered (Section 8) and set as the traffic-record observer (Section 6); open is whether that operator party is a single party or a decentralized party for a BFT synchronizer, and how the registry relates to requiredSynchronizers.

- Operator lifecycle: how governance offboards or bounds a registered operator-run synchronizer (decommission, revoke), mirroring the DSO-side lifecycle states.

- Rewards: the app-reward model for the operator (per-round reporting, the proposed 0.9 x burn cap), and whether it needs aggregate consumption reporting.

## Appendix A: broader design context

Design context beyond the traffic-funding mechanism above. Items marked (net-new) do not exist in Splice 0.6.11 today; items marked (today) are grounded in current code.

### A. Open questions to specify

- Traffic management on a non-global synchronizer.

- How to burn CC to obtain traffic (the Splice mechanism).

- How much CC buys how much traffic (the Splice conversion).

- Transaction types: the protocol characterizes a transaction and draws traffic from the appropriate bucket; Splice configures the protocol with the types and rates. (net-new: Canton traffic is byte-based with no tx-class concept today, EventCostCalculator.scala:109-146.)

- Agreement to purchase traffic.

- Price of traffic.

- Commitment.

- State.

### B. Discount types (proposed)

All discounts apply on dedicated synchronizers only, not the global synchronizer, for now. They stack multiplicatively on the class base price (Appendix C), and every knob is on-chain configuration set by governance. The proposed curve is smooth, with no cliffs.

- Throughput: every 10x of sustained synchronizer throughput halves the price; factor 0.5 ^ log10(tps). Illustrative: 1 TPS = 200c, 10 = 100c, 1,000 = 25c, 100,000 = 6.25c gross.

- Duration (commitment): opt-in; committing 1 year takes 50% off, and each doubling of duration takes a further 25% off; factor 0.5 x 0.75 ^ log2(years) (1y 50%, 2y 62.5%, 3y ~68.3%, 4y ~71.9%). Backed by staking (Appendix E). List price requires no staking.

- Governance discount: a flat percentage discount on any of the prices, set by vote. Available earlier than the two curves above (see Section 9 on phasing).

Break-even vs the global synchronizer is about 10 TPS at list and just above 1 TPS with a 1-year commitment. There is no price floor in the proposed model.

(Implementation note: the proposed curve is smooth; Daml decimal arithmetic accumulates rounding error on stacked exponentials, so quote-vs-charge consistency needs an agreed evaluation precision or a tabulated approximation when this is put on-ledger.)

(net-new: pricing today is a single global byte-linear extraTrafficPrice with no class or discount dimension, DecentralizedSynchronizer.daml:36-46.)

#### Discount Types - technical definitions

###### Throughput

Throughput is reported in bytes (we use TPS as a high-level description to make it easier to understand but track throughput in bytes at a technical level) each round by the synchronizer operator as part of the reporting they already do for rewards. Note that the throughput is reported as the actual traffic consumed not the sum of activity records (so it’s not affected by unfeatured transactions or featured app weights).

DSO automation uses the reported throughput in the last X ticks to adjust the throughput discount.

DSO automation checks that the total amount purchased for a synchronizer is <= total reported. So a malicious synchronizer operator can report the burn too early or delay it but not change the total burn which is acceptable.

###### Duration

Synchronizer operator stakes for their synchronizer on mainnet for expected throughput in bytes. They need to stake 20% of the committed spend for their target throughput.

If burn falls below the committed spend (measured on a trailing weekly average), the remainder is burnt from the stake to purchase traffic. The traffic is purchased for participant ids configured by the synchronizer operator. The synchronizer operator can configure up to 20 participant ids and the percentage split between those. If this is the case for one week, the discount is lost and the stake is burnt with nothing in return.

###### Utility

Utility (composed, app-internal, org-internal) is a synchronizer-level property set by the synchronizer operator and self-reported on mainnet.

Configuring to org-internal will limit the number of participants that can connect to the synchronizer to 20.

Configuring to app-internal will only allow one participant hosting a party that is featured on mainnet to connect.

### C. Transaction classes and prices (proposed)

List prices before discounts. The global synchronizer stays at a flat 100c with no tiers and no discounts; dedicated synchronizers carry a premium at list and earn it back through the discounts (Appendix B).

- Regular (across orgs and apps, e.g. a bond-vs-cash DvP): 200c on a dedicated synchronizer, double the global synchronizer's 100c.

- App-internal (many parties, one app, e.g. a stablecoin transfer): 150c.

- Org-internal (traffic among validators run by the same operator as the synchronizer): 10c, pure burn, not eligible for rewards.

- Flat platform fee: every dedicated synchronizer burns a flat $250k per year, pure burn, no reward eligibility, payable by a paymaster. Below roughly 10 TPS the global synchronizer is cheaper by design.

- Org-internal cap, temporary by design: org-internal spend is capped at $1m per 12 months all-in, with the $250k flat counting toward it; beyond the cap, internal traffic is free. The cap lifts two years after go-live. This cap has drawn the most debate and is the item most open to community input.

### D. Extended purchase sequence (option)

A fuller purchase sequence, more elaborate than the direct-burn flow in Section 7 and entirely net-new:

1.  Provider announces intent to purchase traffic.

2.  SVs see it and ask for the burn.

3.  Provider burns CC.

4.  SVs issue a traffic coupon.

5.  Provider tops up traffic on the synchronizer for its validators, split between them as it sees fit.

6.  Validators transact and draw down their buckets.

7.  At end of the timeslot, the provider reports actual traffic used and makes the next purchase. Open question: what happens if the purchase is not repeated next timeslot.

The Section 6 flow is simpler and sufficient for the MVP; the announce/ask/coupon handshake, provider-driven split, and usage report would only be built if specifically wanted.

### E. Commitment (proposed)

Staking is opt-in and only buys the duration discount; list price requires no staking. It never pays for usage: the stake is a capacitor guaranteeing the committed spend.

- Stake size: 20% of the total committed spend over the term (so a 3-year commitment stakes roughly three times the 1-year figure at the same rate).

- Healthy: users burn at the committed rate; the stake is untouched and returns at the end of the term.

- Brief shortfall: the stake buys the traffic gap, a forced purchase at the committed rate, nothing lost; the operator refills the capacitor.

- Sustained shortfall: below 80% of committed throughput for one week (measured as a one-week trailing average) terminates the discount, and the remaining stake burns at the committed rate, yielding no traffic and no rewards.

- Under consideration, not part of this proposal: an escape hatch where the remaining stake auto-burns into traffic credits expiring at the original commitment's end date.

(net-new: no staking or commitment tracking tied to traffic exists today.)

### F. Splice capabilities (today)

- SV node admin.

- SV Global-Synchronizer governance voting.

- CC app: minting, burning, rewards.

- Canton Name Service (CNS / ANS).

- Connectivity and upgrades.

### G. Node anatomy (today, from the code)

Validator Node = Validator App (Splice) + participant (Canton) (also wallet UI, ANS/CNS UI). Validator App does: (1) traffic top-ups (TopupMemberTrafficTrigger); (2) global-sync sequencer connection (ReconcileSequencerConnectionsTrigger); (3) reward collection (ReceiveFaucetCouponTrigger, wallet CollectRewardsAndMergeAmuletsTrigger).

Super Validator Node = all of the above + SV App + Scan App + Sequencer + Mediator (bundled sequencer-mediator) + BFT (CometBFT or Canton BFT sequencer). SV App does: governance; reward issuance/processing (the CIP-104 reward computation itself runs in Scan, RewardComputationTrigger); coupon issuance (ReceiveSvRewardCouponTrigger); lifecycle (onboarding/offboarding, LSU); traffic management (ReconcileSequencerLimitWithMemberTrafficTrigger, SvOnboardingUnlimitedTrafficTrigger, MergeMemberTrafficContractsTrigger).

Target Dedicated Synchronizer = a stripped-down Global Synchronizer. The MVP is a single sequencer + mediator (centralized); BFT (multiple sequencers + mediators) is optional/post-MVP. From the SV side we need: the traffic-management functionality (extracted); a validator app; a participant; a sequencer + mediator (BFT optional).

### H. Reward Integration (source notes)

The notes below are the original discussion notes, from which Section 10 is written up. The table after them maps each note to where it lands in Section 10 and to the design mechanism it corresponds to.

- mainnet extensions tbar

  - each extension is represented by a single (decentralized) party

  - each round that party reports activity on extension synchronizer on global synchronizer in Daml

    - commitment to root hash and total activity records

      - updates a total ever reported (possibly in registry contract)

    - extension party expands root hash (after svs compute issuance per activity record) on global synchronizer (requires noting that party on the ProcessRewardsV2 contracts)

    - an extension that wants to take a cut can include some percentage of activity to themselves

      - computed as part of ingesting the activity records

      - policies for what you are allowed to do there tbd

  - app reward tranche is split across synchronizers based on the proportion of burn in that round

    - for each synchronizer then issue coupons based on activity like we do for global atm

      - the dedicated synchronizer operator can decide who gets featured on their synchronizer

      - default mode of using the FA rights from GSync must be supported

    - push issuance per activity record into process rewards
      ⇒ coupons get created with actual CC amount

    - as for the featured apps, a dedicated sync weight is managed by the SVs via voting

      - that weight is applied to the reported total activity before splitting the app rewards tranche across synchronizers

      - ⇒ a suspected malicious dedicated sync can be set to 0%

  - svs compare total purchased against total reported for an extension as of round end, if reported > purchased, flag extension as potentially malicious and cap rewards

    - ingest MemberTraffic into tcs

    - track total of activity reported on a DedicatedSynchronizerState contract

  - need some timeout mechanism if extension does not report in time

    - e.g. if not reported on-ledger 1 tick after round close, count as zero

      - timeout on CalculateRewards

  - validator rewards

    - only makes sense after validator-based app rewards, otherwise same principle

  - TODO from discussion

    - need to reweight reported amount by purchase price

| **Note** | **Section 10 bullet** | **Design mechanism** | **Status** |
|----|----|----|----|
| One (decentralized) party per extension | Reporting model | the operator party on DedicatedSynchronizerState (a plain party; decentralizing it is not modeled) | in the design |
| Reports activity per round in Daml | Reporting model | the operator-controlled report choice on DedicatedSynchronizerState | in the design |
| Commitment to root hash and total activity records | Reporting model | ExtensionActivityReport carrying (activityRootHash, totalActivity); the total is a weight sum, not a record count | in the design |
| Updates a total ever reported (possibly in registry contract) | Reporting model | the running total on DedicatedSynchronizerState; kept off the registry to leave RegisteredSynchronizer stable | in the design |
| Extension party expands root hash, noted on the ProcessRewardsV2 contracts | Expansion to coupons | an expander party appended to ProcessRewardsV2, observer and expansion controller | in the design |
| Extension can take a cut, computed while ingesting records, policies tbd | Operator-side responsibilities | a leaf whose provider is the operator; no on-ledger policy | representable; policy open |
| App reward tranche split across synchronizers by proportion of burn | SV-side responsibilities | collapsed on-ledger into the vote-supplied issuance rate | SV-side |
| For each synchronizer, issue coupons based on activity as for global today | Expansion to coupons | leaf expansion mints coupons at weight x rate | in the design |
| Operator decides who is featured on their synchronizer | Featured apps | per-synchronizer featuring authority | net-new, open |
| Default mode of using the FA rights from GSync | Featured apps | operator-side default | deferred |
| Push issuance per activity record into process rewards, coupons with actual CC | Expansion to coupons | the issuance-rate field; coupons carry a resolved CC amount | in the design |
| Dedicated sync weight managed by SVs via voting, applied before the split | SV-side responsibilities | feeds the same vote-supplied rate | SV-side |
| Suspected malicious sync can be set to 0% | SV-side responsibilities | not expressible as a rate (must be positive); the off switch is archiving the registration (Section 8) | differs from notes |
| SVs compare total purchased against total reported, flag + cap | Start-processing | reported <= purchased enforced at start-processing against an SV-attested figure; no on-ledger flag, the vote fails | partly on-ledger |
| Ingest MemberTraffic into tcs | SV-side responsibilities | the temporal contract store (TcsStore / DbTcsStore), single-synchronizer today (DbTcsStore.scala:21-28) | SV-side |
| Track total reported on a DedicatedSynchronizerState contract | Reporting model | as named | in the design |
| Timeout if not reported one tick after round close, count as zero | SV-side responsibilities | off-ledger; strict round monotonicity already prevents back-filling on-ledger | SV-side |
| Timeout on CalculateRewards | SV-side responsibilities | the extension flow does not go through CalculateRewardsV2, so the timeout lives SV-side | differs from notes |
| Validator rewards, only after validator-based app rewards | Validator rewards on reported activity | sequenced second; double-count question open | open |
| TODO: reweight reported amount by purchase price | Section 14 open questions | belongs at the purchased-vs-reported comparison, which today would compare traffic bytes against activity weights | open |

## Appendix B: 2026 workstreams

### Workstream 1: MVP of a no-discount dedicated synchronizer (phase 2 in CIP)

- **Traffic purchases work the same on every synchronizer:**

  - Records carry the synchronizer id and migration id end to end (MemberTraffic DecentralizedSynchronizer.daml:62-63, AmuletRules_BuyMemberTraffic AmuletRules.daml:272-273, CO_BuyMemberTraffic Install.daml:262-263, BuyTrafficRequest:39-40, ValidatorTopUpState TopUpState.daml:21-22).

  - Every purchase mints a ValidatorRewardCoupon whichever synchronizer it is for (AmuletRules.daml:2280, coupon at :2305).

- **A reusable traffic-management module**:

> Generalize ReconcileSequencerLimitWithMemberTrafficTrigger to run per operator against its own sequencer, selecting purchases by sync id from the on-ledger observer, and parse the sync id safely (skip-not-fail). MergeMemberTrafficContractsTrigger already scopes merges per (member, synchronizerId). Already in PR(#14 & #15)

**Estimate: ~1 week (review and merge). Target: Aug 17 - Aug 21.**

- **Register the dedicated synchronizer.**

  - A syncId -> operator party mapping created by a DSO vote.

> (done, PRs #1/#2)

- The buy choice accepts a registered synchronizer and funds its traffic with Canton Coin, otherwise limited to requiredSynchronizers (AmuletRules.daml:1763). (done, PR #2)

- Served so a buyer can pass it by explicit disclosure, the only way the buy choice reads it (DecentralizedSynchronizer.daml:144-146). (Daml choice done; nothing serves it yet, canton-extending-mainnet#41/#42)

- Offboard via DSO vote: archiving the registration closes the buy path (nothing to disclose) and the reward path (start-processing requires the live registration). (Daml approved, not merged, PR #12)

- Uniqueness of the mapping is enforced off-ledger, an SV-UI duplicate check at proposal time (canton-extending-mainnet#54, MVP work), with the offboard vote as the recovery for a duplicate that slips through.

> **Estimate: ~1.5 weeks. Target: Aug 17 - Aug 26.**

Note: The governed per-synchronizer rate is deferred to Workstream 2.

- **Dedicated purchases are recorded correctly:** Keep migration id at 0 the whole way, including the top-up state (TopupMemberTrafficTrigger.scala:235, AmuletRules.daml:1774-1778, Install.daml:166); ingest records with an operator set (SvDsoStore.scala:1470, ScanStore.scala:383). Scan's buy-member-traffic tx-log parsing is being removed upstream, so re-check how a dedicated purchase is reported after we rebase off 0.6.12. (ingestion is #60; the top-up pinning is untracked).

> **Estimate: ~0.5 week. Target: Aug 17 - Aug 20.**

- **The Sync Operator Node:**

  - Runs a participant connected to both the global and the dedicated synchronizer.

  - Sums purchases carrying its sync id and grants the total on its own sequencer via setSequencerTrafficControlState.

  - Grants unlimited traffic to its own mediator, which has no way to buy any, as SvOnboardingUnlimitedTrafficTrigger does for SVs. The operator's participant is not given a blanket grant: it buys like any other, so an operator whose participant also runs an app does not get that app's traffic free.

  - Dedicated sync permission: configure onboardingRestriction = RestrictedOpen from the start and manage it by operator, one ParticipantSynchronizerPermission per participant. Splice already has the switch but only on the global-sync path (SvAppConfig.scala:355, SV1Initializer.scala:470-472, :493-500). The synchronizer starts permissioned, and that's one field in the initial dynamic synchronizer parameters at bootstrap.

> Note: One sequencer and a single operator party in MVP; BFT (multiple sequencers/mediators, a decentralized operator party) is out of scope but not precluded.

**Estimate: ~3 weeks. Target: Aug 27 - Sep 17.**

- **Base rate of zero on the dedicated sequencer**: so all usage is funded. maxBaseTrafficAmount is a NonNegativeLong and never a divisor, so 0 is legal. Confirm which onboarding process is the blocker for this, Probably setSequencerTrafficControlState might need to allow creating members sequencer has never seen before. The operator grants first, and the joiner spends that grant to submit its trust certificate. If it rejects, the member has to be registered first, and registration happens at onboarding, which itself costs traffic. That is the only loop we can find

**Estimate: ~0.5 week. Target: Sep 14 - Sep 17.**

- **Automatic top-ups:**

  - Generalize TopupMemberTrafficTrigger to buy for each synchronizer, with its own threshold and amount, and funds checked across both. The global minTopupAmount floor still applies.

  - The dedicated synchronizer's top-up state is created on the global synchronizer; creating it on the dedicated one needs the traffic it is buying.

  - CO_BuyMemberTraffic (Install.daml:259-265) and BuyTrafficRequest must carry the registration, plus the wallet API and frontend.

**Estimate: ~2 weeks. Target: Aug 27 - Sep 10.**

- **Upgrading the dedicated synchronizer** **on the operator's own schedule:**

  - Serve the successor sequencer's connection details, which validators get from Scan today (listDsoSequencers).

  - Preserve sequencer ids across the upgrade, or validators will not roll forward (RollForwardLsuTrigger.scala:103-105) & Copy members' leftover traffic to the new sequencer (LsuTransferTrafficTrigger).

  - Use LSU, not migration ids.

**Estimate: ~1.5 weeks. Target: Sep 21 - Oct 2.**

- **Governance-voted per-synchronizer discount:** a fixed percentage set by SV vote that applies multiplicatively to that dedicated synchronizer's traffic price only, never to the global synchronizer, as the CIP's temporary bridge until the Phase-3 discount logic lands. RegisteredSynchronizer is already the per-synchronizer governance record, so a discount field on it set by the same vote is the natural home, and is much smaller than making fees per-synchronizer.

**Estimate: ~0.5 weeks. Target: Sep 11 - Sep 15**

- **Flat platform fee ($250k/year per dedicated synchronizer) (todo, design not settled):** the CIP requires a pure burn that buys no traffic credits and carries no reward eligibility, counts toward the org-internal cap, and may be paid by a paymaster on the operator's behalf. It should be paid over time rather than as one lump sum, and a synchronizer whose fee lapses should stop working. The requirements are clear; the mechanism is in todo - will update once finalized.

**Estimate: ~1.5 weeks. Target: Oct 12 - Oct 23**

- **Setup and deployment:** -

  - Bootstrapping: how a dedicated synchronizer is created at all. Namespace and keys, sequencer and mediator initialization, the initial topology, and the first dynamic parameters, plus what the operator node automates versus what a person does through the Canton console. The SV app has an equivalent (SynchronizerNodeInitializer, SV1Initializer) but it assumes DSO governance rather than a single operator. (est ~1 week)

    A local two-synchronizer topology to verify everything against, and what the e2e test module runs on. Needed before base rate 0 and acceptance can be checked at all. -

    A Helm chart for the synchronizer (sequencer, mediator, database) and one for the Sync Operator Node (participant, database, app), usable for LocalNet, DevNet and MainNet. The base rate and onboarding restriction are dynamic synchronizer parameters set by topology, not chart values.

    Operator docs: bring-up, registration, permissioning, preserving sequencer ids across upgrades, and the connection details validators need.

> **Estimate: ~4.5 weeks. Target: local topology Aug 27 - Sep 10; charts and docs Sep 18 - Oct 7.**

- **Acceptance:** Register, connect a validator, submit before and after buying, and let a top-up fire on its own; repeat past a global-synchronizer migration (dedicated-sync records and top-up state survive it) and across an LSU upgrade of the dedicated synchronizer and verify everything with an e2e test module.

**Estimate: ~3 weeks. Target: Sep 21 - Oct 16.**

- **Migrating a Phase-1 synchronizer:** Phase 1 deploys dedicated synchronizers without economic changes, so live ones have to be brought onto the economy in place. No/Limited downtime is needed if the order holds: register, flip the onboarding restriction, get traffic bought and granted for every existing member, then set base rate 0 last. Restricting onboarding is additive, since RestrictedOpen is only checked when a new participant onboards (TopologyMappingChecks.scala:575). Base rate 0 is the disruptive step, and the only outage risk is missing a member before it flips.

**Estimate: ~0.5 weeks. Target: Oct 23 - Oct 27**

### Workstream 2: PoC of differential discounting and rewards (todo) (phase 3 in CIP)

- Per-transaction-class characterization: teach the protocol to classify a transaction and draw from the right bucket/rate (net-new; no tx-class concept in Canton traffic today).

  The three pricing classes and the governance-voted fixed discount (Appendix A.B and A.C).

  Per-synchronizer pricing: make SynchronizerFeesConfig/extraTrafficPrice per-sync rather than a single global value (a splice-amulet schema change).

  Commitment / staking: staking + tracking + duration + a draw-down penalty (Appendix A.E).

  Rewards, per Section 10: the on-ledger half (the per-round activity report and its DedicatedSynchronizerState, the expander/rate/budget extension of the reward-processing contracts, and the weighted batch tree with its reported-vs-purchased gate); the SV-side automation (tranche split by burn proportion, per-synchronizer weight, purchased-figure sourcing, report timeout); the operator-side automation (activity records, durable tree storage, report and expansion triggers); and the reweighting of reported activity by purchase price. (net-new: none of this exists today; the coupon-minting pipeline it plugs into does.)

## Appendix C: User Stories / Test Cases

This section lays out the explicit scenarios that we expect to work in Phase 2 (MVP, 2026 deliverable)

### Dedicated Sync Registration

1.  Off-ledger: an organization interested in operating a dedicated synchronizer contacts some SV, indicates their interest, and provides a syncId (TBD: just any string?) and their (the SO) party ID

2.  Off-ledger: the SVs (via the tokenomics committee ?) agree on the discount for this synchronizer

3.  Some SV creates a vote proposal to register a synchronizer with the provided Sync ID, SO ID and discount (note that this will be extended in phase 3 to non-voted registrations)

4.  The SVs vote to accept the proposal

5.  Once accepted and effective, automation on some SV:

    1.  Creates a RegisteredSynchronizer contract signed by the DSO and observed by the SO, which records the fact that this synchronizer is approved, its SO party ID, and the approved discount

    2.  Creates a SynchronizerFeeState that indicates the flat fee has been paid until now.

6.  The SO submits a transaction to pay x days of platform fee by burning (annualFee / 365 * x) CC, where x is between some dso-configured min and max (e.g. between one round and a full year).

    1.  This transaction archives the SynchronizerFeeState and create a new one with paidThrough extended by x (from its previous value).

7.  The SO spins up a (centralized) synchronizer node, and a sync-operator app, connected to a participant that hosts the SO party.

8.  The sync-operator app sees the RegisteredSynchronizer contract, and initializes the dedicated synchronizer. The synchronizer is initialized to be a permitted synchronizer.

### 2. Traffic Purchase and Transacting on the Dedicated Sync

Prerequisite: A dedicated sync syncId has been initialized and registered; Some validators is spun up and initialized (not necessarily connected to any synchronizer)

1.  Off-ledger: A validator that is interested in transacting on the dedicated sync contacts the SO, and asks to be permissioned on it, providing its participantId

2.  The SO configures the synchronizer (TBD: by some UI? Admin call to the sequencer? API in the sync-op app?) to permission this participant

3.  The participant may now connect to the dedicated synchronizer

4.  Initially, the participant’s traffic balance on the dedicated sync is zero (no free traffic on dedicated sync), and any transaction submitted on the dedicated sync must fail

5.  Someone submits a transaction on the gSync to purchase traffic for participantId on the dedicated sync (identified by syncId), providing the current RegisteredSynchronizer and SynchronizerFeeState contracts (exposed via explicit disclosure from Scan)

    1.  The daml code for the transaction confirms that paidThrough is later than now.

    2.  A MemberTraffic contract is created (or replaced) indicating the amount of traffic purchased for participant participantId and synchronizer syncId. The SO is an observer on this contract.

6.  The SO’s participant observes the MemberTraffic contract. Automation on the sync-operator app sees it, and updates participantId’s traffic balance on the sequencer (via the sequencer’s admin API) to be amountBurnt / (gSyncTrafficPrice x registeredDiscount) (for example, if the gSync traffic price is $60 / MB, a dedicated sync with 50% discount would credit for $60 burnt (in CC) 60 / (60 * 0.5) = 2 MB of traffic)

7.  The participant submits traffic to the dedicated sync, and traffic is drawn down on the sequencer just like it is on the gSync, i.e. a transaction of size 1MB uses up 1MB of traffic balance.

8.  The validator app of the participant can also be configured to auto-topup traffic for the dedicated sync, similarly to the corresponding configuration for the gSync. This automatically submits transactions as in step (5) when needed.

9.  Explicitly: There is NO prevention against a malicious SO topping up balances manually without paying for traffic

### 3. Auto-Permissioning

**TBD: set priority. Itai: I suspect this is nice-to-have, or even out-of-scope**

1.  SO admin configures the dedicated Sync to auto-permissioning mode

2.  A validator that is interested in transacting on the dedicated sync purchases traffic for that validator on the dSync (or someone purchases it for them)

3.  SO app notices the traffic purchase, and automatically permissions the validator for this synchronizer

### 4. Flat Platform Fee: Happy Path: Alternative A

**Note: This is an alternative, to be discussed, see Alternative B below (difference is step 4.4)**

Prerequisite: A dedicated sync syncId has been initialized and registered

1.  Some party submits a transaction to burn (x * annualFee / 365) CC for synchronizer syncId

2.  paidThrough on the SynchronizerFeeState of the synchronizer is increased by x days (regardless of its current value, i.e., if it was 7 days in the past, and one day is paid, it’s only increased to be 6 days in the past)

3.  Any traffic purchase transaction for the dedicated synchronizer must fail if paidThrough for that synchronizer is before now

4.  Traffic submitted to the dedicated synchronizer will succeed for participants with enough traffic balance, regardless of the state of SynchronizerFeeState at time of submission

Note: the total paid is not tracked, it is guaranteed to be 250k/year for a functional sync, so even for future use cases of including that in a cap, one can simply assume a flat 250k/year burn

### 5. Flat Platform Fee: Happy Path: Alternative B

**Note: This is an alternative, to be discussed, see Alternative A above (difference is step 5.4)**

Prerequisite: A dedicated sync syncId has been initialized and registered

1.  Some party submits a transaction to burn annualFee / 365 CC for synchronizer syncId

2.  paidThrough on the SynchronizerFeeState of the synchronizer is increased by x days (regardless of its current value, i.e., if it was 7 days in the past, and one day is paid, it’s only increased to be 6 days in the past)

3.  Any traffic purchase transaction for the dedicated synchronizer must fail if paidThrough for that synchronizer is before now

4.  Enforcement (for honest sync nodes and validators):

    1.  Automation in the sync-operator app observes paidThrough, and when that time is reached, configures the sequencer to not accept further transactions. When a new SynchronizerFeeState is created with paidThrough in the future, the sequencer is (automatically) enabled again.

    2.  Validators poll the fee state from Scan, and similarly configure their participants to not transact on a synchronizer whose fees are not up-to-date.

Note: the total paid is not tracked, it is guaranteed to be 250k/year for a functional sync, so even for future use cases of including that in a cap, one can simply assume a flat 250k/year burn

### 6. Sync Upgrades

Prerequisite: A dedicated sync syncId has been initialized and registered, a new Splice release with protocol changes is released

1.  The (human) SO sees in release notes of Splice that a new release is available which requires an LSU

2.  At their convenience, but before the next such Splice release is available (e.g. within a month), the operator initiates an LSU via the sync-operator app, indicating the freeze time and upgrade time

3.  The sync-operator app coordinates the LSU automatically, just like the SV app coordinates it for the gSync

4.  Participants connected to both gSync and dedicated sync work seamlessly with both, regardless of which synchronizer upgraded first (and whether or not they upgraded at the same time), as long as they are not more than 1 protocol version apart.
