# Splice CI: rules for getting a PR through

How to land a change on the DA feature fork and pass its CI on the first try. Almost every rule
below is invisible to a local `daml build` / `daml test`, which is why they cause round-trips. All
are checkable locally in the dev shell before you push. Env setup + build commands:
[`development.md`](development.md); test tiers: [`testing.md`](testing.md).

**The fork + remote.** The `splice/` submodule's code home is the DA feature fork
**`canton-network/splice-multi-sync`**, which runs DA's CI. In a set-up working copy that is the
`origin` remote; a fresh clone may still show `ChainSafe/splice` until the submodule repoint lands
(tracked in the control-center PR that updates `.gitmodules`). Confirm with `git -C splice remote -v`
and push to the remote that is `canton-network/splice-multi-sync` (below we call it `origin`).

## PR / git workflow

- **The fork's merge target is `feat/dedicated-sync`**, DA's long-running feature branch (their
  direction), so the fork's `main` stays a clean mirror of upstream `canton-network/splice` and
  never takes our commits. `main` remains the target in this repo.
- **Stack PRs when the work depends on unmerged work.** Base the PR on the branch it builds on, not
  the merge target. Fixes to shared/base work flow downstack: land them on the base branch, then the
  dependent branch absorbs them (merge, or rebase onto the target after the base squashes; owner's
  choice). Stacks are queues for the merge target, not long-lived lines. (The PoC ran this way:
  `multi-sync-poc-registration`, then `multi-sync-poc-buy-traffic` on top.)
- **Retarget the child before deleting a merged parent's branch.** GitHub only auto-retargets
  dependent PRs when the branch is deleted through the web UI's post-merge button; `gh pr merge
  --delete-branch` deletes the raw ref and **closes** dependent PRs instead. `gh pr edit <child>
  --base <target>` first, then merge and delete.
- **Everything squash-merges into the target.** Each PR lands as a single commit (the upstream
  Splice convention), which keeps each reviewed unit cleanly revertable and keeps PR-discussion
  fixups in the PR record rather than the target's history. The squash commit message must carry
  `[ci]` and `Signed-off-by`. (Rungs 1–2 landed on `feat/dedicated-sync` this way.)
- **Do not rewrite shared history.** Never rewrite `main`, `release-line-*`, or
  `feat/dedicated-sync` once others build on it, and coordinate before rewriting a branch someone
  else has stacked on. Otherwise force-pushing or amending your own open PR branch is fine; with
  submodule pins restricted to `feat/dedicated-sync` and squash-merge, it breaks nothing.
- **`[ci]` on the head commit.** The branch tip must carry `[ci]` or the real jobs auto-cancel (see
  gates); a new head from a merge or an amend needs it too.
- **Submodule push order:** push `splice/` to its remote first, then `git add splice` and push here.

## CI setup gates (miss one and the real jobs never run)

1. **`[ci]` in the head commit message.** Otherwise the real jobs auto-cancel and only planner/gate
   jobs "pass". Any new head (a merge, an amend, or a squash commit) needs it too.
2. **DCO sign-off** on every commit: `git commit --signoff` (and `git merge --signoff`). Must match
   the author.
3. **Release-line mirror (one-time per release).** The fork must contain upstream
   `release-line-<version>` (e.g. `release-line-0.6.11`) or CI's container setup fails ("Fetch
   release line ... failed"). Push it from upstream. (Done for 0.6.11.)

## Daml/Scala source rules (pass `daml build`, fail CI)

- **License header (`headerCheck`, in the `lint` alias).** Every non-generated `.daml` and `.scala`
  file must start with the Apache/DA header, so **any new file you add fails CI without it**:
  ```
  -- Copyright (c) 2024 Digital Asset (Switzerland) GmbH and/or its affiliates. All rights reserved.
  -- SPDX-License-Identifier: Apache-2.0
  ```
  (`.scala` uses the `//` form.) Run `sbt headerCreate` to auto-insert, or `sbt headerCheck` to verify.
- **Warts (`scripts/check-daml-warts.sh`):** no bare `fetch` / `archive`. It `git grep`s
  `(exercise.*_Fetch|fetch|archive)\b` **case-sensitively** and only exempts full-line `--` comments,
  so a *trailing* comment containing "fetch"/"archive" fails. Approved helpers pass for two different
  reasons: `fetchAndArchive` / `fetchReferenceData` / `fetchPublicReferenceData` / `fetchButArchiveLater`
  because `fetch` followed by a capital letter has no word boundary; `potentiallyUnsafeArchive` /
  `fetchAndArchive` because the pattern `archive` is lowercase and they use capital `Archive`.
