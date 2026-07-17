#!/usr/bin/env bash
# Shared config + helpers for the LocalNet harness.
# Sourced by localnet-up.sh / localnet-down.sh / localnet-e2e.sh. Do not run directly.
#
# Adapted from the clean pattern in ChainSafe/canton-x402-facilitator, but driving OUR Splice
# tree's compose with the multi-sync (dedicated app-synchronizer) profile added.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- config (all overridable via env) ---
# Splice tree carrying the 0.6.13 compose + the PoC branches.
SPLICE_DIR="${SPLICE_DIR:-/Users/s3b/Dev/splice}"
LOCALNET_DIR="${LOCALNET_DIR:-$SPLICE_DIR/cluster/compose/localnet}"

# Phase 1: stock published images. Phase 2 overrides IMAGE_TAG (and sets IMAGE_REPO="") to point
# at a locally-built splice-app image carrying the PoC DARs.
IMAGE_TAG="${IMAGE_TAG:-0.6.13}"
PARTY_HINT="${PARTY_HINT:-cs-localnet-1}"

# LocalNet unsafe dev auth (HS256). Matches env/*-auth-on.env in the compose dir.
AUTH_SECRET="${AUTH_SECRET:-unsafe}"
AUTH_AUDIENCE="${AUTH_AUDIENCE:-https://canton.network.global}"
LEDGER_USER="${LEDGER_USER:-ledger-api-user}"
WALLET_USER="${WALLET_USER:-app-provider}"

# Host ports = role-prefix + suffix (see env/common.env): app-provider=3, app-user=2, sv=4.
APP_PROVIDER_JSON="${APP_PROVIDER_JSON:-3975}"        # JSON Ledger API v2 (suffix 975)
APP_PROVIDER_VALIDATOR="${APP_PROVIDER_VALIDATOR:-3903}" # validator admin API (suffix 903)
APP_USER_JSON="${APP_USER_JSON:-2975}"

STATE_DIR="$PROJECT_DIR/.localnet"
DISCOVERED_ENV="$STATE_DIR/discovered.env"

# Profiles: the 3 standard roles + the dedicated synchronizer.
PROFILES=(--profile sv --profile app-provider --profile app-user --profile multi-sync)

export LOCALNET_DIR IMAGE_TAG PARTY_HINT
[ -n "${IMAGE_REPO:-}" ] && export IMAGE_REPO

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo ">> $*"; }
require() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found on PATH"; }

# docker compose wrapper matching build-tools/splice-localnet-compose.sh (absolute paths + env files).
localnet_compose() {
  docker compose \
    --env-file "$LOCALNET_DIR/compose.env" \
    --env-file "$LOCALNET_DIR/env/common.env" \
    -f "$LOCALNET_DIR/compose.yaml" \
    -f "$LOCALNET_DIR/resource-constraints.yaml" \
    "$@"
}

# mint_token <subject> -> unsafe HS256 JWT for the LocalNet ledger/validator APIs.
# Uses python3 (always present on macOS) so the scripts do not depend on an nvm-loaded node.
mint_token() {
  python3 - "$1" "$AUTH_AUDIENCE" "$AUTH_SECRET" <<'PY'
import sys, json, hmac, hashlib, base64
sub, aud, secret = sys.argv[1], sys.argv[2], sys.argv[3]
def b64(b): return base64.urlsafe_b64encode(b).rstrip(b"=")
data = b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode()) + b"." + \
       b64(json.dumps({"sub": sub, "aud": aud, "exp": 9999999999}).encode())
sig = b64(hmac.new(secret.encode(), data, hashlib.sha256).digest())
sys.stdout.write((data + b"." + sig).decode())
PY
}
