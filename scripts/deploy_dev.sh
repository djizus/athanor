#!/usr/bin/env bash
# Bootstrap the Athanor:Ascend dev environment on a running Katana.
#
# Flow:
#   1. sozo build
#   2. Declare + deploy mock_lords (no constructor args)
#   3. Rewrite dojo_dev.toml init_call_args so actions::dojo_init receives the
#      deployed mock_lords address in its third slot
#   4. sozo migrate
#   5. Extract world/actions/mock_lords addresses and write them to
#      client/.env.local so the TypeScript client picks them up
#
# Prerequisites:
#   - katana --dev running on 5050 (seed 0)
#   - sozo, starkli, jq installed
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROFILE="dev"
RPC_URL="${RPC_URL:-http://localhost:5050}"
# Katana dev seed=0 default account #0
ACCT="${ACCT:-0x127fd5f1fe78a71f8bcd1fec63e3fe2f0486b6ecd5c86a0466c3a21fa5cfcec}"
PK="${PK:-0xc5b2fcab997346f3ea1c00b002ecf6f382c5f9c9659a3894eb783c5320f912}"

MANIFEST="$ROOT/manifest_${PROFILE}.json"
DOJO_TOML="$ROOT/dojo_${PROFILE}.toml"
SIERRA="$ROOT/target/${PROFILE}/athanor_mock_lords.contract_class.json"
CASM="$ROOT/target/${PROFILE}/athanor_mock_lords.compiled_contract_class.json"
CLIENT_ENV="$ROOT/client/.env.local"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*" >&2; }

command -v sozo    >/dev/null || { err "sozo not found"; exit 1; }
command -v starkli >/dev/null || { err "starkli not found"; exit 1; }
command -v jq      >/dev/null || { err "jq not found"; exit 1; }

info "Building contracts..."
sozo --profile "$PROFILE" build 2>&1 | tail -5
[ -f "$SIERRA" ] || { err "Missing $SIERRA"; exit 1; }
[ -f "$CASM" ]   || { err "Missing $CASM — ensure casm=true in Scarb.toml"; exit 1; }

# starkli needs an encrypted keystore, or STARKNET_PRIVATE_KEY env var.
export STARKNET_RPC="$RPC_URL"
export STARKNET_PRIVATE_KEY="$PK"
export STARKNET_ACCOUNT="$ACCT"

# --- Declare mock_lords (idempotent — returns already-declared hash) ---
info "Declaring mock_lords..."
DECLARE_OUT=$(starkli declare "$SIERRA" --compiler-version 2.12.0 --watch 2>&1 || true)
LORDS_CLASS=$(echo "$DECLARE_OUT" | grep -oE '0x[0-9a-fA-F]{40,}' | head -1 || true)
if [ -z "$LORDS_CLASS" ]; then
    # Already declared: starkli sometimes prints the hash without "Class hash:"
    LORDS_CLASS=$(echo "$DECLARE_OUT" | tail -5 | grep -oE '0x[0-9a-fA-F]+' | head -1 || true)
fi
[ -n "$LORDS_CLASS" ] || { err "Could not extract class hash. Output:\n$DECLARE_OUT"; exit 1; }
info "mock_lords class: $LORDS_CLASS"

# --- Deploy mock_lords (no ctor args) ---
info "Deploying mock_lords..."
DEPLOY_OUT=$(starkli deploy "$LORDS_CLASS" --salt 0x1 --watch 2>&1 || true)
LORDS_ADDR=$(echo "$DEPLOY_OUT" | grep -oE '0x[0-9a-fA-F]{40,}' | tail -1 || true)
[ -n "$LORDS_ADDR" ] || { err "Could not extract deployed address. Output:\n$DEPLOY_OUT"; exit 1; }
info "mock_lords:     $LORDS_ADDR"

# --- Rewrite dojo_dev.toml init_call_args ---
info "Writing mock_lords address into $DOJO_TOML..."
python3 - "$DOJO_TOML" "$LORDS_ADDR" <<'PY'
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
addr = sys.argv[2]
src = path.read_text()
marker = '"athanor_0_1-actions" = '
idx = src.index(marker)
end = src.index("\n", idx)
new_line = f'{marker}["0x0", "0x0", "{addr}"]'
path.write_text(src[:idx] + new_line + src[end:])
PY

# --- Migrate Dojo world ---
info "Migrating Dojo..."
sozo --profile "$PROFILE" migrate 2>&1 | tail -5

# --- Extract addresses for client ---
[ -f "$MANIFEST" ] || { err "Manifest missing at $MANIFEST"; exit 1; }
WORLD_ADDRESS=$(jq -r '.world.address // empty' "$MANIFEST")
ACTIONS_ADDRESS=$(jq -r '.contracts[] | select(.tag == "athanor_0_1-actions") | .address // empty' "$MANIFEST")

[ -n "$WORLD_ADDRESS" ]   || { err "Could not extract world_address"; exit 1; }
[ -n "$ACTIONS_ADDRESS" ] || { err "Could not extract actions_address"; exit 1; }

# --- Write client/.env.local ---
info "Writing $CLIENT_ENV..."
mkdir -p "$(dirname "$CLIENT_ENV")"
cat > "$CLIENT_ENV" <<EOF
VITE_RPC_URL=$RPC_URL
VITE_WORLD_ADDRESS=$WORLD_ADDRESS
VITE_ACTIONS_ADDRESS=$ACTIONS_ADDRESS
VITE_LORDS_ADDRESS=$LORDS_ADDR
VITE_BURNER_FUNDING_ACCOUNT=$ACCT
VITE_BURNER_FUNDING_KEY=$PK
EOF

echo
info "Dev bootstrap done."
echo "  World:    $WORLD_ADDRESS"
echo "  Actions:  $ACTIONS_ADDRESS"
echo "  mLORDS:   $LORDS_ADDR"
echo "  RPC:      $RPC_URL"
echo
echo "Next: cd client && pnpm dev"
