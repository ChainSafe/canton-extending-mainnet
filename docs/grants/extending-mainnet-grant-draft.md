## Development Fund Proposal

**Author:** Sebastian Lindner (Outer Sunset \- A Five North subsidiary) and Wayne Collier (Digital Asset)  
**Status:** Draft   
**Created:** 2026-09-15   
**Label:** tokenomics   
**Champion:** Shaul Kfir   
**SIG alignment:** Canton Protocol & Multi-Synchronizer, Tokenomics

---

## Abstract

Canton Mainnet runs one burn-mint economy, and that burn-mint economy runs on one synchronizer. Every other synchronizer on Mainnet sits outside Canton Coin tokenomics, historically under enterprise license fees that are being phased out as the stack is open-sourced. The CIP "Extending Mainnet: Tokenomics Alignment Across the Entire Canton Network" closes that gap. This proposal funds the implementation.

The deliverable is the Daml, Scala, and operational work that lets a dedicated synchronizer participate in the Canton Coin economy: its traffic is funded by burning CC on the Global Synchronizer, its operator grants the purchased traffic on its own sequencer, and its pricing is governed on-chain by Super Validator vote. The work ships into `canton-network/splice-multi-sync`, a Splice feature fork, under the same Apache 2.0 license and the same CI as Splice itself, and upstreams into Splice.

Delivery is in two phases matching the CIP:

- **CIP Phase 2 (M1 to M6), target end of October 2026.** A dedicated synchronizer joins the economy at Global Synchronizer rates, with an SV-voted per-synchronizer discount. This phase delivers on-ledger registration, CC-funded traffic purchases, a dSync Operator application that turns traffic purchases into enforced sequencer traffic, Scan visibility, and dSync deployment mechanics.  
- **CIP Phase 3 (M7 to M12), target mid-March 2027.** The full pricing model: consumption reporting, the dedicated base price and its org-internal carve-out, the two discount curves, commitments backed by staked CC, the org-internal cap, and app-reward distribution for dedicated-synchronizer activity.

An eleventh milestone covers ratification alignment. The CIP is in draft and carries eight open questions, so keeping the implementation matched to what actually ratifies is work in its own right rather than a contingency.

---

## Delivery team

This is a joint application by Digital Asset and Outer Sunset.

- **Outer Sunset** will own the core development of Phases 2 and 3.   
- **Digital Asset** will be responsible for project management, technical design reviews, test design, integration, CI and test on the Continuous Integration Long Running (CILR) and DevNet networks, and release coordination across Phases 2 and 3. Digital Asset will also be responsible for detailed code reviews, but that work is covered under an existing Maintenance grant.  

---

## Specification

### 1. Objective

Put every synchronizer on Canton Mainnet on the same Canton Coin burn-mint economy.

Today a validator burns CC through `AmuletRules_BuyMemberTraffic` to buy sequencer traffic on the Global Synchronizer, and the Super Validators all record that purchase by updating the Validator’s traffic balance. That flow is the economic link between using Canton and contributing to it, but it exists for just one synchronizer.

The objective is to generalize it: any dedicated synchronizer's traffic is funded by burning CC on the Global Synchronizer, priced under on-chain governance parameters, and recorded by that synchronizer's operator on its sequencers. 

### 2. Implementation mechanics

**The funding path.** A buyer exercises `AmuletRules_BuyMemberTraffic` on the Global Synchronizer, passing the dedicated synchronizer's id as `synchronizerId` and the credited participant id as `memberId`. The choice burns CC through `splitAndBurn`, mints the buyer's `ValidatorRewardCoupon`, and creates a `MemberTraffic` record keyed by `(memberId, synchronizerId, migrationId)`. Two properties of the existing code make this tractable: the buy choice is already structurally multi-synchronizer aware, and `getTotalPurchasedMemberTraffic` is already keyed per member, synchronizer, and migration id.

**Registration.** In CIP Phase 2, the first deliverable from this grant, a dedicated synchronizer is registered by Super Validator governance vote, which records a `syncId` to operator-party mapping in a `RegisteredSynchronizer` contract signed by the DSO party. The buy choice reads that contract, supplied by the submitter through explicit disclosure, to confirm the synchronizer is registered and to learn the operator party. A synchronizer id has the form `name::namespace` where the namespace is a key fingerprint, so the operator is identifiable from the id but not usable as a Daml party; the mapping supplies the party. Registration is reversible by the same route, and archiving it closes the buy path.

In CIP Phase 3, this registration will be automated, and will not require a Super Validator governance vote. 

