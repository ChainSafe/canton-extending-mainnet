# Reconciliation: existing issues → new plan

> Dispositions: **shipped** = implemented and merged on `canton-network/splice-multi-sync`
> `feat/dedicated-sync` (close as done, note the landing PR); **superseded** = close,
> pointing at the new plan item; **carries** = keep open, retitle/relabel to the new slug;
> **keep** = unaffected by the re-plan. New slugs become issue links once filed.

## Epics

| Old | Title | Disposition | New |
|---|---|---|---|
| #1 | [Epic T0] LocalNet + dev harness | superseded | dev-harness half shipped; LocalNet half continues as P2-E9.1 |
| #2 | [Epic T1] Analysis, pricing & DA coordination | keep (retitle) | cross-cutting, no phase slug — retitle to drop the T1 taxonomy, e.g. "[Cross-cutting] DA coordination, CIP & pricing analysis" |
| #13 | [Epic E1] On-ledger registration + CC-funded buy | superseded | split: P2-E1 + P2-E2 |
| #14 | [Epic E2] Reconcile-to-sequencer automation | superseded | P2-E5 |
| #15 | [Epic E3] Sync Operator Node + deployment | superseded | split: P2-E5 (node) + P2-E8 (deployment) |
| #16 | [Epic E4] Dedicated sequencer base-rate = 0 | superseded | P2-E5.4 (folded to a leaf) |
| #17 | [Epic E5] Validator auto top-up | superseded | P2-E5.5 (folded to a leaf) |
| #18 | [Epic E6] Scan / observability | superseded | P2-E7 |
| #19 | [Epic E7] Per-synchronizer pricing (schema) | superseded | P3-E2 |
| #20 | [Epic E8] Tx-class characterization + discount curve | superseded | split: P3-E1 + P3-E3 |
| #21 | [Epic E9] Commitment / staking | superseded | P3-E4 |
| #22 | [Epic E10] Operator reward model | superseded | P3-E6 (rewards confirmed out of P2, 2026-08-17) |

## Leaves

| Old | Title | Disposition | New / note |
|---|---|---|---|
| #5 | Phase-2 e2e demo driver | superseded | P2-E9.2 |
| #6 | CIP Section 6.2 duration-factor bug | close (resolved) | fixed in CIP v0.3: duration discount now "0.5 × 0.75 ^ log2(years)" = the corrected `Di × (1−D)^log2(d)` form, matching its table (verified); `Section5Table.daml` stands as the confirming test |
| #27 | RegisteredSynchronizer template + public fetch | **shipped** (fork PR #1) | P2-E1.2 = production hardening on the same shape |
| #28 | DsoRules_RegisterSynchronizer governance action | **shipped** (fork PR #1) | P2-E1.3; NOTE FR-1 may re-open the model (P2-E1.1) |
| #29 | Buy gate + operator observer | **shipped** (fork PR #2) | P2-E2.1 + P2-E2.2 |
| #30 | Operator lifecycle governance (offboard/revoke) | **shipped** (fork PR #12) | P2-E1.3 |
| #31 | Extract traffic-management triggers | carries (PR #15 in review) | P2-E5.1 |
| #32 | Reconcile trigger → SetTrafficPurchased | carries | P2-E5.3 |
| #33 | Sync-id parse hardening | carries (PR #14 in review) | folds into P2-E5.1 acceptance |
| #34 | Operator-aware merge grouping | carries | P2-E2.5 |
| #35 | Build the Sync Operator Node | carries | P2-E5.2 |
| #36 | LSU management | carries | P2-E8.4 |
| #37 | Helm + operator docs | carries | P2-E8.3 |
| #38 | Base rate = 0 | carries | P2-E5.4 |
| #39 | Wallet CO_BuyMemberTraffic carry | carries | P2-E2.4 |
| #40 | Generalize TopupMemberTrafficTrigger | carries | P2-E5.5 |
| #41 | Index RegisteredSynchronizer in Scan | carries | P2-E7.1 |
| #42 | Dedicated-sync Scan endpoints | carries | P2-E7.2 |
| #43 | Per-synchronizer `fees` in AmuletConfig | superseded | P3-E2 (P2 uses the discount lever + fee config instead) |
| #44 | Transaction-class characterization | superseded | P3-E1 |
| #45 | Discount curve at burn time | superseded | P3-E3 |
| #46 | Staking / draw-down / shortfall | superseded | P3-E4 |
| #47 | Extension reward reporting + expansion (Daml PoC) | **shipped** (fork PRs #8/#12) | P3-E6 builds on it; not P2 |
| #54 | Registry uniqueness: SV-UI duplicate check | carries | P2-E1.4 |
| #57 | SV-side extension reward integration | superseded | P3-E6 (out of P2) |
| #58 | Operator-side reward automation | superseded | P3-E6 (out of P2) |
| #60 | Registered-sync purchases dropped at ingestion past gsync migration 0 | keep (bug) | fixed by P2-E1.5/P2-E5.2 acceptance; close on fix |
| #61 | SV-trigger guard for expander-set ProcessRewardsV2 | superseded | P3-E6 (out of P2) |
| #62 | BatchOfSynchronizers fan-out | superseded | P3-E6 (out of P2) |

