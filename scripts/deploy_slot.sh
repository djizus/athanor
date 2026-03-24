#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE="slot"
SLOT_NAME="athanor-djizus-slot"
NAMESPACE="athanor_v2"
CONTRACT_TAG="${NAMESPACE}-actions_v2"
MANIFEST="$ROOT_DIR/manifest_${PROFILE}.json"
DOJO_BRIDGE="$ROOT_DIR/client/scripts/autoload/dojo_bridge.gd"
DOJO_TOML="$ROOT_DIR/dojo_${PROFILE}.toml"
TORII_TOML="$ROOT_DIR/torii_${PROFILE}.toml"
RPC_URL="https://api.cartridge.gg/x/${SLOT_NAME}/katana"
TORII_URL="https://api.cartridge.gg/x/${SLOT_NAME}/torii"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*" >&2; }

command -v sozo >/dev/null 2>&1 || { err "sozo not found"; exit 1; }
command -v jq >/dev/null 2>&1   || { err "jq not found"; exit 1; }

if [ ! -f "$DOJO_TOML" ]; then
    err "Missing $DOJO_TOML"
    exit 1
fi

ACCOUNT_ADDRESS=$(grep '^account_address' "$DOJO_TOML" | head -1 | sed 's/.*= *"\(.*\)"/\1/' || true)
PRIVATE_KEY=$(grep '^private_key' "$DOJO_TOML" | head -1 | sed 's/.*= *"\(.*\)"/\1/' || true)

if [ -z "$ACCOUNT_ADDRESS" ] || [ "$ACCOUNT_ADDRESS" = "0x0" ] || [ -z "$PRIVATE_KEY" ] || [ "$PRIVATE_KEY" = "0x0" ]; then
    warn "No account in dojo_slot.toml, trying to fetch from Slot..."
    if ! command -v slot >/dev/null 2>&1; then
        err "slot CLI not found and dojo_slot.toml has no account"
        err "Install slot and run: slot deployments accounts $SLOT_NAME katana"
        exit 1
    fi

    ACCOUNTS_OUTPUT=$(slot deployments accounts "$SLOT_NAME" katana 2>&1 || true)
    ACCOUNT_ADDRESS=$(printf "%s" "$ACCOUNTS_OUTPUT" | jq -r '
        if type=="array" and length>0 then .[0].address // ""
        elif type=="object" and has("accounts") and (.accounts | type)=="array" and (.accounts | length)>0 then .accounts[0].address // ""
        elif type=="object" then .address // ""
        else "" end' 2>/dev/null || true)
    PRIVATE_KEY=$(printf "%s" "$ACCOUNTS_OUTPUT" | jq -r '
        if type=="array" and length>0 then (.[0].privateKey // .[0].private_key // .[0].secretKey // "")
        elif type=="object" and has("accounts") and (.accounts | type)=="array" and (.accounts | length)>0 then (.accounts[0].privateKey // .accounts[0].private_key // .accounts[0].secretKey // "")
        elif type=="object" then .privateKey // .private_key // .secretKey // ""
        else "" end' 2>/dev/null || true)
    if [ -z "$ACCOUNT_ADDRESS" ] || [ "$ACCOUNT_ADDRESS" = "null" ]; then
        ACCOUNT_ADDRESS=$(printf "%s" "$ACCOUNTS_OUTPUT" | grep -Ei 'address' | grep -Eo '0x[0-9a-fA-F]+' | head -1 || true)
    fi
    if [ -z "$PRIVATE_KEY" ] || [ "$PRIVATE_KEY" = "null" ]; then
        PRIVATE_KEY=$(printf "%s" "$ACCOUNTS_OUTPUT" | grep -Ei 'private|secret' | grep -Eo '0x[0-9a-fA-F]+' | head -1 || true)
    fi

    if [ -z "$ACCOUNT_ADDRESS" ] || [ -z "$PRIVATE_KEY" ]; then
        err "Could not fetch account from Slot output"
        echo "$ACCOUNTS_OUTPUT"
        exit 1
    fi

    sed -i "s|account_address = \".*\"|account_address = \"$ACCOUNT_ADDRESS\"|" "$DOJO_TOML"
    sed -i "s|private_key = \".*\"|private_key = \"$PRIVATE_KEY\"|" "$DOJO_TOML"
fi

info "Using account: $ACCOUNT_ADDRESS"

info "Building contracts (profile: $PROFILE)..."
cd "$ROOT_DIR"
sozo build -P "$PROFILE" 2>&1

info "Migrating contracts to Slot RPC..."
MAX_ATTEMPTS=6
for attempt in $(seq 1 $MAX_ATTEMPTS); do
    MIGRATE_OUTPUT=$(sozo migrate -P "$PROFILE" 2>&1) && break
    WAIT=$((30 + 30 * attempt))
    warn "Migration attempt $attempt/$MAX_ATTEMPTS failed. Retrying in ${WAIT}s..."
    echo "$MIGRATE_OUTPUT"
    sleep "$WAIT"
done
echo "$MIGRATE_OUTPUT" | tail -5

if [ ! -f "$MANIFEST" ]; then
    err "Manifest not found at $MANIFEST"
    exit 1
fi

WORLD_ADDRESS=$(jq -r '.world.address // empty' "$MANIFEST")
ACTIONS_ADDRESS=$(jq -r ".contracts[] | select(.tag == \"${CONTRACT_TAG}\") | .address // empty" "$MANIFEST")

if [ -z "$WORLD_ADDRESS" ]; then
    err "Could not extract world_address from manifest"
    exit 1
fi
if [ -z "$ACTIONS_ADDRESS" ]; then
    warn "Could not extract actions_address (tag: ${CONTRACT_TAG}) — trying fallback"
    ACTIONS_ADDRESS=$(jq -r '.contracts[-1].address // empty' "$MANIFEST")
fi

info "world_address:   $WORLD_ADDRESS"
info "actions_address: $ACTIONS_ADDRESS"

if [ -f "$TORII_TOML" ]; then
    info "Updating torii_slot.toml..."
    sed -i "s|world_address = \"0x[0-9a-fA-F]*\"|world_address = \"$WORLD_ADDRESS\"|" "$TORII_TOML"
fi

if [ -f "$DOJO_BRIDGE" ]; then
    info "Updating dojo_bridge.gd with deployed addresses and Slot URLs..."
    sed -i "s|@export var world_address := \"0x[0-9a-fA-F]*\"|@export var world_address := \"$WORLD_ADDRESS\"|" "$DOJO_BRIDGE"
    sed -i "s|@export var actions_address := \"0x[0-9a-fA-F]*\"|@export var actions_address := \"$ACTIONS_ADDRESS\"|" "$DOJO_BRIDGE"
    sed -i "s|@export var torii_url := \"[^\"]*\"|@export var torii_url := \"$TORII_URL\"|" "$DOJO_BRIDGE"
    sed -i "s|@export var rpc_url := \"[^\"]*\"|@export var rpc_url := \"$RPC_URL\"|" "$DOJO_BRIDGE"
    info "dojo_bridge.gd updated for Slot."
fi

info "Done."
echo ""
echo "  World:   $WORLD_ADDRESS"
echo "  Actions: $ACTIONS_ADDRESS"
echo "  RPC:     $RPC_URL"
echo "  Torii:   $TORII_URL"
echo "  Account: $ACCOUNT_ADDRESS"
echo ""
echo "Slot deployments (if not already created):"
echo "  slot d create $SLOT_NAME katana --config ./katana_slot.toml"
echo "  slot d create $SLOT_NAME torii --config ./torii_slot.toml"
echo ""
echo "Launch:"
echo "  cd client && godot"
