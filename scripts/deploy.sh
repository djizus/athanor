#!/bin/bash
set -e

#
# Athanor Deployment Script
#
# Usage: ./scripts/deploy.sh <env>
#   env: dev | slot | sepolia
#
# Workflow:
#   1. Build contracts (sozo build)
#   2. Declare MinigameRegistryContract and FullTokenContract classes
#   3. Deploy MinigameRegistryContract
#   4. Deploy FullTokenContract (with registry address)
#   5. Update dojo config with deployed token address (denshokan_address)
#   6. Run sozo migrate (with retry for remote envs)
#   7. Copy manifest to client, update client .env
#   8. Print summary and next steps
#
# Prerequisites:
#   - sozo, jq installed
#   - For dev: katana running locally (katana --dev --dev.no-fee --dev.seed 0 --invoke-max-steps 10000000 --http.cors_origins '*')
#   - For slot: slot credentials configured in dojo_slot.toml
#   - For sepolia: account funded, credentials in dojo_sepolia.toml
#
# Key learnings encoded in this script:
#   - Cairo Option::None serializes as 1 (second enum variant), Option::Some(v) as 0 v
#   - FullTokenContract game_registry_address uses Option::Some = "0 <addr>"
#   - FullTokenContract event_relayer_address uses Option::None = "1"
#   - game_system dojo_init: creator_address, denshokan_address, renderer_address(Option::None=1), vrf_address
#   - config_system dojo_init: creator_address (ONE param)
#   - exploration_system, crafting_system, hero_system: NO dojo_init (read from centralized Config model)
#   - sozo migrate MUST run from workspace root, not from contracts/
#   - Fresh katana required for dev (no schema upgrade support)

NAMESPACE="athanor"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_step()  { echo -e "${CYAN}[STEP $1]${NC} $2"; }

ENV="${1:-}"
if [ -z "$ENV" ] || [[ ! "$ENV" =~ ^(dev|slot|sepolia)$ ]]; then
    echo "Usage: $0 <env>"
    echo "  env: dev | slot | sepolia"
    exit 1
fi

case "$ENV" in
    dev)     PROFILE="dev" ;;
    slot)    PROFILE="slot" ;;
    sepolia) PROFILE="sepolia" ;;
esac

DOJO_CONFIG="${PROJECT_ROOT}/dojo_${PROFILE}.toml"
MANIFEST_FILE="${PROJECT_ROOT}/manifest_${PROFILE}.json"
CLIENT_DIR="${PROJECT_ROOT}/client"
CLIENT_MANIFEST="${CLIENT_DIR}/manifest_${PROFILE}.json"
TARGET_DIR="${PROJECT_ROOT}/target/${PROFILE}"

if [ "$PROFILE" = "dev" ]; then
    TARGET_DIR="${PROJECT_ROOT}/target/dev"
fi

REGISTRY_CLASS_FILE="${TARGET_DIR}/athanor_MinigameRegistryContract.contract_class.json"
TOKEN_CLASS_FILE="${TARGET_DIR}/athanor_FullTokenContract.contract_class.json"

if [ ! -f "$DOJO_CONFIG" ]; then
    print_error "Dojo config not found: $DOJO_CONFIG"
    exit 1
fi

extract_address() {
    local output="$1"
    echo "$output" | grep -E "^\s*Address\s*:" | grep -oE '0x[0-9a-fA-F]+' | head -1
}

extract_class_hash() {
    local output="$1"
    echo "$output" | grep -i "class hash" | grep -oE '0x[0-9a-fA-F]+' | tail -1
}

get_credentials() {
    RPC_URL=$(grep "rpc_url" "$DOJO_CONFIG" | head -1 | cut -d'"' -f2)
    ACCOUNT_ADDRESS=$(grep "account_address" "$DOJO_CONFIG" | head -1 | cut -d'"' -f2)
    PRIVATE_KEY=$(grep "private_key" "$DOJO_CONFIG" | head -1 | cut -d'"' -f2)

    if [ -z "$RPC_URL" ] || [ -z "$ACCOUNT_ADDRESS" ] || [ -z "$PRIVATE_KEY" ]; then
        print_error "Missing credentials in $DOJO_CONFIG (need rpc_url, account_address, private_key)"
        exit 1
    fi
}

SOZO_PROFILE_FLAG=""
if [ "$PROFILE" != "dev" ]; then
    SOZO_PROFILE_FLAG="-P $PROFILE"
fi

echo "============================================"
echo " Athanor Deployment — ${ENV}"
echo " Config: ${DOJO_CONFIG}"
echo "============================================"
echo ""

