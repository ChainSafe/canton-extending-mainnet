# Development Fund Proposal: Universal Burn, Phase 1

**Author:** Sebastian Lindner (Outer Sunset - A Five North subsidiary) and Wayne Collier (Digital Asset)

**Status:** Draft

**Created:** 2026-09-15

**Label:** tokenomics

**Champion:** Shaul Kfir

**SIG alignment:** Canton Protocol & Multi-Synchronizer, Tokenomics

---

## Abstract

Canton Mainnet runs one burn-mint economy, and that burn-mint economy runs on one synchronizer. Every other synchronizer on Mainnet sits outside Canton Coin tokenomics, historically under enterprise license fees that are being phased out as the stack is open-sourced. The CIP "Universal Burn and Synchronizer Pricing" closes that gap. This proposal funds the implementation of its Phase 1.

The deliverable is the Daml, Scala, and operational work that lets a dedicated synchronizer participate in the Canton Coin economy: its traffic is funded by burning CC on the Global Synchronizer, its operator grants the purchased traffic on its own sequencer, and its pricing is governed on-chain by Super Validator vote. The work ships initially into canton-network/splice-multi-sync, a Splice feature fork, under the same Apache 2.0 license and using the same CI as Splice itself, and upstreams into Splice upon completion.

A dedicated synchronizer joins the economy at Global Synchronizer rates, with an SV-voted per-synchronizer discount. It delivers on ledger registration, CC-funded traffic purchases, a dSync Operator application that turns traffic purchases into enforced sequencer traffic, Scan visibility, and dSync deployment mechanics, through to production operation on Mainnet.

The CIP's Phase 2, the volume pricing curve and the commitment, collateral and loyalty discounts, is the subject of a second proposal. The CIP defers the details of these features to a second CIP, and this proposal does not depend on them: it builds the traffic management mechanism those discounts will later flow through.

Matching the implementation to the final form of the ratified CIP may require additional work, and it is tracked in Milestone 1.

---

## Delivery team

This is a joint application by Digital Asset and Outer Sunset.

- Outer Sunset will own the core development of this proposal, and a planned follow up proposal to implement Universal Burn Phase 2.
- Digital Asset will be responsible for project management, technical design reviews, CI and test on the Continuous Integration Long Running (CILR) and DevNet networks, and release coordination, across this proposal and the second proposal planned to follow it. Digital Asset will also be responsible for detailed code reviews, but that work is covered under an existing Maintenance grant.

---

## Specification

### 1. Objective

Put every synchronizer on Canton Mainnet on the same Canton Coin burn-mint economy.

Today a validator burns CC through AmuletRules_BuyMemberTraffic to buy sequencer traffic on the Global Synchronizer, and the Super Validators all record that purchase by updating the Validator's traffic balance. That flow is the economic link between using Canton and contributing to it, but it exists for just one synchronizer.

The objective is to generalize it: any dedicated synchronizer's traffic is funded by burning CC on the Global Synchronizer, priced under on-chain governance parameters, and recorded by that synchronizer's operator on its sequencers.

### 2. Implementation mechanics

**The funding path.** A buyer exercises AmuletRules_BuyMemberTraffic on the Global Synchronizer, passing the dedicated synchronizer's id as synchronizerId and the credited participant id as memberId. The choice burns CC through splitAndBurn, mints the buyer's ValidatorRewardCoupon, and creates a MemberTraffic record keyed by (memberId, synchronizerId, migrationId). Two properties of the existing code make this tractable: the buy choice is already structurally multi-synchronizer aware, and getTotalPurchasedMemberTraffic is already keyed per member, synchronizer, and migration id.

**Registration.** In the deliverable from this grant, a dedicated synchronizer is registered by Super Validator governance vote, which records a syncId to operator-party mapping in a RegisteredSynchronizer contract signed by the DSO party. The buy choice reads that contract, supplied by the submitter through explicit disclosure, to confirm the synchronizer is registered and to learn the operator party. A synchronizer id has the form name::namespace where the namespace is a key fingerprint, so the operator is identifiable from the id but not usable as a Daml party; the mapping supplies the party. Registration is reversible by the same route, and archiving it closes the buy path.

