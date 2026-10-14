# Development Fund Proposal: Universal Burn, Phase 2

**Author:** Sebastian Lindner (Outer Sunset - A Five North subsidiary) and Wayne Collier (Digital Asset)

**Status:** Draft

**Created:** 2026-10-13

**Label:** tokenomics

**Champion:** Shaul Kfir

**SIG alignment:** Canton Protocol & Multi-Synchronizer, Tokenomics

---

## Abstract

The CIP "Universal Burn and Synchronizer Pricing" asks the Super Validators to approve a framework and defers its numbers to a second CIP. Its Phase 1 puts every production synchronizer on the same list price, with a Super Validator voted discount decided case by case. Its Phase 2 replaces that interim lever with a published pricing curve: the price per megabyte falls as a dedicated synchronizer's sustained throughput rises, and three further discounts apply to operators who commit to a throughput, back the commitment with collateral, and keep it in place over time.

This proposal funds the implementation of that Phase 2. It builds the mechanism; the values the mechanism carries are on-chain governance parameters, and the second CIP proposes them. Every constant named here is the current proposal rather than a ratified figure.

The work covers consumption reporting, without which the Super Validators cannot measure a dedicated synchronizer's throughput; the volume curve and the three discounts inside the single rate function the first proposal installed; the commitment contract and its collateral lifecycle, including valuation, shortfalls, margin calls and notice; permissionless self-registration, which ends the interim stage where joining the economy requires a Super Validator vote; and app-reward distribution for dedicated-synchronizer activity, which closes the net-cost gap between a dedicated synchronizer and the Global Synchronizer.

It depends on the first proposal having landed, and on the second CIP existing. The CIP estimates its Phase 2 at Q3 2027.

---

## Delivery team

This is a joint application by Digital Asset and Outer Sunset.

- Outer Sunset will own the core development of this proposal.
- Digital Asset will be responsible for project management, technical design reviews, test design, integration, CI and test on the Continuous Integration Long Running (CILR) and DevNet networks, and release coordination across this proposal. Digital Asset will also be responsible for detailed code reviews, but that work is covered under an existing Maintenance grant.


---

## Specification

### 1. Objective

Replace the interim per-synchronizer discount with the published pricing model the CIP describes, so that the price of traffic on a dedicated synchronizer is a function of its throughput and its commitments rather than of a case-by-case vote, and so that apps and validators on dedicated synchronizers earn rewards for their traffic as they would on the Global Synchronizer.

### 2. Implementation mechanics

**Measuring throughput.** Consumed traffic lives in the dedicated sequencer's database, which the Super Validators do not run and cannot recompute. An operator-signed on-ledger consumption report, attributed per party as the reward rules require, records total transactions, average throughput and total traffic consumed over a window, with strictly increasing windows and no back-filling. Reported consumption is bounded by purchased traffic, which is already on the Global Synchronizer's ledger, so reported-against-purchased is publicly checkable per synchronizer and per round.

**The volume curve.** The price per megabyte halves for every tenfold increase in sustained throughput above 1 TPS, falling smoothly in between, with the list price applying below that. Sustained throughput is the highest of a synchronizer's 7, 30 and 90 day averages, or its committed throughput where that is higher, fed from the consumption reports.

**The three discounts.** On top of the curve, an operator who commits to a throughput for a year or more and posts collateral receives a commitment discount on the committed share of its traffic; a collateral discount that grows with the collateral posted, between a governed minimum and maximum; and a loyalty discount that grows with each year the commitment and its collateral stay in place, up to a governed floor. Only the committed share receives them: the remainder is priced on the volume curve, and each day's rate blends the two, fixed before the day's traffic is known.

**The commitment instrument.** A commitment contract records committed throughput, term and posted collateral. Collateral is denominated in USD and posted in CC, valued daily, with a governed band inside which no action is taken. A shortfall against the commitment is drawn from collateral and credited back as traffic rather than taken as a penalty. Below the band, a margin call requires a top-up within a governed period, and collateral not topped up is forfeited. Ending a commitment, or reducing collateral above the minimum, requires a governed notice period.

