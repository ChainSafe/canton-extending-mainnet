# deploy/ — deployment overlays

Deployment for the initiative is **DRY/KISS: consume what Splice ships; add only a thin ChainSafe
overlay, in Splice's own idiom.** No NixOS. See **`../history/rfcs/RFC-001-nixos-deployment.md`**
(the NixOS proposal was rejected; the RFC now records the model below).

- **LocalNet / dev** — docker-compose from the `splice/` submodule, driven by `../scripts/localnet-*.sh`.
  Already working; nothing lives here for it.
- **SV / validator (clusters)** — Splice Helm charts (`splice/cluster/helm`) consumed as-is, plus a
  ChainSafe `values` overlay. Only when we run full stacks.
- **dedicated-sync-operator** — the one net-new artifact we own. A compose overlay for LocalNet, a
  Helm chart (reusing Splice's participant/sequencer/mediator building blocks) for real deployment.
  Tracks work-plan **E3-3**.

This directory holds those overlays as they get built. It is empty until the operator-node work
(E3) starts.
