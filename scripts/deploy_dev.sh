#!/usr/bin/env bash
set -euo pipefail

# Deploy Athanor contracts to local Katana and update Godot project.godot
#
# Prerequisites:
#   1. katana --dev --dev.no-fee  (running in another terminal)
#   2. torii (optional, for entity sync)
#   3. jq installed
#
# Usage:
#   ./scripts/deploy_dev.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$ROOT_DIR/manifest_dev.json"
PROJECT_GODOT="$ROOT_DIR/client/project.godot"
DOJO_TOML="$ROOT_DIR/dojo_dev.toml"
PROFILE="dev"
NAMESPACE="athanor"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*" >&2; }

# --- Preflight ---
command -v sozo >/dev/null 2>&1 || { err "sozo not found. Install dojo toolchain."; exit 1; }
command -v jq >/dev/null 2>&1   || { err "jq not found. Install jq."; exit 1; }

if [ ! -f "$PROJECT_GODOT" ]; then
    err "client/project.godot not found at $PROJECT_GODOT"
    exit 1
fi

# Check Katana is running
if ! curl -s -o /dev/null -w '' http://localhost:5050 2>/dev/null; then
    err "Katana not reachable at localhost:5050. Start it first:"
    err "  katana --dev --dev.no-fee"
    exit 1
fi

# --- Build & Migrate ---
info "Building contracts..."
cd "$ROOT_DIR"
sozo build 2>&1

info "Migrating contracts (profile: $PROFILE)..."
MIGRATE_OUTPUT=$(sozo migrate -P "$PROFILE" 2>&1) || {
    err "Migration failed:"
    echo "$MIGRATE_OUTPUT"
    exit 1
}
echo "$MIGRATE_OUTPUT"
info "Migration complete."

# --- Parse manifest ---
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
    err "Could not extract actions_address from manifest (tag: ${NAMESPACE}-actions)"
    exit 1
fi

info "world_address:   $WORLD_ADDRESS"
info "actions_address: $ACTIONS_ADDRESS"

# --- Read dev account from dojo_dev.toml ---
ACCOUNT_ADDRESS=""
PRIVATE_KEY=""
if [ -f "$DOJO_TOML" ]; then
    ACCOUNT_ADDRESS=$(grep '^account_address' "$DOJO_TOML" | head -1 | sed 's/.*= *"\(.*\)"/\1/')
    PRIVATE_KEY=$(grep '^private_key' "$DOJO_TOML" | head -1 | sed 's/.*= *"\(.*\)"/\1/')
fi

if [ -z "$ACCOUNT_ADDRESS" ] || [ -z "$PRIVATE_KEY" ]; then
    warn "Could not read dev account from dojo_dev.toml — project.godot account fields unchanged"
fi

# --- Update project.godot ---
info "Updating client/project.godot..."

# Replace config values using sed (match the existing key=value pattern)
sed -i "s|config/world_address=.*|config/world_address=\"$WORLD_ADDRESS\"|" "$PROJECT_GODOT"
sed -i "s|config/actions_address=.*|config/actions_address=\"$ACTIONS_ADDRESS\"|" "$PROJECT_GODOT"

if [ -n "$ACCOUNT_ADDRESS" ] && [ -n "$PRIVATE_KEY" ]; then
    sed -i "s|config/account/address=.*|config/account/address=\"$ACCOUNT_ADDRESS\"|" "$PROJECT_GODOT"
    sed -i "s|config/account/private_key=.*|config/account/private_key=\"$PRIVATE_KEY\"|" "$PROJECT_GODOT"
    info "account_address: $ACCOUNT_ADDRESS"
fi

# --- Start Torii hint ---
info "Done! To start Torii:"
echo ""
echo "  torii --world $WORLD_ADDRESS --rpc http://localhost:5050"
echo ""
info "Then launch Godot — burner account will auto-connect."
