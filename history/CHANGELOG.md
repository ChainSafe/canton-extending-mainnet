# Changelog

Notable structural + coordination changes to the Extending Mainnet control center.
(Product code changes live in the splice fork's git history.)

## 2026-07

- Made the `ChainSafe/splice` fork the `splice/` **submodule** (single working tree, full history,
  branch `daml-poc-buy-traffic`); the LocalNet harness now points at it. Retired the standalone
  `~/Dev/splice` clone.
- Turned this repo into a **control center**: added `AGENTS.md`, `docs/architecture.md`,
  `history/`, `tools/` (RFC-002), `deploy/` (RFC-001), `telemetry/` (RFC-003).
- Merged the archived `ChainSafe/canton-cip-docs` into `docs/cip/` (history preserved via subtree).
- Pushed this repo to a new **private** `ChainSafe/canton-extending-mainnet`.
- Split issue tracking: code in `ChainSafe/splice` (epics E0–E10); tooling/analysis here (T0/T1).
- Built + verified the multi-sync LocalNet harness (`scripts/`).
- Drafted (unverified) the Daml PoC in the fork: governance registration + CC-funded buy.
