# CLAUDE.md

Guidance for Claude Code when working in this repository. **Read [`AGENTS.md`](AGENTS.md) first** — it is the agent-agnostic index (sibling projects + how to navigate this control-center repo); this file adds Claude-specific notes.

## Project

**canton-extending-mainnet** is ChainSafe's implementation work for the Canton CIP **"Extending Mainnet: Tokenomics Alignment Across the Entire Canton Network"** (Shaul Kfir, Digital Asset). It generalizes Canton's single Global-Synchronizer traffic-purchase + Burn-Mint flow into per-synchronizer, per-transaction-class, discount-curve, optionally-staked pricing across all extension synchronizers.

**This is a standalone project. It is NOT related to `canton-middleware`** (a separate ChainSafe repo). Do not reference, import from, or write to canton-middleware.

- **Repo roles:** this repo (`ChainSafe/canton-extending-mainnet`) is the **tooling / analysis / docs / planning** hub and the **issue tracker for all epics** (T0/T1 + E0-E10). The actual on-ledger + app **code** changes live in the Splice fork `canton-network/splice-multi-sync` (the PoC ladder, merging into the long-running `feat/dedicated-sync`). See `README.md`.
- **Design docs / analysis:** now in this repo under `docs/cip/` (technical plan, kickoff, diagrams, exec summary, presenter notes) - merged in from the former `ChainSafe/canton-cip-docs`, which is **archived**. Working design + planning live under `docs/design/` and `docs/planning/`.
- **ChainSafe's role:** as a Super Validator and prospective dedicated-synchronizer operator, co-designing and piloting the CIP with Digital Asset.

## Stack

