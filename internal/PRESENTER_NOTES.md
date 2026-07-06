# Presenter aids: Extending Mainnet technical review

**For:** the Canton / Digital Asset working session
**Companion to:** the external memo `external/extending-mainnet-technical-review.md`
**Use:** speaker notes are glanceable cue blocks (one per section); the cheat sheet is a dense one-pager for mid-call reference.

---

## Part A. Speaker notes

Cue lines, not scripts. Bold is the line to actually say.

**OPEN (30 sec)**
- We read the CIP against the Splice and Canton source, not the summaries.
- Four things: the mechanism you are generalizing, how much already exists, the four questions that decide the design, and how we de-risk it cheaply.
- **"Every identifier we cite is real, so this is a read of your code, and we can be precise about reuse vs. new."**

**1. The mechanism today**
- Your core already exists: burn Canton Coin to buy sequencer traffic.
- Metering is in the protocol, priced in **bytes**, with a **fan-out** term, not per-transaction. (Remember this for 3.2.)
- Purchase burns on-ledger: `AmuletRules_BuyMemberTraffic`, then `splitAndBurn`, then a `MemberTraffic` record.
- Two facts we lean on later: the buy choice **already carries `synchronizerId`**, and **already separates payer (`provider`) from beneficiary (`memberId`)**, so paymaster is already legal.
- Price is a governed **USD/MB** rate; CC burned floats with `amuletPrice`.
- **The load-bearing fact: `SetTrafficPurchased` grants a balance decoupled from the burn.** It enables the discount, and it is also the hole in 3.1.
- **Land line: "A synchronizer is blind. It orders encrypted messages and cannot see other synchronizers, including you, the SVs. That boundary is what makes this hard."**

**2. What changes, how much exists**
- One flat Global-only price becomes per-synchronizer, per-class, discount-curve, staked. Value stays in one Burn-Mint Equilibrium.
- **"Most of this is reuse, not new machinery."** Walk the table if asked: `synchronizerId`, payer not equal to beneficiary, grant decoupled from burn, `amuletPrice`, `LockedAmulet`, `DsoRules` votes, coupon beneficiary weights.
- New surface is four contained things: per-synchronizer pricing object, class classifiers, commitment-stake over `LockedAmulet`, report to mint.
- **Caveat to say out loud: "the contracts are small; the hard part is the trust model around invisible activity."**

**3.1 THE MAIN SLIDE (privacy collapses three checks into one)**
- Say it slowly. Three "separate" mechanisms (realized-TPS for staking, burn/reward report for minting, and the grant vs burn link) are **all attested by the same party** on a single-operator synchronizer.
- `SetTrafficPurchased` can grant with no burn, so nothing on-chain ties them.
- **Land line: "The security of expanding burn-mint network-wide reduces to one invariant the CIP does not state yet: staked collateral must be at least the value an operator could fraudulently mint."**
- Fixable: size stake to the mintable ceiling, plus a challenge window, plus slashing, plus optional multi-SV attestation. **Design it as the security property, not three independent-looking pieces.**
- On the diagram: **"anti-fraud is stake plus slashing, not a proof. There is no proof possible, because the activity is invisible."**

**3.2 Per-tx price vs per-byte metering**
- Curve is cents per tx; sequencer charges bytes with fan-out. **They do not convert by a constant.**
- Cross-org DvP is high fan-out and byte-heavy; an internal transfer is cheap; the model prices them flat.
- Any fixed average-bytes-per-tx is gameable both ways. Need a defined conversion, or redefine the billing unit.

**3.3 Discount lives at the grant layer, not the formula**
- Native pricing is consumption-measured; a commitment is forward-looking, so **it cannot be a price multiplier.**
- Delivered by granting a subsidized balance via `SetTrafficPurchased`.
- Consequence: pricing, staking-burn, and report become **one coupled trust triangle**, not three safeguards. This reinforces 3.1.

**3.4 Per-round DSO load**
- Report and shortfall-burn are DSO-party transactions. Every SV validates them at 2/3 BFT, the most expensive kind.
- N synchronizers times a round every ~10 min is load **on the Global Synchronizer**, the thing you are trying to offload.
- **"Batch per-window, and model capacity before fixing the cadence."**

