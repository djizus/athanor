#!/usr/bin/env bash
# Athanor:Ascend — user story runbook for local verification.
#
# Prerequisites (run once, outside this script):
#   - katana running: katana --dev --dev.no-fee --dev.seed 0 \
#                            --invoke-max-steps 10000000 \
#                            --http.cors_origins '*'
#   - sozo migrated: ./scripts/user_stories.sh migrate
#
# Then exercise the scenarios:
#   ./scripts/user_stories.sh spawn         -> spawn a Bronze run (500 stamina)
#   ./scripts/user_stories.sh spawn-silver  -> spawn a Silver run (1500 stamina)
#   ./scripts/user_stories.sh spawn-gold    -> spawn a Gold run (4000 stamina)
#   ./scripts/user_stories.sh room0         -> enter room 0 (procedural)
#   ./scripts/user_stories.sh turn          -> submit one confirm_turn batch
#   ./scripts/user_stories.sh state         -> read RunState + player ActorState
#   ./scripts/user_stories.sh all           -> run the above sequentially
#
# Account pinned to katana's default #0 (seed 0). Addresses land in
# manifest_dev.json after the first migrate; the script reads them.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROFILE="dev"
ACCT="0x127fd5f1fe78a71f8bcd1fec63e3fe2f0486b6ecd5c86a0466c3a21fa5cfcec"
PK="0xc5b2fcab997346f3ea1c00b002ecf6f382c5f9c9659a3894eb783c5320f912"
GAS="--l1-gas-price 1000000000 --l1-data-gas-price 10000000 --l2-gas-price 1000000000"
FEE="--fee strk"

sozo_exec() {
    sozo --profile "$PROFILE" execute "$@" \
         --account-address "$ACCT" --private-key "$PK" \
         $GAS $FEE --wait
}

sozo_call() {
    sozo --profile "$PROFILE" call "$@" \
         --account-address "$ACCT"
}

cmd="${1:-all}"

case "$cmd" in
    migrate)
        sozo --profile "$PROFILE" migrate \
             --account-address "$ACCT" --private-key "$PK" \
             $GAS $FEE
        ;;

    spawn)
        # spawn(game_id = 1, settings_id = 1) — Bronze tier (500 stamina budget)
        sozo_exec "athanor_0_1-actions" spawn 1 1
        ;;

    spawn-silver)
        # spawn(game_id = 1, settings_id = 2) — Silver tier (1500 stamina budget)
        sozo_exec "athanor_0_1-actions" spawn 1 2
        ;;

    spawn-gold)
        # spawn(game_id = 1, settings_id = 3) — Gold tier (4000 stamina budget)
        sozo_exec "athanor_0_1-actions" spawn 1 3
        ;;

    room0)
        # enter_room(game_id = 1, room_id = 0)
        sozo_exec "athanor_0_1-actions" enter_room 1 0
        ;;

    turn)
        # Submit a single Move action: east by 1 tile.
        # confirm_turn(game_id, actions: Span<felt252>)
        # actions layout: [action_type=MOVE(0), target_x, target_y]
        # Move from (1,1) to (2,1):
        sozo_exec "athanor_0_1-actions" confirm_turn 1 3 0 2 1
        ;;

    strike)
        # Ability batch: ACTION_TYPE_ABILITY(1), slot=0 Strike, target_mode=SINGLE(0), target_actor_id=1, 0, 0
        sozo_exec "athanor_0_1-actions" confirm_turn 1 6 1 0 0 1 0 0
        ;;

    state)
        echo "=== RunState ==="
        sozo_call --world "$(jq -r '.world.address' manifest_dev.json)" \
            model get "athanor_0_1-RunState" "$ACCT" 1 || true

        echo "=== Player ActorStatePacked ==="
        sozo_call --world "$(jq -r '.world.address' manifest_dev.json)" \
            model get "athanor_0_1-ActorStatePacked" "$ACCT" 1 0 || true
        ;;

    egc)
        # EGC hooks — token_id == game_id
        actions_addr=$(jq -r '.contracts[] | select(.tag=="athanor_0_1-actions") | .address' manifest_dev.json)
        echo "=== score(token_id=1) ==="
        sozo --profile "$PROFILE" call --contract "$actions_addr" score 1 || true
        echo "=== game_over(token_id=1) ==="
        sozo --profile "$PROFILE" call --contract "$actions_addr" game_over 1 || true
        ;;

    all)
        "$0" migrate
        echo
        "$0" spawn
        echo
        "$0" room0
        echo
        "$0" turn
        echo
        "$0" state
        echo
        "$0" egc
        ;;

    *)
        echo "unknown command: $cmd"
        echo "usage: $0 [migrate|spawn|spawn-silver|spawn-gold|room0|turn|strike|state|egc|all]"
        exit 1
        ;;
esac