## New work with no old counterpart

Flat platform fee (all of P2-E3), governance discount (P2-E4), purchase pricing records
(P2-E2.3), migration-id policy as its own leaf (P2-E1.5), consumption reporting (P2-E6),
operator metrics (P2-E7.3), bootstrapping (P2-E8.1), permissioned-from-day-one (P2-E8.2),
P1→P2 migration (P2-E8.5), air-gapped proxy parking lot (P2-E8.6), two-sync LocalNet
(P2-E9.1), CI integration (P2-E9.3), FR-1 decision (P2-E1.1), rate-function socket
(P2-E4.3), and everything in phase-3-epics.md beyond the old E7–E10 sketches.

## Notes

- The **shipped** Daml PoC (fork `feat/dedicated-sync`: registration, buy, reward
  reporting, lifecycle) is ahead of this plan in Daml terms; the plan's P2-E1/E2 leaves
  describe the same shapes as production work items (hardening, FR-1 outcome, pricing
  fields). The reward-reporting half (#47's output) parks as P3-E6 input.

## Filed mapping (2026-08-19)

| Slug | Issue |
|---|---|
| P2-E1 | #64 |
| P2-E2 | #65 |
| P2-E3 | #66 |
| P2-E4 | #67 |
| P2-E5 | #68 |
| P2-E6 | #69 |
| P2-E7 | #70 |
| P2-E8 | #71 |
| P2-E9 | #72 |
| P3-E1 | #73 |
| P3-E2 | #74 |
| P3-E3 | #75 |
| P3-E4 | #76 |
| P3-E5 | #77 |
| P3-E6 | #78 |
| P3-E7 | #79 |
| P2-E1.1 | #80 |
| P2-E1.2 | #81 |
| P2-E1.3 | #82 |
| P2-E1.4 | #54 (carried) |
| P2-E1.5 | #83 |
| P2-E2.1 | #84 |
| P2-E2.2 | #85 |
| P2-E2.3 | #86 |
| P2-E2.4 | #39 (carried) |
| P2-E2.5 | #34 (carried) |
| P2-E3.1 | #87 |
| P2-E3.2 | #88 |
| P2-E3.3 | #89 |
| P2-E3.4 | #90 |
| P2-E4.1 | #91 |
| P2-E4.2 | #92 |
| P2-E4.3 | #93 |
| P2-E5.1 | #31 (carried) |
| P2-E5.2 | #35 (carried) |
| P2-E5.3 | #32 (carried) |
| P2-E5.4 | #38 (carried) |
| P2-E5.5 | #40 (carried) |
| P2-E6.1 | #94 |
| P2-E6.2 | #95 |
| P2-E6.3 | #96 |
| P2-E7.1 | #41 (carried) |
| P2-E7.2 | #42 (carried) |
| P2-E7.3 | #97 |
| P2-E8.1 | #98 |
| P2-E8.2 | #99 |
| P2-E8.3 | #37 (carried) |
| P2-E8.4 | #36 (carried) |
| P2-E8.5 | #100 |
| P2-E8.6 | #101 |
| P2-E9.1 | #102 |
| P2-E9.2 | #103 |
| P2-E9.3 | #104 |
