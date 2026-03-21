#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE="slot"
SLOT_NAME="athanor-djizus-slot"
NAMESPACE="athanor"
MANIFEST="$ROOT_DIR/manifest_${PROFILE}.json"
PROJECT_GODOT="$ROOT_DIR/client/project.godot"
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

info "Building contracts..."
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
echo "$MIGRATE_OUTPUT"

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

info "Updating torii_slot.toml..."
sed -i "s|world_address = \"0x[0-9a-fA-F]*\"|world_address = \"$WORLD_ADDRESS\"|" "$TORII_TOML"

info "Updating client/project.godot..."
sed -i "s|config/katana_url=.*|config/katana_url=\"$RPC_URL\"|" "$PROJECT_GODOT"
sed -i "s|config/torii/torii_url=.*|config/torii/torii_url=\"$TORII_URL\"|" "$PROJECT_GODOT"
sed -i "s|config/world_address=.*|config/world_address=\"$WORLD_ADDRESS\"|" "$PROJECT_GODOT"
sed -i "s|config/actions_address=.*|config/actions_address=\"$ACTIONS_ADDRESS\"|" "$PROJECT_GODOT"
sed -i "s|config/account/address=.*|config/account/address=\"$ACCOUNT_ADDRESS\"|" "$PROJECT_GODOT"
sed -i "s|config/account/private_key=.*|config/account/private_key=\"$PRIVATE_KEY\"|" "$PROJECT_GODOT"

info "Done."
echo ""
echo "Next manual steps:"
echo "  slot d create $SLOT_NAME katana --config ./katana_slot.toml"
echo "  slot d create $SLOT_NAME torii --config ./torii_slot.toml"
echo ""
echo "Config synced:"
echo "  RPC:     $RPC_URL"
echo "  Torii:   $TORII_URL"
echo "  World:   $WORLD_ADDRESS"
echo "  Account: $ACCOUNT_ADDRESS"
echo ""
echo "Runtime mode:"
echo "  - Slot/public RPC -> Controller flow (browser/passkey)"
echo "  - localhost RPC   -> burner flow (sozo CLI)"
