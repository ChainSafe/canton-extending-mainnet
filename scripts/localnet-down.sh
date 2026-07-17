#!/usr/bin/env bash
# Tear down LocalNet.
# Usage:  scripts/localnet-down.sh           # stop + remove containers, KEEP volumes (ids persist)
#         scripts/localnet-down.sh --wipe     # also delete volumes + discovered.env (fresh ledger next up)
set -euo pipefail
# shellcheck source=scripts/localnet-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/localnet-common.sh"

require docker
WIPE=""
[ "${1:-}" = "--wipe" ] && WIPE="-v"

if [ -d "$LOCALNET_DIR" ]; then
  info "Stopping LocalNet${WIPE:+ (wiping volumes)}..."
  localnet_compose "${PROFILES[@]}" down $WIPE || true
else
  # fallback: the compose dir moved/missing -> remove by compose project label
  info "Compose dir missing; removing containers by project label 'localnet'..."
  docker ps -aq --filter 'label=com.docker.compose.project=localnet' | xargs -r docker rm -f || true
  if [ -n "$WIPE" ]; then
    docker volume ls -q --filter 'label=com.docker.compose.project=localnet' | xargs -r docker volume rm || true
  fi
fi

if [ -n "$WIPE" ]; then
  rm -f "$DISCOVERED_ENV"
  info "Wiped. Next 'up' mints fresh synchronizer ids + DSO party."
else
  info "Stopped. Volumes kept (ledger state + ids persist). Use --wipe for a clean slate."
fi