**The governance surface.** Splice's Super Validator governance application renders each governance action as its own form, so every action and every parameter used in CIP Phase 2 needs matching work in that application: a form to raise the vote request, the fields for the parameter, validation at proposal time, and rendering on the review and listing screens. That work will be included in each milestone that introduces a parameter.

**Delivery to the operator.** The buy choice sets the Synchronizer Operator as an observer on the `MemberTraffic` created by that choice, so the operator's Validator node records every purchase for its synchronizer on-ledger and event-driven, with no Scan polling. 

**The grant.** A new Splice application running on the Synchronizer Operator’s Validator node, the sync operator app (`apps/syncoperator`), sums purchases for that synchronizer id and calls `SetTrafficPurchased` on that synchronizer’s sequencer, through the Validator’s Admin API. Dedicated synchronizers run at base rate zero, so all usage must be funded. 

**Pricing.** In CIP Phase 2 dedicated traffic will be priced at the Global Synchronizer rate, multiplied by a per-synchronizer discount factor that Super Validator governance sets by vote on the registration contract. This is the CIP's interim governance discount. Phase 3 introduces an automated discount calculation that includes two discount curves: one discount for volume and a second for committing to use more than a minimum for a given duration.  

**Consumption and enforcement.** Consumed traffic lives in the dedicated sequencer's database, which the Super Validators do not run and cannot recompute. Phase 3 closes that gap with an operator-signed on-ledger consumption report, reconcilable against settled burn, which then feeds discounts and application rewards. 

Stack: Daml (SDK 3.4.8) for on-ledger contracts, Scala for app automation and triggers, Helm and Docker for deployment, Docker LocalNet for end-to-end testing.

### 3. Architectural alignment

This work extends existing Splice machinery. The burn mechanism, the purchase record, the reward coupon, the reconciliation trigger, the reward-processing pipeline, and the traffic-control parameters are all reused. The net-new functionality is a registration template with a governance action, an operator observer on the purchase record, an operator-run variant of the reconciliation trigger, and in Phase 3 a consumption report and automated pricing.

Against the Foundation's current priority areas:

- **Scaling the network.** Multi-synchronizer architecture is the substance of this work. It gives the ecosystem an economically coherent way to balance load between the Global Synchronizer and more dedicated capacity, which is a scaling path Canton's architecture already assumes.  
- **Stability and maintainability.** All changes are additive and schema-compatible.   
- **App building and developer experience.** Simplified traffic accounting is a named priority. Phase 3's per-purchase pricing records make the price of any purchase recomputable by a third party from chain data.  
- **Security and resilience.** The trust model is stated explicitly and bounded: funding is authoritative on the Global Synchronizer because the burn is recorded there, while reported consumption is bounded rather than verified, with governance offboarding as the off switch.

Relevant CIPs: the Extending Mainnet CIP (economic design), and CIP-0079 (the CC/USD price feed this reuses for conversion). This work will also build on the final version of traffic-based app rewards (the pending replacement for CIP-0104), once that approach is finalized. Traffic purchases will comply with Token Standard V2 (CIP-0112).

### 4. Backward compatibility

Global Synchronizer users see no change to price, reward mechanics, or purchase flow. This is a requirement of the CIP and a constraint on every change here.

- All Daml changes are backwards compatible under Splice's upgrade checker: new fields on released serializable types are `Optional` and appended last, and new variant constructors follow the nullary rule rather than adding fields to existing ones.  
- The Global Synchronizer, and any synchronizer in `requiredSynchronizers`, is priced and gated exactly as today. The discount is absent by construction rather than by a check, because a required synchronizer has no registration to carry one.  
- Existing dedicated synchronizers deployed under CIP Phase 1 join the economy in place through a documented migration path, with no rebuild and no forced date.

Adoption of any Daml change on Mainnet requires a Super Validator supermajority vote. That is a timing dependency this grant tracks as a delivery risk.

---

## Milestones and deliverables

### CIP Phase 2: one economy (M1 to M6)

#### Milestone 1: On-ledger registration and CC-funded traffic purchase

- **Estimated delivery:** Six weeks after Grant Approval  
- **Focus:** The on-ledger foundation. A synchronizer can be registered by vote, and its traffic can be funded in CC.  
- **Deliverables:** `RegisteredSynchronizer` template with public read path; register and offboard governance actions in `splice-dso-governance`; `AmuletRules_BuyMemberTraffic` extended to accept a registered synchronizer by explicit disclosure; registered operator set as observer on `MemberTraffic`; migration-id policy for dedicated synchronizers; proposal and review forms in the SV application for the register and offboard actions.  
- **Residual:** registry uniqueness enforced off-ledger as a duplicate warning in the SV application at proposal time, with the offboard vote as recovery for a duplicate that slips through; merge automation grouping purchases per operator as well as per member and synchronizer.  
- **Acceptance:** Super Validators can register a dedicated synchronizer by vote and revoke it by vote, raising and reviewing both from the SV application rather than by assembling a payload by hand. Any party can fund traffic for a validator on that synchronizer by burning CC on the Global Synchronizer, and the purchase is visible to the synchronizer's operator on-ledger without polling. A synchronizer that is not registered cannot have traffic purchased for it. Demonstrable by a reviewer on LocalNet.  
- **Amount:** 1.0M CC

