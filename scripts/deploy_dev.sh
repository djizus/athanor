#!/usr/bin/env bash
set -euo pipefail

# Deploy Athanor v2 contracts to local Katana and update client config
#
# Prerequisites:
#   1. katana --dev --dev.no-fee --dev.no-account-validation  (running)
#   2. jq installed
#
# Usage:
#   ./scripts/deploy_dev.sh              # Build, migrate, update client, print torii cmd
#   ./scripts/deploy_dev.sh --with-torii # Also start torii in background

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE="v2"
NAMESPACE="athanor_v2"
CONTRACT_TAG="${NAMESPACE}-actions_v2"
MANIFEST="$ROOT_DIR/manifest_v2.json"
DOJO_BRIDGE="$ROOT_DIR/client/scripts/autoload/dojo_bridge.gd"
START_TORII=false

for arg in "$@"; do
    case $arg in
        --with-torii) START_TORII=true ;;
    esac
done

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

if ! curl -s -o /dev/null -w '' http://localhost:5050 2>/dev/null; then
    err "Katana not reachable at localhost:5050. Start it first:"
    err "  katana --dev --dev.no-fee --dev.no-account-validation"
    exit 1
fi

# --- Build & Migrate ---
info "Building contracts (profile: $PROFILE)..."
cd "$ROOT_DIR"
sozo build -P "$PROFILE" 2>&1

info "Migrating contracts (profile: $PROFILE)..."
MIGRATE_OUTPUT=$(sozo migrate -P "$PROFILE" 2>&1) || {
    err "Migration failed:"
    echo "$MIGRATE_OUTPUT"
    exit 1
}
echo "$MIGRATE_OUTPUT" | tail -3
info "Migration complete."

# --- Parse manifest ---
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

# --- Update dojo_bridge.gd defaults ---
if [ -f "$DOJO_BRIDGE" ]; then
    info "Updating dojo_bridge.gd with deployed addresses..."
    sed -i "s|@export var world_address := \"0x[0-9a-fA-F]*\"|@export var world_address := \"$WORLD_ADDRESS\"|" "$DOJO_BRIDGE"
    sed -i "s|@export var actions_address := \"0x[0-9a-fA-F]*\"|@export var actions_address := \"$ACTIONS_ADDRESS\"|" "$DOJO_BRIDGE"
    info "dojo_bridge.gd updated."
else
    warn "dojo_bridge.gd not found at $DOJO_BRIDGE — skipping address injection"
fi

# --- Torii ---
if [ "$START_TORII" = true ]; then
    command -v torii >/dev/null 2>&1 || { err "torii not found"; exit 1; }
    info "Starting Torii..."
    torii --world "$WORLD_ADDRESS" --rpc http://localhost:5050 &
    TORII_PID=$!
    sleep 2
    if kill -0 "$TORII_PID" 2>/dev/null; then
        info "Torii running (PID: $TORII_PID)"
        info "  GraphQL: http://localhost:8080/graphql"
    else
        err "Torii failed to start"
    fi
fi

# --- Done ---
echo ""
info "Deploy complete!"
echo ""
echo "  World:   $WORLD_ADDRESS"
echo "  Actions: $ACTIONS_ADDRESS"
echo ""
if [ "$START_TORII" = false ]; then
    echo "  Start Torii:"
    echo "    torii --world $WORLD_ADDRESS --rpc http://localhost:5050"
    echo ""
fi
echo "  Launch Godot:"
echo "    cd client && godot"
echo ""
echo "  QA script:"
echo "    ./scripts/qa_local.sh --keep"
