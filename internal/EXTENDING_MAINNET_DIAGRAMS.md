# Extending Mainnet: Tokenomics Alignment — Architecture & Sequence Diagrams

**Companion to:** [Kickoff Proposal](EXTENDING_MAINNET_KICKOFF_PROPOSAL.md) · [Technical Plan](CIP_EXTENDING_MAINNET_TECHNICAL_PLAN.md)
**Date:** 2026-06-30

### Legend (viability coding)
- 🟩 **Reused** — exists today in Splice/Canton, verified against source. Low risk.
- 🟧 **Net-new** — new Daml / off-chain tooling, designable on existing primitives.
- 🟥 **Needs Digital Asset** — a Canton-protocol change or a tokenomics/governance decision that gates the design.

In the architecture diagram these map to green / orange / red fills. In the sequence diagrams they're called out in notes.

---

## 1. High-level architecture

Where each piece lives, and what is reused vs. net-new. Off-chain tooling is what ChainSafe builds; the substantive contracts land upstream in Splice; one primitive needs Digital Asset.

```mermaid
flowchart TB
  USERS["Participants / users"]

  subgraph OFF["Off-chain operator tooling — ChainSafe builds"]
    PQ["Pricing / quote tool (shadow mode)"]
    ORA["Realized-TPS oracle feed"]
    GD["Traffic grant-driver"]
    TUP["Top-up bot"]
    RR["Reward reporter"]
  end

  subgraph EXT["Extension Synchronizer — operator-run"]
    ESEQ["Sequencer: meters bytes, enforces traffic"]
    EMED["Mediator"]
    EPAR["Per-network traffic params"]
  end

  subgraph GS["Global Synchronizer — Super Validators, BFT 2/3"]
    GSEQ["SV Sequencers + Mediator"]
    DSO["DSO party: 2/3 BFT governance"]
  end

  subgraph SPL["Splice Daml (on Global Synchronizer)"]
    AR["AmuletRules: BuyMemberTraffic, splitAndBurn"]
    PCFG["Per-network PricingConfig + curve"]
    MT["MemberTraffic record"]
    OMR["OpenMiningRound: amuletPrice oracle (~10 min)"]
    COUP["Reward coupons + issuance curve"]
    GOV["DsoRules governance vote"]
    LOCK["LockedAmulet time-lock"]
    CS["CommitmentStake"]
    RTA["RealizedThroughputAttestation"]
    EBR["ExtensionBurnReport"]
    PBURN["Conditional partial-burn of stake"]
  end

  USERS -->|submit tx| ESEQ
  TUP -->|BuyMemberTraffic| AR
  PQ -. reads .-> PCFG
  PQ -. reads .-> OMR
  AR --> PCFG
  AR -->|burn CC| COUP
  AR --> MT
  MT -. observed by .-> GD
  GD -->|SetTrafficPurchased| ESEQ
  ORA -->|attest realized TPS| RTA
  CS --> LOCK
  RTA --> PBURN
  PBURN -->|burn shortfall| CS
  RR -->|submit report| EBR
  EBR -->|bounded by| CS
  EBR -->|mint coupons| COUP
  DSO --> GOV
  GOV --> PCFG
  DSO --> AR
  DSO --> EBR
  DSO --> PBURN

  classDef reuse fill:#d4f7d4,stroke:#2e7d32,color:#000;
  classDef new fill:#ffe0b2,stroke:#e65100,color:#000;
  classDef da fill:#ffcdd2,stroke:#b71c1c,color:#000;
  class ESEQ,EMED,EPAR,GSEQ,DSO,AR,MT,OMR,COUP,GOV,LOCK,TUP,USERS reuse;
  class PQ,ORA,GD,RR,PCFG,CS,RTA,EBR new;
  class PBURN da;
```

---

## 2. Sequence — Traffic purchase (the core mechanism)

Generalized per-network bandwidth purchase. Only the price-class selection and per-network config are new; the burn → record → grant pipeline is reused as-is.

```mermaid
sequenceDiagram
  autonumber
  actor U as User / Paymaster
  participant Bot as Top-up bot (off-chain)
  participant AR as AmuletRules (Global)
  participant OMR as OpenMiningRound (price oracle)
  participant MT as MemberTraffic
  participant GD as Grant-driver (off-chain)
  participant SEQ as Extension Sequencer

  U->>SEQ: submit tx (consumes byte-metered traffic)
  Note over SEQ: extra-traffic balance running low
  Bot->>OMR: read amuletPrice (current ~10-min round)
  Bot->>AR: BuyMemberTraffic(provider, memberId, syncId, priceClass)
  Note right of AR: priceClass + per-network PricingConfig = NEW.<br/>Everything below is REUSED
  AR->>AR: cost = curve(class,tps,dur) x bytes / amuletPrice
  AR->>AR: splitAndBurn — burn Canton Coin
  Note over AR: also mints a ValidatorRewardCoupon over the burn
  AR->>MT: create/update (usdSpent, totalPurchased)
  MT-->>GD: observed on-ledger
  GD->>SEQ: SetTrafficPurchased(absolute balance)
  SEQ-->>U: balance credited, tx proceeds
```

