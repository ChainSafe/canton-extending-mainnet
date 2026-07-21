# Work Plan — Extending Mainnet: Dedicated Synchronizer Traffic

## Context

ChainSafe is co-designing and piloting the Canton CIP *"Extending Mainnet: Tokenomics
Alignment Across the Entire Canton Network"* (Shaul Kfir, Digital Asset). It generalizes
Canton's single Global-Synchronizer traffic-purchase + Burn-Mint flow into
per-synchronizer, CC-funded, discount-curve, optionally-staked pricing across **dedicated**
(non-global) synchronizers.

This document enumerates the work as epics and issues so the team can create and track them.
It is grounded in the design doc (`docs/design/extension-traffic-manager.md`), the meeting
decisions (`history/meetings/2026-07-08-*`), and the actual Splice fork integration surface (real
file paths + consumer counts below).

**Where we are today (built):** LocalNet brought up and the real burn-mint loop observed, and
an **unverified Daml PoC** of the MVP on-ledger path drafted as two stacked PRs on
`canton-network/splice-multi-sync` (PR #1 registration, PR #2 CC-funded buy). Earlier, the CIP pricing math
was validated off-ledger (`sync-pricing/`) — that is **design-validation analysis, not part
of the implementation** (see "Parked analysis" below). No Scala/automation, no per-sync
pricing, and no compiled/tested on-ledger code exist yet.

**How to use this document:** each `[E#-#]` block is a copy-paste-ready GitHub issue (title =
the block heading, body = the fields below it). Epics group the issues; workstreams map to
milestones. Nothing here is auto-created — file the issues wherever the team tracks work.

---

## How this maps to GitHub

- **Milestones** = workstreams: `WS0 Foundation`, `WS1 MVP (no-discount)`, `WS2 Discounts & rewards`.
- **Epics** = a parent issue per `E#` with a task list linking its child issues (or a label `epic:E#`).
- **Labels** used on every issue block below:
  - workstream: `ws0` | `ws1` | `ws2`
  - area: `area:daml-amulet` | `area:daml-governance` | `area:scala-sv` | `area:scala-validator` | `area:scala-scan` | `area:ops` | `area:localnet` | `area:pricing`
  - `gated:digital-asset` — needs an upstream/DA decision before it can land (all core-package Daml changes ship in DA-owned `splice-amulet` / `splice-dso-governance`, so they require an upstream release + DAR vetting).
  - `status:poc-drafted` — already drafted in the fork PoC, pending compile/verify.

## Status snapshot

| Area | State |
|---|---|
| LocalNet bring-up + observed burn-mint loop | **Built** / verified 2026-07-08 |
| Daml PoC: registration + CC-funded buy (fork PRs #1/#2) | **Drafted, UNVERIFIED** (not compiled) |
| Splice fork dev env (nix/direnv/dpm/sbt) | In progress (env setup being resolved) |
| Scala automation (reconcile, auto-topup), Scan, operator node, deploy | **Not started** |
| Per-sync pricing, tx-class discounts, staking, operator rewards (WS2) | **Not started**, gated |
| Shadow pricing engine + conversion harness (`sync-pricing/`) | **Parked** — design analysis, not on the implementation path |

## Parked analysis (not implementation work)

The `sync-pricing/` package (shadow discount curve + tx→bytes→USD→CC conversion harness) was
built to **validate the CIP math off-ledger before touching on-ledger schema**. It is **not**
on the implementation path: the MVP reuses Splice's existing `computeSynchronizerFees` +
`splitAndBurn` unchanged (no discounts), and any real pricing (WS2) lands in DA-owned core
packages. Recommendation: **keep the code as a reference artifact, but do not track it as
active work.** One finding is worth carrying forward regardless:

### [ANALYSIS-1] Raise the CIP Section 6.2 duration-factor bug with Digital Asset
**Labels:** `ws2`, `area:pricing`, `gated:digital-asset`
**Summary:** The CIP's own `Di * D ^ log2(d)` does not reproduce its published Section 5 table;
`Di * (1 - D) ^ log2(d)` (a 25% incremental discount per doubling) does. Encoded as a passing
test in `sync-pricing/daml/Test/Section5Table.daml`. This is a correction to the CIP text, not
code we ship.
**Acceptance criteria:**
- [ ] Bug written up and raised with DA; CIP text corrected or the intended formula confirmed.

## Epics overview

| Epic | Title | WS | Status |
|---|---|---|---|
| E0 | Verify & land the Daml PoC | WS0 | drafted → verify |
| E1 | On-ledger registration + CC-funded buy (Daml) | WS1 | poc-drafted |
| E2 | Reconcile-to-sequencer automation (Scala) | WS1 | not started |
| E3 | Sync Operator Node + deployment | WS1 | not started |
| E4 | Dedicated sequencer base-rate = 0 | WS1 | not started |
| E5 | Validator auto top-up for dedicated traffic | WS1 | not started |
| E6 | Scan / observability (dedicated-sync endpoints) | WS1 | not started |
| E7 | Per-synchronizer pricing (schema change) | WS2 | gated |
| E8 | Transaction-class characterization + discount curve | WS2 | gated |
| E9 | Commitment / staking | WS2 | gated |
| E10 | Operator reward model | WS2 | gated |

---

# WS0 — Foundation

## Epic E0 — Verify & land the Daml PoC
Compile, test, and demonstrate the drafted on-ledger PoC end-to-end before building anything on top of it.

### [E0-1] Stand up the Splice fork dev environment
**Labels:** `ws0`, `area:ops`
**Summary:** Nix flake + direnv dev shell (provides `dpm`/`sbt`/JDK/`damlc`). Enable flakes, source the nix daemon, `direnv allow` in the fork.
**Key files:** `splice/.envrc`, `splice/DEVELOPMENT.md`, `~/.config/nix/nix.conf`.
**Acceptance criteria:**
- [ ] `nix --version` and `which sbt dpm` resolve inside the repo.
- [ ] `direnv reload` completes with `direnv: using nix` and no `nix: command not found`.
- [ ] Short README note capturing the macOS gotchas (flakes flag, daemon sentinel).

### [E0-2] Compile the PoC Daml
**Labels:** `ws0`, `area:daml-amulet`, `area:daml-governance`, `status:poc-drafted`
**Summary:** Build the modified packages; fix compile errors in the blind-written PoC.
**Key files:** `sbt splice-amulet-daml/damlBuild`, `sbt splice-dso-governance-daml/damlBuild`; `project/DamlPlugin.scala`.
**Acceptance criteria:**
- [ ] Both `damlBuild` tasks succeed; Java codegen regenerates.
- [ ] Any fixes pushed to branches `multi-sync-poc-registration` / `multi-sync-poc-buy-traffic`.
**Dependencies:** E0-1.

### [E0-3] Run the Daml Script test suites
**Labels:** `ws0`, `area:daml-amulet`, `area:daml-governance`, `status:poc-drafted`
**Summary:** Run and green the registration + buy tests (incl. negative unregistered/below-min-topup cases).
**Key files:** `sbt splice-amulet-test-daml/damlTest`, `sbt splice-dso-governance-test-daml/damlTest`; `TestRegisterSynchronizer.daml`, `TestBuyDedicatedSyncTraffic.daml`.
**Acceptance criteria:**
- [ ] Both suites pass; PoC PRs move out of draft.
**Dependencies:** E0-2.

### [E0-4] LocalNet end-to-end demo (manual reconcile)
**Labels:** `ws0`, `area:localnet`
**Summary:** On LocalNet `multi-sync`, register a dedicated sync via vote, buy traffic via explicit disclosure (CC burned, `DedicatedSyncTraffic` created), then play `SetTrafficPurchased` **manually** in the console and draw it down — substituting for the not-yet-built reconcile trigger.
**Key files:** `splice/cluster/compose/localnet`.
**Acceptance criteria:**
- [ ] Register → buy → manual grant → transact chain observed on a live dedicated sequencer.
- [ ] DAR deployment/vetting path resolved (custom `IMAGE_TAG` from local build is the likely route) — **the main risk**.
**Dependencies:** E0-3.

### [E0-5] Reconcile PoC design divergences
**Labels:** `ws0`, `gated:digital-asset`
**Summary:** Confirm the two decisions where the PoC departs from the design doc, with DA: (a) **new sibling `AmuletRules_BuyDedicatedSyncTraffic`** vs modifying the existing `AmuletRules_BuyMemberTraffic` gate; (b) a **separate `DedicatedSyncTraffic` template** vs adding an `operator` observer to `MemberTraffic`. PoC chose sibling + separate template (additive, avoids ~41-file codegen churn). Also confirm `RegisteredSynchronizer` lives in `splice-amulet` (dependency-correct), not `splice-dso-governance`.
**Acceptance criteria:**
- [ ] Decision recorded in the design doc; upstream contribution path agreed.

---

# WS1 — MVP (no-discount CC-funded dedicated traffic)

## Epic E1 — On-ledger registration + CC-funded buy (Daml)
The MVP on-ledger surface. Largely drafted in the PoC; this epic hardens and lands it.

### [E1-1] `RegisteredSynchronizer` template + public fetch
**Labels:** `ws1`, `area:daml-amulet`, `gated:digital-asset`, `status:poc-drafted`
**Summary:** DSO-signed `syncId → operator party` registry, operator as observer, with a public `RegisteredSynchronizer_Fetch` (mirrors `OpenMiningRound_Fetch`) for explicit-disclosure reads. Add a lifecycle-state field for offboard/revoke.
**Key files:** `daml/splice-amulet/daml/Splice/DecentralizedSynchronizer.daml:120`.
**Acceptance criteria:**
- [ ] Template + fetch compile; lifecycle-state field present.
- [ ] Not conflated with `requiredSynchronizers` or DSO `synchronizers` config.

### [E1-2] Governance action `DsoRules_RegisterSynchronizer`
**Labels:** `ws1`, `area:daml-governance`, `gated:digital-asset`, `status:poc-drafted`
**Summary:** New `SRARC_RegisterSynchronizer` variant + choice + result + dispatch arm (mirrors `DsoRules_CreateUnallocatedUnclaimedActivityRecord`). A vote creates the `splice-amulet` registry contract.
**Key files:** `daml/splice-dso-governance/daml/Splice/DsoRules.daml:122` (variant), `:1699` (choice), `:342` (result), dispatch arm.
**Acceptance criteria:**
- [ ] Vote-to-create path exercised by `TestRegisterSynchronizer`.
**Dependencies:** E1-1.

### [E1-3] `AmuletRules_BuyDedicatedSyncTraffic` + `DedicatedSyncTraffic`
**Labels:** `ws1`, `area:daml-amulet`, `gated:digital-asset`, `status:poc-drafted`
**Summary:** Sibling of `AmuletRules_BuyMemberTraffic`: reads the disclosed `RegisteredSynchronizer`, enforces `minTopupAmount` (no `requiredSynchronizers` gate), reuses `computeSynchronizerFees` + `splitAndBurn`, records `DedicatedSyncTraffic` (operator = observer).
**Key files:** `AmuletRules.daml:317` (choice), `:1962` (result), `:339` (`validateDedicatedSyncTopupAmount`), `:1791` (`computeSynchronizerFees`); `DecentralizedSynchronizer.daml:153` (`DedicatedSyncTraffic`).
**Acceptance criteria:**
- [ ] Buy burns CC + creates the record; operator observes it; below-min-topup rejected.
**Dependencies:** E1-1.

### [E1-4] Operator lifecycle governance (offboard / revoke)
**Labels:** `ws1`, `area:daml-governance`, `gated:digital-asset`
**Summary:** Governance action(s) to decommission/revoke a registered operator-run sync, mirroring DSO-side lifecycle states (design doc §14 open question).
**Acceptance criteria:**
- [ ] Registry entry can be retired by vote; effect on in-flight purchases defined.
**Dependencies:** E1-1, E1-2.

## Epic E2 — Reconcile-to-sequencer automation (Scala)
The off-ledger step that grants purchased traffic onto the dedicated sequencer.

### [E2-1] Extract traffic-management triggers into a reusable module
**Labels:** `ws1`, `area:scala-sv`
**Summary:** Factor the SV-app traffic triggers out of `singlesv` so both the SV and the Sync Operator can run them; do not hard-wire a single sequencer (keep BFT open).
**Key files:** `apps/sv/src/main/scala/.../sv/automation/singlesv/ReconcileSequencerLimitWithMemberTrafficTrigger.scala`.
**Acceptance criteria:**
- [ ] Trigger logic parameterized by target sequencer connection + synchronizer id.
**Dependencies:** E0-3.

### [E2-2] Reconcile trigger for `DedicatedSyncTraffic` → `SetTrafficPurchased`
**Labels:** `ws1`, `area:scala-sv`, `area:scala-validator`
**Summary:** New/generalized trigger firing on `DedicatedSyncTraffic`, resolving the operator/sequencer via `RegisteredSynchronizer.operator`, summing purchased totals from the operator-observed record (not Scan polling), and calling `setSequencerTrafficControlState` on the dedicated sequencer. Today's trigger is `MemberTraffic`-only and assumes the SV's single connected sequencer == contract sync id.
**Key files:** `ReconcileSequencerLimitWithMemberTrafficTrigger.scala` (single-seq check `:68-87`, `reconcileExtraTrafficLimitForMember:124`, `:152`); `apps/common/.../environment/SequencerAdminConnection.scala`; `apps/sv/.../store/SvDsoStore.scala:949` (aggregation).
**Acceptance criteria:**
- [ ] Purchased total for a member on a dedicated sync is granted on that sync's sequencer.
- [ ] Runs against the operator's sequencer admin connection, not only the SV's.
**Dependencies:** E1-3, E2-1.

### [E2-3] Sync-id parse hardening (skip-not-fail)
**Labels:** `ws1`, `area:scala-sv`
**Summary:** Both traffic triggers parse the sync id with a throwing `tryFromString`; make them skip unknown ids instead of failing the trigger.
**Key files:** `ReconcileSequencerLimitWithMemberTrafficTrigger.scala`, `MergeMemberTrafficContractsTrigger.scala`.
**Acceptance criteria:**
- [ ] An unparseable/foreign sync id is skipped with a warning, not a crash.

### [E2-4] Merge trigger for `DedicatedSyncTraffic`
**Labels:** `ws1`, `area:scala-sv`
**Summary:** Compact many `DedicatedSyncTraffic` contracts per `(member, syncId, migrationId)`, mirroring `MergeMemberTrafficContractsTrigger` (already scoped per member/sync).
**Key files:** `apps/sv/.../automation/delegatebased/MergeMemberTrafficContractsTrigger.scala`.
**Acceptance criteria:**
- [ ] Multiple purchases collapse to one record without changing totals.
**Dependencies:** E1-3.

## Epic E3 — Sync Operator Node + deployment
Run and deploy the participant that operates a dedicated synchronizer.

### [E3-1] Build the Sync Operator Node
**Labels:** `ws1`, `area:ops`, `area:scala-sv`
**Summary:** Operator participant connected to both syncs, onboarded as an ordinary global validator; ingests `DedicatedSyncTraffic` as observer and runs the reconcile trigger (E2-2). MVP single sequencer + mediator; BFT out of scope but not precluded.
**Acceptance criteria:**
- [ ] Operator node grants traffic on its dedicated sequencer from on-ledger purchases, no Scan polling.
**Dependencies:** E2-2, E4-1.

### [E3-2] LSU management on the dedicated sync
**Labels:** `ws1`, `area:ops`
**Summary:** Operator manages logical synchronizer upgrades on the dedicated sync independently of the global sync; purchased traffic preserved per `migrationId`.
**Acceptance criteria:**
- [ ] A dedicated-sync LSU preserves granted traffic (mirrors `LsuTransferTrafficTrigger`).

### [E3-3] Deployment: Helm charts + operator docs
**Labels:** `ws1`, `area:ops`
**Summary:** Helm charts for a non-global synchronizer (single sequencer + mediator) and operator runbook.
**Acceptance criteria:**
- [ ] A dedicated sync can be brought up from the charts and registered.

## Epic E4 — Dedicated sequencer base-rate = 0

### [E4-1] Set and verify base rate = 0 on the dedicated sequencer
**Labels:** `ws1`, `area:ops`, `gated:digital-asset`
**Summary:** Set `maxBaseTrafficAmount = 0` so `availableTraffic = extraTrafficPurchased − extraTrafficConsumed` (no free allowance). Verify end-to-end (onboarding + rate-limiter paths) on a running dedicated sync.
**Key files:** Amulet `baseRateTrafficLimits` (`DecentralizedSynchronizer.daml:30-37`); deploy config `baseRateBurstWindowMins`.
**Acceptance criteria:**
- [ ] With base rate 0, a member with no purchase cannot transact; after a grant it can, drawing down.
- [ ] Onboarding still works with base rate 0 (confirm no breakage).

## Epic E5 — Validator auto top-up for dedicated traffic
(Design doc marks this "likely MVP — confirm.")

### [E5-1] `CO_BuyDedicatedSyncTraffic` wallet operation
**Labels:** `ws1`, `area:daml-amulet`
**Summary:** New `AmuletOperation` constructor + `handleBuyDedicatedSyncTraffic` + `COO_*` outcome, exercising the dedicated buy choice.
**Key files:** `daml/splice-wallet/daml/Splice/Wallet/Install.daml:258` (`CO_BuyMemberTraffic`), `:297` (outcome), `:63-65` (dispatch), `:161/189` (handler).
**Acceptance criteria:**
- [ ] Wallet treasury can enqueue a dedicated-sync buy.
**Dependencies:** E1-3.

### [E5-2] Generalize `TopupMemberTrafficTrigger` to dedicated syncs
**Labels:** `ws1`, `area:scala-validator`
**Summary:** Auto-topup for a validator connected to both syncs when low on dedicated traffic; supply the disclosed `RegisteredSynchronizer`; target non-active syncs (explicit TODO today) and emit the dedicated operation.
**Key files:** `apps/validator/.../automation/TopupMemberTrafficTrigger.scala` (`CO_BuyMemberTraffic:131`, `enqueue:142`, active-sync-only TODO `:86-92`); `apps/wallet/.../util/TopupUtil.scala`.
**Acceptance criteria:**
- [ ] A validator low on dedicated traffic auto-buys via a global-sync burn keyed by the dedicated sync id.
**Dependencies:** E5-1.

## Epic E6 — Scan / observability (dedicated-sync endpoints)

### [E6-1] Index the new choice + template in Scan
**Labels:** `ws1`, `area:scala-scan`
**Summary:** Parse `AmuletRules_BuyDedicatedSyncTraffic` and index `DedicatedSyncTraffic` / `RegisteredSynchronizer` (ACS filter + tables), mirroring the `MemberTraffic` path.
**Key files:** `apps/common/.../history/AmuletEvent.scala:286`, `apps/scan/.../store/ScanTxLogParser.scala:413` (`fromBuyMemberTraffic:905`), `apps/scan/.../store/db/ScanTables.scala`, `SvDsoStore` ingestion `:1469`.
**Acceptance criteria:**
- [ ] Dedicated buys/records appear in Scan's store.
**Dependencies:** E1-3.

### [E6-2] Dedicated-synchronizer Scan endpoints (funding side only)
**Labels:** `ws1`, `area:scala-scan`
**Summary:** New endpoints: list registered synchronizers; per-sync purchased/burned totals; serve the `RegisteredSynchronizer` disclosed contract a buyer attaches. **Omit `total_consumed`** (a separate endpoint, not reusing `getMemberTrafficStatus`'s shape) — consumption visibility is the operator's choice.
**Key files:** `apps/scan/.../store/ScanStore.scala:382`, `scan.yaml`, `apps/scan/.../HttpScanHandler.scala`.
**Acceptance criteria:**
- [ ] A buyer can fetch the operator party + disclosed registration from Scan.
- [ ] Endpoints expose funding totals; no consumed field.
**Dependencies:** E6-1.

---

# WS2 — Discounts & rewards (deferred, gated on Digital Asset)

These epics are intentionally lighter; each needs a DA/upstream decision and depends on WS1.
The intended pricing math for E7/E8 already exists as validated Daml in the parked
`sync-pricing/` package (see "Parked analysis").

## Epic E7 — Per-synchronizer pricing (schema change)
### [E7-1] Make `fees` per-synchronizer in `AmuletConfig`
**Labels:** `ws2`, `area:daml-amulet`, `area:pricing`, `gated:digital-asset`
**Summary:** Turn the single global `SynchronizerFeesConfig` into a per-sync map; ripples into validators, all three `Patchable` instances, and both fee-computation sites. Large blast radius: ~60 Scala + ~50 TS consumers of the `AmuletConfig`/`decentralizedSynchronizer` surface (most read-only), plus the SV governance UI config builders.
**Key files:** `DecentralizedSynchronizer.daml:21` (`AmuletDecentralizedSynchronizerConfig`), `:36` (`SynchronizerFeesConfig`, `extraTrafficPrice:38`, `minTopupAmount:44`), `Patchable :179/:184/:192`; `AmuletConfig.daml:97`; Scala seed `apps/common/.../util/SpliceUtil.scala:507`; Pulumi `cluster/pulumi/common/src/domainFees.ts`; UI `apps/sv/frontend/src/utils/buildAmuletConfigChanges.ts`.
**Acceptance criteria:**
- [ ] Fees can differ per synchronizer; governance can set a dedicated sync's rate by vote.
- [ ] Codegen + Scala + TS consumers compile; SV config UI round-trips the new shape.

## Epic E8 — Transaction-class characterization + discount curve
### [E8-1] Transaction-class concept (net-new)
**Labels:** `ws2`, `area:pricing`, `gated:digital-asset`
**Summary:** Canton meters bytes only, no tx-class concept. Protocol must classify a tx and draw from the right bucket/rate. The three classes: composed-across-apps $1.00; single-app/multi-validator $0.30; org-internal (≤5 named validators) $0.10 capped $500k/yr.
**Acceptance criteria:**
- [ ] A tx is characterized and priced from its class (design + on-ledger representation agreed with DA).

### [E8-2] Enforce the discount curve at burn time
**Labels:** `ws2`, `area:pricing`, `area:daml-amulet`, `gated:digital-asset`
**Summary:** Feed the CIP discount curve (tiered mode; the `(1 − D)` Section-6.2 correction) into the buy choice / `computeSynchronizerFees`, replacing the flat byte-linear price. Add the governance-voted fixed discount.
**Reference (parked):** the intended tiered math already exists as validated Daml in `sync-pricing/daml/SyncPricing.daml` (`priceCents`, `DiscountMode.Tiered`) — reuse it if pricing is built. See [ANALYSIS-1] for the `(1-D)` correction.
**Acceptance criteria:**
- [ ] On-ledger price for a class/throughput/duration matches the shadow engine's tiered output.
**Dependencies:** E7-1, E8-1.

## Epic E9 — Commitment / staking
### [E9-1] Staking, tracking, duration, draw-down penalty + shortfall burn
**Labels:** `ws2`, `area:daml-amulet`, `gated:digital-asset`
**Summary:** Net-new commitment contracts (stake + duration + penalty) and the coupon-free shortfall burn. None exists on-ledger today.
**Acceptance criteria:**
- [ ] A committed buyer's stake, duration, and under-consumption penalty are modeled and enforced.

## Epic E10 — Operator reward model
### [E10-1] Consumption reporting + report-to-mint
**Labels:** `ws2`, `area:scala-sv`, `area:pricing`, `gated:digital-asset`
**Summary:** Aggregate consumption from the dedicated sequencer (`listSequencerTrafficControlState`, sum `extraTrafficConsumed`), a per-round total-traffic report, the proposed ~0.9× burn-ratio cap, and the operator app-reward mint path.
**Key files:** `apps/common/.../environment/SequencerAdminConnection.scala:368`.
**Acceptance criteria:**
- [ ] Operator receives app rewards derived from reported consumption, capped as agreed.

---

## Open questions — gated on Digital Asset / upstream

Track these as a pinned issue or a decision log; they block the `gated:digital-asset` items.
1. **Contribution model:** all on-ledger changes land in DA-owned `splice-amulet` / `splice-dso-governance` → upstream release + DAR vetting. How does ChainSafe contribute (PR upstream, or vetted fork DARs)?
2. **Sibling choice vs modify existing** `AmuletRules_BuyMemberTraffic`; **separate `DedicatedSyncTraffic` vs `MemberTraffic` observer** (E0-5).
3. **Operator party representation:** single vs decentralized (BFT); relation to `requiredSynchronizers` (§14).
4. **Operator lifecycle:** governance offboard/revoke semantics (§14).
5. **Reward model:** per-round reporting, 0.9× cap, whether aggregate consumption reporting is required (§14).
6. **Auto-topup in MVP?** (design doc marks "likely — confirm").
7. **Base-rate = 0 safety** confirmation end-to-end (E4-1).
8. **The 8 "to specify" items** (Appendix A of the design doc): traffic mgmt on non-global sync, burn mechanism, CC↔traffic conversion, tx types, agreement-to-purchase, price, commitment, state.

## Build / verification reference
- Compile: `sbt splice-amulet-daml/damlBuild`, `sbt splice-dso-governance-daml/damlBuild`.
- Test: `sbt splice-amulet-test-daml/damlTest`, `sbt splice-dso-governance-test-daml/damlTest` (concurrency capped at 4).
- Plugin/keys: `project/DamlPlugin.scala`; package projects in `build.sbt` (`splice-amulet-daml:908`, `-test:960`; `splice-dso-governance-daml:973`, `-test:986`).
