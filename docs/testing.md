# Testing strategy

Short version: **our code lives in the Splice fork, so we test it with Splice's own framework.** We
do **not** adopt `canton-middleware`'s structure (it's a separate Go service that drives Canton as an
external client) — though we borrow its *generic* black-box patterns for our LocalNet harness.

Three tiers, by what they cover and where they live.

## Tier 1 — Daml Script tests (primary, for on-ledger logic)

Fast, no network; auto-discovered and run by Splice CI (no registration needed).

- **Where** (in the `splice/` submodule): `daml/<pkg>-test/daml/Splice/Scripts/`.
  - AmuletRules / CC choices → `splice-amulet-test`
  - DsoRules / governance votes → `splice-dso-governance-test`
- **Run** (in the Nix dev shell): `sbt splice-amulet-test-daml/Test/damlTest` (or `splice-dso-governance-test-daml/Test/damlTest`). Granularity is per-package — `dpm test` runs every `Script ()` in the package.
- **Ours (green):** `TestBuyDedicatedSyncTraffic.daml` (buy: happy path + below-min-topup + wrong-`expectedDso` + `RegisteredSynchronizer` empty-id `ensure`) and `TestRegisterSynchronizer.daml` (register via a supermajority vote).
- **Checklist for a new test:** file `Test<Feature>.daml` (module name = path), `test_* : Script ()`, reuse `Splice.Scripts.Util` (`setupDefaultAppWithUsers`, `tap`, `getTransferContext`, `fetchAmuletRulesByKey`) and `Splice.Scripts.DsoTestUtils` (`initMainNet`, `initiateAndAcceptVote`); cover the negative with `submitMustFail`. No bootstrap by hand.

## Tier 2 — Scala integration tests (apps / automation, real Canton)

For the parts that aren't pure ledger logic: the reconcile trigger, the operator node, Scan endpoints (WS1). Spins up a real Canton and drives it via Canton-console app-references.

- **Where:** `apps/app/src/test/scala/org/lfdecentralizedtrust/splice/integration/tests/<Name>IntegrationTest.scala`.
- **Framework:** extend `SpliceTests.IntegrationTest`; env via `EnvironmentDefinition.simpleTopology1Sv(...)`; drive triggers deterministically with `TriggerTestUtil.setTriggersWithin` / `trigger[T].runOnce().futureValue`. Closest template: `MemberTrafficIntegrationTest.scala`.
- **Required after adding one:** `sbt updateTestConfigForParallelRuns`, then commit the changed root `test-*.log` (the CI shard manifest) — otherwise static checks fail.
- Not built yet (the WS1 Scala code doesn't exist). This is the template to follow when it lands.

## Tier 3 — black-box LocalNet e2e (control-center harness)

Drives a running multi-sync network via CLI/console/API. This is the analogue of canton-middleware's e2e, and it lives **here**, not in the fork.

- **Where:** `scripts/localnet-{up,down,e2e}.sh` (+ `docs/localnet.md`).
- **Now:** `localnet-e2e.sh` smoke-checks (both synchronizers connected + a CC tap) and self-skips when the stack is down.
- **Phase 2:** grows into the register → buy → grant → drawdown console driver (needs the custom-DAR `splice-app` image).
- **Borrowed generic patterns** (from canton-middleware / canton-x402-facilitator — patterns only, no coupling): opt-in isolation, runtime discovery of ports/ids, wait-for-health via Docker healthchecks, "poll to a terminal state then assert, with the last-seen value in the failure message," and teardown on exit.

## Policy

- Fork changes are tested in the fork (Tiers 1/2) — that is what Splice CI gates.
- Do **not** couple to `canton-middleware`; only adopt generic patterns into Tier 3.
- Run Daml tests inside the Nix dev shell: `direnv exec . sbt '<proj>/Test/damlTest'` (env setup: `AGENTS.md` / `docs/localnet.md`).
