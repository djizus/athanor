# Athanor v0.1 — Implementation Plan

> Fully on-chain competitive grimoire race on Starknet. Port of Alchemist PoC using the Dojo engine, Cartridge Controller, and Torii indexer. Reference implementations: `references/alchemist/` (game logic) and `references/zkube/` (Dojo architecture).

---

## 1. Game Summary

Players send heroes on expeditions through dangerous zones, gather ingredients, craft potions by trial-and-error, and race to discover all 30 recipes in their grimoire. First to complete the grimoire wins.

**Core loop**: Explore → Gather → Craft → Buff heroes → Explore deeper → Discover all 30 recipes.

### What Changes Going On-Chain

| Aspect | Browser PoC | On-Chain (Athanor) |
|--------|-------------|-------------------|
| State | React useReducer + localStorage | Dojo models on Starknet |
| Tick system | 100ms client-side tick | Lazy evaluation at claim time |
| RNG | Mulberry32 (seeded PRNG) | Cartridge VRF (verifiable) |
| Multiplayer | Solo only | Competitive (shared seed races) |
| Wallet | None | Cartridge Controller (session keys) |
| Persistence | localStorage | Starknet L2 state |
| Events | In-memory notifications | Dojo events (indexed by Torii) |
| Floats | f64 everywhere | u32 fixed-point (x1000 or x10000) |
| Strings | JavaScript strings | felt252 (short strings or IDs) |

### The Big Architectural Shift: Lazy Evaluation

The browser PoC ticks 10x/sec and simulates exploration in real-time. On-chain, that's impossible (and unnecessary). Instead:

1. **Send Expedition** → Record `(hero_id, start_time, seed)` on-chain
2. **Hero explores off-screen** — no transactions needed
3. **Claim Loot** → Contract computes ALL exploration events that *would have occurred* between `start_time` and `now`, deterministically from the seed
4. **Result is identical** to what the real-time simulation would have produced

This is the same pattern used in idle/incremental games on-chain. The seed + elapsed time fully determines the outcome. VRF provides the seed at expedition start; the rest is pure math.

---

## 2. Tech Stack

| Layer | Technology | Version | Notes |
|-------|-----------|---------|-------|
| Smart Contracts | Cairo | 2.13.1 | Same as zkube |
| Framework | Dojo | 1.8.0 | ECS: models, systems, events |
| Frontend | React 19 + TypeScript + Vite | Latest | Same as zkube client |
| Wallet | Cartridge Controller | ^0.13.9 | Session keys for gasless play |
| Indexer | Torii | ^1.8.2 | Real-time state sync |
| RNG | Cartridge VRF | - | Verifiable randomness |
| Deployment | Slot (dev) → Sepolia → Mainnet | - | Progressive rollout |
| Package Manager | pnpm | - | Workspace: contracts + client |

### Key Dependencies (from zkube reference)

**Contracts (Scarb.toml)**:
- `dojo = "1.8.0"`
- `starknet = "2.13.1"`
- `origami_random` (VRF helpers)
- `openzeppelin_*` (if token needed later)

**Client (package.json)**:
- `@dojoengine/sdk`, `@dojoengine/core`, `@dojoengine/react`, `@dojoengine/recs`
- `@cartridge/connector`, `@cartridge/controller`
- `@starknet-react/core`, `starknet`

---

## 3. Project Structure