- **Doc comments on choices (`gen-daml-docs.sh` / `dpm docs`):** never attach a Haddock `-- |` doc
  comment *before* a `choice` (`parse error on input '-- |'`). Surfaces in the separate `docs` job
  **and** in `static_tests` (`Test/compile` builds the docs project's generated resources). To
  document a choice, put `-- ^` on the line *after* the `choice ... : Result` declaration; that is
  the in-tree idiom (`DsoRules_GarbageCollectAmuletPriceVotes`, `DsoRules.daml:935-938`, and many
  others). `-- |` is fine on templates / `data` / functions / modules; `-- ^` is fine on fields.
  `**.Scripts.**` (tests) are excluded from doc generation.
- **Terminology / "whitelabel" (`scripts/rename.sh no_illegal_daml_references`):** Splice scrubs
  branded/legacy terms from Daml. **Banned words** (case-insensitive, anywhere in `daml/`): `global`,
  `coin`, `domain`, `cn`, `collective`, `consortium`, `whitepaper`, `currency`, `founder`/`founding`,
  `leader`, `google`, `DsoReward`. **Banned tokens** (case-sensitive): `svc` / `SVC` / `Svc`.
  **Restricted phrasings:**
  - `DSO` (uppercase word) only as `DSO party` / `DSO governance` / `DSO rules` / `DSO delegate` /
    `DSO-level` / `DSO automation` / `DSO.` (period) / `standard DSO`.
  - capital `Dso` in a comment only as `DsoRules` or `DsoExpire`.
  - lowercase `dso` in a comment only when preceded by a period (dotted access, e.g. `x.dsoParty`);
    a **bare `dso` / `dsoParty` / `dsoRules` word in a comment fails**.
  - no bare `CC` / `cc`; no bare `member`.

  Substitutions we use:

  | Instead of | Write |
  |---|---|
  | global synchronizer / non-global | decentralized synchronizer / dedicated |
  | CC, Canton Coin | Amulet |
  | "the DSO", "a DSO vote", "DSO of X" | "the DSO party", "DSO governance" |
  | `splice-dso-governance` (in a comment) | "the governance package" |
  | `expectedDso` / `ForDso` (in a comment) | "the expected DSO party" / "MemberTraffic group-id" |

  Two more ways it bites: the check is a **line-based** regex, so an allowed phrase that wraps
  across comment lines fails (`...by DSO` / newline / `automation...` — keep "DSO automation" and
  friends on one line); and the case-sensitive `cc` token matches inside hex literals, so test
  synchronizer ids like `1220cccc...` fail — use `aa`/`dd`/`ee` runs in test data.

  macOS `grep`/`rg` can't replicate the PCRE faithfully — run the real check in the dev shell (it
  needs `TOOLS_LIB` + `rg`, both provided there).

Others rarely bite: trailing-whitespace, Daml return-types, Daml interface-impls, `scalafmt` (part of
`lint`; only if you touch Scala), GHA lint, image-digest pinning, npm namespacing. `check-todos`
needs `GITHUB_TOKEN` (unrunnable locally, passes in CI). `check-repo-names` currently fails on
**pre-existing** Splice files only — not our code and not a gating step.

## Regenerate generated artifacts on ANY Daml change (even a comment)

A Daml change changes the compiled DAR, so the `static_tests` step **`SBT-based static checks`** and
then **`Verify no changes in SBT test files`** fail until you regenerate and commit. That step runs
`Test/compile lint updateTestConfigForParallelRuns updateDarResources`, in order:

1. **`Test/compile`** — compiles all Scala incl. tests and builds the docs project's generated docs.
   A Scala/test compile break or a `-- |` doc-parse error fails here first (and masks the rest).
2. **`lint`** — an alias that runs `damlDarsLockFileCheck` (DAR-lock), the terminology check,
   `scalafmtCheck`, and `headerCheck`, among others.
3. **`updateTestConfigForParallelRuns`** — regenerates `test*.log`.
4. **`updateDarResources`** — regenerates `apps/.../environment/DarResources.scala` (pins each DAR's
   package-id).

What you run locally to satisfy them and commit the results:

- `sbt damlDarsLockFileUpdate` — refreshes checked-in `daml/dars/*.dar` + `daml/dars.lock`. Committing
  the binary DARs is expected. **No version bump** unless the package version already exists in the
  release line (`git show origin/release-line-<ver>:daml/dars.lock`); if so, run
  `sbt 'damlBumpPackageVersionsMutate origin/main'` first.
- `sbt updateDarResources updateTestConfigForParallelRuns` — regenerates `DarResources.scala` +
  `test*.log`; commit them or `Verify no changes in SBT test files` fails.

**Merging up with conflicts in the generated files.** The regen tasks patch incrementally and skip
any file containing conflict markers, so markers in `daml/dars.lock` or `DarResources.scala` survive
`damlDarsLockFileUpdate` and land in the commit. Resolve them to anything parseable first, then
regen.

## Smart-contract upgrade (SCU) compatibility

`daml build` + tests pass regardless, so these bite late (compat check / package vetting):

- **Append new serializable-variant constructors LAST** (LF encodes constructor ranks). A new
  `SRARC_*` in `DsoRules_ActionRequiringConfirmation` goes after all existing ones, before
  `deriving`. Matching is by name, so `case` arms / choices can sit anywhere.
