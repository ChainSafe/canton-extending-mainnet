# Splice CI and PR workflow

How to get a PR through Digital Asset's Splice CI on the first try. Our code lives in the `splice/`
submodule, whose `origin` is the DA feature fork **`canton-network/splice-multi-sync`**; that fork
runs DA's own CI (self-hosted runners, private container). Most of our back-and-forth has come from
a few non-obvious rules below, all of which you can check locally before pushing.

For environment setup and the build/test commands, see [`development.md`](development.md); for the
test tiers, [`testing.md`](testing.md). This doc is the CI and git-workflow layer on top.

## PR / git workflow

- **Two rung branches.** The PoC is split into `multi-sync-poc-registration` (rung 1, governance
  registration) and `multi-sync-poc-buy-traffic` (rung 2, the CC-funded buy). Buy **builds on**
  registration. A fix to shared/rung-1 code goes on `registration` first, then is **merged** into
  `buy` (not cherry-picked, not rebased), so the two stay consistent.
- **Never force-push.** On any branch (fork branches, the `splice/` submodule, this control-center
  repo). Force-push rewrites history that PRs, CI, and teammates track. Instead: add new commits,
  **merge** `main`/upstream in when behind (do not rebase), and `git revert` to undo a landed change.
- **Bake in the CI requirements from the first commit** (below): `[ci]` and `Signed-off-by`. Because
  we never force-push, you cannot amend them in later without a history rewrite.
- **Submodule push order.** When you change code in `splice/`: commit and push the submodule to the
  fork **first**, then `git add splice` here and push the superproject. Otherwise the superproject
  points at a commit nobody else can fetch.

## CI setup gates (miss one and the real jobs never run)

1. **`[ci]` opt-in.** CI only runs the real jobs if the branch's **head commit message** contains
   `[ci]`. Without it, jobs auto-cancel and you see only planner/gate jobs "pass". Put `[ci]` in
   every commit so any new head (including a merge commit) carries it.
2. **DCO sign-off.** Every commit needs a `Signed-off-by:` line matching the author. Use
   `git commit --signoff` (and `git merge --signoff` for merge commits). A missing sign-off fails
   the DCO check.
3. **Release-line branch mirror (one-time per release).** A feature fork must contain the upstream
   `release-line-<version>` branch (for us, `release-line-0.6.11`), or CI's container/runner setup
   fails with "Fetch release line ... failed". Mirror it from upstream with a normal branch push.
   See Splice CONTRIBUTING, "Maintaining a feature fork". (Already done for 0.6.11.)

## Daml static checks (deterministic - fix these locally, never let CI find them)

These run in the `static_tests` job **before** any tests, so they gate everything.

- **Daml warts (`scripts/check-daml-warts.sh`).** Bans "naked" `fetch` / `archive`. It is a
  `git grep` for the words `fetch`, `archive`, and `exercise.*_Fetch`, and it **only ignores
  full-line `--` comments**. So a **trailing** inline comment that contains the bare word `fetch` or
  `archive` fails the check, for example:
  ```
  p : Party -- ^ the reader; authorizes the fetch     -- FAILS (trailing "fetch")
  ```
  Allowed helper identifiers do not match (no word boundary): `fetchAndArchive`,
  `fetchReferenceData`, `fetchButArchiveLater`, `fetchPublicReferenceData`, `potentiallyUnsafeArchive`.
  Note: macOS `grep` mishandles the `\b`/`\s` anchors, so a bare local run of the script can report a
  false "clean". Check with a Linux-equivalent regex (or `git grep -P`).
- **Generated Daml docs (`gen-daml-docs.sh`, i.e. `dpm docs`).** Runs in `static_tests`
  ("SBT-based static checks") and in the separate `docs` job. **Do not attach a Haddock `-- |` doc
  comment directly to a `choice`** - `dpm docs` fails with `parse error on input '-- |'`, while
  `damlc build` ignores it (so your tests stay green and only the docs build breaks). Convention:
  choices use plain `--` comments (no choice in `splice-amulet` uses `-- |`). `-- |` is fine on
  templates, `data`, top-level functions, and module headers; `-- ^` is fine on choice `with`-fields.
  Test scripts (`**.Scripts.**`) are excluded from doc generation, so their comments never matter.
- **Other static steps** (rarely an issue, but they exist): trailing whitespace, Daml return-types
  check, Daml interface-implementations check, TODO format, GitHub-Actions lint, docker base images
  pinned by digest, npm package namespacing.
- **New Scala test files** require `sbt updateTestConfigForParallelRuns` and committing the updated
  root `test-*.log` (checked by the "Verify no changes in SBT test files" step).

## The infra flake (not your code)

DA's self-hosted runners share a Maven/Nix cache that intermittently throws
`java.io.IOException (Stale file handle)` while downloading dependencies or building the Nix
environment. It surfaces as `daml_test`, `scala_test_*`, `docs`, or `ui_tests` failing at their
"Run ..." / "Build ..." step. It is infrastructure, not our code. When a job is red, read the
**failing step's log**, not just the red X: if it says "download error: ... Stale file handle" or
"Failed to build and enter the nix environment", just re-run. Tracked in DACH-NY/cn-test-failures.

## Local pre-flight (run before every push)

In the dev shell (see [`development.md`](development.md); on macOS make sure `nix` is on PATH):

```
cd splice

# 1. Daml Script tests (should be all green)
direnv exec . sbt 'splice-amulet-test-daml/Test/damlTest' 'splice-dso-governance-test-daml/Test/damlTest'

# 2. Daml docs generation for each package you touched (must exit 0)
#    (mirrors gen-daml-docs.sh; excludes test scripts)
for pkg in daml/splice-amulet daml/splice-dso-governance; do
  ( cd "$pkg" && direnv exec . dpm docs $(find daml -name '*.daml') \
      --exclude-modules '**.Scripts.**' -f rst -o /tmp/docs-$(basename $pkg) ) \
    && echo "docs OK: $pkg"
done

# 3. Daml warts (use a Linux-equivalent grep; the raw script under-reports on macOS)
```

If 1-3 pass and your commits carry `[ci]` + `Signed-off-by`, the only remaining CI risk is the
Stale-file-handle flake above.
