# RFC-001: NixOS deployment descriptions

**Status:** Draft. Skeleton lives in `deploy/`.

## Motivation

We prefer executable specs over prose — they never drift. Today deployment is docker-compose
(LocalNet, via `scripts/` over the `splice/` submodule) plus Splice Helm charts
(`splice/cluster/helm`). Neither is a single, reproducible, executable description of "what runs
where." NixOS modules + a flake give us that: `nix run` / `nixos-rebuild`-able environments with
pinned inputs and config-as-code.

## Scope (full build)

A `deploy/` flake exposing NixOS modules per service:
- **`localnet`** — the multi-sync dev network. Parity-first: wrap/drive the splice compose, then
  migrate to native services. Reproduces what `scripts/localnet-up.sh` does today (health-wait +
  discovery).
- **`dedicated-sync-operator`** — the operator node (participant + sequencer + mediator) for the
  dedicated synchronizer, base-rate=0, running the reconcile trigger (work-plan E3/E4). This is
  net-new and needed for the E0-4 end-to-end demo anyway.
- **`sv` / `validator`** (later) — for full-stack test deployments.

Each module: pinned images/DARs, config as Nix (not YAML templating), secrets via agenix/sops,
health checks, and a `nix flake check` that builds them.

## Design sketch

- `deploy/flake.nix` → `nixosConfigurations.<host>` + `packages.<system>.<service>` + `apps`.
- Inputs pinned: nixpkgs, the `splice` submodule (its DAR/image tags), Canton image digests.
- Reuse the discovered wiring (`.localnet/discovered.env`) as module inputs.

## Migration path

1. Wrap the existing compose LocalNet in a Nix app (parity first).
2. Add the operator-node module (new; required for the register→buy→grant e2e).
3. Port SV/validator; retire compose where the Nix module reaches parity.

## Open questions

- Native NixOS services vs Nix-driven compose vs Helm parity for LocalNet.
- Secrets tooling (agenix vs sops-nix).
- How much of Splice's own Helm we replace vs consume.
