#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Deploy Athanor:Ascend contracts to Slot.
#
# Flow:
#   1. sozo build -P slot
#   2. sozo declare + deploy mock_lords on Slot (uses dojo_slot.toml creds)
#   3. Write mock_lords address into dojo_slot.toml init_call_args
#   4. sozo migrate -P slot
#   5. Extract world + actions + mock_lords addresses
#   6. Update torii_slot.toml world_address + client/.env.slot
#
# Prerequisites:
#   - sozo, jq installed
#   - dojo_slot.toml has valid account_address + private_key (either literals
#     or resolved via `slot deployments accounts` fallback below).
#   - Slot instance running: `slot d create $SLOT_NAME katana --config ./katana_slot.toml`
#     (default SLOT_NAME is "zathanor-slot"; override with the env var.)
#
# Usage:
#   ./scripts/deploy_slot.sh
#   SLOT_NAME=my-slot ./scripts/deploy_slot.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE="slot"
SLOT_NAME="${SLOT_NAME:-zathanor-slot}"
NAMESPACE="athanor_0_1"
CONTRACT_TAG="${NAMESPACE}-actions"
MANIFEST="$ROOT_DIR/manifest_${PROFILE}.json"
TORII_TOML="$ROOT_DIR/torii_${PROFILE}.toml"
DOJO_TOML="$ROOT_DIR/dojo_${PROFILE}.toml"
DOJO_DEV_TOML="$ROOT_DIR/dojo_dev.toml"
CLIENT_ENV="$ROOT_DIR/client/.env.${PROFILE}"
TARGET_DIR="$ROOT_DIR/target/${PROFILE}"
LORDS_SIERRA="$TARGET_DIR/athanor_mock_lords.contract_class.json"
RPC_URL="https://api.cartridge.gg/x/${SLOT_NAME}/katana"
TORII_URL="https://api.cartridge.gg/x/${SLOT_NAME}/torii"
TEMP_DOJO_DEV=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*" >&2; }

# --- Preflight ---
command -v sozo >/dev/null 2>&1 || { err "sozo not found"; exit 1; }
command -v jq   >/dev/null 2>&1 || { err "jq not found"; exit 1; }
command -v curl >/dev/null 2>&1 || { err "curl not found"; exit 1; }
[ -f "$DOJO_TOML" ] || { err "Missing $DOJO_TOML"; exit 1; }

rpc_class_hash_at() {
    local address="$1"
    curl -sS -X POST \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"starknet_getClassHashAt\",\"params\":[\"latest\",\"${address}\"]}" \
        "$RPC_URL"
}

assert_contract_exists() {
    local label="$1"
    local address="$2"
    local response
    response=$(rpc_class_hash_at "$address")
    local err_code
    err_code=$(printf "%s" "$response" | jq -r '.error.code // empty' 2>/dev/null || true)
    if [ -n "$err_code" ]; then
        err "$label address is not deployed on Slot: $address"
        printf "%s\n" "$response"
        exit 1
    fi
}

ensure_dojo_profile_compat() {
    # sozo 1.8.x still tries to read dojo_dev.toml in some profile-driven flows
    # even when -P slot is passed. Keep the repo clean by generating a temporary
    # compatibility copy during the deploy and deleting it on exit.
    if [ ! -f "$DOJO_DEV_TOML" ]; then
        cp "$DOJO_TOML" "$DOJO_DEV_TOML"
        TEMP_DOJO_DEV=1
    fi
}

cleanup() {
    if [ "$TEMP_DOJO_DEV" = "1" ]; then
        rm -f "$DOJO_DEV_TOML"
    fi
}

trap cleanup EXIT

# --- Resolve account ---
ACCOUNT_ADDRESS=$(grep '^account_address' "$DOJO_TOML" | head -1 | sed 's/.*= *"\(.*\)"/\1/' || true)
PRIVATE_KEY=$(grep '^private_key' "$DOJO_TOML" | head -1 | sed 's/.*= *"\(.*\)"/\1/' || true)

