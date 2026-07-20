# RFC-001: Deployment model

**Status:** Revised 2026-07-20. **The NixOS proposal is superseded/rejected** (see below); this
RFC now describes the DRY/KISS model. Skeleton lives in `deploy/`.

## Decision

Do **not** introduce NixOS. ChainSafe runs no NixOS fleet today, so Nix modules would be net-new
tooling that re-describes deployments Digital Asset already ships and maintains. Instead:

**Consume what Splice ships; add only a thin ChainSafe overlay, in Splice's own idiom.**

## Why the NixOS draft was rejected

The original RFC proposed a `deploy/` flake with NixOS modules per service (`localnet`, `sv`,
`validator`, `dedicated-sync-operator`). Splice's real deployment story is **docker-compose**
(LocalNet) plus **Helm charts** (clusters). A Nix layer over those:
- re-describes DA-owned compose/Helm, creating a parallel definition that drifts on every image or
  chart bump (violates the two-repo split: consume Splice, don't reimplement);
- adds a new toolchain with no existing ops fleet to justify it (violates KISS);
- its first step was explicitly "wrap/drive the splice compose" — a translation layer with no new
  capability.

## The model

| Layer | Splice ships | ChainSafe action |
|---|---|---|
| **LocalNet / dev** | docker-compose (`splice/cluster/compose/localnet`) | Keep the `scripts/localnet-*.sh` harness over it. Already done — nothing to build. |
| **SV / validator (clusters)** | Helm charts (`splice/cluster/helm`) | Consume as-is + a `values.chainsafe.yaml` overlay. Only when we run full stacks. |
| **dedicated-sync-operator** (net-new) | nothing upstream | The one artifact we own. Compose service for LocalNet; Helm chart (reusing Splice's participant/sequencer/mediator building blocks + a values file) for real deployment. |

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
  sealed-secrets / external-secrets). Not a now-problem. (The rejected draft proposed agenix/sops.)
- **How much of Splice's Helm we override vs consume** — decide per-values-file as needs surface.
