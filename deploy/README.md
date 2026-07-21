# deploy/ — deployment overlays

Deployment for the initiative is **DRY/KISS: consume what Splice ships (docker-compose for LocalNet,
Helm for clusters); add only a thin ChainSafe overlay, in Splice's own idiom.** See
**`../history/rfcs/RFC-001-deployment.md`** for the full model.

- **LocalNet / dev** — docker-compose from the `splice/` submodule, driven by `../scripts/localnet-*.sh`.
  Already working; nothing lives here for it.
- **SV / validator (clusters)** — Splice Helm charts (`splice/cluster/helm`) consumed as-is, plus a
  ChainSafe `values` overlay. Only when we run full stacks.
- **dedicated-sync-operator** — the one net-new artifact we own. A compose overlay for LocalNet, a
  Helm chart (reusing Splice's participant/sequencer/mediator building blocks) for real deployment.
  Tracks work-plan **E3-3**.

This directory holds those overlays as they get built. Until the operator-node work (E3) starts,
it holds only this note.
