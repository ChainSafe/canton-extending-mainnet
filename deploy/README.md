# deploy/ — NixOS deployment (skeleton)

Executable deployment descriptions for the initiative (LocalNet, the dedicated-sync operator node,
later SV/validator). Skeleton only — the full-build plan is
**`../history/rfcs/RFC-001-nixos-deployment.md`**.

Today LocalNet is driven by `../scripts/localnet-*.sh` (docker compose over the `splice/`
submodule). RFC-001 migrates that to Nix so the deployment is a single executable spec that can't
drift from reality.