```
athanor/
├── contracts/                  # Cairo smart contracts
│   ├── Scarb.toml
│   ├── src/
│   │   ├── lib.cairo           # Module declarations
│   │   ├── constants.cairo     # All game parameters (zones, costs, probabilities)
│   │   ├── types.cairo         # Enums and shared types
│   │   ├── models/
│   │   │   ├── game.cairo      # GameSession, GameSeed
│   │   │   ├── hero.cairo      # Hero, HeroPendingLoot
│   │   │   ├── recipe.cairo    # Recipe (per-session, generated from seed)
│   │   │   ├── inventory.cairo # Inventory, IngredientBalance, PotionItem
│   │   │   └── crafting.cairo  # CraftingState, FailedCombo, HintedRecipe
│   │   ├── systems/
│   │   │   ├── game.cairo      # create_game, end_game (lifecycle)
│   │   │   ├── exploration.cairo # send_expedition, claim_loot (lazy eval)
│   │   │   ├── crafting.cairo  # craft, craft_recipe, buy_hint
│   │   │   ├── hero.cairo      # recruit_hero, apply_potion
│   │   │   └── config.cairo    # Game settings management
│   │   ├── helpers/
│   │   │   ├── random.cairo    # VRF wrapper (from zkube pattern)
│   │   │   ├── recipes.cairo   # Deterministic recipe generation
│   │   │   ├── exploration.cairo # Lazy evaluation engine
│   │   │   └── math.cairo      # Fixed-point arithmetic helpers
│   │   ├── events.cairo        # All Dojo events
│   │   └── tests/
│   │       ├── test_recipes.cairo
│   │       ├── test_exploration.cairo
│   │       ├── test_crafting.cairo
│   │       └── test_hero.cairo
│   ├── dojo_dev.toml           # Local Katana config
│   ├── dojo_slot.toml          # Slot deployment config
│   └── dojo_sepolia.toml       # Sepolia deployment config
├── client/                     # React frontend
│   ├── package.json
│   ├── vite.config.ts
│   ├── dojo.config.ts
│   ├── src/
│   │   ├── main.tsx            # Provider hierarchy
│   │   ├── App.tsx             # Router + layout
│   │   ├── dojo/
│   │   │   ├── setup.ts        # Dojo SDK init + Torii sync
│   │   │   ├── context.tsx     # DojoProvider
│   │   │   ├── useDojo.tsx     # Hook
│   │   │   ├── contractModels.ts # RECS component definitions
│   │   │   ├── models.ts       # Client model wrappers
│   │   │   ├── systems.ts      # System call wrappers
│   │   │   └── world.ts        # RECS world instance
│   │   ├── cartridgeConnector.tsx # Controller + session policies
│   │   ├── hooks/              # Game-specific hooks
│   │   ├── ui/                 # React components (pure presentational)
│   │   │   ├── TopBar.tsx
│   │   │   ├── HeroPanel.tsx
│   │   │   ├── ExplorationPanel.tsx
│   │   │   ├── CraftPanel.tsx
│   │   │   ├── GrimoirePanel.tsx
│   │   │   ├── InventoryPanel.tsx
│   │   │   └── EventLog.tsx
│   │   └── styles/
│   └── index.html
├── Scarb.toml                  # Workspace root
├── .gitignore
├── PLAN.md                     # This file
└── references/                 # (gitignored) alchemist + zkube codebases
```

---

## 4. Contract Architecture

### 4.1 Models

#### GameSession — Core game state per player session
```cairo
#[dojo::model]
struct GameSession {
    #[key]
    session_id: u64,              // Unique session identifier
    player: ContractAddress,
    seed: felt252,                // VRF seed (set once at game creation)
    discovered_count: u8,         // Recipes discovered (0-30)
    craft_attempts: u16,          // Total craft attempts (for progressive chance)
    hints_used: u8,               // Hints purchased
    gold: u32,                    // Current gold balance
    hero_count: u8,               // Heroes recruited (1-3)
    game_over: bool,              // Win or quit
    started_at: u64,              // Timestamp
}
```

#### GameSeed — VRF seed storage (same pattern as zkube)
```cairo
#[dojo::model]
struct GameSeed {
    #[key]
    session_id: u64,
    seed: felt252,                // Original VRF seed
    vrf_enabled: bool,
}
```

#### Hero — Per-hero state (3 max per session)
```cairo
#[dojo::model]
struct Hero {
    #[key]
    session_id: u64,
    #[key]
    hero_id: u8,                  // 0, 1, 2
    hp: u32,                      // Current HP (x100 fixed-point for regen precision)
    max_hp: u32,                  // Max HP (x100)
    power: u32,                   // Combat power
    regen_per_sec: u32,           // HP regen when idle (x100)
    status: u8,                   // 0=idle, 1=exploring, 2=returning
    expedition_seed: felt252,     // Sub-seed for this expedition
    expedition_start: u64,        // Timestamp when expedition began
    pending_gold: u32,            // Unclaimed gold from last expedition
    loot_ready: bool,             // True when returned with loot
}
```

#### HeroPendingIngredient — Ingredients from an expedition
```cairo
#[dojo::model]
struct HeroPendingIngredient {
    #[key]
    session_id: u64,
    #[key]
    hero_id: u8,
    #[key]
    ingredient_id: u8,            // 0-24 (index into INGREDIENTS array)
    quantity: u16,
}
```