#### Milestone 2: Sync operator app, traffic reconciliation, and observability

- **Estimated delivery:** Three months after grant approval.  
- **Focus:** Purchases become enforced sequencer traffic on the dedicated synchronizer, visible and buyable through the interfaces the ecosystem already uses.  
- **Deliverables:**   
  *Granting traffic*: a reusable member-traffic reconciliation trigger, extracted from the Super Validator path so an operator runs it against its own sequencer; the sync operator app; per-member purchased totals filtered by synchronizer id and granted through `SetTrafficPurchased`; base rate zero on the dedicated sequencer, with unlimited traffic for the operator's own mediator, which has no way to buy any.   
  *Buying it*: per-synchronizer validator auto top-up with its own threshold and amount, funds checked across every configured synchronizer; the wallet API and frontend carrying a registration through the buy path.   
  *Seeing it*: registrations indexed and served by Scan and the scan proxy, so a buyer can obtain the disclosure blob a purchase requires; per-synchronizer purchase and burn aggregation; `getMemberTrafficStatus` corrected for dedicated synchronizer ids; operator metrics and dashboards. Throughout, a foreign or unparseable synchronizer id is skipped rather than thrown on.  
- **Residual:** traffic bought for a member before it joins the synchronizer is currently never granted, and the store filters still throw on an id they cannot parse rather than skipping it. Both are open defects against this milestone and are named here rather than deferred silently.  
- **Acceptance:** A validator connected to a dedicated synchronizer cannot transact before traffic is bought for it, can transact after, and draws down its balance as it does, including traffic bought before it joined. Auto top-up fires without manual intervention, and the operator's own participant buys traffic like any other rather than receiving a blanket grant. A validator operator buys through the wallet without hand-assembling a disclosure blob. Any third party can read what each dedicated synchronizer has purchased and burned, and an operator can see its own traffic position on a dashboard.  
- **Amount:** 1.0M CC

#### Milestone 3: Per-synchronizer governance discount and the rate pipeline

- **Estimated delivery:** Two months after grant approval  
- **Focus:** The CIP's interim pricing lever.  
- **Deliverables:** Discount factor as a governed field on the registration, set by the same vote that registers the synchronizer, bounded on-ledger to a valid range and surfaced as a field on that vote's form in the SV application; the discount applied multiplicatively to the traffic price at purchase time; enforcement that the discount never applies to the Global Synchronizer; the off-ledger estimate a validator uses before buying kept in agreement with the price the buy charges on-ledger.  
- **Acceptance:** Super Validators can set and change a named dedicated synchronizer's discount by vote from the SV application, taking effect prospectively. Traffic on a discounted synchronizer costs proportionally less CC, and the price of any purchase is recomputable by a third party from chain data. The Global Synchronizer's price is unchanged and cannot be discounted.  
- **Amount:** 1.0M CC

#### Milestone 4: CILR deployment

- **Estimated delivery:** Three months after grant approval  
- **Focus:** The whole flow runs end to end on an internal network, with no external governance dependency.  
- **Deliverables:** Scripted synchronizer bootstrap (sequencer, mediator, initial topology, dynamic parameters including base rate zero and permissioned onboarding from day one); Helm charts for the synchronizer and the sync operator app, usable for CILR, DevNet and Mainnet; a two-synchronizer topology where the dedicated synchronizer runs four sequencer and mediator nodes at a 3 of 4 threshold, so it is exercised as a BFT synchronizer rather than a single node; end-to-end acceptance scenario including cross-synchronizer workflows, and CI integration; upgrade-compatibility gate on Daml changes.  
- **Acceptance:** The end-to-end scenario (register, connect a validator, submit before and after buying, let a top-up fire, run a workflow spanning both synchronizers, survive a Global Synchronizer migration and a dedicated LSU) runs in CI and is reproducible by a reviewer. A node can be lost without taking the dedicated synchronizer down.  
- **Amount:** 1.0M CC

#### Milestone 5: DevNet deployment

