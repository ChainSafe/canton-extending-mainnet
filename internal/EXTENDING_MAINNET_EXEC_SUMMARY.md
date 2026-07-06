# Extending Mainnet: Tokenomics Alignment — Executive Summary

**For:** Digital Asset kickoff · **From:** Sebastian Lindner (ChainSafe) · **Date:** 2026-06-23 · reconciled 2026-07-02
**Subject:** CIP "Extending Mainnet: Tokenomics Alignment Across the Entire Canton Network" (Shaul Kfir, DA)
**Companion docs:** [Kickoff Proposal & Technical Plan](EXTENDING_MAINNET_KICKOFF_PROPOSAL.md) (full context, Canton primer) · [Component Technical Plan](CIP_EXTENDING_MAINNET_TECHNICAL_PLAN.md) (detailed design, effort sizing) · [Diagrams](EXTENDING_MAINNET_DIAGRAMS.md)

---

### The project, in one line
Take the single, flat, one-network mechanism by which Canton charges for bandwidth and recycles fees into rewards, and make it **per-network, tiered, discountable, and commitment-stakeable** across every synchronizer — so the whole "network of networks" feeds one token economy.

### Why now
As participants run their own (extension) synchronizers for throughput and cost, the fees they generate should still flow into the same Burn-Mint Equilibrium and reward pools — not fragment. This CIP is the pricing + tokenomics layer that makes that true.

### The key insight: ~60% is already built
The existing "burn Canton Coin to buy sequencer bandwidth" flow is reusable almost as-is. The on-chain buy call is **already network-aware** and **already separates payer from beneficiary** (the paymaster model is free). Per-network byte pricing, the USD→token oracle, on-chain time-locks, and the 2/3 DSO governance vote all exist. **Per-network pricing and operator-subsidy need new pricing *state* and a price-class-aware buy call — not new sequencer machinery.**

### What's genuinely net-new (3 primitives, all blocked by one wall)
Extension-network activity is **cryptographically invisible to the validator set** (Canton's privacy model). That single fact is why these three are hard:
1. A trustworthy **realized-throughput oracle** (for the commitment shortfall + the org-internal cap).
2. A **coupon-free conditional partial-burn of a staked principal** — a Splice Amulet change: the existing `splitAndBurn` mints a `ValidatorRewardCoupon` over its burn, so a burn that yields no reward is a new choice.
3. A **cross-network reward-reporting → minting** protocol (self-attested; needs anti-fraud bounding).

### Economics — clarified
The "~9.75% net cost" is a **steady-state-BME identity**, not a phantom number: a CIP **footnote** decomposes it as **5% dev fund (CIP-0082) + 4.75% Super Validators** — *"the stable emissions starting ten years from network launch."* It holds because mint ≈ burn at steady state (~10 yrs out); the design lets an operator *capture* the 90.25% for its own activity. Caveat: minting stays **schedule-driven** — we must not encode "re-mint X% of each burn."

### Decisions we need from Digital Asset (the kickoff ask)
| # | Decision | Why it gates everything |
|---|---|---|
| 1 | Can a privileged choice **burn part of a locked stake** with no re-mint and **no reward coupon**? | Go/no-go for staking; a Splice Amulet change (`splitAndBurn` mints a coupon today) |
| 2 | Is CC **pinned to the Global Synchronizer** (so a stake is already DSO-witnessable), and is **multi-synchronizer reassignment GA** for the composability the model assumes? | Determines whether "one economy" holds or each synchronizer needs its own coin |
| 3 | Is report-driven minting **additive to** or **drawn from** the issuance curve? | Decides whether this changes the supply cap & BME network-wide |
| 4 | Trust model: **self-attested-bounded-by-stake** acceptable, or require verification? | A prior CIP *removed* self-reporting — this reverses it; needs DA buy-in |

*(Plus a spec catch: the §6.2 duration-discount formula fixed its units to years but still uses `D` where reproducing the table needs `1 − D` — at a 2-year commitment the written formula gives 0.125 against the table's 0.375. The current revision also moved to three base prices — regular / app-internal / org-internal — adding an "app-internal" classifier.)*

### The interesting engineering risks
- **Pricing unit mismatch:** curve is per-transaction, metering is per-byte (with fan-out) — gameable without a defined conversion.
- **FX risk:** stake is in tokens, price is in USD — a token-price swing can trigger forfeiture with zero usage change.
- **Governance load:** per-round, per-network reports are the most expensive transactions — needs batching, or it slows the Global Synchronizer (the opposite of the goal).

### Plan & ownership
**Phase 0** spec + the feasibility spikes → **Phase 1** shadow-mode pricing (off-ledger, no risk; ChainSafe builds independently) → **Phase 2** one test extension synchronizer with live staking → **Phase 3** reward reporting → **Phase 4** mainnet DSO vote.
**ChainSafe drives** spec co-design, off-chain operator tooling, the Phase-2 pilot network, and the SV vote. **The substantive contracts land upstream in Splice (DSO-activated); the reassignment/GA question is DA's.**
