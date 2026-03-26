# Athanor v2 Domain Specification

## Game Phases
- `Explore` — player walks freely, no combat constraints
- `PlayerTurn` — player spends stamina on movement + abilities
- `EnemyTurn` — resolve pending telegraphs, then enemies act via deterministic rules
- `Complete` — all rooms cleared, run succeeded
- `Failed` — player HP reached 0

## Combat Grid
- **8×8 tiles** (64 total)
- ~20 tiles blocked by obstacles (~30% coverage)
- Blocked bitmap: `u64` (bit index = y * 8 + x)
- Occupancy bitmap: `u64` (same encoding)
- Isometric 2:1 visual perspective

## Abilities (5 starter, all available from turn 1)

| Ability | Target Mode | Stamina Cost | Cooldown (turns) | AOE Shape | Base Damage | Notes |
|---------|-------------|-------------|-------------------|-----------|-------------|-------|
| Strike | SingleTarget | 15 | 0 | Single tile (adjacent) | 20 | Melee range only (Manhattan dist ≤ 1) |
| Dash | Directional | 20 | 2 | Line (up to 3 tiles) | 10 | Moves player to end tile. Stops at last unoccupied tile. Hits first enemy in path. If all tiles occupied, fails (no stamina spent). |
| Cleave | Directional | 25 | 1 | Cone (3 tiles in 90° arc) | 15 | Hits all enemies in cone |
| Fireball | Positional | 30 | 2 | Circle (radius 1 = 5 tiles cross pattern) | 25 | Targets any tile within range 4. Damages all actors in AOE including player if in range. |
| Guard | Self | 10 | 3 | Self only | 0 | Reduces all damage taken during next enemy phase by 50%. Refresh policy: reapplying resets duration, does not stack. |

## Stamina
- Max stamina: 100 (refills at start of each PlayerTurn)
- Movement cost: 10 stamina per tile (Manhattan distance)
- Leftover stamina does NOT carry over
- Player can move, ability, move, ability in any order within a single PlayerTurn

## Telegraph Timing (Into the Breach Model)
1. Enemy Phase N: enemies create telegraphs (danger zones appear on grid at 40% opacity)
2. Player Phase N+1: player sees telegraphs and decides whether to spend stamina dodging or attacking
3. Enemy Phase N+1 START: pending telegraphs resolve — damage applied to all actors inside the shape. THEN enemies act (move + create new telegraphs)
4. Turn index is strictly monotonic

## Combat Flow
1. Player enters ArenaStarter → `fight_mode` = true → doors lock → enemies spawn
2. Player Phase: spend stamina on move/abilities. End turn manually or when stamina = 0.
3. Enemy Phase: resolve telegraphs → each enemy follows deterministic rules (move + telegraph). Order: by speed stat, break ties by actor_id ascending.
4. Repeat 2-3 until all enemies dead (RoomCleared) or player HP = 0 (RunFailed)
5. `fight_mode` = false → doors unlock → player exits

## Actor Stats

| Stat | Player Default | Brute Default | Caster Default | Description |
|------|---------------|---------------|----------------|-------------|
| max_hp | 100 | 40 | 25 | Maximum hit points |
| max_stamina | 100 | — | — | Only player has stamina |
| offense | 20 | 15 | 20 | Base damage multiplier |
| defense | 5 | 8 | 3 | Flat damage reduction |
| speed | 10 | 5 | 8 | Turn order within enemy phase (higher = acts first) |
| move_cost | 10 | — | — | Stamina per tile moved (player only) |

## Damage Formula
`actual_damage = max(1, base_damage + attacker.offense - target.defense)`
If Guard active on target: `actual_damage = max(1, actual_damage / 2)`