if [ -z "$ACCOUNT_ADDRESS" ] || [ "$ACCOUNT_ADDRESS" = "0x0" ] || [ -z "$PRIVATE_KEY" ] || [ "$PRIVATE_KEY" = "0x0" ]; then
    warn "No account in $DOJO_TOML — trying slot CLI..."
    command -v slot >/dev/null 2>&1 || { err "slot CLI not found and no account configured"; exit 1; }

    ACCOUNTS_JSON=$(slot deployments accounts "$SLOT_NAME" katana 2>&1 || true)
    ACCOUNT_ADDRESS=$(printf "%s" "$ACCOUNTS_JSON" | jq -r '
        if type=="array" and length>0 then .[0].address // ""
        elif type=="object" and has("address") then .address // ""
        else "" end' 2>/dev/null || true)
    PRIVATE_KEY=$(printf "%s" "$ACCOUNTS_JSON" | jq -r '
        if type=="array" and length>0 then (.[0].privateKey // .[0].private_key // "")
        elif type=="object" then (.privateKey // .private_key // "")
        else "" end' 2>/dev/null || true)

    if [ -z "$ACCOUNT_ADDRESS" ] || [ -z "$PRIVATE_KEY" ]; then
        err "Could not resolve account. Configure dojo_slot.toml manually."
        exit 1
    fi

    sed -i "s|account_address = \".*\"|account_address = \"$ACCOUNT_ADDRESS\"|" "$DOJO_TOML"
    sed -i "s|private_key = \".*\"|private_key = \"$PRIVATE_KEY\"|" "$DOJO_TOML"
    info "Account written to $DOJO_TOML"
fi

info "Account: $ACCOUNT_ADDRESS"

ensure_dojo_profile_compat

SOZO_AUTH=(--rpc-url "$RPC_URL" --account-address "$ACCOUNT_ADDRESS" --private-key "$PRIVATE_KEY")

# --- Build ---
info "Building contracts (profile=$PROFILE)..."
cd "$ROOT_DIR"
sozo build -P "$PROFILE" 2>&1 | tail -5
[ -f "$LORDS_SIERRA" ] || { err "Missing $LORDS_SIERRA"; exit 1; }

# --- Declare mock_lords ---
info "Declaring mock_lords on Slot..."
DECLARE_OUT=$(sozo --profile "$PROFILE" declare "${SOZO_AUTH[@]}" --wait "$LORDS_SIERRA" 2>&1 || true)
LORDS_CLASS=$(echo "$DECLARE_OUT" | grep -oE '0x[0-9a-fA-F]{60,}' | tail -1 || true)
if [ -z "$LORDS_CLASS" ]; then
    err "Could not extract class hash. Output:"; echo "$DECLARE_OUT"; exit 1
fi
info "mock_lords class: $LORDS_CLASS"

# --- Deploy mock_lords (salt 0x1 for a deterministic Slot address) ---
info "Deploying mock_lords on Slot..."
DEPLOY_OUT=$(sozo --profile "$PROFILE" deploy "${SOZO_AUTH[@]}" --wait --salt 0x1 "$LORDS_CLASS" 2>&1 || true)
LORDS_ADDR=$(echo "$DEPLOY_OUT" | grep -oE 'Address[[:space:]]*:[[:space:]]*0x[0-9a-fA-F]+' | grep -oE '0x[0-9a-fA-F]+' | tail -1 || true)
if [ -z "$LORDS_ADDR" ]; then
    err "Could not extract deployed address. Output:"; echo "$DEPLOY_OUT"; exit 1
fi
info "mock_lords: $LORDS_ADDR"

# --- Rewrite dojo_slot.toml init_call_args ---
info "Writing mock_lords address into $DOJO_TOML..."
python3 - "$DOJO_TOML" "$LORDS_ADDR" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
addr = sys.argv[2]
src = path.read_text()
marker = '"athanor_0_1-actions" = '
idx = src.index(marker)
end = src.index("\n", idx)
new_line = f'{marker}["0x0", "0x0", "{addr}"]'
path.write_text(src[:idx] + new_line + src[end:])
PY

# --- Migrate ---
info "Migrating Dojo world to Slot..."
MAX_ATTEMPTS=3
MIGRATE_SUCCESS=false
for attempt in $(seq 1 $MAX_ATTEMPTS); do
    if MIGRATE_OUTPUT=$(sozo migrate -P "$PROFILE" 2>&1); then
        MIGRATE_SUCCESS=true
        break
    fi
    WAIT=$((15 * attempt))
    warn "Attempt $attempt/$MAX_ATTEMPTS failed. Retrying in ${WAIT}s..."
    sleep "$WAIT"
done

if [ "$MIGRATE_SUCCESS" != "true" ]; then
    err "Migration failed after $MAX_ATTEMPTS attempts. Last output:"
    echo "$MIGRATE_OUTPUT"
    exit 1
fi

echo "$MIGRATE_OUTPUT" | tail -3

# --- Extract addresses ---
[ -f "$MANIFEST" ] || { err "Manifest not found at $MANIFEST"; exit 1; }

WORLD_ADDRESS=$(echo "$MIGRATE_OUTPUT" | grep -oE 'world at address 0x[0-9a-fA-F]+' | grep -oE '0x[0-9a-fA-F]+' | tail -1 || true)
if [ -z "$WORLD_ADDRESS" ]; then
    WORLD_ADDRESS=$(jq -r '.world.address // empty' "$MANIFEST")
fi

# Prefer the live world registry over manifest data. The manifest can be stale
# if generated artifacts from a previous run survived in the tree.
INSPECT_JSON=$(sozo inspect --json --profile "$PROFILE" --world "$WORLD_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null || true)
ACTIONS_ADDRESS=$(printf "%s" "$INSPECT_JSON" | jq -r --arg TAG "$CONTRACT_TAG" '.contracts[]? | select(.tag == $TAG) | .address // empty' 2>/dev/null | head -1)
if [ -z "$ACTIONS_ADDRESS" ]; then
    ACTIONS_ADDRESS=$(jq -r ".contracts[] | select(.tag == \"${CONTRACT_TAG}\") | .address // empty" "$MANIFEST")
fi

[ -n "$WORLD_ADDRESS" ]   || { err "Could not extract world_address";   exit 1; }
[ -n "$ACTIONS_ADDRESS" ] || { err "Could not extract actions_address"; exit 1; }

# Manifest data can go stale if a previous migrate left generated artifacts in
# the tree. Before we write client/.env.slot or torii_slot.toml, verify the
# extracted addresses actually exist on the live Slot RPC.
assert_contract_exists "World" "$WORLD_ADDRESS"
assert_contract_exists "Actions" "$ACTIONS_ADDRESS"
assert_contract_exists "mock_lords" "$LORDS_ADDR"

info "World:   $WORLD_ADDRESS"
info "Actions: $ACTIONS_ADDRESS"

# --- Update torii_slot.toml ---
if [ -f "$TORII_TOML" ]; then
    sed -i "s|world_address = \"0x[0-9a-fA-F]*\"|world_address = \"$WORLD_ADDRESS\"|" "$TORII_TOML"
    info "$TORII_TOML updated"
fi

# --- Write client/.env.slot ---
# Mirrors the shape used by zkube-budokan so a future Controller migration
# drops in cleanly. `pnpm slot` in client/ activates this mode file.
info "Writing $CLIENT_ENV..."
mkdir -p "$(dirname "$CLIENT_ENV")"
cat > "$CLIENT_ENV" <<EOF
# Slot deployment configuration — regenerated by scripts/deploy_slot.sh.
VITE_PUBLIC_DEPLOY_TYPE=slot
VITE_PUBLIC_SLOT=$SLOT_NAME
VITE_PUBLIC_NAMESPACE=$NAMESPACE
VITE_PUBLIC_NODE_URL=$RPC_URL
VITE_PUBLIC_TORII=$TORII_URL
VITE_PUBLIC_MASTER_ADDRESS=$ACCOUNT_ADDRESS
VITE_PUBLIC_MASTER_PRIVATE_KEY=$PRIVATE_KEY

# Contract addresses
VITE_PUBLIC_WORLD_ADDRESS=$WORLD_ADDRESS
VITE_PUBLIC_ACTIONS_ADDRESS=$ACTIONS_ADDRESS
VITE_PUBLIC_LORDS_ADDRESS=$LORDS_ADDR
EOF

# --- Done ---
echo ""
info "Slot deploy complete."
echo "  World:   $WORLD_ADDRESS"
echo "  Actions: $ACTIONS_ADDRESS"
echo "  mLORDS:  $LORDS_ADDR"
echo "  RPC:     $RPC_URL"
echo "  Torii:   $TORII_URL"
echo "  Account: $ACCOUNT_ADDRESS"
echo ""
echo "Next steps:"
echo "  slot d update $SLOT_NAME torii --config ./torii_slot.toml   # if world changed"
echo "  cd client && pnpm slot                                      # HTTPS dev server"