#### Recipe — Per-session recipe (30 per game, generated from seed)
```cairo
#[dojo::model]
struct Recipe {
    #[key]
    session_id: u64,
    #[key]
    recipe_id: u8,                // 0-29
    ingredient_a: u8,             // Ingredient index (0-24), sorted a < b
    ingredient_b: u8,
    effect_type: u8,              // 0=max_hp, 1=power, 2=regen_speed
    effect_value: u8,             // Magnitude of buff
    discovered: bool,
}
```

#### IngredientBalance — Player's ingredient inventory
```cairo
#[dojo::model]
struct IngredientBalance {
    #[key]
    session_id: u64,
    #[key]
    ingredient_id: u8,            // 0-24
    quantity: u16,
}
```

#### PotionInventory — Crafted potions in inventory
```cairo
#[dojo::model]
struct PotionInventory {
    #[key]
    session_id: u64,
    #[key]
    potion_index: u16,            // Auto-incrementing
    recipe_id: u8,
    effect_type: u8,
    effect_value: u8,
}
```

#### FailedCombo — Tracks tried-and-failed ingredient combos
```cairo
#[dojo::model]
struct FailedCombo {
    #[key]
    session_id: u64,
    #[key]
    ingredient_a: u8,             // Sorted: a < b
    #[key]
    ingredient_b: u8,
    failed: bool,                 // Always true (existence = failed)
}
```

#### HintedRecipe — Recipes with a hint purchased
```cairo
#[dojo::model]
struct HintedRecipe {
    #[key]
    session_id: u64,
    #[key]
    recipe_id: u8,
    revealed_ingredient: u8,      // Which ingredient was revealed
}
```

### 4.2 Systems

#### game_system — Lifecycle management
```
create_game(session_id) → Create session, generate VRF seed, generate 30 recipes, spawn hero #0
end_game(session_id)    → Mark game over (surrender)
```

#### exploration_system — Hero expeditions (lazy evaluation)
```
send_expedition(session_id, hero_id)  → Validate hero idle + no pending loot, record start time + sub-seed
claim_loot(session_id, hero_id)       → Compute all exploration events from start_time to now,
                                         resolve HP drain + events + ingredient drops,
                                         determine when hero dies and starts returning,
                                         calculate return timer, transfer loot to pending
```

#### crafting_system — Potion crafting
```
craft(session_id, ingredient_a, ingredient_b)    → Consume ingredients, check recipes, handle discovery/soup
craft_recipe(session_id, recipe_id)              → Re-brew a known recipe (max possible)
buy_hint(session_id)                             → Spend gold, reveal one ingredient of random undiscovered recipe
```

#### hero_system — Hero management
```
recruit_hero(session_id)                                → Spend gold, add hero
apply_potion(session_id, potion_index, hero_id)         → Consume potion, buff hero stats permanently
```

### 4.3 Lazy Evaluation Engine (the hard part)

The core of the on-chain exploration. When `claim_loot` is called:

