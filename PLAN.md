# Athanor:Ascend — Design & Implementation Notes

> **Last updated**: 2026-04-20
> **Branch**: `feat/ascend`
> **Status**: Single-mode POC, online-only, deployed to Cartridge Slot.

---

## Core identity

Athanor:Ascend is an onchain tactical roguelike (Into the Breach-style):
deterministic enemy telegraphs, a toolkit of 5 abilities, and endless rooms
that scale until HP runs out. Combat is authoritative on-chain — the client
plays optimistically and submits a single `confirm_turn` batch per turn.

## Game model

- **One mode**: "Standard" (`settings_id = 1`). No tiers.
- **Endless runs**: no fixed room count, no "win". A run ends only when
  player HP ≤ 0.
- **Per-turn stamina**: cap = 80, refilled at the start of each player phase
  in `systems::actions::process_enemy_phase` (Step 3). Stamina = 0 is **not**
  a game-over. Intra-turn bonuses (kill +10, orb +20) evaporate on refill.
- **Hero**: 80 HP, 80 stamina/turn (`GameSettings::new_default`).
- **Entry fee**: 100 mLORDS, transferred from the player via
  `settings.entry_fee_lords` on `spawn`.
- **No bump displacement**: moving into an enemy-occupied tile is a hard
  reject. `push_actor_steps` silently no-ops on block/immovable. Displacement
  lives exclusively in Shove and Slam.

### Turn loop

`PLAYER_ACTION → RESOLVE → ENEMY_ACTION`, resolved in `process_enemy_phase`:

1. Resolve PULL telegraphs (Puller drags player 2 tiles toward itself).
2. Resolve STAMINA_DRAIN telegraphs (Drainer subtracts stamina, saturating).
3. Resolve DAMAGE telegraphs (everyone else).
4. Enemy AI moves + re-telegraphs (speed desc, actor_id asc tie-break).
5. Refill player stamina to `max_stamina`; tick ability cooldowns; rotate
   orb bitmaps (`*_fresh → *_aged → expired`).

### 5 abilities

| # | Name   | Cost | CD | Damage | Effect                                                |
|---|--------|------|----|--------|-------------------------------------------------------|
| 0 | Strike | 20   | 0  | 15     | Adjacent enemy.                                       |
| 1 | Dash   | 20   | 1  | 10     | Line move up to 3 tiles, hit first enemy in path.     |
| 2 | Heal   | 25   | 3  | 0      | Restore 20 HP to self.                                |
| 3 | Shove  | 20   | 1  | 5      | Push adjacent enemy 2 tiles away.                     |
| 4 | Slam   | 35   | 2  | 10     | AOE all adjacent + push each 1 tile away.             |

Blocked Shove/Slam push = silent fail (no collision bonus damage).

### 6 enemy archetypes (POC base HP)

| Type     | HP | Speed | Behavior                 | Telegraph                        | Orb drop |
|----------|----|-------|--------------------------|----------------------------------|----------|
| Brute    | 30 | 5     | Chase + melee            | Single tile on player            | stamina  |
| Caster   | 20 | 8     | Kite                     | 3×3 circle on player             | HP       |
| Flanker  | 25 | 7     | Flank behind last move   | Single tile behind player        | stamina  |
| Heavy    | 45 | 3     | Slow chase, **immovable** | Cross (+) on player              | HP       |
| Puller   | 22 | 6     | Maintain distance        | 3×3 PULL zone (forced movement)  | HP       |
| Drainer  | 22 | 6     | Maintain distance        | 3×3 STAMINA_DRAIN zone (-20 STA) | stamina  |

HP and offense scale per room via `stat_mult` (100 % @ room 0 → 690 % @ room
17 → +60 %/room beyond). `stat_mult` is piecewise, not linear — see
`helpers::procedural::stat_mult`. Defense / speed / immovable don't scale.

### Archetype rolls

`helpers::procedural::archetype_weights(tier)`:

| Tier | Brute | Caster | Flanker | Heavy | Puller | Drainer |
|------|-------|--------|---------|-------|--------|---------|
| 0    | 60    | 30     | 10      | 0     | 0      | 0       |
| 1    | 40    | 25     | 20      | 15    | 0      | 0       |
| 2    | 25    | 20     | 20      | 15    | 10     | 10      |
| 3    | 15    | 20     | 20      | 15    | 15     | 15      |
| 4    | 10    | 15     | 20      | 20    | 20     | 15      |

Tier bands: 0-2 → tier 0, 3-6 → tier 1, 7-11 → tier 2, 12-17 → tier 3,
18+ → tier 4. Per-room caps: ≤ 2 Pullers, ≤ 2 Heavies, ≤ 2 Drainers.

### Orbs

- **Stamina orbs**: Brute / Flanker / Drainer kills drop one on the death
  tile. Pickup = `+ORB_STAMINA_BONUS` (20), capped at `max_stamina`. Since
  stamina refills each turn, stamina orbs are a same-turn-only bonus.
  Bitmaps: `RoomState.orbs_fresh` / `orbs_aged`.
- **HP orbs**: Caster / Heavy / Puller kills drop one. Pickup = `+ORB_HP_BONUS`
  (10), capped at `max_hp`. HP carries across turns → persistent value.
  Bitmaps: `RoomState.hp_orbs_fresh` / `hp_orbs_aged`.
- Both orb types share the 2-turn lifetime (`*_fresh` → `*_aged` → expired).

### Scoring

- `max_hp × 10` per kill (scaled enemies are worth more).
- `100 × rooms_cleared` bonus on each room clear (accumulates).
- Score is read by the EGC `IMinigameTokenData` trait from `RunState.score`.

