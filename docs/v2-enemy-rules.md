# Athanor v2 Enemy Rules

## Design Philosophy
Enemies follow simple, deterministic rules that the player can learn and predict. The depth comes from multiple enemies creating overlapping threats, not from any single enemy being "smart." This is the Into the Breach model.

## Execution Order
During EnemyTurn, enemies act in this order:
1. Sort by `speed` descending (higher speed = acts first)
2. Break ties by `actor_id` ascending (lower ID = acts first)

Each enemy executes its full turn (move + telegraph) before the next enemy acts.

## Archetype: Melee Brute

**Stats:** HP 40, Offense 15, Defense 8, Speed 5

**Movement Rule:**
1. Calculate Manhattan distance to player on each axis: `dx = abs(player.x - brute.x)`, `dy = abs(player.y - brute.y)`
2. If already adjacent (Manhattan distance = 1): do NOT move
3. Otherwise move 1 tile toward player along the **longer axis** (reduces the larger gap first)
4. Tie-break (dx == dy): move along **X-axis** (horizontal preference)
5. If target tile is blocked or occupied: try the other axis. If both blocked: don't move.

**Attack Rule:**
- After moving, if adjacent to player (Manhattan distance ≤ 1): create a **SingleTile telegraph** on the player's current position
- Telegraph damage: `brute.offense` (15)
- If NOT adjacent after moving: no telegraph this turn

**Example Scenarios:**

```
Scenario 1: Brute at (1,1), Player at (5,3)
  dx=4, dy=2 → longer axis is X → Brute moves to (2,1)
  Manhattan dist to player = 3+2 = 5 → not adjacent → no telegraph

Scenario 2: Brute at (4,3), Player at (5,3)  
  Manhattan dist = 1 → adjacent → don't move
  Create SingleTile telegraph at (5,3) with damage 15

Scenario 3: Brute at (3,1), Player at (3,4)
  dx=0, dy=3 → move along Y → Brute moves to (3,2)
  Not adjacent → no telegraph

Scenario 4: Brute at (2,2), Player at (4,4)
  dx=2, dy=2 → tie → X-axis preference → Brute moves to (3,2)
  Not adjacent → no telegraph
```

## Archetype: Ranged Caster

**Stats:** HP 25, Offense 20, Defense 3, Speed 8

**Movement Rule:**
1. Calculate Manhattan distance to player: `dist = abs(player.x - caster.x) + abs(player.y - caster.y)`
2. If `dist < 3`: move 1 tile **away** from player along the **longer axis** (increase distance)
3. If `dist >= 3`: do NOT move (comfortable range)
4. Tie-break for retreat direction (dx == dy): move along **X-axis**
5. If retreat tile is blocked or occupied: try other axis. If both blocked: don't move.

**Attack Rule:**
- After moving (or staying), ALWAYS create a **Circle telegraph** (radius 1, cross pattern = 5 tiles) centered on the **player's current position**
- Telegraph damage: `caster.offense` (20)
- Range: unlimited (caster always telegraphs regardless of distance)

**Circle AOE Pattern (radius 1):**
```
  . X .
  X X X
  . X .
```
5 tiles: center + 4 cardinal neighbors

**Example Scenarios:**

```
Scenario 1: Caster at (6,6), Player at (4,5)
  dist = 2+1 = 3 → dist >= 3 → don't move
  Create Circle telegraph centered at (4,5) with damage 20
  Affected tiles: (4,5), (3,5), (5,5), (4,4), (4,6)

Scenario 2: Caster at (4,4), Player at (4,3)
  dist = 0+1 = 1 → dist < 3 → retreat
  dx=0, dy=1 → longer axis is Y → move away on Y → Caster moves to (4,5)
  Create Circle telegraph centered at (4,3) with damage 20

Scenario 3: Caster at (3,3), Player at (2,2)
  dist = 1+1 = 2 → dist < 3 → retreat
  dx=1, dy=1 → tie → X-axis preference → move away on X → Caster moves to (4,3)
  Create Circle telegraph centered at (2,2) with damage 20
```

## Determinism Guarantee
Given identical `ActorState` positions + stats + `RoomState` blocked bitmap, the enemy rules produce **exactly the same output** every time. There is no randomness. The player can fully predict enemy behavior.

## Future Extensibility
Post-M1 archetypes can add complexity:
- **Charger**: moves 2 tiles toward player, telegraphs a line attack
- **Bomber**: doesn't move, telegraphs large radius AOE with 2-turn delay
- **Shielder**: moves to protect other enemies, telegraphs adjacent area
Each archetype adds a new simple rule, not more complex AI.