- **Estimated delivery:** Four months after grant approval  
- **Focus:** A dedicated synchronizer runs continuously on a shared network, under the ratified CIP.  
- **Deliverables:** The charts deployed on DevNet, running the same four-node topology at a 3 of 4 threshold; operator guide covering bring-up, registration, permissioning, top-up configuration, and offboarding.  
- **Acceptance:** The synchronizer keeps sequencing while the Global Synchronizer is unavailable, and settles once it returns.  
- **Adoption gate:** A dedicated synchronizer registered by governance vote and running continuously on DevNet, funded by CC burn, carrying traffic for validators the operator does not run, deployed from the published charts rather than a development tree. Evidenced on-chain by the registration contract and the associated MemberTraffic records.  
- **Amount:** 2.0M CC (0.5M delivery, 1.5M adoption gate)

#### Milestone 6: Mainnet deployment by a third party

- **Estimated delivery:** Six months after grant approval  
- **Focus:** An operator outside the delivery team runs one in production.  
- **Deliverables:** LSU upgrade runbook preserving sequencer ids and member traffic across the upgrade, so an operator upgrades on its own schedule rather than the Global Synchronizer's; a documented path for bringing an existing dedicated synchronizer onto the economy in place, covering the cases that make it non-trivial (traffic management may have been disabled and never switched on live, or enabled with consumption already ahead of anything purchased, or the synchronizer may be unpermissioned).  
- **Acceptance:** A third party follows only the operator guide and brings a dedicated synchronizer from nothing to registered, permissioned, funded, and carrying enforced traffic. An existing dedicated synchronizer joins the economy with no rebuild.  
- **Adoption gate:** A dedicated synchronizer operated on Mainnet by a party outside the delivery team, funded by CC burn.  
- **Depends on:** the Super Validator vote adopting these changes on Mainnet.  
- **Amount:** 2.0M CC (0.5M delivery, 1.5M adoption gate)

### CIP Phase 3: Self-Registration and Dynamic Pricing (M7 to M12)

Phase 3 milestones depend on ratification of the CIP's Phase 3 dynamic pricing model.

#### Milestone 7: Traffic Consumption reporting and reconciliation

- **Estimated delivery:** Five months after grant approval  
- **Focus:** Traffic consumption on a dedicated synchronizer is invisible to the Super Validators. This reports consumption on-ledger and makes it checkable against what was burned.   
- **Deliverables:** Per-synchronizer report state contract, DSO-signed with the operator as observer; an operator-controlled report choice recording total transactions, average throughput, and total traffic consumed over a window, with strictly increasing windows and no back-filling; an on-ledger definition of a silent synchronizer; report submission automation in the sync operator app; a Scan view reconciling reported consumption against settled burn per synchronizer.  
- **Acceptance:** Any third party can check, per dedicated synchronizer and per round, whether reported consumption exceeds what was paid for in burned CC. A synchronizer that stops reporting is detectable on-ledger. An offboarded synchronizer's reports are inert.  
- **Amount:** 0.75M CC

#### Milestone 8: Dedicated pricing and the org-internal carve-out

- **Estimated delivery:** Five months after grant approval  
- **Focus:** The dedicated base price of $2 enters the rate pipeline, with a carve-out for org-internal synchronizers at 10c and the Global Synchronizer pinned at 100c.  
- **Deliverables:** The dedicated base price as a governed USD-per-megabyte rate calibrated to the median CIP-0112 transfer; the rate function extended to select between the base price and the org-internal rate; org-internal status as a property of the synchronizer recorded on its registration, set when it is registered rather than declared per transaction; enforcement that an org-internal synchronizer stays org-internal, by bounding which participants may connect to it; org-internal traffic excluded from reward eligibility; per-purchase pricing records carrying the rate and applied factors so the price is recomputable; both rates and the org-internal flag exposed as governance parameters in the SV application; a governance action setting that flag on an already-registered synchronizer, so one live under Phase 2 gains Phase 3 pricing without re-registering.  
- **Design point:** org-internal is a property of the synchronizer, not of individual transactions. That removes per-transaction class characterization from the design entirely, and with it the problem that classifying transactions mechanically has always been gameable. The open item is how strictly the carve-out is enforced, from a bounded set of connected validators to a single namespace.  
- **Acceptance:** Traffic on a dedicated synchronizer is priced at the dedicated rate, an org-internal synchronizer at the carve-out rate with no reward eligibility, and the Global Synchronizer's single rate is unchanged. A participant outside the permitted set cannot transact on an org-internal synchronizer. A third party can recompute any purchase's price from chain data alone.  
- **Amount:** 0.75M CC

#### Milestone 9: Throughput and duration discounts

