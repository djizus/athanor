#!/usr/bin/env bash
set -euo pipefail

# Deploy Athanor to Slot (Cartridge hosted Katana + Torii)
#
# Prerequisites:
#   1. slot auth login
#   2. jq installed
#   3. sozo installed
#
# Usage:
#   ./scripts/deploy_slot.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE="slot"
SLOT_NAME="athanor-djizus-slot"
NAMESPACE="athanor"
MANIFEST="$ROOT_DIR/manifest_${PROFILE}.json"
PROJECT_GODOT="$ROOT_DIR/client/project.godot"
DOJO_TOML="$ROOT_DIR/dojo_${PROFILE}.toml"
KATANA_TOML="$ROOT_DIR/katana_${PROFILE}.toml"
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
command -v slot >/dev/null 2>&1 || { err "slot not found. Install: curl -L https://slot.cartridge.sh | bash"; exit 1; }
command -v jq >/dev/null 2>&1   || { err "jq not found"; exit 1; }

# --- Step 1: Create Slot Katana deployment ---
info "Creating Katana deployment: $SLOT_NAME"
slot deployments create "$SLOT_NAME" katana --config "$KATANA_TOML" 2>&1 || warn "Katana may already exist, continuing..."

# --- Step 2: Get Slot account credentials ---
info "Waiting for Katana to be ready..."
for i in $(seq 1 12); do
    ACCOUNTS_JSON=$(slot deployments accounts "$SLOT_NAME" katana 2>&1) && break
    warn "Katana not ready yet, retrying in 10s... ($i/12)"
    sleep 10
done

if [ -z "${ACCOUNTS_JSON:-}" ]; then
    err "Katana never became ready after 2 minutes"
    exit 1
fi

ACCOUNT_ADDRESS=$(echo "$ACCOUNTS_JSON" | jq -r '.[0].address // empty' 2>/dev/null)
PRIVATE_KEY=$(echo "$ACCOUNTS_JSON" | jq -r '.[0].privateKey // empty' 2>/dev/null)

if [ -z "$ACCOUNT_ADDRESS" ] || [ -z "$PRIVATE_KEY" ]; then
    err "Could not parse Slot accounts. Output:"
    echo "$ACCOUNTS_JSON"
    exit 1
fi

info "Using account: $ACCOUNT_ADDRESS"

# --- Step 3: Update dojo_slot.toml with account ---
sed -i "s|account_address = \"0x[0-9a-fA-F]*\"|account_address = \"$ACCOUNT_ADDRESS\"|" "$DOJO_TOML"
sed -i "s|private_key = \"0x[0-9a-fA-F]*\"|private_key = \"$PRIVATE_KEY\"|" "$DOJO_TOML"

# --- Step 4: Build & Migrate ---
info "Building contracts..."
cd "$ROOT_DIR"
sozo build -P "$PROFILE" 2>&1

info "Migrating contracts to Slot..."
MAX_ATTEMPTS=6
for attempt in $(seq 1 $MAX_ATTEMPTS); do
    MIGRATE_OUTPUT=$(sozo migrate -P "$PROFILE" 2>&1) && break
    WAIT=$((30 + 30 * attempt))
    warn "Migration attempt $attempt/$MAX_ATTEMPTS failed. Retrying in ${WAIT}s..."
    echo "$MIGRATE_OUTPUT"
    sleep "$WAIT"
done
echo "$MIGRATE_OUTPUT"

if echo "$MIGRATE_OUTPUT" | grep -qi "failed\|error"; then
    warn "Migration may have issues, checking manifest..."
fi

# --- Step 5: Parse manifest ---
if [ ! -f "$MANIFEST" ]; then
    err "Manifest not found at $MANIFEST"
    exit 1
fi

WORLD_ADDRESS=$(jq -r '.world.address // empty' "$MANIFEST")
ACTIONS_ADDRESS=$(jq -r ".contracts[] | select(.tag == \"${NAMESPACE}-actions\") | .address // empty" "$MANIFEST")

if [ -z "$WORLD_ADDRESS" ]; then
    err "Could not extract world_address from manifest"
    exit 1
fi
if [ -z "$ACTIONS_ADDRESS" ]; then
    err "Could not extract actions_address (tag: ${NAMESPACE}-actions)"
    exit 1
fi

info "world_address:   $WORLD_ADDRESS"
info "actions_address: $ACTIONS_ADDRESS"

# --- Step 6: Update torii config & deploy Torii ---
info "Updating torii_slot.toml..."
sed -i "s|world_address = \"0x[0-9a-fA-F]*\"|world_address = \"$WORLD_ADDRESS\"|" "$TORII_TOML"

info "Creating Torii deployment: $SLOT_NAME"
slot deployments create "$SLOT_NAME" torii --config "$TORII_TOML" 2>&1 || {
    warn "Torii may already exist, updating..."
    slot deployments update "$SLOT_NAME" torii --config "$TORII_TOML" 2>&1 || true
}

# --- Step 7: Update project.godot for Controller auth (no burner keys) ---
info "Updating client/project.godot..."

sed -i "s|config/katana_url=.*|config/katana_url=\"$RPC_URL\"|" "$PROJECT_GODOT"
sed -i "s|config/torii/torii_url=.*|config/torii/torii_url=\"$TORII_URL\"|" "$PROJECT_GODOT"
sed -i "s|config/world_address=.*|config/world_address=\"$WORLD_ADDRESS\"|" "$PROJECT_GODOT"
sed -i "s|config/actions_address=.*|config/actions_address=\"$ACTIONS_ADDRESS\"|" "$PROJECT_GODOT"
sed -i "s|config/account/address=.*|config/account/address=\"$ACCOUNT_ADDRESS\"|" "$PROJECT_GODOT"
sed -i "s|config/account/private_key=.*|config/account/private_key=\"$PRIVATE_KEY\"|" "$PROJECT_GODOT"

info "Done! Slot deployment ready."
echo ""
echo "  RPC:     $RPC_URL"
echo "  Torii:   $TORII_URL"
echo "  World:   $WORLD_ADDRESS"
echo "  Account: $ACCOUNT_ADDRESS"
echo ""
info "Launch Godot — burner auto-connects with Slot deployer account."