```
fn resolve_expedition(seed: felt252, hero: Hero, elapsed_seconds: u64) -> ExpeditionResult {
    let mut rng = create_rng(seed);
    let mut hp = hero.hp;
    let mut gold = 0;
    let mut ingredients: Array<(u8, u16)> = array![];
    let mut depth_seconds = 0;

    // Simulate second-by-second
    loop {
        if depth_seconds >= elapsed_seconds { break; }

        let zone = get_zone_at_depth(depth_seconds);

        // HP drain from zone
        hp -= zone.hp_drain_per_sec;  // (zone_index + 1) * 100 in fixed-point
        if hp <= 0 { break; }

        // Roll exploration event
        let roll = rng.next() % 10000;
        if roll < zone.trap_chance {
            hp -= rand_int(ref rng, zone.trap_damage_min, zone.trap_damage_max);
        } else if roll < zone.trap_chance + zone.gold_chance {
            gold += rand_int(ref rng, zone.gold_min, zone.gold_max);
        } else if roll < zone.trap_chance + zone.gold_chance + zone.heal_chance {
            hp = min(hp + rand_int(ref rng, zone.heal_min, zone.heal_max), hero.max_hp);
        } else if roll < zone.trap_chance + zone.gold_chance + zone.heal_chance + zone.beast_chance {
            // Beast encounter
            let beast_power = rand_int(ref rng, zone.beast_power_min, zone.beast_power_max);
            if hero.power >= beast_power {
                let loot = rand_int(ref rng, zone.beast_loot_min, zone.beast_loot_max);
                gold += loot;
                hp -= loot / 5;  // 20% of loot as damage
            } else {
                hp -= rand_int(ref rng, zone.trap_damage_min, zone.trap_damage_max) + beast_power;
            }
        }
        // else: nothing happens

        if hp <= 0 { break; }

        // Independent ingredient drop roll
        let drop_roll = rng.next() % 10000;
        if drop_roll < zone.ingredient_drop_chance {
            let qty = rand_int(ref rng, zone.ingredient_qty_min, zone.ingredient_qty_max);
            let ingredient = zone.ingredients[rng.next() % 5];
            // accumulate ingredient
        }

        depth_seconds += 1;
    };

    // Hero died at depth_seconds → return timer = depth_seconds / 2
    ExpeditionResult { gold, ingredients, death_depth: depth_seconds, hp_at_death: max(0, hp) }
}
```

**Key insight**: The elapsed time since `send_expedition` caps the simulation. If the hero's HP would run out at depth 45s but 120s have elapsed, the hero died at 45s, spent 22.5s returning, and has been idle for 52.5s (regenerating). All computed in one transaction.

**Gas considerations**: Worst case is ~90 seconds of simulation (hero survives to zone S). That's 90 loop iterations with simple math — well within Starknet's step limit.

### 4.4 Events

```cairo
#[dojo::event]
struct GameCreated {
    #[key]
    session_id: u64,
    player: ContractAddress,
    seed: felt252,
}

#[dojo::event]
struct ExpeditionStarted {
    #[key]
    session_id: u64,
    hero_id: u8,
}

#[dojo::event]
struct ExpeditionResolved {
    #[key]
    session_id: u64,
    hero_id: u8,
    death_depth: u32,
    gold_earned: u32,
    ingredients_earned: u8,   // Count of distinct ingredients
}

#[dojo::event]
struct RecipeDiscovered {
    #[key]
    session_id: u64,
    recipe_id: u8,
    player: ContractAddress,
}

#[dojo::event]
struct PotionApplied {
    #[key]
    session_id: u64,
    hero_id: u8,
    effect_type: u8,
    effect_value: u8,
}

#[dojo::event]
struct HeroRecruited {
    #[key]
    session_id: u64,
    hero_id: u8,
    cost: u32,
}

#[dojo::event]
struct GrimoireCompleted {
    #[key]
    session_id: u64,
    player: ContractAddress,
    elapsed_seconds: u64,
}
```

---

## 5. Client Architecture

### 5.1 Provider Hierarchy (following zkube pattern)

```tsx
<StarknetConfig
  chains={[slotChain, sepolia, mainnet]}
  connectors={[cartridgeConnector]}
  provider={jsonRpcProvider({ rpc })}
>
  <DojoProvider value={setupResult}>
    <App />
  </DojoProvider>
</StarknetConfig>
```

### 5.2 Torii Subscriptions

Subscribe to these models in `setup.ts`:
- `athanor-GameSession`
- `athanor-Hero`
- `athanor-Recipe`
- `athanor-IngredientBalance`
- `athanor-PotionInventory`
- `athanor-FailedCombo`
- `athanor-HintedRecipe`

### 5.3 System Calls

```typescript
// Wrapped via handleTransaction (zkube pattern)
systemCalls.createGame({ account, sessionId })
systemCalls.sendExpedition({ account, sessionId, heroId })
systemCalls.claimLoot({ account, sessionId, heroId })
systemCalls.craft({ account, sessionId, ingredientA, ingredientB })
systemCalls.craftRecipe({ account, sessionId, recipeId })
systemCalls.buyHint({ account, sessionId })
systemCalls.recruitHero({ account, sessionId })
systemCalls.applyPotion({ account, sessionId, potionIndex, heroId })
systemCalls.endGame({ account, sessionId })
```

### 5.4 Session Policies