- **Estimated delivery:** Six months after grant approval  
- **Focus:** Throughput and duration discounts, multiplicative on the dedicated base price.  
- **Deliverables:** Curve definitions as governed configuration (throughput at 0.5 per 10x of sustained throughput, duration at 0.5 times 0.75 per doubling of term); the trailing measurement window fed from Milestone 6's consumption reports; curve application inside the single rate function; bounds and floors so stacked exponentials cannot be gamed at a boundary or driven to a degenerate price; an evaluation-precision decision for Daml decimal arithmetic so a quoted price and a charged price agree; the curve constants and measurement window exposed as governance parameters in the SV application, with a proposal-time preview of the price a change produces.  
- **Open question consumed:** the CIP's OQ-1, the measurement window and anti-burst smoothing.  
- **Acceptance:** A dedicated synchronizer's price falls as its sustained throughput rises, on the curve the CIP specifies, measured from its own on-ledger reports. Every quoted discount is reproducible by a third party from published parameters and chain data.  
- **Amount:** 0.75M CC

#### Milestone 10: Commitments, staking, and the org-internal cap

- **Estimated delivery:** Seven months after grant approval  
- **Focus:** The economic obligations that sit alongside per-megabyte pricing. Both reuse the same state-contract and pull-payment pattern.  
- **Deliverables:** Commitment contract recording committed throughput, term, and a CC bond fixed at 20% of committed spend at commitment time; shortfall handling where the bond buys the missing traffic at the committed rate as a forced purchase rather than a penalty, split across operator-configured participant ids; termination when the bond falls below 80% for more than a week, burning the remainder with no credits and no reward eligibility; bond top-up and end-of-term return; org-internal spend accounting and the $1m per rolling 12 months cap, with automatic sunset after two years and no vote required to lift it; the stake percentage, thresholds, cap and sunset exposed as governance parameters in the SV application.  
- **Open questions consumed:** the CIP's OQ-5 (org-internal identification and enforcement) and OQ-7 (commitments against capped traffic).  
- **Acceptance:** An operator can commit to a throughput level, stake against it, and receive the corresponding duration discount. A shortfall purchases the committed traffic from the bond rather than penalizing the operator. Committed terms, stake, and status are publicly readable, so committed future burn and total value locked are computable from chain data.  
- **Amount:** 1.0M CC

#### Milestone 11: Self-registration

- **Estimated delivery:** Seven months after grant approval  
- **Focus:** A dedicated synchronizer is registered without a Super Validator vote.  
- **Deliverables:** A permissionless creation path for the registration, gated by the operator's stake and fee obligations rather than a governance vote; on-ledger uniqueness of the synchronizer id, replacing the duplicate check that today lives in the SV voting UI at proposal time and disappears with the vote; the SV application updated so the vote-based and self-service paths coexist; offboarding unchanged, so governance keeps the ability to archive a registration.  
- **Acceptance:** An operator registers a dedicated synchronizer and begins funding its traffic without a governance vote. Two registrations cannot claim the same synchronizer id. Governance can still offboard a self-registered synchronizer.  
- **Amount:** 0.75M CC

#### Milestone 12: App-reward distribution and Phase 3 acceptance

- **Estimated delivery:** Eight months after grant approval  
- **Focus:** Close the net-cost gap. Until this lands, dedicated-synchronizer burn is gross-cost-identical to the Global Synchronizer but not net-cost-identical, because Global Synchronizer usage recirculates through rewards and dedicated usage does not.  
- **Deliverables:** Per-app activity records extending Milestone 6's report under a Merkle commitment; the reward-processing contracts extended with an expander party, an issuance rate, and a weight budget, appended so absent values preserve today's behavior exactly; a weighted batch tree where each node commits to its children's weights and the budget is threaded down, so minted CC cannot exceed committed weights, which cannot exceed reported activity, which cannot exceed purchased traffic; the vote-gated start-processing flow enforcing a live registration, a positive issuance rate, and the reported-against-purchased bound; operator-side expansion automation with durable tree storage; the Super Validator guard so existing global reward automation skips contracts carrying an expander; a documented path for moving a synchronizer already live under Phase 2 onto the Phase 3 model, within Canton 3.x; Phase 3 end-to-end acceptance across all pricing features.  
- **Scope note:** validator rewards are minted at purchase today, which covers dedicated synchronizers as they stand. A separate change moves them to traffic-based issuance, and when it lands dedicated synchronizers will need to integrate with it. That integration is carried by M13, where its timing dependency already sits.  
- **Open question consumed:** the CIP's OQ-2, whether reward allocation keys off total burn or reward-eligible burn only. Our design note recommends burn-weighted records so that heavily discounted traffic cannot mint the same rewards for a fraction of the burn.  
- **Acceptance:** App providers operating on a dedicated synchronizer earn app rewards for that activity, drawn from the existing pools with the split unchanged and no new pool for operators. The bound chain is publicly checkable per synchronizer and per round. A dedicated synchronizer already live under Phase 2 moves onto Phase 3 pricing in place, with no re-registration and no rebuild. Phase 3 pricing runs end to end in CI.  
- **Adoption gate:** at least one dedicated synchronizer operating on the full Phase 3 pricing model on Mainnet, with at least one connected validator the operator does not run, evidenced on-chain or by Foundation-confidential attestation. Digital Asset operates dedicated synchronizers on this economy long term, so the first adopter is a committed party rather than a forecast. If the Phase 3 Daml changes have not cleared the Super Validator vote by the milestone date, the gate is met to the same standard on DevNet and carries to Mainnet on ratification.  
- **Amount:** 4.0M CC (1.0M delivery, 3.0M adoption gate)

