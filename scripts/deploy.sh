#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Deploy Athanor contracts to Slot
#
# Builds, migrates, extracts addresses, and updates client + torii config.
#
# Prerequisites:
#   - sozo, jq installed
#   - dojo_slot.toml configured with account credentials
#   - Slot Katana running: slot d create athanor-djizus-slot katana --config ./katana_slot.toml
#
# Usage:
#   ./scripts/deploy.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE="slot"
SLOT_NAME="athanor-djizus-slot"
NAMESPACE="athanor_0_1"
CONTRACT_TAG="${NAMESPACE}-actions"
MANIFEST="$ROOT_DIR/manifest_${PROFILE}.json"
MAIN_MENU="$ROOT_DIR/client/scripts/main_menu.gd"
TORII_TOML="$ROOT_DIR/torii_${PROFILE}.toml"
DOJO_TOML="$ROOT_DIR/dojo_${PROFILE}.toml"
RPC_URL="https://api.cartridge.gg/x/${SLOT_NAME}/katana"
TORII_URL="https://api.cartridge.gg/x/${SLOT_NAME}/torii"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*" >&2; }

# --- Preflight ---
command -v sozo >/dev/null 2>&1 || { err "sozo not found"; exit 1; }
command -v jq >/dev/null 2>&1   || { err "jq not found"; exit 1; }
[ -f "$DOJO_TOML" ] || { err "Missing $DOJO_TOML"; exit 1; }

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

# --- Build ---
info "Building contracts..."
cd "$ROOT_DIR"
sozo build -P "$PROFILE" 2>&1

# --- Migrate ---
info "Migrating to Slot..."
MAX_ATTEMPTS=3
for attempt in $(seq 1 $MAX_ATTEMPTS); do
    MIGRATE_OUTPUT=$(sozo migrate -P "$PROFILE" 2>&1) && break
    WAIT=$((15 * attempt))
    warn "Attempt $attempt/$MAX_ATTEMPTS failed. Retrying in ${WAIT}s..."
    sleep "$WAIT"
done
echo "$MIGRATE_OUTPUT" | tail -3

# --- Extract addresses ---
[ -f "$MANIFEST" ] || { err "Manifest not found at $MANIFEST"; exit 1; }

WORLD_ADDRESS=$(jq -r '.world.address // empty' "$MANIFEST")
ACTIONS_ADDRESS=$(jq -r ".contracts[] | select(.tag == \"${CONTRACT_TAG}\") | .address // empty" "$MANIFEST")

[ -n "$WORLD_ADDRESS" ] || { err "Could not extract world_address"; exit 1; }
if [ -z "$ACTIONS_ADDRESS" ]; then
    ACTIONS_ADDRESS=$(jq -r '.contracts[-1].address // empty' "$MANIFEST")
    warn "Used fallback for actions_address"
fi

info "World:   $WORLD_ADDRESS"
info "Actions: $ACTIONS_ADDRESS"

# --- Update main_menu.gd (source of truth for client) ---
if [ -f "$MAIN_MENU" ]; then
    sed -i "s|const DEFAULT_WORLD_ADDRESS := \"0x[0-9a-fA-F]*\"|const DEFAULT_WORLD_ADDRESS := \"$WORLD_ADDRESS\"|" "$MAIN_MENU"
    sed -i "s|const DEFAULT_ACTIONS_ADDRESS := \"0x[0-9a-fA-F]*\"|const DEFAULT_ACTIONS_ADDRESS := \"$ACTIONS_ADDRESS\"|" "$MAIN_MENU"
    info "main_menu.gd updated"
fi

# --- Update torii_slot.toml ---
if [ -f "$TORII_TOML" ]; then
    sed -i "s|world_address = \"0x[0-9a-fA-F]*\"|world_address = \"$WORLD_ADDRESS\"|" "$TORII_TOML"
    info "torii_slot.toml updated"
fi

# --- Done ---
echo ""
echo "  World:   $WORLD_ADDRESS"
echo "  Actions: $ACTIONS_ADDRESS"
echo "  RPC:     $RPC_URL"
echo "  Torii:   $TORII_URL"
echo "  Account: $ACCOUNT_ADDRESS"
echo ""
echo "Next steps:"
echo "  slot d update $SLOT_NAME torii --config ./torii_slot.toml   # if world changed"
echo "  cd client && godot                                          # play"