Match Splice's stack:
- **Daml** for on-ledger contracts (developed against Daml SDK **3.4.8**).
- **Scala/JVM** for apps + automation (later, matching Splice's SV/validator triggers).
- **Docker LocalNet** for local end-to-end testing (Splice's Docker-based local network).
- Splice source: `canton-network/splice` (mirror: `hyperledger-labs/splice`); Canton: `digital-asset/canton`.

## Layout

This is a "control center" repo — see [`AGENTS.md`](AGENTS.md) for the full map + sibling projects. In brief:
- `splice/` — submodule -> **`canton-network/splice-multi-sync` fork** (the code: Daml + Scala + TS + vendored Canton). Work in it, push to the fork, then `git add splice` in this repo to bump the pointer. Push the submodule before the superproject.
- `docs/` — `architecture.md`, `design/`, `cip/` (merged from the archived canton-cip-docs), `planning/`, `localnet.md`.
- `history/` — `rfcs/`, `meetings/`, `experiments/`, `incidents/`, `CHANGELOG.md`.
- `scripts/` LocalNet harness · `tools/` navigator · `deploy/` deployment overlays (RFC-001) · `telemetry/` (RFC-003) · `sync-pricing/` parked pricing analysis.

## Common commands

```
cd sync-pricing
daml build                       # compile the pricing library to a DAR
daml test                        # run the acceptance tests (currently 14 scripts, all green)
```

## Status & next steps

- **Done:** shadow-mode pricing engine (off-ledger, pure Daml, no Splice dependency). Reproduces the CIP Section 5 table; encodes the Section 6.2 `(1 - D)` factor fix as an executable test; three tiers (100/30/10); extension-only throughput discount; smooth + tiered modes (recommend **tiered** on-ledger to avoid Numeric rounding drift).
- **Done:** `splice/` submodule now points at the **`canton-network/splice-multi-sync` fork** (full history, tracking `feat/dedicated-sync`, the fork's long-running merge target). LocalNet lives at `splice/cluster/compose/localnet`; the harness (`scripts/localnet-*.sh`) pulls published `ghcr.io/digital-asset/...` images by `IMAGE_TAG` (default 0.6.13).
- **Done:** brought up Docker LocalNet (full `sv`+`app-provider`+`app-user` stack, verified 2026-07-08) and observed the real `AmuletRules_BuyMemberTraffic` -> `splitAndBurn` (mints `ValidatorRewardCoupon`) -> `SetTrafficPurchased` flow fire with no manual trigger. Runs in ~4.8 GiB of the 7.7 GiB Docker allocation. See [[splice-localnet]] memory for the exact command + observed numbers.
- **Done:** cents/tx-to-bytes conversion harness (`TrafficConversion.daml`): faithful ports of Canton's `EventCostCalculator` (integer byte cost) and Splice's `computeSynchronizerFees` (bytes -> USD -> CC), plus the inverse (CIP cents/tx -> bytes/CC). Grounded by `TrafficConversionTest.daml`, which pins Canton's own unit-test vectors AND reproduces the live LocalNet buy exactly (1,200,000 bytes -> $20.004 -> 4000.8 CC at extraTrafficPrice=$16.67/MB, scaling=4, amuletPrice=$0.005/CC, baseEventCost=0, all read from the running Scan API).
- **Next / Later (gated on Digital Asset answers):** wire per-synchronizer pricing into `AmuletConfig` (a schema change — it is a single config today, not a map), the commitment-stake + coupon-free shortfall burn, and the report-to-mint path.

## Conventions

- Grounded in real Splice/Canton source: `computeSynchronizerFees` (AmuletRules.daml; round `trafficPrice` takes precedence over config `extraTrafficPrice`), `splitAndBurn` mints a `ValidatorRewardCoupon`, `SynchronizerFeesConfig` in DecentralizedSynchronizer.daml.
- Docs style (carried from canton-cip-docs): avoid em/long dashes; direct language.

## Splice contribution policy (check before every fork PR)

The fork carries upstream's policy files and they bind our work. **Read them, do not work from this
summary:** `splice/CONTRIBUTING.md`, `splice/AI_POLICY.md`, `splice/TESTING.md`,
`splice/MAINTAINERS.md`. For the mechanical CI gates (setup gates, terminology, headers, artifact
regeneration, SCU, flakes, local pre-flight) see [`docs/splice-ci.md`](docs/splice-ci.md), which is
authoritative and not repeated here.

**AI policy (`AI_POLICY.md`), the one that binds us most.** We are fully accountable for every line
submitted under our name, must understand it, and must be able to say why each change is there; "the
AI wrote it" is not an answer. Self-review aggressively before asking for review. Do not open a PR we
would not have opened without AI. Issues and PRs that read as unreviewed AI output (overlong and
padded, referencing things that do not exist, plausible-sounding but wrong, bot-style prose) **may be
closed without discussion**, and repeat offences can get an account blocked. The same rule applies to
review comments we leave on other people's PRs: do not post AI-generated feedback we have not read
carefully and cannot defend. A PR opened by a named human keeps the single-approval rule; only
bot-opened or fully autonomous PRs need two human reviewers. There is no duty to label AI assistance,
but never deny it if asked.

**Daml changes need a maintainer conversation first.** Adopting them on a prod system takes an SV
supermajority vote, so `CONTRIBUTING.md` asks contributors to reach out to the Splice Maintainers
before proposing the change, not after opening the PR.

**Backwards compatibility.** All Daml changes must be backwards compatible. Variant and enum
constructors may now be added directly; the `ExtFoo` constructors are historical workarounds and can
be ignored. The live hazard is different: **only add nullary constructors to a type whose
constructors are all nullary**, or a Daml-LF enum silently becomes a variant and the codegen changes
shape.

**Testing.** "Every contribution must be tested in an automated test." A LocalNet profile or a manual
run does not satisfy this.

**Naming and types**, from `CONTRIBUTING.md`, worth knowing before writing rather than in review:
use `amount`, never `quantity` or `number`; use `sender`/`receiver`, never `payer`/`payee`; use
`listXXX`/`acceptXXX`/`rejectXXX`/`withdrawXXX` for proposal management; config flags are `enableXXX`,
never `disableXXX`; prefer Scala types and convert to Java as late as possible; Daml `Numeric` is
`scala.math.BigDecimal` in Scala and `string` in protobuf.

**Scan update-history types are BFT-consensus types.** Any schema change to one breaks JSON equality
across SVs running different versions. Adding an `Option[_]` is the trap, because circe emits
`"field": null` where old code omits the key: use `Option[OmitNullString]` with the `omitWhenNone`
helper, or gate the change behind a threshold record time. This applies to the OpenAPI types, not to
Daml payloads, which are stored structurally by `ProtobufCodec.serializeValue` and so cannot diverge
between SVs.

**Where our fork knowingly diverges.** These are the feature fork's own choices, not defects, but
they matter when the fork is upstreamed and they should not be re-argued in every review.
`CONTRIBUTING.md` documents squash-and-merge with CI tags stripped and noise like "address review
comments" removed, while the fork uses merge commits and keeps `[ci]` in history. Upstream PR titles
are imperative with no conventional-commit prefix plus a trailing `(#N)`, e.g. "Add new ACS snapshot
endpoints using opaque pagination tokens (#6995)", while the fork uses `feat:`/`fix:`. Branches are
documented as `<yourname>/<descriptive>` and the fork uses `feat/<topic>`.

## Git Commit Rules

Never include "Co-authored-by" or any reference to Claude/Anthropic in commit messages or pull requests.