### Milestone 13: Ratification alignment

- **Estimated delivery:** Runs across the term, accepted at its end  
- **Focus:** The CIP is in draft, carries eight open questions, and has not been through community feedback or a vote. Parameters, phasing and enforcement depth will move, and keeping the implementation matched to the text that actually ratifies is continuous work.  
- **Deliverables:** Reconciliation of the implementation against each published revision of the CIP, with divergences identified and either closed or recorded; implementation of ratified answers that differ from the design assumed here; the items deliberately scoped out of M1 to M12 where ratification makes them required, namely settlement of the negative traffic balances a synchronizer accrues while the Global Synchronizer is unavailable, integration with the in-flight move of validator rewards to traffic-based issuance, migration of a synchronizer into or out of org-internal status, and the air-gapped validator good-standing attestation; upstream Splice rebases across the term.  
- **Acceptance:** At term end the delivered implementation matches the ratified CIP, and any remaining divergence is documented with the reason it was left open. Where ratification changed an answer this grant had already built against, the change is implemented or the cost of implementing it is set out for the Committee.  
- **Amount:** 2.0M CC

---

## Acceptance criteria

Each milestone above carries its own criteria. Across the grant, the Tech and Ops Committee will evaluate against:

- **Capability focused.** Every criterion is written as something an ecosystem participant can do that they could not do before, reproducible by a reviewer on LocalNet or verifiable on-chain.  
- **Public verifiability.** Pricing, purchases, registrations, commitments, and reported consumption are readable from onchain data, so third parties can recompute prices and check the reported-against-purchased bound without trusting any operator.  
- **No regression to the Global Synchronizer.** Its price, reward mechanics, and purchase flow are unchanged at every milestone.  
- **Adoption.** Gated at M5, M6 and M12, where adoption first becomes possible.

On the adoption weighting: a third of the request is adoption-contingent, concentrated at the three milestones where adoption is actually possible. The ten build milestones are weighted by the scope each carries, because none of them can have an adopter yet: a dedicated synchronizer cannot join the economy until M6 completes, and it cannot run the full pricing model until M12 does. Attaching nominal adoption numbers to the build milestones would be theatre. Concentrating real money behind the two gates is not: if nothing adopts, three quarters of each of those two milestones does not pay out.

---

## Funding

**Total funding request: 18.0M CC**: 8.0M for Phase 2, 8.0M for Phase 3, and 2.0M for keeping the implementation aligned with the CIP as it ratifies.

| Milestone | Trigger | Amount (CC)  | DA / OS Split (CC) |
| :---- | :---- | :---- | :---- |
| M1: Registration and CC-funded traffic purchase | Committee acceptance | 1.0M | x.xM / x.xM |
| M2: Sync operator app, traffic reconciliation, and observability | Committee acceptance | 1.0M | x.xM / x.xM |
| M3: Governance discount and rate pipeline | Committee acceptance | 1.0M | x.xM / x.xM |
| M4: CILR deployment | Committee acceptance | 1.0M | x.xM / x.xM |
| M5: DevNet deployment | 0.5M delivery, 1.5M adoption | 2.0M | x.xM / x.xM |
| M6: Mainnet deployment by a third party | 0.5M delivery, 1.5M adoption | 2.0M | x.xM / x.xM |
| M7: Traffic Consumption reporting and reconciliation | Committee acceptance | 0.75M | x.xM / x.xM |
| M8: Dedicated pricing and the org-internal carve-out | Committee acceptance | 0.75M | x.xM / x.xM |
| M9: Throughput and duration discounts | Committee acceptance | 0.75M | x.xM / x.xM |
| M10: Commitments, staking, org-internal cap | Committee acceptance | 1.0M | x.xM / x.xM |
| M11: Self-registration | Committee acceptance | 0.75M | x.xM / x.xM |
| M12: App-reward distribution and Phase 3 acceptance | 1.0M delivery, 3.0M adoption | 4.0M | x.xM / x.xM |
| M13: Ratification alignment | Committee acceptance | 2.0M | x.xM / x.xM |
| **Total** |  | **18.0M** | **x.xM / x.xM** |

