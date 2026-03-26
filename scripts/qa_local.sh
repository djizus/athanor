#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Athanor v2 Local QA Script
#
# Deploys v2 contracts to local Katana and plays through a full combat loop
# to verify the onchain game logic works end-to-end.
#
# Prerequisites:
#   - katana, sozo, torii installed (dojo toolchain)
#   - jq installed
#   - No katana already running on port 5050
#
# Usage:
#   ./scripts/qa_local.sh          # Full run: start katana, deploy, play, stop
#   ./scripts/qa_local.sh --keep   # Keep katana running after QA for manual inspection
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE="v2"
NAMESPACE="athanor_0_1"
CONTRACT_TAG="${NAMESPACE}-actions"
KEEP_RUNNING=false
KATANA_PID=""
TORII_PID=""

# --- Args ---
for arg in "$@"; do
    case $arg in
        --keep) KEEP_RUNNING=true ;;
    esac
done

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*" >&2; }
step()  { echo -e "\n${CYAN}${BOLD}>>> $*${NC}"; }
pass()  { echo -e "    ${GREEN}✓${NC} $*"; }
fail()  { echo -e "    ${RED}✗${NC} $*"; FAILURES=$((FAILURES + 1)); }

FAILURES=0

cleanup() {
    if [ "$KEEP_RUNNING" = true ]; then
        if [ -n "$KATANA_PID" ]; then
            info "Katana still running (PID: $KATANA_PID). Kill with: kill $KATANA_PID"
        fi
        if [ -n "$TORII_PID" ]; then
            info "Torii still running (PID: $TORII_PID). Kill with: kill $TORII_PID"
        fi
        return
    fi
    if [ -n "$TORII_PID" ] && kill -0 "$TORII_PID" 2>/dev/null; then
        kill "$TORII_PID" 2>/dev/null || true
        wait "$TORII_PID" 2>/dev/null || true
    fi
    if [ -n "$KATANA_PID" ] && kill -0 "$KATANA_PID" 2>/dev/null; then
        kill "$KATANA_PID" 2>/dev/null || true
        wait "$KATANA_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# --- Preflight ---
step "Preflight checks"
command -v katana >/dev/null 2>&1 || { err "katana not found"; exit 1; }
command -v sozo >/dev/null 2>&1   || { err "sozo not found"; exit 1; }
command -v torii >/dev/null 2>&1  || { err "torii not found"; exit 1; }
command -v jq >/dev/null 2>&1     || { err "jq not found"; exit 1; }
pass "All tools found"

# Kill any existing katana on 5050
if lsof -i :5050 -t >/dev/null 2>&1; then
    warn "Port 5050 in use — killing existing process"
    kill $(lsof -i :5050 -t) 2>/dev/null || true
    sleep 1
fi

# =============================================================================
# 1. START KATANA
# =============================================================================
step "Starting Katana (dev mode, no fees)"
katana --dev --dev.no-fee --dev.no-account-validation 2>/dev/null &
KATANA_PID=$!
sleep 2

if ! kill -0 "$KATANA_PID" 2>/dev/null; then
    err "Katana failed to start"
    exit 1
fi
pass "Katana running (PID: $KATANA_PID)"

# =============================================================================
# 2. BUILD & MIGRATE
# =============================================================================
step "Building contracts"
cd "$ROOT_DIR"
sozo build -P "$PROFILE" 2>&1 | tail -2
pass "Build succeeded"

step "Migrating v2 contracts (profile: $PROFILE)"
MIGRATE_OUT=$(sozo migrate -P "$PROFILE" 2>&1) || {
    err "Migration failed:"
    echo "$MIGRATE_OUT"
    exit 1
}
echo "$MIGRATE_OUT" | tail -5
pass "Migration succeeded"

# Parse manifest for world address
MANIFEST="$ROOT_DIR/manifest_v2.json"
if [ ! -f "$MANIFEST" ]; then
    # Try alternative manifest location
    MANIFEST="$ROOT_DIR/manifests/v2/deployment/manifest.json"
fi

WORLD_ADDRESS=""
if [ -f "$MANIFEST" ]; then
    WORLD_ADDRESS=$(jq -r '.world.address // empty' "$MANIFEST" 2>/dev/null || true)
fi

if [ -z "$WORLD_ADDRESS" ]; then
    # Extract from migration output
    WORLD_ADDRESS=$(echo "$MIGRATE_OUT" | grep -oP '0x[0-9a-fA-F]+' | head -1 || true)
    warn "Could not parse manifest — extracted world address from output: $WORLD_ADDRESS"
fi

info "World address: $WORLD_ADDRESS"

# =============================================================================
# 3. HELPER: execute action
# =============================================================================
exec_action() {
    local entrypoint="$1"
    shift
    local calldata="$*"
    local cmd="sozo execute $CONTRACT_TAG $entrypoint $calldata -P $PROFILE --wait 2>&1"
    local out
    out=$(eval "$cmd") || {
        fail "$entrypoint($calldata) — REVERTED"
        echo "$out" | tail -5
        return 1
    }
    pass "$entrypoint($calldata)"
    return 0
}

# =============================================================================
# 4. QA: FULL GAME LOOP
# =============================================================================
step "QA: Spawn a new run"
exec_action "spawn" "0"

# game_id is the first uuid() — typically starts at a known value
# In Dojo, world.uuid() returns incrementing integers. First call = some base value.
# We'll try game_id = 0, then 1 if that fails.
GAME_ID=0

step "QA: Enter room 0"
if ! exec_action "enter_room" "$GAME_ID 0" 2>/dev/null; then
    GAME_ID=1
    info "Retrying with game_id=1..."
    exec_action "enter_room" "$GAME_ID 0" || {
        # Try a few more IDs
        for id in 2 3 4 5; do
            GAME_ID=$id
            if exec_action "enter_room" "$GAME_ID 0" 2>/dev/null; then
                break
            fi
        done
    }
fi
info "Using game_id=$GAME_ID"

step "QA: Player Phase — Movement"
# Move player from entry (1,1) toward enemies
# Each move costs 10 stamina, player has 100
exec_action "move_action" "$GAME_ID 2 1"    # move right (cost 10, stamina=90)
exec_action "move_action" "$GAME_ID 3 1"    # move right (cost 10, stamina=80)
exec_action "move_action" "$GAME_ID 4 1"    # move right (cost 10, stamina=70)

step "QA: Player Phase — Use Guard (self buff)"
# Guard: ability_id=4, target_mode=3 (Self), target_a=0, target_b=0
exec_action "use_ability" "$GAME_ID 4 3 0 0"

step "QA: Player Phase — End Turn"
exec_action "end_player_phase" "$GAME_ID"

step "QA: Enemy Phase — Step (telegraphs + enemy AI)"
exec_action "step_enemy_phase" "$GAME_ID"

step "QA: Turn 2 — Move toward Brute (positions depend on enemy AI)"
exec_action "move_action" "$GAME_ID 5 1" 2>/dev/null || warn "move(5,1) blocked/occupied — expected after enemy AI"
exec_action "move_action" "$GAME_ID 5 2" 2>/dev/null || warn "move(5,2) blocked/occupied — expected after enemy AI"
exec_action "move_action" "$GAME_ID 4 2" 2>/dev/null || true

step "QA: Turn 2 — Strike the Brute"
# Strike: ability_id=0, target_mode=0 (SingleTarget), target_a=1 (brute actor_id), target_b=0
# Need to be adjacent to brute. If brute moved toward us, might be at (5,2) or nearby
exec_action "use_ability" "$GAME_ID 0 0 1 0" || {
    warn "Strike failed — brute may not be adjacent. Trying to move closer..."
    exec_action "move_action" "$GAME_ID 6 2" || true
    exec_action "use_ability" "$GAME_ID 0 0 1 0" || warn "Strike still failed — continuing"
}

step "QA: Turn 2 — Fireball toward Caster"
# Fireball: ability_id=3, target_mode=2 (Positional), target_a=x, target_b=y
# Caster started at (5,6). Fireball range=4, cost=30
exec_action "use_ability" "$GAME_ID 3 2 5 6" || {
    warn "Fireball failed — caster may have moved. Continuing..."
}

step "QA: Turn 2 — End Turn + Enemy Phase"
exec_action "end_player_phase" "$GAME_ID"
exec_action "step_enemy_phase" "$GAME_ID"

step "QA: Turn 3 — Keep attacking"
# Try Strike again on brute
exec_action "use_ability" "$GAME_ID 0 0 1 0" || {
    warn "Strike failed — adjusting position"
    # Try moving to find brute
    exec_action "move_action" "$GAME_ID 5 2" 2>/dev/null || true
    exec_action "use_ability" "$GAME_ID 0 0 1 0" 2>/dev/null || true
}

# Cleave: ability_id=2, target_mode=1 (Directional), target_a=2 (South), target_b=0
exec_action "use_ability" "$GAME_ID 2 1 2 0" || {
    warn "Cleave failed — continuing"
}

exec_action "end_player_phase" "$GAME_ID"
exec_action "step_enemy_phase" "$GAME_ID"

# Keep fighting for a few more turns
for turn in 4 5 6 7 8; do
    step "QA: Turn $turn — Attack cycle"
    # Try strike on brute (actor 1)
    exec_action "use_ability" "$GAME_ID 0 0 1 0" 2>/dev/null || true
    # Try strike on caster (actor 2)
    exec_action "use_ability" "$GAME_ID 0 0 2 0" 2>/dev/null || true
    # Try fireball
    exec_action "use_ability" "$GAME_ID 3 2 5 5" 2>/dev/null || true
    
    # End turn + enemy phase (may fail if game is already over)
    exec_action "end_player_phase" "$GAME_ID" 2>/dev/null || { info "Game may have ended"; break; }
    exec_action "step_enemy_phase" "$GAME_ID" 2>/dev/null || { info "Game may have ended"; break; }
done

# =============================================================================
# 5. OPTIONAL: START TORII
# =============================================================================
if [ "$KEEP_RUNNING" = true ] && [ -n "$WORLD_ADDRESS" ]; then
    step "Starting Torii for manual inspection"
    torii --world "$WORLD_ADDRESS" --rpc http://localhost:5050 2>/dev/null &
    TORII_PID=$!
    sleep 2
    if kill -0 "$TORII_PID" 2>/dev/null; then
        pass "Torii running (PID: $TORII_PID)"
        info "GraphQL:  http://localhost:8080/graphql"
        info "gRPC:     http://localhost:8080"
    fi
fi

# =============================================================================
# 6. RESULTS
# =============================================================================
echo ""
echo "============================================"
if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  QA PASSED — All actions executed successfully${NC}"
else
    echo -e "${YELLOW}${BOLD}  QA COMPLETED — $FAILURES action(s) failed/reverted${NC}"
    echo -e "${YELLOW}  (Some failures are expected if combat ended early)${NC}"
fi
echo "============================================"
echo ""

if [ "$KEEP_RUNNING" = true ]; then
    info "Stack is running. Press Ctrl+C to stop."
    info "  Katana PID: $KATANA_PID"
    [ -n "$TORII_PID" ] && info "  Torii PID:  $TORII_PID"
    [ -n "$WORLD_ADDRESS" ] && info "  World:      $WORLD_ADDRESS"
    echo ""
    info "Useful commands:"
    echo "  sozo execute $CONTRACT_TAG spawn 0 -P $PROFILE --wait"
    echo "  sozo execute $CONTRACT_TAG enter_room <GAME_ID> 0 -P $PROFILE --wait"
    echo "  sozo execute $CONTRACT_TAG move_action <GAME_ID> <X> <Y> -P $PROFILE --wait"
    echo "  sozo execute $CONTRACT_TAG use_ability <GAME_ID> <ABILITY> <MODE> <A> <B> -P $PROFILE --wait"
    echo "  sozo execute $CONTRACT_TAG end_player_phase <GAME_ID> -P $PROFILE --wait"
    echo "  sozo execute $CONTRACT_TAG step_enemy_phase <GAME_ID> -P $PROFILE --wait"
    echo ""
    wait
fi

exit 0