# ---------------------------------------------------
# Step 1: Build
# ---------------------------------------------------
print_step 1 "Building contracts..."
cd "$PROJECT_ROOT"
sozo clean $SOZO_PROFILE_FLAG 2>/dev/null || true
sozo build $SOZO_PROFILE_FLAG
print_info "Build complete"

if [ ! -f "$REGISTRY_CLASS_FILE" ]; then
    print_error "MinigameRegistryContract not found at $REGISTRY_CLASS_FILE"
    exit 1
fi
if [ ! -f "$TOKEN_CLASS_FILE" ]; then
    print_error "FullTokenContract not found at $TOKEN_CLASS_FILE"
    exit 1
fi

# ---------------------------------------------------
# Step 2: Get credentials
# ---------------------------------------------------
get_credentials
print_info "RPC: $RPC_URL"
print_info "Account: $ACCOUNT_ADDRESS"

VRF_ADDRESS="0x0"
if [ "$ENV" = "sepolia" ]; then
    VRF_ADDRESS="0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f"
    print_info "VRF: $VRF_ADDRESS (Cartridge VRF on Sepolia)"
else
    print_info "VRF: disabled (pseudo-random)"
fi

# ---------------------------------------------------
# Step 3: Declare external contract classes
# ---------------------------------------------------
print_step 2 "Declaring external contract classes..."

