#!/usr/bin/env bash
# navigator.sh - quick orientation for agents/humans: repo map + submodule + LocalNet status.
# Seed for RFC-002 (agent-navigation APIs). Read-only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== canton-extending-mainnet control center =="
echo
echo "-- repo map --"
for d in AGENTS.md docs history scripts tools deploy telemetry sync-pricing splice; do
  if [ -e "$ROOT/$d" ]; then
    note=""; [ "$d" = splice ] && note="(submodule: the code)"
    printf "  %-14s %s\n" "$d" "$note"
  fi
done
echo
echo "-- sibling projects --"
echo "  see AGENTS.md (sibling-project table)"
echo
echo "-- splice submodule --"
git -C "$ROOT" submodule status splice 2>/dev/null | sed 's/^/  /' \
  || echo "  not initialized: git submodule update --init splice"
echo
echo "-- LocalNet --"
if command -v docker >/dev/null 2>&1 && \
   [ -n "$(docker ps -q --filter 'label=com.docker.compose.project=localnet' 2>/dev/null)" ]; then
  n="$(docker ps -q --filter 'label=com.docker.compose.project=localnet' | wc -l | tr -d ' ')"
  echo "  running ($n containers). smoke test: scripts/localnet-e2e.sh"
else
  echo "  down. bring up: scripts/localnet-up.sh"
fi