The implementation of CIP Phase 2 (via a subsequent grant proposal) will automate this registration so it no longer requires a Super Validator governance vote, delivering permissionless self-registration, with an on-ledger uniqueness check in replacing the one the Super Validator application performs today at proposal time, which blocks a vote request whose synchronizer id is already registered or already proposed. Offboarding remains a governance vote either way.

**Governance variables.** The CIP requires the framework to be configurable via on-chain governance parameters that the Super Validators can change with a 2/3 vote. Splice's Super Validator governance app renders each separate type of governance action as its own form, so every action and every parameter this proposal introduces needs matching work to either add it to existing forms or to add a new type of vote proposal. Registration, offboarding and later changes to a synchronizer's parameters are each a new proposal type, with the discount set as a field on the registration vote itself and changed afterwards by its own action. That work sits inside the milestone that introduces the parameter rather than in a milestone of its own, in both phases.

**Delivery to the operator.** The buy choice sets the Synchronizer Operator as an observer on the MemberTraffic created by that choice, so the operator's Validator node records every purchase for its synchronizer on-ledger and event-driven, with no Scan polling.

**The traffic grant.** A new Splice application running on the Synchronizer Operator's Validator node, the sync operator app (apps/syncoperator), sums purchases for that synchronizer id and calls SetTrafficPurchased on that synchronizer's sequencer, through the Validator's Admin API. Dedicated synchronizers run at base rate zero, so all usage must be funded.

**Pricing.** Dedicated traffic is priced at the Global Synchronizer's list price, currently $60 per megabyte set through CIP-0084, about $1 for a Canton Coin transfer before rewards, multiplied by a per-synchronizer discount factor that Super Validator governance sets by vote on the registration contract. This is the current CIP's interim governance discount, and the proposed Phase 2 CIP will end it when the pricing curve and commitment discounts go live. Phase 2 introduces the automated calculation: a volume curve on sustained throughput, and multiple discounts that stack on it for committing to a throughput.

**Consumption and enforcement.** The dedicated sequencer runs at base rate zero, so a member transacts only up to the traffic its operator has granted, enforced locally by the sequencer itself. Consumed traffic sits in that sequencer's databases, which the Super Validators do not run and cannot recompute. Nothing in this phase depends on them doing so, because funding is authoritative on the Global Synchronizer where the burn is recorded. The operator-signed consumption report that closes that gap belongs to the second proposal, where the pricing curve and app rewards need it.

**Stack:** Daml (SDK 3.5.2) for on-ledger contracts, Scala for app automation and triggers, Helm and Docker for deployment, Docker LocalNet for end-to-end testing.

### 3. Architectural and Roadmap alignment

This work extends existing Splice machinery. The burn mechanism, the purchase record, the reward coupon, the reconciliation trigger, the reward-processing pipeline, and the traffic-control parameters are all reused. The net-new functionality is a registration template with a governance action, an operator observer on the purchase record, and an operator-run variant of the reconciliation trigger. The consumption report and the automated pricing that build on them belong to the second proposal.

This proposal supports against the following Foundation DevFund RFP areas:

- Scaling the network. Multi-synchronizer scaling is core to this work. The proposal will give the ecosystem an economically coherent way to balance load between the Global Synchronizer and more dedicated capacity, which is a scaling path Canton's architecture already assumes.
- App building and developer experience. Simplified traffic accounting is a named priority. Phase 2's per-purchase pricing records make the price of any purchase recomputable by a third party from chain data.

