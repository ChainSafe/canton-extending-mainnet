# LocalNet for dedicated-synchronizer e2e

A clean, re-runnable Docker LocalNet for testing the dedicated-synchronizer traffic PoC end to
end. Modeled on the setup in `ChainSafe/canton-x402-facilitator`, but it brings up the
**`multi-sync`** profile (a second, dedicated `app-synchronizer` with its own sequencer +
mediator) which our feature needs.

Delivered in two phases:
- **Phase 1 (works today):** stock Splice images. Brings up the full stack + the dedicated
  synchronizer, discovers the ids, and runs a smoke check. Does **not** yet exercise the PoC's new
  choices (stock DARs).
- **Phase 2 (later):** a custom local `splice-app` image carrying the PoC DARs, driving the real
  register -> buy -> grant -> drawdown flow. See the bottom of this file.

## Prerequisites
- Docker Desktop running. **Raise the memory allocation** to ~10 GB: the stock 3-profile run used
  ~4.8 GiB, and `multi-sync` adds the `app-sequencer` + `app-mediator` + a second synchronizer
  bootstrap on top of that.
- `python3` and `curl` (both standard on macOS). No Nix and no `node`/nvm needed for Phase 1.
- The Splice tree at `/Users/s3b/Dev/splice` (0.6.13). Override with `SPLICE_DIR=...`.

## Commands
```bash
scripts/localnet-up.sh        # start; waits for health + multi-sync, discovers ids, prints wiring
scripts/localnet-e2e.sh       # smoke check (self-skips if the stack is down)
scripts/localnet-down.sh      # stop + remove containers, KEEP volumes (ids persist)
scripts/localnet-down.sh --wipe   # also delete volumes + discovered.env (fresh ledger next up)
```
Bring-up takes several minutes on first run (image pulls + synchronizer bootstrap). It is
idempotent - re-running `up` is safe.

## What you get (wiring)
| Thing | Value |
|---|---|
| SV UI | http://localhost:4000 |
| App-provider UI | http://localhost:3000 (wallet user `app-provider`) |
| App-user UI | http://localhost:2000 |
| JSON Ledger API v2 | app-provider `http://localhost:3975/v2`, app-user `http://localhost:2975/v2` |
| Validator admin API | app-provider `http://localhost:3903/api/validator` |
| Auth (unsafe dev) | HS256, secret `unsafe`, aud `https://canton.network.global`, users `ledger-api-user` / `app-provider` |

Discovered ids are written to `.localnet/discovered.env` (gitignored):
`GLOBAL_SYNC_ID`, `DEDICATED_SYNC_ID` (the `app-synchronizer`), `DSO_PARTY` (`DSO::<namespace>`).
These are stable only while the Postgres volume persists - after `--wipe` they change, so re-read
the file after each fresh `up`.

## How it works
`scripts/localnet-common.sh` holds config + helpers (`localnet_compose` wrapper, `mint_token`).
`localnet-up.sh` drives the Splice tree's own compose:
```
docker compose --env-file compose.env --env-file env/common.env \
  -f compose.yaml -f resource-constraints.yaml \
  --profile sv --profile app-provider --profile app-user --profile multi-sync up -d
```
then waits on the `canton`/`splice` Docker healthchecks and the `multi-sync-startup` container,
mints an unsafe HS256 JWT, and discovers the synchronizers via
`GET :3975/v2/state/connected-synchronizers`.

`IMAGE_TAG` defaults to `0.6.13`. If those images are not published on ghcr, fall back with
`IMAGE_TAG=0.6.11 scripts/localnet-up.sh` (Phase 1 does not need our DARs, so any published tag
works for the smoke test).

## Version note
The scripts point at the standalone fork clone `/Users/s3b/Dev/splice` (0.6.13, which carries the
PoC). The `splice` git submodule under this repo is still pinned at 0.6.11; it should later be
bumped to 0.6.13 or retired so there is a single tree.

## Phase 2 - the real on-ledger e2e (not yet wired)
Gated on the Nix dev env (work-plan E0-1) and a compiled PoC (E0-2/E0-3). Steps:
1. In the Nix shell: bump the two modified packages' versions, `sbt <pkg>-daml/damlBuild` (regens
   `DarResources.scala` + Java codegen), `sbt bundle`, then build a local `splice-app` image via
   `cluster/images/local.mk`.
2. `IMAGE_REPO="" IMAGE_TAG=<local-tag> scripts/localnet-up.sh` to run on the custom image.
3. Drive the flow from a Canton console script: base-rate=0, register via governance vote, buy via
   explicit disclosure, manual `SetTrafficPurchased`, then transact + observe drawdown. The
   `scripts/localnet-e2e.sh` TODO block lists the exact steps.
