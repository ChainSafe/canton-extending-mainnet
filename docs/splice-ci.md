# Splice CI: rules for getting a PR through

How to land a change on the DA feature fork (`canton-network/splice-multi-sync`, the `splice/`
submodule) and pass its CI on the first try. Almost every rule below is invisible to a local
`daml build` / `daml test`, which is why they cause round-trips. All are checkable locally in the
dev shell before you push. Env setup + build commands: [`development.md`](development.md); test
tiers: [`testing.md`](testing.md).

## PR / git workflow

- **Two rung branches.** `multi-sync-poc-registration` (rung 1, governance registration) then
  `multi-sync-poc-buy-traffic` (rung 2, Amulet-funded buy), which **builds on** registration. Land a
  shared/rung-1 fix on `registration`, then **merge** it into `buy` (never rebase, never cherry-pick).
- **Never force-push** — fork branches, the submodule, or this repo. Add new commits, **merge** when
  behind (not rebase), `git revert` to undo.
- **Bake `[ci]` + `Signed-off-by` into every commit from the start** (see gates) — no force-push
  means you cannot amend them in later.
- **Submodule push order:** push `splice/` to the fork first, then `git add splice` + push here.

## CI setup gates (miss one and the real jobs never run)

1. **`[ci]` in the head commit message.** Otherwise the real jobs auto-cancel and only planner/gate
   jobs "pass". Keep it in every commit so any new head (incl. a merge commit) has it.
2. **DCO sign-off** on every commit: `git commit --signoff` (and `git merge --signoff`). Must match
   the author.
3. **Release-line mirror (one-time per release).** The fork must contain upstream
   `release-line-<version>` (e.g. `release-line-0.6.11`) or CI's container setup fails ("Fetch
   release line ... failed"). Push it from upstream. (Done for 0.6.11.)

## Daml source rules (pass `daml build`, fail CI)

Enforced in `static_tests` before any tests. The three that bite:

- **Warts (`scripts/check-daml-warts.sh`):** no bare `fetch` / `archive`. It `git grep`s for those
  words and only exempts **full-line** `--` comments, so a *trailing* comment containing "fetch" or
  "archive" fails. Allowed helpers don't match (no word boundary): `fetchAndArchive`,
  `fetchReferenceData`, `fetchButArchiveLater`, `fetchPublicReferenceData`, `potentiallyUnsafeArchive`.
- **Doc comments on choices (`gen-daml-docs.sh` / `dpm docs`):** never attach a Haddock `-- |` doc
  comment to a `choice` (`parse error on input '-- |'`). Choices use plain `--`. `-- |` is fine on
  templates / `data` / functions / modules; `-- ^` is fine on fields. `**.Scripts.**` (tests) are
  excluded from docs.
- **Terminology / "whitelabel" (`scripts/rename.sh no_illegal_daml_references`):** Splice scrubs
  branded/legacy terms from Daml. **Banned words** (case-insensitive, anywhere in `daml/`): `global`,
  `coin`, `domain`, `cn`, `collective`, `consortium`, `whitepaper`, `currency`, `founder`/`founding`,
  `leader`, `google`, `DsoReward`. **Restricted phrasings:** `DSO` only as `DSO party` / `DSO
  governance` / `DSO rules` / `DSO delegate` / `DSO-level` / `DSO automation`; no bare `Dso`/`dso` in
  comments except `DsoRules` / `dsoParty`; no bare `CC`/`cc`; no bare `member`. Substitutions we use:

  | Instead of | Write |
  |---|---|
  | global synchronizer / non-global | decentralized synchronizer / dedicated |
  | CC, Canton Coin | Amulet |
  | "the DSO", "a DSO vote", "DSO of X" | "the DSO party", "DSO governance" |
  | `splice-dso-governance` (in a comment) | "the governance package" |
  | `expectedDso` / `ForDso` (in a comment) | "the expected DSO party" / "MemberTraffic group-id" |

  macOS `grep`/`rg` can't replicate the PCRE faithfully — run the real check in the dev shell (it
  needs `TOOLS_LIB` + `rg`, both provided there).

Others rarely bite: trailing-whitespace, Daml return-types, Daml interface-impls, GHA lint,
image-digest pinning, npm namespacing. `check-todos` needs `GITHUB_TOKEN` (unrunnable locally, passes
in CI). `check-repo-names` currently fails on **pre-existing** Splice files only — not our code and
not a gating step.

## Regenerate generated artifacts on ANY Daml change (even a comment)

A Daml source change changes the compiled DAR, so `static_tests` (`SBT-based static checks` +
`Verify no changes in SBT test files`) fails until you regenerate and commit:

1. `sbt damlDarsLockFileUpdate` — refreshes checked-in `daml/dars/*.dar` + `daml/dars.lock`
   (`DarLockChecker`). Committing the binary DARs is expected. **No version bump** unless the
   package version already exists in the release line
   (`git show origin/release-line-<ver>:daml/dars.lock`); if it does, run
   `sbt 'damlBumpPackageVersionsMutate origin/main'` first.
2. `sbt updateDarResources updateTestConfigForParallelRuns` — regenerates
   `apps/.../environment/DarResources.scala` (the generated file pinning each DAR's package-id) and
   test config. Commit the regenerated `DarResources.scala`, or `Verify no changes in SBT test files`
   fails.

These run inside `SBT-based static checks` in order (docs -> DarLock -> DarResources), so an earlier
failure masks a later one; expect them to surface one at a time.

## Smart-contract upgrade (SCU) compatibility

`daml build` + tests pass regardless, so these bite late (compat check / package vetting):

- **Append new serializable-variant constructors LAST** (LF encodes constructor ranks). A new
  `SRARC_*` in `DsoRules_ActionRequiringConfirmation` goes after all existing ones, before
  `deriving`. Matching is by name, so `case` arms / choices can sit anywhere.
- **Additive-only for released types:** new templates, new choices, new records are fine; do not
  reorder/remove constructors or change field order of a released serializable record.

## Infra flakes (not your code — re-run)

DA's shared self-hosted runners flake in two ways. Read the **failing step's log**, not just the red X:

- **Stale file handle** (`java.io.IOException`) during Maven download / nix-env build. Hits
  `daml_test`, `scala_test_*`, `docs`, `ui_tests` at their "Run/Build" step.
- **wall-clock-time timeout** (exit code **124**): heavy scala integration shards run out of time
  (~40+ min) under load — the tests themselves pass (`Failed 0, Errors 0`), the shard just doesn't
  finish. Known DA issue (`timeout-minutes: 60 # TODO(#3013)`).

Fix: re-run the failed jobs — `gh run rerun <run-id> --failed`. If they keep timing out it is DA
infra, unrelated to our additive Daml; raise it with DA rather than changing our code.

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

# 4. If any Daml source changed: regenerate + stage the artifacts
direnv exec . sbt 'damlDarsLockFileUpdate' 'updateDarResources' 'updateTestConfigForParallelRuns'
git add daml/dars.lock daml/dars '**/DarResources.scala' test*.log
```

If 1-4 are clean, the change is SCU-safe (above), and every commit carries `[ci]` + `Signed-off-by`,
the only remaining CI risk is the infra flakes.
