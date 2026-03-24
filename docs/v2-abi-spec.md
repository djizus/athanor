# Athanor v2 ABI Specification

## Namespace
`athanor_v2`

## Contract Actions

### spawn_v2(class_id: u8)
Creates a new run. Initializes RunState, RoomState (room 0), and player ActorState.
- Emits: RunSpawnedV2

### enter_room_v2(game_id: u32, room_id: u8)
Transitions player to a new room. Initializes RoomState with grid layout, spawns enemy actors.
- Validates: run not complete/failed, room_id is valid next room
- Emits: RoomEnteredV2

### move_v2(game_id: u32, target_x: u8, target_y: u8)
Moves player actor to target tile.
- Validates: phase == PlayerTurn, target in bounds (0-7), target not blocked, target not occupied, player has enough stamina (Manhattan distance * move_cost)
- Deducts stamina
- Updates occupancy bitmap
- Emits: ActorMoved

### use_ability_v2(game_id: u32, ability_id: u8, target_mode: u8, target_a: u8, target_b: u8)
Player uses an ability.
- target_mode: 0=SingleTarget (target_a=actor_id), 1=Directional (target_a=direction 0-3 for N/E/S/W), 2=Positional (target_a=x, target_b=y), 3=Self (target_a/b ignored)
- Validates: phase == PlayerTurn, ability not on cooldown, sufficient stamina, target valid for ability type
- Deducts stamina, sets cooldown, resolves damage/effects
- Emits: AbilityUsed, ActorDamaged (per target hit), ActorDied (if HP=0), GuardApplied (for Guard)

### end_player_phase_v2(game_id: u32)
Ends the player's turn. Transitions to EnemyTurn phase.
- Validates: phase == PlayerTurn
- Emits: TurnEnded

### step_enemy_phase_v2(game_id: u32)
Executes the enemy phase:
1. Resolve pending telegraphs (created_turn + 1 == current_turn): apply damage to actors in shapes
2. For each enemy (sorted by speed desc, then actor_id asc): apply deterministic rules (move + create telegraph)
3. Check terminal states: all enemies dead → RoomCleared, player dead → RunFailed
4. If neither terminal: transition back to PlayerTurn, increment turn_index, reset player stamina
- Emits: TelegraphResolved (per telegraph), EnemyTurnComputed, ActorMoved (per enemy move), TelegraphCreated (per new telegraph), ActorDamaged, ActorDied, RoomCleared or RunFailed (if terminal), TurnEnded

## Entity Schemas

### RunState
Keys: `player: ContractAddress`, `game_id: u32`
Fields:
- `phase: u8` — 0=Explore, 1=PlayerTurn, 2=EnemyTurn, 3=Complete, 4=Failed
- `room_id: u8`
- `turn_index: u16`
- `player_actor_id: u8`
- `status_flags: u8`

### RoomState
Keys: `player: ContractAddress`, `game_id: u32`, `room_id: u8`
Fields:
- `width: u8` — always 8
- `height: u8` — always 8
- `blocked: u64` — bitmap, bit y*8+x = 1 if tile is an obstacle
- `occupancy: u64` — bitmap, bit y*8+x = 1 if an actor is on that tile
- `enemy_count: u8` — number of alive enemies
- `cleared: bool`

### ActorState
Keys: `player: ContractAddress`, `game_id: u32`, `actor_id: u8`
Fields:
- `faction: u8` — 0=Player, 1=Enemy
- `archetype: u8` — 0=Hero, 1=Brute, 2=Caster
- `hp: u16`, `max_hp: u16`
- `stamina: u16`, `max_stamina: u16`
- `offense: u8`, `defense: u8`, `speed: u8`, `move_cost: u8`
- `pos_x: u8`, `pos_y: u8`
- `alive: bool`
- `guard_active: bool` — true if Guard buff is active for next enemy phase
- `room_id: u8` — which room this actor belongs to

### AbilitySlotState
Keys: `player: ContractAddress`, `game_id: u32`, `actor_id: u8`, `slot_index: u8`
Fields:
- `ability_id: u8` — 0=Strike, 1=Dash, 2=Cleave, 3=Fireball, 4=Guard
- `cooldown_remaining: u8`

### TelegraphState
Keys: `player: ContractAddress`, `game_id: u32`, `telegraph_id: u8`
Fields:
- `source_actor_id: u8`
- `shape_type: u8` — 0=SingleTile, 1=Line, 2=Cone, 3=Circle
- `param_a: u8`, `param_b: u8`, `param_c: u8` — shape-specific params (center x/y, direction, radius, etc)
- `damage: u16`
- `created_turn: u16`
- `resolves_turn: u16` — always created_turn + 1
- `resolved: bool`
- `room_id: u8`

## Events (14 total)

| Event | Key Fields | Data Fields |
|-------|-----------|-------------|
| RunSpawnedV2 | player, game_id | class_id |
| RoomEnteredV2 | player, game_id | room_id, enemy_count |
| ActorMoved | player, game_id | actor_id, from_x, from_y, to_x, to_y |
| AbilityUsed | player, game_id | actor_id, ability_id, target_mode, target_a, target_b |
| GuardApplied | player, game_id | actor_id |
| TelegraphCreated | player, game_id | telegraph_id, source_actor_id, shape_type, param_a, param_b, param_c, damage, resolves_turn |
| TelegraphResolved | player, game_id | telegraph_id, actors_hit_count |
| EnemyTurnComputed | player, game_id | turn_index, enemies_acted |
| TurnEnded | player, game_id | turn_index, phase |
| ActorDamaged | player, game_id | actor_id, damage, remaining_hp, source |
| ActorDied | player, game_id | actor_id |
| RoomCleared | player, game_id | room_id |
| RunCompleted | player, game_id | turns_taken |
| RunFailed | player, game_id | turn_index |
