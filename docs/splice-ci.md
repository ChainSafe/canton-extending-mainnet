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

- **Two rung branches.** `multi-sync-poc-registration` (rung 1, governance registration) then
  `multi-sync-poc-buy-traffic` (rung 2, Amulet-funded buy), which **builds on** registration. Land a
  shared/rung-1 fix on registration, then **merge** it into buy (never rebase, never cherry-pick):
  ```
  git push origin multi-sync-poc-registration
  git checkout multi-sync-poc-buy-traffic
  git merge --signoff multi-sync-poc-registration   # then resolve, regenerate artifacts (below)
  git push origin multi-sync-poc-buy-traffic
  ```
- **Never force-push** — fork branches, the submodule, or this repo. Add new commits, **merge** when
  behind (not rebase), `git revert` to undo.
- **Bake `[ci]` + `Signed-off-by` into every commit from the start** (see gates) — no force-push
  means you cannot amend them in later.
- **Submodule push order:** push `splice/` to `origin` first, then `git add splice` + push here.

## CI setup gates (miss one and the real jobs never run)

1. **`[ci]` in the head commit message.** Otherwise the real jobs auto-cancel and only planner/gate
   jobs "pass". Keep it in every commit so any new head (incl. a merge commit) has it.
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
  comment to a `choice` (`parse error on input '-- |'`). Surfaces in the separate `docs` job **and**
  in `static_tests` (`Test/compile` builds the docs project's generated resources). Choices use plain
  `--`. `-- |` is fine on templates / `data` / functions / modules; `-- ^` is fine on fields.
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

## Smart-contract upgrade (SCU) compatibility

`daml build` + tests pass regardless, so these bite late (compat check / package vetting):

- **Append new serializable-variant constructors LAST** (LF encodes constructor ranks). A new
  `SRARC_*` in `DsoRules_ActionRequiringConfirmation` goes after all existing ones, before
  `deriving`. Matching is by name, so `case` arms / choices can sit anywhere.
- **Additive-only for released types:** new templates, new choices, new records are fine; do not
  reorder/remove constructors or change field order of a released serializable record.

## Required jobs + infra flakes

The `final_result` gate requires: `static_tests`, `docs`, `daml_test`, `deployment_test`,
`ts_cli_tests`, `ui_tests`, and the `scala_test_*` set. Only
`scala_test_with_cometbft` / `docker_compose` / `local_net` / `canton_enterprise` may skip;
`deployment_test` is required even for a static-only PR (opt-in via a `[static]` flag / `static`
label). So a green `static_tests` alone is not enough.

DA's shared self-hosted runners flake in two ways — read the **failing step's log**, not the red X:

- **Stale file handle** (`java.io.IOException`) during Maven download / nix-env build. Hits
  `daml_test`, `scala_test_*`, `docs`, `ui_tests`, `deployment_test` at their "Run/Build" step.
- **wall-clock-time timeout** (exit code **124**): heavy scala integration shards run out of time
  (~40+ min) under load — the tests themselves pass, the shard just doesn't finish. Individual slow
  tests (e.g. token settlement) can also exceed their `eventually` wait under load. The failing set
  varies run-to-run (= load, not broken tests). Known DA issue (`timeout-minutes: 60 # TODO(#3013)`).

Fix: re-run the failed jobs — `gh run rerun <run-id> --failed`. If they keep failing on tests
unrelated to your change, it is DA infra — raise it with DA rather than changing our code.

## Local pre-flight (dev shell; on macOS ensure `nix` is on PATH)

```
cd splice

# 1. Daml Script tests
direnv exec . sbt 'splice-amulet-test-daml/Test/damlTest' 'splice-dso-governance-test-daml/Test/damlTest'

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