---

## 3. Sequence — Commitment staking + per-round shortfall burn

Discount is delivered by *granting* subsidized balance (not by re-pricing). The shortfall burn is the piece that needs a Splice Amulet (Daml) change — upstream + DSO-activated.

```mermaid
sequenceDiagram
  autonumber
  participant OP as Operator
  participant CS as CommitmentStake (NEW)
  participant LOCK as LockedAmulet (reused)
  participant GD as Grant-driver
  participant SEQ as Extension Sequencer
  participant ORA as TPS oracle (off-chain)
  participant RTA as RealizedThroughputAttestation (NEW)
  participant DSO as DSO (2/3 BFT)

  OP->>LOCK: lock 20% stake (DSO already co-signs via the Amulet)
  OP->>CS: create commitment (committedTps, duration)
  Note over CS,GD: while Active and above threshold
  GD->>SEQ: SetTrafficPurchased (discounted balance)
  loop each ~10-min round
    ORA->>RTA: attest realized TPS (self-reported)
    DSO->>RTA: co-sign / confirm
    DSO->>CS: ProcessRound(attestation)
    alt realized below committed
      CS->>LOCK: burn shortfall from stake
      Note right of LOCK: NEEDS DA — conditional partial-burn,<br/>no re-mint, no reward coupon
    end
  end
  alt stake below 80% for over 1 week
    DSO->>CS: cancel discount + forfeit (burn at full rate)
    GD->>SEQ: withdraw grant
  else operator replenishes in time
    OP->>LOCK: re-lock to restore stake
  end
```

---

## 4. Sequence — Reward reporting to the DSO, then mint (with override)

Because extension activity is invisible to the validators, the operator self-reports; anti-fraud is stake + slashing, not a proof.

```mermaid
sequenceDiagram
  autonumber
  participant OP as Operator (off-chain reporter)
  participant EBR as ExtensionBurnReport (NEW)
  participant SVA as SV automation
  participant CS as CommitmentStake (collateral)
  participant DSO as DSO (2/3 BFT)
  participant COUP as Reward coupons + issuance

  OP->>OP: meter own burn + reward allocation this round
  OP->>EBR: submit report (syncId, round, burnedCC, allocation, override)
  SVA->>EBR: validate against per-round cap
  SVA->>CS: check report within staked / committed capacity
  Note over SVA: challenge window — anti-fraud = stake + slash,<br/>NOT cryptographic proof
  SVA->>DSO: t-of-n confirm
  DSO->>COUP: mint AppRewardCoupon / ValidatorRewardCoupon
  Note right of COUP: beneficiaries per override policy.<br/>SV + dev-fund pools unchanged.<br/>additive-vs-curve = GATE-1 (needs DA)
```

---

## 5. Sequence — Org-internal classification + $500k/12mo cap

Classification must check signed topology and be co-signed, or an operator could mislabel cross-org traffic as internal. *(The current CIP revision adds a third "app-internal" tier — a distinct "within a single application" predicate — not yet drawn here.)*

```mermaid
sequenceDiagram
  autonumber
  participant U as Candidate tx
  participant CLS as Classifier choice (NEW, co-signed)
  participant TOPO as Topology (PartyToParticipant)
  participant CAP as OrgInternalCapState (NEW, rolling 12mo)
  participant GD as Grant-driver
  participant SEQ as Extension Sequencer

  U->>CLS: price this tx
  CLS->>TOPO: are ALL parties hosted on the designated up-to-5 validators?
  alt all parties internal
    CLS->>CAP: add gross fee (USD)
    alt cumulative under 500k in trailing 12mo
      CLS->>GD: charge org-internal base (10c) then burn
    else cap reached
      CLS->>GD: grant FREE balance (no burn)
      Note right of GD: post-cap subsidy — who funds it? (open)
    end
    GD->>SEQ: SetTrafficPurchased
  else any party externally hosted
    CLS->>GD: charge regular base (100c) then burn
    GD->>SEQ: SetTrafficPurchased
  end
```

---

## Notes for reviewers
- Diagrams are deliberately at the *logical* level (contracts + off-chain roles), not node/deployment topology. Say the word if you want a deployment view (participant/sequencer/mediator node layout).
- Every 🟥 item corresponds to a decision in the kickoff "what we need from DA" section: partial-burn (staking), reassignment/denomination (staking), additive-vs-curve (reward minting), and the self-attestation trust model.
- The two 🟥-gated sequences (3 and 4) are drawn as the *intended* design; if a DA go/no-go comes back negative, those flows change materially.