Relevant CIPs: the Universal Burn and Synchronizer Pricing CIP (economic design), CIP-0084 (the process that sets the Global Synchronizer's list price), and CIP-0079 (the CC/USD price feed this reuses for conversion). Traffic purchases will comply with Token Standard V2 (CIP-0112).

### 4. Backward compatibility

Global Synchronizer users see no change to price, reward mechanics, or purchase flow.

- All Daml changes are backwards compatible under Daml Smart Contract Upgrade rules as enforced also by Splice's upgrade checker: new fields on released serializable types are Optional and appended last, and new variant constructors follow the nullary rule rather than adding fields to existing ones.
- The Global Synchronizer, and any synchronizer in requiredSynchronizers, is priced and gated exactly as today. The discount is absent by construction rather than by a check, because a required synchronizer has no registration to carry one.
- Dedicated synchronizers already deployed on Mainnet join the economy in place through a documented migration path, with no rebuild and no forced date.

Adoption of any Daml change on Mainnet requires a Super Validator supermajority vote. That is a timing dependency this grant tracks as a delivery risk.

---

## Milestones and Deliverables

### Milestone 1: Daml models and CIP acceptance

- **Estimated delivery:**
  - The related CIP has been submitted for discussion by representatives of Outer Sunset and Digital Asset, prior to submission of this proposal.
  - Estimated time for CIP approval is 4-6 weeks after submission of the CIP.
  - Payment Milestone 1 will be due four weeks after acceptance of the CIP, or forfeited if the CIP is not accepted within 6 months of grant approval.
- **Type:** Adoption
- **Focus:** The on-ledger foundation and the CIP's interim pricing lever.
- **Deliverables:**
  - *Registration:* RegisteredSynchronizer Daml template with public read path; register and offboard governance actions in splice-dso-governance; migration-id policy for dedicated synchronizers.
  - *Upstreaming:* The Daml above contributed to canton-network/splice and carried into a Splice release, so the package versions the Super Validators vote on are the released ones.
  - *Funding:* AmuletRules_BuyMemberTraffic Daml model extended to accept a registered synchronizer by explicit disclosure; registered operator set as observer on MemberTraffic.
  - *Pricing:* Discount factor as a governed field on the registration, set by the same vote that registers the synchronizer, and bounded on-ledger to a valid range; applied multiplicatively at purchase; a single rate function in the buy path that any later pricing rule also flows through.
- **Out of scope, carried by the second proposal:** on-ledger uniqueness of the synchronizer id, which arrives with self-registration; the move of validator rewards to traffic-based issuance; tighter enforcement of operator reporting; and air-gapped validator attestation.
- **Residual:** nothing on-ledger stops the same synchronizer being registered twice. The Super Validator form blocks a duplicate when the proposal is raised, an offboard vote removes one that gets through, and purchase-record consolidation for that synchronizer pauses until it is gone.
- **Acceptance:**
  - Super Validators register a dedicated synchronizer by vote and revoke it by vote.
  - Any party funds traffic for a validator on a registered synchronizer by burning CC on the Global Synchronizer, and the operator sees that purchase on-ledger without polling. The same attempt against an unregistered synchronizer is rejected.
  - Super Validators set a named synchronizer's discount by vote, taking effect prospectively, so traffic on it costs proportionally less CC. The Global Synchronizer carries no discount and its price is unchanged.
  - A third party recomputes the price of any purchase from chain data.
- **Amount:** 2.0M CC

### Milestone 2: Backend and frontend implementation

- **Estimated delivery:** Three months after grant approval.
- **Type:** Delivery
- **Focus:** Purchases become enforced sequencer traffic on the dedicated synchronizer, visible and purchasable through the interfaces the ecosystem already uses.
- **Deliverables:**
  - *Granting traffic:* a reusable member-traffic reconciliation trigger, extracted from the Super Validator path so an operator runs it against its own sequencer; a "Synchronizer Operator" (SO) app; per-member purchased totals filtered by synchronizer id and granted through SetTrafficPurchased; base rate zero on the dedicated sequencer, with unlimited traffic for the synchronizer's own mediator; an operator-set outage allowance in the app's config, raising each member's limit above its purchased total while the Global Synchronizer is unreachable and returning it when the operator removes it; the validator's next top-up buying back the shortfall alongside its normal purchase.
  - *Buying it:* per-synchronizer validator auto top-up with its own threshold and amount, funds checked across every configured synchronizer; the wallet API and frontend carrying a registration through the buy path.
  - *Seeing it:* synchronizer registrations indexed and served by Scan and the scan proxy, so a buyer can obtain the disclosure blob a purchase requires; per-synchronizer purchased and burned totals readable or computable from Scan's /update, /event and /acs/ endpoints; getMemberTrafficStatus corrected for dedicated synchronizer ids; operator metrics and dashboards.
  - *Governing it:* vote proposal and review forms in the SV application for every action and parameter this proposal introduces which cannot be accommodated by existing vote proposal forms, including the register and offboard actions and the discount factor as a field on the "registration" vote proposal form, with validation at proposal time.
  - *Upgrading it:* the sync operator app triggering a logical synchronizer upgrade for its own synchronizer, so an operator upgrades on its own schedule rather than the Global Synchronizer's.
  - Throughout, a foreign or unparseable synchronizer id is skipped rather than throwing an error.
- **Acceptance Criteria:**
  - A validator transacts on a dedicated synchronizer once traffic is bought for it, and draws down its balance on that synchronizer as it does. A validator operator buys traffic through the wallet.
  - Auto top-up buys traffic without manual intervention, on each dedicated synchronizer, whenever a balance falls below its configured threshold. The operator's own Validator node purchases traffic like any other, rather than receiving a blanket grant.
  - Any third party can read what each dedicated synchronizer has purchased and burned, and an operator can see its own traffic position on a dashboard.
  - Super Validators raise, review and pass every action and parameter introduced here via the SV governance app.
  - The sync operator can configure the dSync to temporarily allow "traffic overdrafts" up to a configured limit, to be consumed in case the gSync becomes unavailable. Those are post-purchased upon reconnecting to the gSync.
  - The sync operator can trigger an LSU via the operator app, to apply upgrades. Those do not need to be in lockstep with those of the gSync, but should follow successful upgrades of the gSync.
- **Amount:** 3.0M CC

### Milestone 3: Deployment tooling and testing

- **Estimated delivery:** Four months after grant approval.
- **Type:** Delivery
- **Focus:** The whole flow runs end to end on an internal network, then continuously on DevNet from the published artifacts, with the tooling and documentation an outside operator needs to deploy, upgrade and migrate.
- **Deliverables:**
  - *Bootstrap and charts:* scripted synchronizer bootstrap covering sequencer, mediator, initial topology and dynamic parameters, including base rate zero and permissioned onboarding from day one; Helm charts for the synchronizer and the sync operator app, usable for CILR, DevNet and Mainnet alike.
  - *Topology:* a four-node default synchronizer topology, where the dedicated synchronizer runs four sequencer and mediator nodes at a 3 of 4 threshold, so it is exercised as a BFT synchronizer rather than a single node.
  - *Testing:* an end-to-end acceptance scenario including cross-synchronizer workflows, with CI integration; an upgrade-compatibility gate on Daml changes.
  - *DevNet:* the charts deployed on DevNet, running the same four-node topology at a 3 of 4 threshold.
  - *Documentation:* an operator guide covering bring-up, registration, permissioning, top-up configuration and offboarding.
  - *Upgrades:* an LSU upgrade runbook for the operator-triggered upgrade, preserving sequencer ids and member traffic across it.
- **Acceptance:**
  - The end-to-end scenario runs in CI and is reproducible by a reviewer: register, connect a validator, submit before and after buying, let a top-up fire, run a workflow spanning both synchronizers, and perform a Global Synchronizer LSU and a dedicated synchronizer LSU.
  - The dedicated synchronizer continues processing when one of its four nodes is lost.
  - It also continues processing through a Global Synchronizer outage on prepaid traffic and then on the operator-set allowance, and settles any advance once the Global Synchronizer returns.
  - A dedicated synchronizer registered by governance vote runs continuously on DevNet, funded by DevNet CC burn, carrying traffic for validators the operator does not run, deployed from the published charts rather than a development tree, evidenced on-chain by the registration contract and the associated MemberTraffic records.
- **Amount:** 2.0M CC

### Milestone 4: Mainnet adoption in production

- **Estimated delivery:** Payment will be due after enabling on MainNet and demonstrating acceptance, not at a specific date, or forfeited if the acceptance criteria are not met within 12 months of grant approval.
- **Type:** Adoption
- **Focus:** The Daml is live on Mainnet and a dedicated synchronizer is running on it in production.
- **Acceptance:**
  - Every Daml package delivered here is vetted on Mainnet, the Super Validators having adopted it by vote.
  - At least one dedicated synchronizer runs in production on Mainnet, operated by a party outside the delivery team and funded by CC burn, brought up from the operator guide alone. The registration, purchases and burn are verifiable on-chain through Scan; the operator's independence is confirmed by the Foundation, which may keep their identity confidential.
- **Depends on:** Super Validator adoption of these changes on Mainnet.
- **Amount:** 2.0M CC

---

## Acceptance criteria

Each milestone above carries its own criteria. Across the grant, the Tech and Ops Committee will evaluate against:

- Capability focused. Every criterion is written as something an ecosystem participant can do that they could not do before, reproducible by a reviewer on LocalNet or verifiable on-chain.
- Public verifiability. Pricing, purchases and registrations are readable from onchain data, so a third party can recompute the price of any purchase without trusting any operator.
- No regression to the Global Synchronizer. Nothing changes for existing users. A validator buying traffic on the Global Synchronizer pays the same price, earns the same rewards, and uses the same purchase flow after this work ships as before it.
- Adoption. Gated at M1 and M4, where adoption first becomes possible: approval of the CIP, and production operation on Mainnet by a party outside the delivery team.

On the adoption weighting: 4.0M of the 9.0M request is adoption-contingent, concentrated at the two milestones where adoption is actually possible.

---

## Funding

Total funding request: 9.0M CC: Delivery: 6.0M CC. Adoption-contingent: 4.0M CC.

| Milestone | Trigger | Amount (CC) | DA / OS Split (CC) | Deadline |
|---|---|---|---|---|
| M1: Daml and the CIP | CIP approved by Super Validator vote | 2.0M | x.xM / x.xM | 4-6 weeks after CIP |
| M2: Backend and frontend implementation | Committee acceptance | 3.0M | x.xM / x.xM | 3 months after grant |
| M3: Deployment Tooling and Testing | Committee acceptance | 2.0M | x.xM / x.xM | 4 months after grant |
| M4: MainNet adoption in production | Third-party operation on Mainnet | 2.0M | x.xM / x.xM | 12 months after grant |
| **Total** | | **9.0M** | x.xM / x.xM | |

### Volatility stipulation

The delivery milestones complete within approximately four months of grant approval. Two milestones carry no fixed date, because they turn on events this grant does not control: Milestone 1 on approval of the CIP, and Milestone 4 on a third party operating a dedicated synchronizer on Mainnet. The proposal is denominated in a fixed amount of Canton Coin, so if either of those, or a Committee-requested scope change, carries the grant past nine months, the remaining milestones are re-evaluated at that point and renegotiated for USD/CC price volatility.

---

## Motivation

The problem is structural, not incremental. Canton's architecture is multi-synchronizer by design, and applications with premium needs already run their own syncs. Those synchronizers are Mainnet: their transactions compose atomically with everything else on the network. Their economics are not. An operator can run a Mainnet synchronizer, benefit from the shared protocol, security model, and interoperability, and contribute nothing to the ecosystem that maintains them. License fees used to cover that, and they are ending.

Who benefits. Every current and future dedicated synchronizer operator, every validator connected to one, and every CC holder, through the burn those synchronizers begin contributing. Today the set of synchronizers inside CC tokenomics is one (1). This work makes that set unbounded. Why it also unlocks scaling. Load that today must sit on the Global Synchronizer, or sit off the economy entirely, gets a priced path onto dedicated capacity. This proposal puts that path in place at one list price, with a discount voted case by case. The second proposal replaces that with a published curve, so the price falls automatically as a synchronizer's throughput rises and as its operator commits to that volume. That is what makes high-volume workloads viable on dedicated capacity.

---

## Rationale

Why extend rather than replace. The buy choice, the purchase record, the reward coupon, the reconciliation trigger, and the reward-processing pipeline all exist and all work. Two properties of the current code make the dedicated case small rather than large: the buy choice is already structurally multi-synchronizer aware, and purchased totals are already keyed per member, synchronizer, and migration id. The design deliberately adds a registration template, an observer field, an operator-run variant of an existing trigger, and appended optional fields. It introduces no parallel economy, no second price feed, no new reward pool, and no change to the pool split.

Why registration is a separate template rather than a config field. Splice's requiredSynchronizers means "the synchronizers Amulet and ANS users should be connected to", and code relies on that meaning. Overloading it with "synchronizers that support traffic purchases" is the kind of reuse that looks economical and produces a subtle regression. A dedicated template with its own governance action keeps the existing meaning intact.

Why the operator learns about purchases on-ledger rather than by polling. Setting the registered operator as an observer on the purchase record makes delivery event-driven and removes an off-ledger dependency from the funding path. A buyer-supplied operator party could be wrong or spoofed, which would break both delivery and reward attribution; the governed registration supplies it instead.

Why this proposal installs a single rate function. The volume curve and the three discounts that follow in the second proposal all multiply into the same price. Routing this proposal's one discount through a single function means the second proposal changes the values flowing through it rather than the shape of the pipeline, and there is exactly one place where a pricing rule can be wrong.

Alternatives considered.

- An announce, approve, coupon, and report handshake around purchases. Rejected. The direct burn flow is simpler, removes a trusted step, and is sufficient.
- Recording a derived effective rate on the purchase record. Rejected after implementation and review: the rate is recomputable from the exercise and the pinned registration, so recording it adds a field that can drift from the value actually used.
- Verifying dedicated-synchronizer activity rather than bounding it. Not available, and not needed here. The Super Validators do not run the dedicated sequencer or mediator, so there is nothing to recompute against. Nothing in this proposal depends on measuring consumption: funding is authoritative because the burn is recorded on the Global Synchronizer. When the second proposal adds consumption reporting, it bounds reported activity by purchased traffic and states that trust boundary explicitly.
- A reward pool for dedicated-synchronizer operators. Rejected, consistent with the CIP. The four existing reward pools and their split are unchanged; this work extends who participates in them.

---

## Maintenance

This code ships into canton-network/splice-multi-sync, Canton Foundation's Splice feature fork, under the same Apache 2.0 license, CI, and contribution rules as Splice, and upstreams into Splice. Digital Asset is currently the core maintainer of Splice and is a co-applicant. Digital Asset will incorporate long-term maintenance into its existing maintenance grant.

Beyond that, the applicants commit to security patches for disclosed vulnerabilities in code delivered here, correctness fixes affecting the traffic purchase, pricing, or reconciliation paths, and tracking of Canton Improvement Proposals that change the semantics this work depends on. The design documentation, work breakdown, and operator guides remain public.

---

## Co-marketing

On release, the applicants will work with the Foundation on announcement coordination, a technical write-up of the design and its trust model, and operator-facing material for teams evaluating a dedicated synchronizer. The design document, the work breakdown, and the operator guides are public and reusable by the Foundation.