- **Additive-only for released types:** new templates, new choices, new records are fine; do not
  reorder/remove constructors or change field order of a released serializable record. Appending an
  `Optional` field to a released record, or to a choice's parameters, is upgrade-legal as long as it
  goes last (`MemberTraffic.operator` and `optRegisteredSynchronizer` are the live examples).

## Required jobs + infra flakes

The `final_result` gate requires: `static_tests`, `docs`, `daml_test`, `deployment_test`,
`ts_cli_tests`, `ui_tests`, and the `scala_test_*` set. Only
`scala_test_with_cometbft` / `docker_compose` / `local_net` / `canton_enterprise` may skip;
`deployment_test` is required even for a static-only PR (opt-in via a `[static]` flag / `static`
label). So a green `static_tests` alone is not enough.

**A job can fail while sbt succeeds.** CI wraps sbt with an output scanner and a post-step log
check, so read the failing step's log before assuming a test broke:

- **Zero `DsWarning`s.** Any Daml warning line in the build output fails the job, even on sbt
  `[success]`. The ones that have bitten: a tuple of size >5 in a Script return type ("Daml only
  has Show/Eq for tuples of size <= 5" — use a record), an unused binding, a non-exhaustive `case`.
- **The canton runtime log check.** The scala_test wrapper ends with
  `(checkErrors) log/canton_network_test.clog contains problems` when canton nodes logged
  above-threshold noise during an otherwise green run; under runner load this fires as a flake
  (all tests passed — re-run).
- **Diagnosis:** the trailer "Executing the custom container implementation failed. Please contact
  your self hosted runner administrator" is the runner's generic message for any failed step, not
  evidence of infra. Grep the job log for `Tests: succeeded` first: sbt-green plus job-red is
  always scanner or infra, never code.

DA's shared self-hosted runners flake in recognizable ways — read the **failing step's log**, not the red X:

- **Stale file handle** (`java.io.IOException`) during Maven download / nix-env build. Hits
  `daml_test`, `scala_test_*`, `docs`, `ui_tests`, `deployment_test` at their "Run/Build" step.
- **wall-clock-time timeout** (exit code **124**): heavy scala integration shards run out of time
  (~40+ min) under load — the tests themselves pass, the shard just doesn't finish. Individual slow
  tests (e.g. token settlement) can also exceed their `eventually` wait under load. The failing set
  varies run-to-run (= load, not broken tests). Known DA issue (`timeout-minutes: 60 # TODO(#3013)`).
- **`connect ETIMEDOUT`** before any real work ran.
- **`SEQUENCER_SUBMISSION_AFTER_UPGRADE_TIME`** WARN in `roll_forward_lsu`: a submission racing the
  upgrade cutoff; the suite passes, the log scanner fails the job.
- **simtime `TrafficBasedRewardsTimeBasedIntegrationTest`** stuck at `...ActivityTotalsUndetermined`
  (an `eventually` timeout under load).
- **splitwell frontend** Selenium `Could not find IdQuery(...)` element-lookup timeouts.
- **docker-compose**: sbt boot-server IPC `EADDRINUSE` during the parallel make kills the DAR
  build, "Waiting for all services" never opens, and the job hangs to a ~55-min cancel.

Fix: re-run the failed jobs — `gh run rerun <run-id> --failed`. If they keep failing on tests
unrelated to your change, it is DA infra — raise it with DA rather than changing our code.

Also cosmetic: a force-push can fire two `pull_request` events a second apart; the concurrency
group cancels one, and the cancelled run's torn-down jobs show unexpanded `${{ inputs.test_name }}`
check names in the PR's check list. Read the surviving run.

## Local pre-flight (dev shell; on macOS ensure `nix` is on PATH)

```
cd splice

# 1. Daml Script tests — keep the log; CI fails the job on ANY DsWarning, even when sbt succeeds
direnv exec . sbt 'splice-amulet-test-daml/Test/damlTest' 'splice-dso-governance-test-daml/Test/damlTest' | tee /tmp/damltest.log
grep -c DsWarning /tmp/damltest.log   # must be 0

# 2. Docs, per changed package (must exit 0)
( cd daml/splice-amulet && direnv exec . dpm docs $(find daml -name '*.daml') \
    --exclude-modules '**.Scripts.**' -f rst -o /tmp/docs-amulet )

# 3. Terminology (authoritative; needs the dev shell)
direnv exec . bash scripts/rename.sh no_illegal_daml_references

# 4. License headers on new files
direnv exec . sbt headerCheck        # or headerCreate to auto-insert

# 5. If any Daml source changed: regenerate + stage the artifacts
direnv exec . sbt 'damlDarsLockFileUpdate' 'updateDarResources' 'updateTestConfigForParallelRuns'
git add daml/dars.lock daml/dars '**/DarResources.scala' test*.log
```

If 1-5 are clean, the change is SCU-safe (above), and every commit carries `[ci]` + `Signed-off-by`,
the only remaining CI risk is the infra flakes.
