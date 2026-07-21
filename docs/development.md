# Development: environment setup + running tests

A followable guide to get from a fresh clone to building and testing the Daml PoC. The code lives in
the `splice/` submodule (the `ChainSafe/splice` fork); it builds with a Nix dev shell (provides
`dpm` / `sbt` / JDK / `damlc`) loaded by direnv. Deeper Splice-specific details:
`splice/DEVELOPMENT.md`.

## 0. Prerequisites

- **Docker Desktop** (for LocalNet). Raise its memory to ~10 GB for the multi-sync profile.
- **git**, plus **Nix** and **direnv** for the dev shell (step 2).

## 1. Clone (with the submodule)

```
git clone --recurse-submodules git@github.com:ChainSafe/canton-extending-mainnet.git
# already cloned without submodules?
git submodule update --init splice
```
The `splice/` submodule tracks the fork's `daml-poc-buy-traffic` branch (carries the PoC).

## 2. One-time environment setup (Nix + direnv)

1. **direnv:** `brew install direnv`, then hook it into your shell (add to `~/.zshrc`):
   ```
   eval "$(direnv hook zsh)"
   ```
2. **Nix:** `bash <(curl -sSfL https://nixos.org/nix/install)`
3. **Enable flakes:**
   ```
   mkdir -p ~/.config/nix
   echo 'extra-experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
   ```
4. **macOS gotcha — make sure `nix` is on PATH in every shell.** Add near the TOP of `~/.zshrc`:
   ```
   if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
     . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
   fi
   ```
   (If `nix` is missing right after `source ~/.zshrc`, that's the daemon script's once-per-shell
   guard — just open a fresh terminal.)
5. **Authorize + build the dev shell:**
   ```
   cd splice
   direnv allow
   ```
   The first load builds/downloads the whole toolchain — **multi-GB and slow**. A
   `Nix daemon disconnected unexpectedly` on the very first build is usually resource contention while
   building the full shell; just **re-run** — Nix resumes from cache and gets further each time.

**Verify:** inside `splice/`, `nix --version` and `which sbt dpm` both resolve.

## 3. Build + test the Daml

Everything runs inside the dev shell. If direnv is loaded in your interactive shell (you `cd splice`)
you can call `sbt` directly; for scripts / non-interactive use, wrap with `direnv exec .`:

```
cd splice

# Build the PoC packages
direnv exec . sbt 'splice-amulet-daml/damlBuild' 'splice-dso-governance-daml/damlBuild'

# Run the Daml Script tests
direnv exec . sbt 'splice-amulet-test-daml/Test/damlTest'
direnv exec . sbt 'splice-dso-governance-test-daml/Test/damlTest'
```
- `damlTest` runs *every* `Script ()` in the package (no single-test selector). `DAML_DEBUG=1` for verbose.
- What the tests cover + how to add one: **`docs/testing.md`**.

Expected green (our PoC): `test_RegisterSynchronizer_viaVote`; `test_BuyDedicatedSyncTraffic` +
`_belowMinTopup` + `_wrongExpectedDso`; `test_RegisteredSynchronizer_ensureNonEmpty`.

## 4. LocalNet (black-box e2e)

From the repo root (drives the `splice/` submodule):
```
scripts/localnet-up.sh      # then: scripts/localnet-e2e.sh   ;   tear down: scripts/localnet-down.sh
```
Full guide: **`docs/localnet.md`**.

## 5. Working on the code (submodule workflow)

- Edit in `splice/`, work on a branch, commit, push to the `ChainSafe/splice` fork.
- Then in this repo: `git add splice` to bump the pointer + commit. **Push the submodule before the
  superproject**, or the superproject points at a commit nobody else can fetch.
- **Before you push a fork PR:** read [`splice-ci.md`](splice-ci.md) - the CI gates (`[ci]` + DCO
  sign-off + release-line branch), the Daml static checks that pass `damlc build` but fail CI (warts,
  generated docs), the no-force-push rule, and a local pre-flight you can run to pass CI first try.

## Troubleshooting

- **`sbt: command not found`** — the dev shell isn't loaded. `cd splice && direnv allow`; see step 2.4.
- **`direnv: error .../.envrc is blocked`** — run `direnv allow` at that path (allow is per-path, so it
  must be re-approved after the checkout moves).
- **`Nix daemon disconnected unexpectedly` on first build** — resource contention building the full
  shell; re-run (it resumes incrementally from cache).
- **Deeper Splice / Canton build details** — `splice/DEVELOPMENT.md`.