**Self-registration.** A permissionless creation path for the registration replaces the Super Validator vote, with on-ledger uniqueness of the synchronizer id in place of the duplicate check that lives in the Super Validator application today. Offboarding remains a governance vote.

**App rewards.** Per-app activity records extend the consumption report under a Merkle commitment, weighted by the CC actually burned after discounts, so heavily discounted traffic cannot mint the rewards of undiscounted traffic. Minted CC is bounded by committed weights, committed weights by reported activity, and reported activity by purchased traffic.

**Governance.** Every constant in the model is an on-chain governance parameter that a two-thirds Super Validator vote can change, as the CIP requires. Each one needs a form in the Super Validator application, with validation at proposal time and a preview of the price a change produces.

**Stack:** DAML (SDK 3.5.2) for on-ledger contracts, Scala for app automation and triggers, Helm and Docker for deployment, Docker LocalNet for end-to-end testing.

### 3. Architectural alignment

This work extends what the first proposal installed rather than replacing it. The single rate function in the buy path is where the curve and the discounts apply; the registration contract is where governance parameters already live; the operator application is where the reporting automation runs. The net-new functionality is the consumption report, the commitment contract and its collateral lifecycle, the discount functions, the self-registration path, and the reward-expansion machinery.

Against the Foundation's current priority areas:

- Scaling the network. Volume pricing is the mechanism that makes high-throughput, low-value workloads viable on Canton, and it prices them onto dedicated capacity rather than onto the Global Synchronizer.
- Stability and maintainability. All changes are additive and schema-compatible, and every constant is a governance parameter rather than a code change.
- App building and developer experience. The price of any purchase is recomputable by a third party from published parameters and chain data.
- Security and resilience. The trust model is stated explicitly and bounded: funding is authoritative on the Global Synchronizer because the burn is recorded there, while reported consumption is bounded rather than verified, with governance offboarding as the off switch.