Adoption-contingent: 6.0M CC, a third of the request.

Milestones are sized by the scope they carry, not by when the work was done. 

### Volatility stipulation

The grant runs longer than six months. It is denominated in a fixed amount of Canton Coin and requires re-evaluation at the six-month mark. If the timeline extends past that point because of Committee-requested scope changes, the remaining milestones are renegotiated for USD/CC price volatility.

---

## Motivation

**The problem is structural, not incremental.** Canton's architecture is multi-synchronizer by design, and applications with premium needs already run their own syncs. Those synchronizers are Mainnet: their transactions compose atomically with everything else on the network. Their economics are not. An operator can run a Mainnet synchronizer, benefit from the shared protocol, security model, and interoperability, and contribute nothing to the ecosystem that maintains them. License fees used to cover that, and they are ending.

**Who benefits.** Every current and future dedicated synchronizer operator, every validator connected to one, and every CC holder through the burn those synchronizers begin contributing. Today the set of synchronizers inside CC tokenomics is one. This work makes that set unbounded. The CIP's own illustrative modelling puts a single dedicated synchronizer at 1,000 TPS at several billion dollars of annual burn; we do not forecast adoption here, but the leverage of moving even one production synchronizer into the economy is large relative to the grant.

**Why it also unlocks scaling.** Load that today must sit on the Global Synchronizer, or sit off the economy entirely, gets a priced path onto dedicated capacity. The discounts are the market mechanism, not a pricing convenience: they let operators compete on price and terms around a common, CC-denominated settlement layer, and let users move between synchronizers as their needs change.

**Timing.** The CIP is in draft and open for community feedback now. Funding the implementation now keeps delivery aligned with ratification rather than serialized behind it.

---

## Rationale

**Why extend rather than replace.** The buy choice, the purchase record, the reward coupon, the reconciliation trigger, and the reward-processing pipeline all exist and all work. Two properties of the current code make the dedicated case small rather than large: the buy choice is already structurally multi-synchronizer aware, and purchased totals are already keyed per member, synchronizer, and migration id. The design deliberately adds a registration template, an observer field, an operator-run variant of an existing trigger, and appended optional fields. It introduces no parallel economy, no second price feed, no new reward pool, and no change to the pool split.

**Why registration is a separate template rather than a config field.** Splice's `requiredSynchronizers` means "the synchronizers Amulet and ANS users should be connected to", and code relies on that meaning. Overloading it with "synchronizers that support traffic purchases" is the kind of reuse that looks economical and produces a subtle regression. A dedicated template with its own governance action keeps the existing meaning intact.

**Why the operator learns about purchases on-ledger rather than by polling.** Setting the registered operator as an observer on the purchase record makes delivery event-driven and removes an off-ledger dependency from the funding path. A buyer-supplied operator party could be wrong or spoofed, which would break both delivery and reward attribution; the governed registration supplies it instead.

**Why Phase 2 installs a single rate function.** Phase 3's rates and two discount curves all multiply into the same price. Routing Phase 2's one discount through a single function means Phase 3 changes the values flowing through it rather than the shape of the pipeline, and there is exactly one place where a pricing rule can be wrong.

**Alternatives considered.**

- *Per-synchronizer fee configuration in `AmuletConfig` for Phase 2.* Rejected for Phase 2. The fee config is a single global block today; making it per-synchronizer is a schema change, and a discount factor on the registration achieves the CIP's interim lever at a fraction of the cost. The schema change is revisited in Phase 3 where tiers require it.  
- *An announce, approve, coupon, and report handshake around purchases.* Rejected. The direct burn flow is simpler, removes a trusted step, and is sufficient.  
- *Recording a derived effective rate on the purchase record.* Rejected after implementation and review: the rate is recomputable from the exercise and the pinned registration, so recording it adds a field that can drift from the value actually used.  
- *Verifying dedicated-synchronizer activity rather than bounding it.* Not available. The Super Validators do not run the dedicated sequencer or mediator, so there is nothing to recompute against. The design bounds reported activity by purchased traffic instead and states that trust boundary explicitly.  
- *A reward pool for dedicated-synchronizer operators.* Rejected, consistent with the CIP. The four pools and their split are unchanged; this work extends who participates in them.

---

## Adoption plan

