# RFC-001: Deployment model

**Status:** Accepted 2026-07-20. Overlays land in `deploy/` as they get built.

## Decision

**Deploy with the tooling Splice already ships: docker-compose (LocalNet) and Helm charts
(clusters). Add only a thin ChainSafe overlay, in Splice's own idiom.** No bespoke deployment
framework.

> **Nix vs NixOS.** This RFC rejects **NixOS** — the OS / a `deploy/` flake as a *deployment*
> mechanism. It does **not** reject **Nix the package manager**: we keep using Nix via Splice's
> upstream dev shell to *build* the code (see `docs/development.md`), because that is the DRY/KISS
> choice — consume DA's pinned toolchain rather than reinvent it. Two different tools; only the
> deployment-OS one is out.

## The model

| Layer | Splice ships | ChainSafe action |
|---|---|---|
| **LocalNet / dev** | docker-compose (`splice/cluster/compose/localnet`) | Keep the `scripts/localnet-*.sh` harness over it. Already done — nothing to build. |
| **SV / validator (clusters)** | Helm charts (`splice/cluster/helm`) | Consume as-is + a `values.chainsafe.yaml` overlay. Only when we run full stacks. |
| **dedicated-sync-operator** (net-new) | nothing upstream | The one artifact we own. A compose service for LocalNet; a Helm chart (reusing Splice's participant/sequencer/mediator building blocks + a values file) for real deployment. |

The only genuinely new deployable is the operator node. Everything else is pointing a values/env
file at DA's charts. Nothing is described twice.

## Scope of work

1. **Operator-node compose overlay** for LocalNet — the participant + sequencer + mediator for the
   dedicated synchronizer, base-rate=0, running the reconcile trigger (work-plan E3/E4). Required
   for the E0-4 end-to-end demo regardless.
2. **Operator-node Helm chart** (later) for real deployment, plus ChainSafe values overlays for
   SV/validator when full-stack test deployments are needed. Tracks work-plan **E3-3** (which
   already assumes Helm + operator docs).

## Deferred

- **Secrets:** when the cluster path is real, use whatever the k8s side already uses (SOPS /
  sealed-secrets / external-secrets). Not a now-problem.
- **How much of Splice's Helm we override vs consume** — decide per-values-file as needs surface.

## Alternatives considered

- **NixOS modules / a `deploy/` flake** (the original draft). Rejected: ChainSafe runs no NixOS
  fleet, so it would be net-new tooling that re-describes DA-owned compose/Helm and drifts on every
  image or chart bump, violating both the two-repo split (consume Splice, don't reimplement) and
  KISS. This is unrelated to Splice's Nix *dev shell*, which is the upstream build toolchain, not a
  deployment mechanism (see `docs/development.md`).