REGISTRY_OUTPUT=$(sozo declare $SOZO_PROFILE_FLAG \
    --account-address "$ACCOUNT_ADDRESS" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC_URL" \
    "$REGISTRY_CLASS_FILE" 2>&1) || true
REGISTRY_CLASS=$(extract_class_hash "$REGISTRY_OUTPUT")
if [ -z "$REGISTRY_CLASS" ]; then
    print_error "Failed to declare MinigameRegistryContract"
    echo "$REGISTRY_OUTPUT"
    exit 1
fi
print_info "MinigameRegistryContract class: $REGISTRY_CLASS"

sleep 1

TOKEN_OUTPUT=$(sozo declare $SOZO_PROFILE_FLAG \
    --account-address "$ACCOUNT_ADDRESS" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC_URL" \
    "$TOKEN_CLASS_FILE" 2>&1) || true
TOKEN_CLASS=$(extract_class_hash "$TOKEN_OUTPUT")
if [ -z "$TOKEN_CLASS" ]; then
    print_error "Failed to declare FullTokenContract"
    echo "$TOKEN_OUTPUT"
    exit 1
fi
print_info "FullTokenContract class: $TOKEN_CLASS"

sleep 1

# ---------------------------------------------------
# Step 4: Deploy MinigameRegistryContract
# ---------------------------------------------------
print_step 3 "Deploying MinigameRegistryContract..."

# Constructor: name(ByteArray), symbol(ByteArray), base_uri(ByteArray), event_relayer(Option::None=1)
REGISTRY_DEPLOY_OUTPUT=$(sozo deploy $SOZO_PROFILE_FLAG \
    --account-address "$ACCOUNT_ADDRESS" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC_URL" \
    "$REGISTRY_CLASS" \
    --constructor-calldata \
        str:'Athanor Registry' str:ATHREG str:'' 1 \
    2>&1) || true

REGISTRY_ADDRESS=$(extract_address "$REGISTRY_DEPLOY_OUTPUT")
if [ -z "$REGISTRY_ADDRESS" ]; then
    print_error "Failed to deploy MinigameRegistryContract"
    echo "$REGISTRY_DEPLOY_OUTPUT"
    exit 1
fi
print_info "MinigameRegistryContract: $REGISTRY_ADDRESS"

sleep 1

# ---------------------------------------------------
# Step 5: Deploy FullTokenContract
# ---------------------------------------------------
print_step 4 "Deploying FullTokenContract..."

# Constructor: name, symbol, base_uri, royalty_receiver, royalty_fraction,
#              game_registry(Option::Some=0 <addr>), event_relayer(Option::None=1)
TOKEN_DEPLOY_OUTPUT=$(sozo deploy $SOZO_PROFILE_FLAG \
    --account-address "$ACCOUNT_ADDRESS" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC_URL" \
    "$TOKEN_CLASS" \
    --constructor-calldata \
        str:Athanor str:ATH str:'' \
        "$ACCOUNT_ADDRESS" 0 \
        0 "$REGISTRY_ADDRESS" \
        1 \
    2>&1) || true

TOKEN_ADDRESS=$(extract_address "$TOKEN_DEPLOY_OUTPUT")
if [ -z "$TOKEN_ADDRESS" ]; then
    print_error "Failed to deploy FullTokenContract"
    echo "$TOKEN_DEPLOY_OUTPUT"
    exit 1
fi
print_info "FullTokenContract: $TOKEN_ADDRESS"

sleep 2

# ---------------------------------------------------
# Step 6: Update dojo config with deployed addresses
# ---------------------------------------------------
print_step 5 "Updating $DOJO_CONFIG with deployed addresses..."

sed -i "s|\"${NAMESPACE}-game_system\" = \[.*|\"${NAMESPACE}-game_system\" = [|" "$DOJO_CONFIG"
python3 -c "
import re
with open('$DOJO_CONFIG', 'r') as f:
    content = f.read()

game_block = '''\"${NAMESPACE}-game_system\" = [
    \"$ACCOUNT_ADDRESS\",
    \"$TOKEN_ADDRESS\",
    \"1\",
    \"$VRF_ADDRESS\",
]'''

content = re.sub(
    r'\"${NAMESPACE}-game_system\" = \[.*?\]',
    game_block,
    content,
    flags=re.DOTALL
)

config_block = '''\"${NAMESPACE}-config_system\" = [
    \"$ACCOUNT_ADDRESS\",
]'''
content = re.sub(
    r'\"${NAMESPACE}-config_system\" = \[.*?\]',
    config_block,
    content,
    flags=re.DOTALL
)

with open('$DOJO_CONFIG', 'w') as f:
    f.write(content)
"
print_info "Updated init_call_args with token=$TOKEN_ADDRESS vrf=$VRF_ADDRESS"

# ---------------------------------------------------
# Step 7: Run sozo migrate
# ---------------------------------------------------
print_step 6 "Running sozo migrate..."

MAX_ATTEMPTS=1
if [ "$ENV" != "dev" ]; then
    MAX_ATTEMPTS=6
fi

ATTEMPT=1
MIGRATE_SUCCESS=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if [ $MAX_ATTEMPTS -gt 1 ]; then
        print_info "Migration attempt $ATTEMPT/$MAX_ATTEMPTS..."
    fi

    MIGRATE_OUTPUT=$(sozo migrate $SOZO_PROFILE_FLAG 2>&1) || true
    echo "$MIGRATE_OUTPUT"

    if echo "$MIGRATE_OUTPUT" | grep -q "Migration failed"; then
        if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
            WAIT_TIME=$((15 + (ATTEMPT - 1) * 15))
            print_warn "Attempt $ATTEMPT failed. Waiting ${WAIT_TIME}s before retry..."
            sleep $WAIT_TIME
        fi
        ATTEMPT=$((ATTEMPT + 1))
    else
        MIGRATE_SUCCESS=true
        break
    fi
done

if [ "$MIGRATE_SUCCESS" != "true" ]; then
    print_error "Migration failed after $MAX_ATTEMPTS attempts."
    print_error "For dev: ensure katana is running with a fresh state (restart katana)."
    print_error "For slot/sepolia: check RPC connectivity and account funding."
    exit 1
fi

WORLD_ADDRESS=$(echo "$MIGRATE_OUTPUT" | grep -oE 'world at address 0x[0-9a-fA-F]+' | grep -oE '0x[0-9a-fA-F]+')
if [ -z "$WORLD_ADDRESS" ] && [ -f "$MANIFEST_FILE" ]; then
    WORLD_ADDRESS=$(jq -r '.world.address // empty' "$MANIFEST_FILE" 2>/dev/null)
fi
if [ -z "$WORLD_ADDRESS" ]; then
    print_error "Failed to extract world address"
    exit 1
fi
print_info "World: $WORLD_ADDRESS"

# ---------------------------------------------------
# Step 8: Extract system addresses from manifest
# ---------------------------------------------------
print_step 7 "Extracting system addresses from manifest..."

GAME_SYSTEM=""
CONFIG_SYSTEM=""
EXPLORE_SYSTEM=""
CRAFTING_SYSTEM=""
HERO_SYSTEM=""

if [ -f "$MANIFEST_FILE" ]; then
    GAME_SYSTEM=$(jq -r ".contracts[] | select(.tag == \"${NAMESPACE}-game_system\") | .address" "$MANIFEST_FILE" 2>/dev/null)
    CONFIG_SYSTEM=$(jq -r ".contracts[] | select(.tag == \"${NAMESPACE}-config_system\") | .address" "$MANIFEST_FILE" 2>/dev/null)
    EXPLORE_SYSTEM=$(jq -r ".contracts[] | select(.tag == \"${NAMESPACE}-exploration_system\") | .address" "$MANIFEST_FILE" 2>/dev/null)
    CRAFTING_SYSTEM=$(jq -r ".contracts[] | select(.tag == \"${NAMESPACE}-crafting_system\") | .address" "$MANIFEST_FILE" 2>/dev/null)
    HERO_SYSTEM=$(jq -r ".contracts[] | select(.tag == \"${NAMESPACE}-hero_system\") | .address" "$MANIFEST_FILE" 2>/dev/null)
fi

print_info "game_system:        $GAME_SYSTEM"
print_info "config_system:      $CONFIG_SYSTEM"
print_info "exploration_system: $EXPLORE_SYSTEM"
print_info "crafting_system:    $CRAFTING_SYSTEM"
print_info "hero_system:        $HERO_SYSTEM"

# ---------------------------------------------------
# Step 9: Copy manifest to client
# ---------------------------------------------------
print_step 8 "Updating client configuration..."

if [ -f "$MANIFEST_FILE" ] && [ -d "$CLIENT_DIR" ]; then
    cp "$MANIFEST_FILE" "$CLIENT_MANIFEST"
    print_info "Copied manifest to $CLIENT_MANIFEST"
fi

# Determine URLs based on environment
case "$ENV" in
    dev)
        TORII_URL="http://localhost:8080"
        NODE_URL="http://localhost:5050"
        ;;
    slot)
        SLOT_NAME=$(echo "$RPC_URL" | sed 's|.*/x/\([^/]*\)/.*|\1|')
        TORII_URL="${RPC_URL/katana/torii}"
        NODE_URL="$RPC_URL"
        ;;
    sepolia)
        TORII_URL="${TORII_URL:-http://localhost:8080}"
        NODE_URL="$RPC_URL"
        ;;
esac

CLIENT_ENV="${CLIENT_DIR}/.env"
if [ "$ENV" != "dev" ]; then
    CLIENT_ENV="${CLIENT_DIR}/.env.${ENV}"
fi

cat > "$CLIENT_ENV" << EOF
VITE_PUBLIC_TORII_URL=$TORII_URL
VITE_PUBLIC_NODE_URL=$NODE_URL
VITE_PUBLIC_WORLD_ADDRESS=$WORLD_ADDRESS
VITE_PUBLIC_DEPLOY_TYPE=$ENV
VITE_PUBLIC_NAMESPACE=$NAMESPACE
VITE_PUBLIC_TOKEN_ADDRESS=$TOKEN_ADDRESS
EOF

print_info "Updated $CLIENT_ENV"

# ---------------------------------------------------
# Summary
# ---------------------------------------------------
echo ""
echo "============================================"
echo -e "${GREEN} DEPLOYMENT COMPLETE — ${ENV}${NC}"
echo "============================================"
echo ""
echo "Addresses:"
echo "  World:              $WORLD_ADDRESS"
echo "  FullTokenContract:  $TOKEN_ADDRESS"
echo "  MinigameRegistry:   $REGISTRY_ADDRESS"
echo "  game_system:        $GAME_SYSTEM"
echo "  config_system:      $CONFIG_SYSTEM"
echo "  exploration_system: $EXPLORE_SYSTEM"
echo "  crafting_system:    $CRAFTING_SYSTEM"
echo "  hero_system:        $HERO_SYSTEM"
echo ""
echo "Updated files:"
echo "  $DOJO_CONFIG"
echo "  $CLIENT_ENV"
echo "  $CLIENT_MANIFEST"
echo ""

case "$ENV" in
    dev)
        echo "Next steps:"
        echo "  1. Start Katana (if not already running):"
        echo "     katana --dev --dev.no-fee --dev.seed 0 --invoke-max-steps 10000000 --http.cors_origins '*'"
        echo ""
        echo "  2. Start Torii:"
        echo "     torii --world $WORLD_ADDRESS --rpc http://localhost:5050 --http.cors_origins '*'"
        echo ""
        echo "  3. Start client:"
        echo "     cd client && pnpm dev"
        ;;
    slot)
        echo "Next steps:"
        echo "  1. Start Torii (if not managed by Slot):"
        echo "     torii --world $WORLD_ADDRESS --rpc $RPC_URL --http.cors_origins '*'"
        echo ""
        echo "  2. Start client:"
        echo "     cd client && pnpm dev"
        ;;
    sepolia)
        echo "Next steps:"
        echo "  1. Start Torii:"
        echo "     torii --world $WORLD_ADDRESS --rpc $RPC_URL --http.cors_origins '*'"
        echo ""
        echo "  2. Start client:"
        echo "     cd client && pnpm dev"
        ;;
esac
echo ""