- **A co-applicant operates them long term.** Digital Asset will run dedicated synchronizers on this economy as a matter of its own roadmap, not as a grant deliverable. That makes the first production adopters committed parties, verifiable on-chain, rather than a forecast about third parties.  
- **The applicants run a dedicated synchronizer continuously on DevNet.** Registered, funded by CC burn, carrying validator traffic, upgraded in place through both phases. Sustained operation rather than a demo, and the place an operator or validator can try the path before committing anything on Mainnet. It continues past the grant term as a reference deployment and a compatibility canary across Splice releases.  
- **Make the operator path self-service.** Helm charts, scripted bootstrap, an operator guide, and an LSU runbook, so a prospective operator evaluates and deploys without a bilateral conversation. This is the single largest determinant of adoption for infrastructure of this kind.  
- **Migrate what already exists.** Dedicated synchronizers deployed under Phase 1 join in place through a documented path, with no rebuild and on their own schedule.  
- **Reduce the cost of connecting.** Validator auto top-up works per synchronizer, and the wallet and Scan surfaces carry dedicated purchases, so a validator joining a dedicated synchronizer uses the tooling it already knows.  
- **Report publicly.** Registrations, per-synchronizer purchased and burned totals, and reported consumption are all readable from chain data, so adoption is measurable by anyone without the applicants' cooperation.

---

## Sustainability

Who maintains this after the grant is not an open question here. The code ships into `canton-network/splice-multi-sync`, Digital Asset's Splice feature fork, under the same Apache 2.0 license, CI, and contribution rules as Splice, and upstreams into Splice. Digital Asset maintains Splice and is a co-applicant, so maintenance lands with the protocol's maintainer rather than with a grant-funded team that disperses at the end of the term.

Digital Asset will also operate dedicated synchronizers on this economy long term, and the applicants keep one running on DevNet past the grant term. Both make the applicants users of this software rather than only its authors, which is a more durable maintenance incentive than a commitment on paper.

Beyond that, the applicants commit to security patches for disclosed vulnerabilities in code delivered here, correctness fixes affecting the traffic purchase, pricing, or reconciliation paths, and tracking of Canton Improvement Proposals that change the semantics this work depends on. The design documentation, work breakdown, and operator guides remain public.

---

## Risks and dependencies

- **Super Validator governance.** Adopting Daml changes on Mainnet requires a supermajority vote. Milestone acceptance is written against demonstrable capability rather than a vote outcome, because the vote is outside the grant's control.  
- **CIP ratification timing.** The CIP publishes shortly and has not yet been through community feedback or a vote. It carries eight open questions, and the Phase 3 milestones name the ones they consume. Material divergence between the published text and the design assumed here is what M13 covers. This proposal is updated against the published CIP before submission.  
- **Schedule versus the CIP's indicative dates.** The CIP suggests Phases 1 and 2 ready early in 2027 and Phase 3 mid-2027. This proposal targets 29 October 2026 and mid-March 2027. The Phase 2 date reflects that its core is already built rather than optimism about a standing start. Phase 3 is the more aggressive of the two and assumes ratification does not slip materially.  
- **Upstream Splice divergence.** The fork rebases on upstream Splice periodically, and Daml package versions have collided across the boundary before. Rebase cost is carried in the milestones, with a larger rebase carried by M13.  
- **Outage settlement.** The CIP requires a dedicated synchronizer to keep sequencing while the Global Synchronizer is unavailable, accruing a negative traffic balance that settles on reconnection. That depends on the ledger team delivering negative balances in Phase 1. It is excluded from M1 to M12 and carried by M13.  
- **Traffic-based validator rewards.** Validator rewards mint at purchase today and cover dedicated synchronizers unchanged. A separate change in flight moves them to traffic-based issuance. Its timing sits outside this grant, and the integration it creates is carried by M13.  
- **Org-internal enforcement.** The org-internal carve-out prices traffic at a twentieth of the dedicated rate, so what stops an operator claiming it is load-bearing. Making it a property of the synchronizer rather than of each transaction removes the classification problem, but leaves the question of how strictly the boundary is held, from a bounded set of connected validators to a single namespace. M8 implements the ratified answer. A materially stricter mechanism than the connection bound assumed here is carried by M13.  
- **Governance timing.** Milestone 5 depends on the CIP being ratified in time for DevNet, and Milestone 6 on the Super Validator vote adopting these changes on Mainnet. Neither is within the applicants' control, and the adoption portions of both are exposed to that timing.

---

## Co-marketing

On release, the applicants will work with the Foundation on announcement coordination, a technical write-up of the design and its trust model, and operator-facing material for teams evaluating a dedicated synchronizer. The design document, the work breakdown, and the operator guides are public and reusable by the Foundation.