Controller session keys auto-approve these system calls so the player doesn't sign every transaction:
- `exploration_system::send_expedition`
- `exploration_system::claim_loot`
- `crafting_system::craft`
- `crafting_system::craft_recipe`
- `crafting_system::buy_hint`
- `hero_system::recruit_hero`
- `hero_system::apply_potion`

### 5.5 Client-Side Exploration Simulation

While a hero is exploring on-chain (between `send_expedition` and `claim_loot`), the client runs a **client-side simulation** of the exploration for visual feedback:

1. Read `expedition_seed` and `expedition_start` from Torii
2. Run the same `resolve_expedition` logic in TypeScript (deterministic from seed)
3. Animate the hero progressing through zones, show events, HP draining
4. When player clicks "Claim Loot", the on-chain result will match exactly

This gives the same real-time feel as the PoC while the actual state lives on-chain.

---

## 6. Implementation Phases

### Phase 0: Project Scaffolding (Day 1)
- [ ] Initialize Dojo project with `sozo init`
- [ ] Set up Scarb workspace (contracts package)
- [ ] Set up client with Vite + React 19 + TypeScript
- [ ] Configure dojo_dev.toml for local Katana
- [ ] Wire up Dojo SDK, Torii, and Controller connector
- [ ] Deploy empty world to local Katana
- [ ] Verify round-trip: client → Katana → Torii → client

### Phase 1: Core Models + Game Lifecycle (Days 2-3)
- [ ] Define all models in Cairo (GameSession, Hero, Recipe, etc.)
- [ ] Implement `game_system::create_game`:
  - VRF seed generation (pseudo-random on Katana)
  - Recipe generation (port `generateRecipes` from TypeScript)
  - Hero #0 spawning (Alaric, 100 HP, 5 Power, 1 Regen)
- [ ] Implement `game_system::end_game`
- [ ] Write tests for recipe generation determinism
- [ ] Deploy to Katana, verify models in Torii

### Phase 2: Exploration System (Days 4-6)
- [ ] Implement `exploration_system::send_expedition`
- [ ] Port lazy evaluation engine to Cairo:
  - Zone detection from depth
  - Event probability rolls
  - HP drain calculation
  - Beast combat resolution
  - Ingredient drop rolls
- [ ] Implement `exploration_system::claim_loot`
  - Resolve expedition → write pending loot to models
  - Handle return timer + idle regen
- [ ] Write exhaustive tests:
  - Known seed → known expedition outcome
  - Edge cases: immediate death, survive to zone S
  - Gas profiling for worst-case (90s simulation)

### Phase 3: Crafting System (Days 7-8)
- [ ] Implement `crafting_system::craft`
  - Recipe lookup from sorted ingredient pair
  - Discovery vs re-brew vs failed combo
  - Progressive probability for lucky discoveries
  - Soup (1 gold) on failure
- [ ] Implement `crafting_system::craft_recipe` (batch re-brew)
- [ ] Implement `crafting_system::buy_hint`
- [ ] Win condition check: discovered_count == 30
- [ ] Write tests for all crafting paths

### Phase 4: Hero System (Day 9)
- [ ] Implement `hero_system::recruit_hero`
- [ ] Implement `hero_system::apply_potion`
- [ ] Validate stat buff permanence across expeditions
- [ ] Write tests

### Phase 5: Client MVP (Days 10-14)
- [ ] Set up Dojo provider hierarchy + Torii sync
- [ ] Build UI components (port from alchemist PoC, adapt for on-chain):
  - TopBar (gold, grimoire progress, timer)
  - HeroPanel (hero cards, expedition status, claim button)
  - ExplorationPanel (zone progress visualization)
  - CraftPanel (ingredient selector, brew button)
  - GrimoirePanel (discovered recipes, hints, re-brew)
  - InventoryPanel (ingredients by zone, potions)
- [ ] Wire system calls to UI actions
- [ ] Client-side exploration simulation (visual feedback)
- [ ] Session policies for Controller

### Phase 6: Polish + Deploy (Days 15-17)
- [ ] Deploy to Slot for team testing
- [ ] VRF integration on Sepolia
- [ ] Balancing pass (zone difficulty, drop rates, hint costs)
- [ ] Error handling and edge cases
- [ ] Deploy to Sepolia testnet

---

## 7. Open Questions / Decisions Needed