**Formula catch (the credibility moment)**
- **"Small thing: your formula and your own table disagree."** The formula uses `D = 0.25`; at 2 years that is `0.5 x 0.25 = 0.125`, but your table (and Example 1b's 18.75c) needs `0.375`.
- One-character fix: `1 - D = 0.75`. Units (years) were already fixed; this factor was not.

**4. Candidate designs (buildable)**
- "Candidate shapes, not a fixed design."
- **Stake:** a thin `CommitmentStake` over `LockedAmulet`. The DSO already co-signs it via the embedded `Amulet`, so no extra setup. One new authorization: a **coupon-free** partial burn (needed because `splitAndBurn` mints a `ValidatorRewardCoupon`, and you do not want to reward a slashing). Lifecycle mirrors CIP-0105, but **burns** instead of forfeiting weight.
- **Classifier:** co-signed, reads `PartyToParticipant` topology against the up-to-5 designated validators; rolling 12-month $500k cap. Co-signing is the only defense against relabeling.
- **Flag app-internal:** three tiers now (100 / 30 / 10). "Same operator" anchors on the validator list; **"same application" has no obvious on-ledger primitive**. That is question 2.

**5. De-risk early (constructive close)**
- **Shadow mode:** pricing and curve off-ledger against your section 5 table. No burn, no grant, no dependency on you. Validates the math (would have caught the 6.2 factor), tests the per-tx to bytes conversion. **"We can start this now."**
- **Single-synchronizer pilot:** real grants plus stake, Global as an untouched control. Exercises the trust model safely.

**6. Open questions (the ask)**
- Lead with number 1: **BME semantics. Is report-driven minting additive to issuance, or drawn from the budget?** Biggest tokenomics decision; sets how load-bearing 3.1 is.
- Then: class definitions, staking denomination (FX risk), verification of invisible activity, where CC lives (probably no reassignment needed for the stake), net-cost labeling.

**CLOSE**
- **"The reuse means we are not asking you to rebuild anything. The four questions decide the design, and 3.1 is the one we would most like your view on. We can start shadow mode now and bring numbers to the next session."**

---

## Part B. One-page cheat sheet

Keep this open during the call.

**THE ONE INVARIANT (3.1):** staked collateral >= value an operator could fraudulently mint. Not stated in the CIP. That is the meeting.

**FIVE FACTS TO NAIL**
1. Synchronizer is a blind sequencer; cannot see other synchronizers, including SVs. This is the core constraint.
2. Traffic-purchase flow already exists, already per-network, already payer not equal to beneficiary.
3. `SetTrafficPurchased` grants are decoupled from burn. Enables the discount, causes the trust gap.
4. Security is stake plus slashing, not a proof (activity is invisible, so no proof is possible).
5. Shadow mode has no dependency on DA. We can start now.

**IDENTIFIERS (all verified in `canton-network/splice`)**

| Name | What it is |
|---|---|
| `AmuletRules_BuyMemberTraffic` | on-ledger call that burns CC to buy traffic; carries `synchronizerId`, `provider` separate from `memberId` |
| `splitAndBurn` | burns the CC, and mints a `ValidatorRewardCoupon` over the whole burn |
| `MemberTraffic` | record of purchased traffic (`usdSpent`, `totalPurchased`) |
| `SetTrafficPurchased` | admin RPC that grants an absolute traffic balance; decoupled from burn |
| `SynchronizerFeesConfig` | holds `extraTrafficPrice` (USD/MB); changed by a 2/3 DSO vote |
| `amuletPrice` | governed CC/USD rate, per ~10-min mining round |
| `LockedAmulet` / `Amulet` | time-lock escrow; signed by lock holders plus `dso` plus owner, so DSO already co-signs |
| `DsoRules` / `AmuletConfig` | governance votes over economic params, effective-dated |
| `PartyToParticipant` | signed topology: which participant hosts which party (basis for class) |
| CIP-0105 | approved SV-locking; forfeits weight, not coins (we burn) |

**REBUTTALS (question, then one-liner)**
- Footnote already explains 90.25 / 9.75: "Agreed, 5% dev fund plus 4.75% SV. Our note is presentation-only: label the table steady-state."
- Self-reporting plus slashing is standard: "Workable. Just size the stake to the mintable ceiling and make it the security property, not three separate pieces."
- Can we just price the discount: "No. Consumption-measured pricing cannot hold a forward-looking commitment; it is a `SetTrafficPurchased` grant."
- Reassignment is not needed: "Our read too. If CC is pinned to Global the stake is already witnessable. We are confirming, and asking if reassignment is GA for composability."
- The 6.2 formula is illustrative params: "Params are tunable, but the written formula does not reproduce your own table. Example 1b needs 0.375; the formula gives 0.125. Fix: 1 minus D."
- Why does `splitAndBurn` mint a coupon: "It is in `AmuletRules.daml`: validator activity rewards over the whole burn. So the shortfall-burn must be a new coupon-free choice."
- How big is the build: "Contracts are small and reuse existing primitives. The hard part is the realized-activity oracle plus trust model. Hence shadow mode first."

**SIX OPEN QUESTIONS (the ask)**
1. BME: additive or drawn from curve? (biggest: supply cap, and how load-bearing 3.1 is)
2. Class definitions on-ledger (especially "app-internal") plus co-signing
3. Staking denomination (20% of which CC, re-marked? FX-liquidation risk; are 80% / 1-week normative?)
4. Verification beyond trust plus slashing? (multi-SV, Scan cross-check, fraud proof)
5. Is CC pinned to Global (so no reassignment for the stake)? Is reassignment GA?
6. Label Net columns as steady-state (footnote: 5% dev fund plus 4.75% SV, ~10 years)

**THREE TIERS:** regular 100c / app-internal 30c / org-internal 10c. **CAP:** up to 5 validators, $500k per rolling 12mo, then free.
