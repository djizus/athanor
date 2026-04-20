# CLAUDE.md — Athanor Project Guide

## What is this project?

Athanor:Ascend is an onchain tactical roguelike (Into the Breach-style) built
with Dojo (Cairo smart contracts on Starknet / Cartridge Slot) and a
TypeScript + Three.js web client. Combat is authoritative on-chain; the
client submits batched `confirm_turn` transactions and mirrors state from
Torii.

## Repository Layout

```
contracts/src/        Cairo contracts (namespace: athanor_0_1)
client/               TypeScript + Three.js client (Vite + mkcert HTTPS)
scripts/              Slot deploy script (scripts/deploy.sh)
PLAN.md               Combat design — see "POC Pivot" at the top for the current model
dojo_slot.toml        World seed + account creds + init args for Slot migrate
katana_slot.toml      Slot katana runtime config
torii_slot.toml       Slot torii indexing config
```

## Key Architecture (POC, 2026-04)

See `PLAN.md` → "POC Pivot" for the source of truth.

- **Online-only, endless runs.** Single "Standard" mode. No Bronze/Silver/Gold tiers.
- **Run ends only on HP ≤ 0.** Stamina reaching 0 is not a game-over.
- **Per-turn stamina refill.** Player gets `hero_stamina` (80) back at the
  start of each player phase. Intra-turn bonuses (kill +10, orb +20) do
  not carry across turns.
- **No bump displacement.** Enemy-occupied tiles are hard blockers.
  Displacement lives only in Shove and Slam.
- **Turn order**: `PLAYER → RESOLVE → ENEMY`, resolved in
  `systems::actions::process_enemy_phase` (PULL → STAMINA_DRAIN → DAMAGE).
- **Per-archetype orb drops**: Brute/Flanker/Drainer → stamina orbs (+20,
  same-turn only); Caster/Heavy/Puller → HP orbs (+10, persistent).

### 5 Abilities

| # | Name | Cost | CD | Effect |
|---|------|------|----|--------|
| 0 | Strike | 20 | 0  | 15 dmg adjacent |
| 1 | Dash   | 20 | 1  | Line move + 10 dmg |
| 2 | Heal   | 25 | 3  | Restore 20 HP |
| 3 | Shove  | 20 | 1  | 5 dmg + push 2 tiles (silent fail if blocked) |
| 4 | Slam   | 35 | 2  | 10 dmg all adjacent + push 1 tile each |

### 6 Enemy Archetypes (POC HP values)

| Type     | HP | Behavior                 | Telegraph                       | Orb drop |
|----------|----|--------------------------|----------------------------------|----------|
| Brute    | 30 | Chase + melee            | Single tile on player            | stamina  |
| Caster   | 20 | Kite + AOE               | 3×3 circle on player             | HP       |
| Flanker  | 25 | Flank behind last move   | Single tile behind player        | stamina  |
| Heavy    | 45 | Slow chase, **immovable** | Cross (+) on player              | HP       |
| Puller   | 22 | Maintain distance        | 3×3 PULL zone (forced movement)  | HP       |
| Drainer  | 22 | Maintain distance        | 3×3 STAMINA_DRAIN zone (-20 STA) | stamina  |

Enemy HP and offense scale per room via `stat_mult` (room 0 = 100 %, +15 %
per room through room 2, then piecewise up to 690 % at room 17 and
+60 % per room beyond — endless). Archetype weights introduce Heavy at
tier 1 and Puller/Drainer at tier 2. Caps: 2 Pullers, 2 Heavies, 2
Drainers per room.

## Build & Validate Commands

```bash
# Contracts
sozo build -P slot            # Build Cairo contracts for Slot deploy
sozo test                     # Run contract tests (31 passing)

# Client (TypeScript + Three.js)
cd client && pnpm install
cd client && pnpm typecheck   # tsc --noEmit (browser + electron configs)
cd client && pnpm build       # tsc && vite build --mode slot && electron bundle
cd client && pnpm slot        # HTTPS dev server (mkcert) on :5173

# Deploy to Slot (runs sozo declare/deploy mock_lords + migrate + writes client/.env.slot)
./scripts/deploy.sh
```

## Dev Flow

1. `slot d create zathanor-slot katana --config ./katana_slot.toml`
   (once, requires Slot CLI auth). Override the default name by setting
   `SLOT_NAME` before running `deploy.sh`.
2. `./scripts/deploy.sh` — builds contracts, declares/deploys mock_lords on
   Slot, migrates the Dojo world, and writes `client/.env.slot` with the
   fresh addresses.
3. `cd client && pnpm slot` — Vite + mkcert HTTPS on `https://127.0.0.1:5173`.
   The client makes direct HTTPS calls to the Slot-hosted katana/torii
   (`api.cartridge.gg/x/zathanor-slot/{katana,torii}`) — no proxy needed
   because both ends are HTTPS.

## QA Pipeline (Playwright MCP)

```
# After pnpm slot is running
playwright_browser_navigate     https://127.0.0.1:5173/
playwright_browser_wait_for     time: 5
playwright_browser_take_screenshot
```

