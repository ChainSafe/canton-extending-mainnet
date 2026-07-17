# RFC-003: Centralized analytics, logging & telemetry

**Status:** Draft. Skeleton: `telemetry/`.

## Motivation

"Works uniformly for all projects." Today each sibling logs/metrics differently (or not at all).
A uniform observability layer lets us compare runs, debug across repos, and feed agentic loops with
real signal.

## Scope (full build)

- **Schema / conventions** — an OpenTelemetry-based spec: trace/span naming, resource attributes
  (repo, service, env, commit), log structure, metric names. One versioned doc here.
- **Collector** — an OTel collector config (exporters, sampling), deployable via `deploy/` (RFC-001).
- **Per-project wiring** — a small SDK/snippet each sibling adds to emit to the collector; opt-in.
- **Dashboards** — starter Grafana/Prometheus (or vendor) definitions, checked in.

## Design sketch

- `telemetry/spec.md` (schema), `telemetry/collector/` (OTel config), `telemetry/dashboards/`.
- Deployed as a NixOS module (RFC-001). Agent runs (LocalNet e2e, agentic loops) emit traces so
  experiments in `history/experiments/` have hard data.

## Open questions

- Backend (self-hosted Grafana/Tempo/Loki vs a SaaS).
- Data retention + privacy for internal telemetry.
- Overlap with existing ChainSafe observability (check `canton-chainsafe-platform`).