Relevant CIPs: the Universal Burn and Synchronizer Pricing CIP and the second CIP that proposes the pricing values, CIP-0084 (the process that sets the Global Synchronizer's list price), and CIP-0079 (the CC/USD price feed this reuses for conversion). Traffic purchases comply with Token Standard V2 (CIP-0112).

### 4. Backward compatibility

Global Synchronizer users see no change to price, reward mechanics, or purchase flow. The Global Synchronizer keeps a single price at every volume, with no curve, no discounts and no commitments.

- All DAML changes are backwards compatible under Splice's upgrade checker: new fields on released serializable types are Optional and appended last, and new variant constructors follow the nullary rule.
- A dedicated synchronizer already live under the first proposal moves onto this pricing model in place, with no re-registration and no rebuild.
- The interim Super Validator voted discount ends when the curve and the commitment discounts go live, which is what the CIP specifies.

---

## Milestones and Deliverables

Four milestones, in the same shape as the first proposal. Two delivery, two adoption, none mixing the two.

### Milestone 1: DAML and the second CIP

- **Estimated delivery:**
  - The second CIP follows ratification of the first, which the CIP estimates at its Phase 2, Q3 2027.
  - Estimated time for approval is 4-6 weeks from submission of the second CIP.
  - Payment will be due after acceptance of the second CIP, not at a specific date, or forfeited if the second CIP is not accepted within 12 months of grant approval.
- **Type:** Adoption
- **Focus:** The on-ledger foundation for the pricing model, and keeping it matched to the CIP that actually ratifies.
- **Deliverables:**
  - *Reporting:* the per-synchronizer consumption report state contract, DSO-signed with the operator as observer; an operator-controlled report choice recording total transactions, average throughput and total traffic consumed over a window, attributed per party as the reward rules require, with strictly increasing windows and no back-filling; an on-ledger definition of a silent synchronizer.
  - *Commitments:* the commitment contract recording committed throughput, term and posted collateral, with its shortfall, margin call, forfeiture and notice rules.
  - *Pricing:* the volume curve and the three discount functions as governed configuration inside the existing rate function.
  - *Registration:* a permissionless creation path for the registration, gated by the operator's stake and fee obligations rather than a governance vote, with on-ledger uniqueness of the synchronizer id replacing the duplicate check that today lives in the Super Validator voting UI; offboarding unchanged, so governance keeps the ability to archive a registration.
  - *Ratification:* reconciliation of the implementation against each published revision of both CIPs, with divergences identified and either closed or recorded; implementation of ratified answers that differ from the design assumed here, including any change the second CIP's pricing rules require beyond setting the parameters this proposal exposes; upstream Splice rebases across the term.
- **Carried from the first proposal:** four items deferred there and revisited here, each implemented if it is still required at that point: settlement through negative traffic balances once Canton supports them; integration with the in-flight move of validator rewards to traffic-based issuance; tighter enforcement of operator reporting if a future CIP requires it; the air-gapped validator good-standing attestation.
- **Acceptance:**
  - A dedicated synchronizer's price falls as its sustained throughput rises, on the ratified curve.
  - An operator opens a commitment backed by collateral and receives the ratified discounts on its committed volume.
  - An operator registers a dedicated synchronizer without a governance vote, and two registrations cannot claim the same id.
  - Any divergence between the ratified CIP and this implementation is closed, or documented with the reason it was left open.
- **Amount:** 2.0M CC

### Milestone 2: Backend and frontend implementation

- **Estimated delivery:**
  - We estimate four months after grant approval.
  - Committed to six months after grant approval.
- **Type:** Delivery
- **Focus:** The pricing model runs: throughput is measured from real reports, prices are computed and quoted, commitments are managed, and every parameter has a form.
- **Deliverables:**
  - *Measuring:* report submission automation in the sync operator app; an on-ledger definition of a silent synchronizer; a Scan view reconciling reported consumption against settled burn per synchronizer.
  - *Pricing:* curve application and the three discounts inside the single rate function from the first proposal; the committed share computed as the commitment divided by trailing average traffic and capped at one, so traffic above the commitment is priced on the volume curve and each day's rate blends the two; bounds and floors so the curve cannot be driven to a degenerate price and stacked discounts cannot be gamed at a boundary; an evaluation-precision decision for DAML decimal arithmetic so a quoted price and a charged price agree.
  - *Commitments:* daily valuation of CC-denominated collateral against its USD requirement; margin-call and forfeiture automation; notice handling for ending a commitment or reducing collateral; end-of-term return of unburned collateral.
  - *Governing:* every constant, percentage, floor, band, period, threshold and measurement window exposed as a governance parameter in the Super Validator application, with validation at proposal time and a proposal-time preview of the price a change produces; the Super Validator application updated so the vote-based and self-service registration paths coexist.
- **Acceptance:**
  - A third party reproduces any quoted price from published parameters and chain data, including one measured from a synchronizer's own on-ledger reports.
  - An operator holding a commitment is charged the blended rate the parameters imply, and one who posts more collateral, or stays in a commitment longer, pays less.
  - A shortfall purchases the committed traffic from collateral rather than penalising the operator; a fall in the CC price below the governed band triggers a margin call, and failure to cure it within the governed period forfeits collateral.
  - An operator registers a dedicated synchronizer without a governance vote, and governance can still offboard it. Two registrations cannot claim the same synchronizer id.
  - Committed terms, collateral and status are publicly readable, so a third party computes committed future burn and total value locked. The Global Synchronizer's single rate is unchanged.
- **Amount:** 3.0M CC

### Milestone 3: Deployment, testing and app rewards

- **Estimated delivery:**
  - We estimate six months after grant approval.
  - Committed to eight months after grant approval.
- **Type:** Delivery
- **Focus:** Apps and validators on a dedicated synchronizer earn rewards for their traffic, and the whole pricing model runs end to end.
- **Deliverables:**
  - *Reward records:* per-app activity records extending the consumption report under a Merkle commitment, weighted by the CC actually burned after discounts; the reward-processing contracts extended with an expander party, an issuance rate and a weight budget, appended so absent values preserve today's behaviour exactly.
  - *The bound chain:* a weighted batch tree in which each node commits to its children's weights and the budget is threaded down, bounding minted CC by committed weights, committed weights by reported activity, and reported activity by purchased traffic; a vote-gated start-processing flow enforcing a live registration, a positive issuance rate and that bound.
  - *Automation:* operator-side expansion automation with durable tree storage; a Super Validator guard so existing global reward automation skips contracts carrying an expander.
  - *Deployment and testing:* a documented path for moving a synchronizer already live under the first proposal onto this model in place, within Canton 3.x; charts and operator-guide updates for everything introduced here; end-to-end acceptance across all pricing features in CI and on DevNet.
- **Scope note:** Validator rewards are minted at purchase today, which covers dedicated synchronizers as they stand. A separate change moves them to traffic-based issuance, and when it lands dedicated synchronizers will need to integrate with it. That integration is carried by Milestone 1, where its timing dependency already sits.
- **Acceptance:**
  - App providers operating on a dedicated synchronizer earn app rewards for that activity, drawn from the existing pools with the split unchanged and no new pool for operators.
  - Any third party checks, per synchronizer and per round, that the bound chain holds and that reported consumption does not exceed what was paid for in burned CC.
  - A synchronizer that stops reporting is detectable on-ledger, and an offboarded synchronizer's reports are inert.
  - An operator of a synchronizer already live under the first proposal moves it onto this pricing model in place, with no re-registration and no rebuild.
  - The full model runs end to end in CI and continuously on DevNet.
- **Amount:** 2.0M CC

### Milestone 4: Mainnet adoption on the full pricing model

- **Estimated delivery:**
  - We estimate nine months after grant approval.
  - Payment will be due after a dedicated synchronizer operates on the full pricing model on MainNet and acceptance is demonstrated, not at a specific date, or forfeited if the acceptance criteria are not met within 18 months of grant approval.
- **Type:** Adoption
- **Focus:** The pricing model in production use.
- **Deliverables:** Operator-facing material for commitments and collateral, covering what a commitment obliges, how collateral is valued, and what a margin call requires; support for the first operators through registration, commitment and their first reward distribution.
- **Acceptance:**
  - At least one dedicated synchronizer operates on the full pricing model on Mainnet, with at least one connected validator the operator does not run, evidenced on-chain or by Foundation-confidential attestation.
  - Digital Asset operates dedicated synchronizers on this economy long term, so the first adopter is a committed party rather than a forecast.
  - If the DAML changes have not cleared the Super Validator vote by the milestone date, the gate is met to the same standard on DevNet and carries to Mainnet on ratification.
- **Depends on:** the Super Validator vote adopting these changes on Mainnet.
- **Amount:** 2.0M CC

---

## Acceptance criteria

Each milestone above carries its own criteria. Across the grant, the Tech and Ops Committee will evaluate against:

- Capability focused. Every delivery criterion is written as something an ecosystem participant can do that they could not do before, reproducible by a reviewer on LocalNet or verifiable on-chain.
- Public verifiability. Pricing, purchases, registrations, commitments, collateral and reported consumption are readable from on-chain data, so a third party can recompute any quoted price and check the reported-against-purchased bound without the applicants' cooperation.
- No regression to the Global Synchronizer. Its single price, reward mechanics, and purchase flow are unchanged at every milestone.
- Mechanism, not values. Delivery is judged on the mechanism behaving as the parameters specify, not on any particular parameter value. The values are governance parameters the Super Validators set.
- Delivery and adoption are paid separately. Milestones 2 and 3 are delivery. Milestones 1 and 4 are adoption. No milestone mixes the two.

On the weighting: 4.0M of the 9.0M request is adoption-contingent, concentrated behind the two events that make this work matter rather than spread thinly across the build. Attaching nominal adoption figures to the delivery milestones would be theatre; putting real money behind approval of the second CIP and production use of the pricing model is not. Both sit outside the applicants' control, which the risk section states plainly.

---

## Funding

Total funding request: 9.0M CC: Delivery: 5.0M CC. Adoption-contingent: 4.0M CC.

| Milestone | Trigger | Amount (CC) | DA / OS Split (CC) |
|---|---|---|---|
| M1: DAML and the second CIP | Second CIP approved by Super Validator vote | 2.0M | x.xM / x.xM |
| M2: Backend and frontend implementation | Committee acceptance | 3.0M | x.xM / x.xM |
| M3: Deployment, testing and app rewards | Committee acceptance | 2.0M | x.xM / x.xM |
| M4: MainNet adoption on the full pricing model | Production operation on the full model | 2.0M | x.xM / x.xM |
| **Total** | | **9.0M** | x.xM / x.xM |

Milestones are sized by the scope they carry. Milestone 2 is the largest because it is the largest build: the measurement, pricing, commitment and governance surfaces together.

### Volatility stipulation

The delivery milestones complete within approximately eight months of grant approval. Two milestones carry no fixed date, because they turn on events this grant does not control: Milestone 1 on approval of the second CIP, and Milestone 4 on a dedicated synchronizer operating on the full pricing model on Mainnet. The proposal is denominated in a fixed amount of Canton Coin, so if either of those, or a Committee-requested scope change, carries the grant past twelve months, the remaining milestones are re-evaluated at that point and renegotiated for USD/CC price volatility.

---

## Motivation

A single flat price does not get Canton all the way to one economy. The CIP says so directly: some of the most promising use cases for dedicated synchronizers, payments and trading among them, run at high throughput with a low value per transaction, and at $60 per megabyte before rewards the barrier is too high. Volume pricing is what makes those workloads viable, and commitment discounts are what let an operator trade predictability for price, the way a cloud provider's committed-use discount does.

The first proposal puts dedicated synchronizers inside the economy at one price, with a case-by-case discount decided by vote. That is a stopgap and the CIP says as much: negotiated pricing is neither predictable nor permissionless, and the interim discounts end when the curve goes live. This proposal is what ends them.

Who benefits. Operators, who get a published price they can plan against and a self-serve path to a lower one. Validators and apps on dedicated synchronizers, who begin earning rewards for their traffic. CC holders, through burn from workloads that would otherwise have stayed off the network or off the economy. And the Super Validators, who stop adjudicating individual discounts.

---

## Rationale

**Why the mechanism and the values are separate.** The CIP approves a framework and defers its numbers to a second CIP, and makes every number an on-chain governance parameter. Building the mechanism against parameters rather than constants means a change to the ratified values is a vote rather than a release, and it means this work does not block on the second CIP's numbers being settled.

**Why consumption reporting comes first.** Every discount in the model is a function of throughput, and the Super Validators cannot see traffic on a synchronizer they do not run. Reporting is the measurement without which nothing else can be priced. It is also bounded rather than verified, and that boundary is stated explicitly rather than implied.

**Why collateral rather than contracts.** Cloud providers enforce committed-use discounts through invoices. A permissionless network cannot, so commitments are backed by collateral posted on-chain. That also makes committed burn visible in advance and keeps CC locked for the commitment's term.

**Why only the committed share is discounted.** An operator who commits to 10 TPS and runs 100 should not get the committed price on all of it. Blending the committed and uncommitted shares daily keeps the discount proportionate to the guarantee actually given.

**Why self-registration lands here.** Running a dedicated synchronizer is permissionless under the CIP, but joining the economy requires a vote under the first proposal. That interim stage is expected to last months, not years, and ending it alongside the pricing model keeps the two governance changes in one place.

---

## Adoption plan

- **A co-applicant operates them long term.** Digital Asset will run dedicated synchronizers on this economy as a matter of its own roadmap, not as a grant deliverable, so the first operators on the full pricing model are committed parties rather than a forecast.
- **The applicants keep a dedicated synchronizer on DevNet.** Registered, funded by CC burn, carrying validator traffic, and moved onto the pricing model in place, so an operator can see the full model running before committing anything on Mainnet.
- **Self-serve from end to end.** Self-registration removes the vote, published parameters remove the negotiation, and the operator guide covers commitments and collateral, so an operator evaluates, registers, commits and is priced without a bilateral conversation.
- **Migrate what already exists.** A synchronizer live under the first proposal moves onto this model in place, with no rebuild and on its own schedule.
- **Report publicly.** Registrations, per-synchronizer purchased and burned totals, commitments, collateral and reported consumption are all readable from chain data, so adoption and committed future burn are measurable by anyone.

---

## Sustainability

Who maintains this after the grant is not an open question here. The code ships into canton-network/splice-multi-sync, Digital Asset's Splice feature fork, under the same Apache 2.0 license, CI, and contribution rules as Splice, and upstreams into Splice. Digital Asset maintains Splice and is a co-applicant, so maintenance lands with the protocol's maintainer rather than with a grant-funded team that disperses at the end of the term.

Digital Asset will also operate dedicated synchronizers on this economy long term, and the applicants keep one running on DevNet past the grant term. Both make the applicants users of this software rather than only its authors, which is a more durable maintenance incentive than a commitment on paper.

Beyond that, the applicants commit to security patches for disclosed vulnerabilities in code delivered here, correctness fixes affecting the traffic purchase, pricing, or reconciliation paths, and tracking of Canton Improvement Proposals that change the semantics this work depends on. The design documentation, work breakdown, and operator guides remain public.


---

## Risks and dependencies

- **The second CIP does not exist yet.** This proposal implements a framework the first CIP approves and values a second CIP proposes. If the second CIP's rules differ in shape rather than in value, for instance if loyalty is granted in tranches rather than linearly, the mechanism changes with it, and that is carried by Milestone 1.
- **Dependency on the first proposal.** This work extends the registration, the rate function and the operator application delivered there. It cannot start before they land.
- **Super Validator governance.** Adopting DAML changes on Mainnet requires a supermajority vote, and both adoption milestones are exposed to it. Delivery milestones are written against demonstrable capability instead.
- **Adoption share.** 4.0M of the 9.0M request depends on events outside the applicants' control: approval of the second CIP, and production operation on the full pricing model.
- **Schedule.** The CIP estimates its Phase 2 at Q3 2027, describing that as an ambitious estimate rather than a deadline, and this proposal targets the same. The gating item is the second CIP rather than the engineering.
- **CC price volatility.** Collateral is posted in CC against a USD requirement. The governed band and the margin-call rules are what absorb ordinary movement, but a sharp move could force margin calls across many commitments at once. Parameter choices mitigate this and are the Super Validators' to set.
- **Enforcement depth.** Reports rely on the operator being honest at launch: a maliciously constructed report can misdirect rewards between participants of a synchronizer, but cannot earn rewards on more traffic than was paid for. The CIP places tighter enforcement, by Byzantine fault tolerance, zero-knowledge proofs or trusted execution, in a future CIP, and that work is not in scope here.
- **Upstream Splice divergence.** The fork rebases on upstream Splice periodically. Rebase cost is carried across the milestones, with reconciliation carried by Milestone 1.

---

## Co-marketing

On release, the applicants will work with the Foundation on announcement coordination, a technical write-up of the design and its trust model, and operator-facing material for teams evaluating a dedicated synchronizer. The design document, the work breakdown, and the operator guides are public and reusable by the Foundation.