The menu is online-only: single "Start Run" button that approves the
100 mLORDS entry fee and submits `spawn(game_id, 1)` on-chain. Ability
targeting UI is still being wired; basic move/confirm loop works today.

## Contract Namespace & Naming

Following zkube pattern: version in namespace, not in contract names.

- **Namespace**: `athanor_0_1`
- **Contracts**: `actions`, `setup`
- **Functions**: `spawn`, `enter_room`, `confirm_turn`
- **Models**: `RunState`, `RoomState`, `ActorState`, `AbilitySlotState`,
  `TelegraphState`, `GameSettings`, `Config`

### Batched Turn Architecture

Player plays full turn locally (optimistic), then submits all actions in
one `confirm_turn(game_id, actions: Span<felt252>)` transaction. The
contract processes all player actions sequentially, then auto-runs the
enemy phase (telegraph resolve, enemy AI, new telegraphs, stamina
refill, turn flip).

**Action encoding** (packed felt252 array):

| Action  | Type ID | Fields                                      | Felts |
|---------|---------|---------------------------------------------|-------|
| Move    | 0       | target_x, target_y                          | 3     |
| Ability | 1       | ability_id, target_mode, target_a, target_b | 5     |

```bash
# CLI examples (via sozo execute against Slot)
sozo execute athanor_0_1-actions confirm_turn $GID 3 0 2 1 --wait              # Move to (2,1)
sozo execute athanor_0_1-actions confirm_turn $GID 8 0 2 1 1 0 0 1 0 --wait    # Move + Strike actor 1
```

## Client File Map

| File                            | Purpose |
|---------------------------------|---------|
| `src/state/tiers.ts`           | Single `TIER_STANDARD` (settingsId 1, 80 HP, 80 STA/turn, 100 mLORDS fee) |
| `src/state/combat.ts`          | Combat state shape, `newCombatState`, `tryMove`, `refillStamina`, `computeReachable`, intents |
| `src/state/constants.ts`       | Mirrors `contracts/src/constants.cairo` (ability costs, orb bonuses, drain amount) |
| `src/dojo/config.ts`           | Reads `VITE_PUBLIC_*` env vars written by `scripts/deploy.sh` |
| `src/dojo/burner.ts`           | Raw Starknet `Account` signer using the master burner key from env |
| `src/dojo/client.ts`           | `spawn`, `enter_room`, `confirm_turn`, `approveLords`, `mintLords` wrappers |
| `src/ui/main-menu.ts`          | Online-only menu with a single "Start Run" button |
| `src/ui/router.ts`             | Menu ↔ game transitions; wires input, HUD, game-over |
| `src/ui/hud.ts`, `game-over.ts`| HP/STA bars, ability buttons, death screen |
| `src/game/{scene,grid,actor,obstacles,input}.ts` | Three.js rendering |

### Slot Endpoints

- Katana: `https://api.cartridge.gg/x/zathanor-slot/katana`
- Torii:  `https://api.cartridge.gg/x/zathanor-slot/torii`
- World / actions / lords addresses: set by `scripts/deploy.sh` into
  `torii_slot.toml` and `client/.env.slot`.

## Skills to Use

### Dojo / Contracts
- **dojo-model**: Create/modify Cairo models
- **dojo-system**: Create/modify Cairo system contracts
- **dojo-config**: Scarb.toml, dojo profiles, namespace config
- **dojo-test**: Write Cairo tests
- **dojo-review**: Audit contracts for issues
- **dojo-deploy**: Deploy to Katana/Slot
- **dojo-init**, **dojo-migrate**, **dojo-world**, **dojo-indexer**, **dojo-token**

### Cartridge / Infrastructure
- **controller-setup**, **controller-react**, **controller-sessions**,
  **controller-signers**, **controller-backend**, **controller-native**,
  **controller-presets** — for the future Controller migration
- **slot-deploy**, **slot-rpc**, **slot-teams**, **slot-paymaster**,
  **slot-scale**, **slot-vrng**
- **create-pr**: PR workflow
- **create-a-plan**: Structured planning interviews
- **playwright** (MCP): Browser automation for the Three.js client

## Known Quirks

- `move` is a Cairo keyword — avoid as function names in contracts.
- `sozo build` (default dev profile) works for local compile checks, but
  `sozo migrate` requires `dojo_slot.toml` + Slot auth.
- `slot` CLI auth doesn't work on headless VMs — run `scripts/deploy.sh`
  on a machine that already has `slot` logged in.
- Chrome HSTS caches localhost aggressively once any project uses HTTPS
  there — `vite-plugin-mkcert` + `pnpm slot` is the cleanest way through.
- The `archetype` field on `ActorState` is packed to 3 bits (values 0-7);
  ARCHETYPE_DRAINER=6 fits. Adding a 9th archetype requires a packing
  rework.
- Ability targeting UI is not wired yet — abilities fire via keyboard
  `1-5` in the near future; today only movement submits real actions.