## Architecture

### Contracts (`athanor_0_1` namespace)

- `actions` — main game loop. Entry points: `spawn`, `enter_room`, `confirm_turn`.
- `setup` — writes a single `GameSettings` row + EGC `SettingsComponent` registration.
- Systems: `movement`, `abilities`, `telegraph`, `enemy_ai`, `phase` (constants).
- Helpers: `procedural` (archetype rolls, HP scaling, obstacle placement),
  `bitmap`, `packing`, `random` (VRF wrapper).

### Packed models

| Model              | Packing                                      | Notes                                      |
|--------------------|----------------------------------------------|--------------------------------------------|
| `ActorState`       | 2 × u64 (`resources`, `stats`)               | archetype 3 bits (0-7); Drainer=6 fits.    |
| `TelegraphState`   | 2 × u64 (`packed_a`, `packed_b`)             | `telegraph_type` 2 bits (DAMAGE/PULL/DRAIN)|
| `AbilitySlotState` | 1 × u64                                      | ability_id + cooldown_remaining.           |
| `RoomState`        | plain struct                                 | 4 orb bitmaps + blocked + occupancy.       |

### Batched action encoding

`confirm_turn(game_id, actions: Span<felt252>)` consumes a stream:

| Action  | Type ID | Fields                                       | Felts |
|---------|---------|----------------------------------------------|-------|
| Move    | 0       | `target_x, target_y`                         | 3     |
| Ability | 1       | `ability_id, target_mode, target_a, target_b`| 5     |

Player actions execute sequentially, then the contract auto-runs the enemy
phase. On any failed assert the whole tx reverts; the client restores its
pending batch for the next attempt.

### Client (`client/`)

TypeScript + Three.js, Vite + mkcert HTTPS dev server.

| File                                           | Purpose                                                      |
|------------------------------------------------|--------------------------------------------------------------|
| `src/state/tiers.ts`                           | `TIER_STANDARD` — 80 HP, 80 STA/turn, 100 mLORDS             |
| `src/state/combat.ts`                          | `CombatState`, `tryMove`, `refillStamina`, reachable/intents |
| `src/state/constants.ts`                       | Mirrors `contracts/src/constants.cairo`                      |
| `src/dojo/config.ts`                           | Reads `VITE_PUBLIC_*` from `client/.env.slot`                |
| `src/dojo/burner.ts`                           | Raw Starknet `Account` from the master burner creds          |
| `src/dojo/client.ts`                           | `spawn`, `enter_room`, `confirm_turn`, approve/mint LORDS    |
| `src/ui/main-menu.ts`                          | Single "Start Run" button                                    |
| `src/ui/router.ts`                             | Menu ↔ game transitions, HUD wiring                          |
| `src/game/{scene,grid,actor,obstacles,input}.ts` | Three.js render layer                                       |

Client still carries a placeholder `obstacles` / `enemies` set in
`newCombatState` for visual testing; the Torii subscription that replaces
it with contract state is the next piece to land.

## Deploy & dev flow

Slot-only. The dev loop is: deploy to Slot, run client locally, client
makes HTTPS calls to the HTTPS-hosted Slot katana + torii.

```bash
# One-time: provision the Slot instance (requires slot CLI auth)
slot d create athanor-djizus-slot katana --config ./katana_slot.toml
slot d create athanor-djizus-slot torii  --config ./torii_slot.toml

# Every deploy:
./scripts/deploy.sh
  # builds contracts (slot profile), declares/deploys mock_lords on Slot,
  # migrates the Dojo world, writes client/.env.slot with fresh addresses.

cd client && pnpm slot
  # Vite + mkcert HTTPS on https://127.0.0.1:5173
  # Browser talks to api.cartridge.gg/x/athanor-djizus-slot/{katana,torii}
```

### Slot endpoints

- Katana: `https://api.cartridge.gg/x/athanor-djizus-slot/katana`
- Torii:  `https://api.cartridge.gg/x/athanor-djizus-slot/torii`

### Toolchain

- sozo 1.8.6
- scarb 2.15.1 (cairo 2.15.0, sierra 1.7.0)
- katana 1.7.x
- dojo crate 1.8.0 (pinned in `Scarb.toml`)

## Tests

`sozo test` — 31 tests covering model packing round-trips, archetype
weights + caps, procedural HP scaling, orb lifecycle simulation, and
generator bitmap invariants. Run via `sozo test` from repo root.

Client: `pnpm typecheck` (tsc strict, both browser and electron configs).

## Known quirks

- `move` is a Cairo keyword — avoid as function names.
- `sozo build` (default dev profile) compiles for local checks; `sozo
  migrate` requires `dojo_slot.toml` + Slot auth.
- `slot` CLI auth doesn't work on headless VMs — run `scripts/deploy.sh`
  on a machine that already has `slot` logged in.
- Chrome HSTS caches localhost aggressively once any project uses HTTPS
  there — `vite-plugin-mkcert` + `pnpm slot` is the cleanest way through.
- `ActorState.archetype` is packed into 3 bits (values 0-7); a 9th
  archetype would require a packing rework.

## Open items

- Torii subscription to replace the placeholder offline state in
  `newCombatState`.
- Ability targeting UI — abilities are defined but fire currently only
  via keyboard stubs; click-to-target lands next.
- Proper per-archetype intent shapes on the client (today's placeholder
  renders a single-tile intent regardless of archetype).
- Cartridge Controller migration (currently using a raw dev burner).