### 7.1 Session Identity
**Options:**
- **A) NFT-based** (zkube pattern): Mint an NFT per game session, game_id = token_id. Enables on-chain game history, tradeable sessions.
- **B) Counter-based**: Simple incrementing session_id. Lighter, no NFT overhead.

**Recommendation**: Start with B (counter-based) for v0.1. Add NFTs in v0.2 if needed for marketplace/history features.

### 7.2 Multiplayer / Competitive Mode
The README says "competitive grimoire race" — how does this work?

**Options:**
- **A) Shared seed races**: N players get the same seed. Same recipes, same RNG for exploration. First to 30 wins. Requires matchmaking.
- **B) Leaderboard**: Each player plays solo. Fastest time to 30 recipes = best rank. Daily/weekly leaderboards.
- **C) Solo first**: Ship solo in v0.1. Add competitive in v0.2.

**Recommendation**: C for v0.1. The core loop needs to be fun solo before adding competitive pressure.

### 7.3 Timing Model for Exploration
**Options:**
- **A) Real-time (block-based)**: Expedition uses actual wall-clock time. More idle-game feel. Hero explores while player does other things.
- **B) Action-based**: Player explicitly "advances" exploration in discrete steps. More strategic, less idle. Each step is a transaction.

**Recommendation**: A (real-time). It matches the PoC design and creates natural downtime for crafting between expeditions. The lazy evaluation pattern handles this cleanly.

### 7.4 Token Economy (v0.2+)
Not in scope for v0.1, but worth noting:
- Should there be an ATHANOR token (like zkube's CUBE)?
- Entry fee for competitive races?
- Ingredient/potion trading between players?

---

## 8. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Lazy eval gas too high for deep expeditions | Can't claim loot | Profile early. Cap at ~90 iterations. Optimize with bit-packing. |
| Recipe generation diverges TS vs Cairo | Client simulation doesn't match on-chain | Extensive cross-language determinism tests with known seeds |
| VRF latency on mainnet | Slow game creation | Use pseudo-random on Slot/Katana, VRF only on Sepolia/Mainnet |
| Session key UX | Player confused by approval flow | Follow zkube's Controller pattern exactly — proven in production |
| Ingredient storage bloat (25 items x N players) | High storage costs | Pack all 25 ingredient quantities into a single felt252 (10 bits each = 250 bits) |

---

## 9. Storage Optimization Notes

### Ingredient Packing
25 ingredients x 10 bits each = 250 bits → fits in one felt252 (252 bits).
```cairo
// Pack all ingredient quantities into one felt252
fn pack_ingredients(quantities: @Array<u16>) -> felt252
fn unpack_ingredient(packed: felt252, ingredient_id: u8) -> u16
```
This replaces 25 separate `IngredientBalance` models with a single field on `GameSession`.

### Recipe Packing
Each recipe: ingredient_a (5 bits) + ingredient_b (5 bits) + effect_type (2 bits) + effect_value (5 bits) + discovered (1 bit) = 18 bits.
30 recipes x 18 bits = 540 bits → 3 felt252 values.

### Hero Packing
3 heroes with all stats could pack into 1-2 felt252 values using zkube's bit-packing pattern.

**Decision**: Start with readable separate models. Optimize to packed fields if storage costs become an issue.

---

## 10. Reference Map

| Athanor Component | Reference File |
|-------------------|---------------|
| VRF/Random | `references/zkube/contracts/src/helpers/random.cairo` |
| Game lifecycle | `references/zkube/contracts/src/systems/game.cairo` |
| Model patterns | `references/zkube/contracts/src/models/game.cairo` |
| Scarb config | `references/zkube/Scarb.toml` |
| Client setup | `references/zkube/client-budokan/src/dojo/setup.ts` |
| Controller config | `references/zkube/client-budokan/src/cartridgeConnector.tsx` |
| System calls | `references/zkube/client-budokan/src/dojo/systems.ts` |
| Game logic (TypeScript) | `references/alchemist/src/game/engine.ts` |
| Recipe generation | `references/alchemist/src/game/recipes.ts` |
| RNG system | `references/alchemist/src/game/rng.ts` |
| Game constants | `references/alchemist/src/game/constants.ts` |
| State types | `references/alchemist/src/game/state.ts` |
| Full game spec | `references/alchemist/Alchemist_POC.md` |
