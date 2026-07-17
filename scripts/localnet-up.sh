#!/usr/bin/env bash
# Bring up a clean LocalNet (stock Splice images) with the multi-sync dedicated synchronizer,
# wait until healthy, discover the synchronizer ids + DSO party, and print a wiring banner.
# Idempotent / re-runnable.
#
# Usage:  scripts/localnet-up.sh
# Env:    SPLICE_DIR   path to the Splice tree      (default: /Users/s3b/Dev/splice)
#         IMAGE_TAG    Splice image tag             (default: 0.6.13; use 0.6.11 if 0.6.13 unpublished)
#         IMAGE_REPO   image registry prefix        (Phase 2: set "" for a local splice-app image)
#         PARTY_HINT   local party hint             (default: cs-localnet-1)
set -euo pipefail
# shellcheck source=scripts/localnet-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/localnet-common.sh"

require docker; require curl; require python3
[ -d "$LOCALNET_DIR" ] || die "LocalNet compose dir not found: $LOCALNET_DIR (set SPLICE_DIR)"

# 1. pre-flight: LocalNet hardcodes container names 'canton'/'postgres'; refuse to clash with another project.
for name in canton postgres; do
  proj="$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$name" 2>/dev/null || true)"
  if [ -n "$proj" ] && [ "$proj" != "localnet" ]; then
    die "A container named '$name' from compose project '$proj' clashes with LocalNet. Remove it first."
  fi
done

info "Starting LocalNet (IMAGE_TAG=$IMAGE_TAG; profiles: sv app-provider app-user multi-sync)"
localnet_compose "${PROFILES[@]}" up -d

# 2. wait for canton + splice to become healthy (~7.5 min budget)
info "Waiting for canton + splice health..."
for i in $(seq 1 90); do
  ch="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' canton 2>/dev/null || echo starting)"
  sh="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' splice 2>/dev/null || echo starting)"
  [ "$ch" = healthy ] && [ "$sh" = healthy ] && break
  sleep 5
  [ "$i" = 90 ] && die "canton/splice not healthy in time (canton=$ch splice=$sh). See 'docker logs canton|splice'."
done
info "canton + splice healthy."

# 3. wait for the multi-sync bootstrap (second synchronizer 'app-synchronizer') to complete
info "Waiting for multi-sync bootstrap (app-synchronizer)..."
for i in $(seq 1 60); do
  st="$(docker inspect -f '{{.State.Status}}' multi-sync-startup 2>/dev/null || echo missing)"
  ec="$(docker inspect -f '{{.State.ExitCode}}' multi-sync-startup 2>/dev/null || echo -1)"
  [ "$st" = exited ] && [ "$ec" = 0 ] && break
  if [ "$st" = exited ] && [ "$ec" != 0 ]; then
    die "multi-sync-startup failed (exit $ec); see 'docker logs multi-sync-startup'."
  fi
  sleep 5
  [ "$i" = 60 ] && die "multi-sync bootstrap did not complete in time (status=$st)."
done
info "multi-sync ready."

# 4. discover synchronizer ids + DSO party, persist to .localnet/discovered.env
mkdir -p "$STATE_DIR"
info "Discovering synchronizer ids + DSO party..."
TOKEN="$(mint_token "$LEDGER_USER")"
RESP="$(curl -fsS "http://localhost:${APP_PROVIDER_JSON}/v2/state/connected-synchronizers" \
  -H "Authorization: Bearer $TOKEN")" || die "connected-synchronizers query failed on :$APP_PROVIDER_JSON"

python3 -c '
import sys, json
resp = json.loads(sys.argv[1])
lst = resp.get("connectedSynchronizers") or resp.get("connected_synchronizers") or []
def norm(e): return {"id": e.get("synchronizerId") or e.get("synchronizer_id"),
                     "alias": (e.get("synchronizerAlias") or e.get("synchronizer_alias") or "")}
es = [n for n in (norm(e) for e in lst) if n["id"]]
g = next((e for e in es if "global" in e["alias"].lower()), es[0] if es else None)
d = next((e for e in es if e is not g and any(k in e["alias"].lower() for k in ("app","extra","dedicated"))),
         next((e for e in es if e is not g), None))
ns = g["id"].split("::")[1] if g and "::" in g["id"] else ""
print("GLOBAL_SYNC_ID=" + (g["id"] if g else ""))
print("DEDICATED_SYNC_ID=" + (d["id"] if d else ""))
print("DSO_PARTY=" + ("DSO::" + ns if ns else ""))
print("# aliases: " + " ; ".join(e["alias"] + "=" + e["id"] for e in es))
' "$RESP" > "$DISCOVERED_ENV"

echo "--- $DISCOVERED_ENV ---"; cat "$DISCOVERED_ENV"

# 5. banner
cat <<EOF

>> LocalNet is up. Wiring:
   SV UI            http://localhost:4000
   App-provider UI  http://localhost:3000   (wallet user: $WALLET_USER)
   App-user UI      http://localhost:2000
   JSON Ledger API  app-provider http://localhost:${APP_PROVIDER_JSON}/v2   app-user http://localhost:${APP_USER_JSON}/v2
   Validator admin  app-provider http://localhost:${APP_PROVIDER_VALIDATOR}/api/validator
   Discovered ids   $DISCOVERED_ENV
   Auth (unsafe)    HS256 secret='$AUTH_SECRET' aud='$AUTH_AUDIENCE' users: $LEDGER_USER, $WALLET_USER

Next:  scripts/localnet-e2e.sh    Tear down:  scripts/localnet-down.sh [--wipe]
EOF
