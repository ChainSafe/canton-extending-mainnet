#!/usr/bin/env bash
# Phase-1 end-to-end smoke check for the dedicated-synchronizer LocalNet.
# Self-skips (exit 0) when the stack is down, so it is safe to wire into CI later.
# When up: asserts BOTH synchronizers are connected (global + app-synchronizer) and a CC tap works.
#
# The real register -> buy -> grant -> drawdown flow (work-plan E0-4) is Phase 2 and needs the
# custom splice-app image carrying the PoC DARs - see the TODO block at the end.
set -euo pipefail
# shellcheck source=scripts/localnet-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/localnet-common.sh"

require curl; require python3

# self-skip if the ledger is not reachable
if ! curl -fsS "http://localhost:${APP_PROVIDER_JSON}/v2/version" >/dev/null 2>&1; then
  echo "SKIP: LocalNet ledger not reachable on :$APP_PROVIDER_JSON (run scripts/localnet-up.sh first)."
  exit 0
fi
info "Ledger reachable on :$APP_PROVIDER_JSON."

# 1. both synchronizers connected (global + dedicated app-synchronizer)
TOKEN="$(mint_token "$LEDGER_USER")"
RESP="$(curl -fsS "http://localhost:${APP_PROVIDER_JSON}/v2/state/connected-synchronizers" \
  -H "Authorization: Bearer $TOKEN")"
COUNT="$(python3 -c 'import sys,json; r=json.loads(sys.argv[1]); print(len(r.get("connectedSynchronizers") or r.get("connected_synchronizers") or []))' "$RESP")"
info "Connected synchronizers: $COUNT"
[ "$COUNT" -ge 2 ] || die "expected >=2 synchronizers (global + app-synchronizer); got $COUNT. Did multi-sync come up?"

# 2. CC tap on the app-provider wallet
WTOKEN="$(mint_token "$WALLET_USER")"
info "Tapping 100 CC to '$WALLET_USER' wallet..."
curl -fsS -X POST "http://localhost:${APP_PROVIDER_VALIDATOR}/api/validator/v0/wallet/tap" \
  -H "Authorization: Bearer $WTOKEN" -H 'content-type: application/json' \
  -d '{"amount":"100.0"}' >/dev/null || die "wallet tap failed on :$APP_PROVIDER_VALIDATOR"

info "PASS: both synchronizers connected and a CC tap succeeded."

cat <<'EOF'

TODO (Phase 2 - requires the custom splice-app image with the PoC DARs):
  1. Set the dedicated sequencer base rate = 0 (work-plan E4-1).
  2. Register the dedicated sync via the SRARC_RegisterSynchronizer governance vote -> RegisteredSynchronizer.
  3. Exercise AmuletRules_BuyDedicatedSyncTraffic with explicit disclosure of RegisteredSynchronizer
     -> assert CC burned (splitAndBurn) and a DedicatedSyncTraffic created with the operator as observer.
  4. Manually call SetTrafficPurchased on the app-sequencer; submit a tx on the dedicated sync; observe drawdown.
EOF
