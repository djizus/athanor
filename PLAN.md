# Athanor v0.1 — Implementation Plan

> Fully on-chain competitive grimoire race on Starknet. Port of Alchemist PoC using the Dojo engine, Cartridge Controller, and Torii indexer. Uses the Provable Games embeddable game standard (game-components). Reference implementations: `references/alchemist/` (game logic) and `references/zkube/` (Dojo architecture).

---

## 1. Game Summary (MVP Scope)

Players send heroes on expeditions through dangerous zones, gather ingredients, craft potions by trial-and-error, and race to discover all recipes in their grimoire.

**Core loop**: Explore → Gather → Craft → Buff heroes → Explore deeper → Discover all 10 recipes.

### MVP Simplifications (v0.1)

| Aspect | Full Game (PoC) | MVP (v0.1) |
|--------|----------------|------------|
| Zones | 5 (D→S) | **3** (Verdant Meadow, Crystal Cavern, Aether Spire) |
| Ingredients per zone | 5 | **3** |
| Total ingredients | 25 | **9** |
| Possible combinations | 325 (25C2) | **36** (9C2) |
| Recipes to discover | 30 | **10** |
| Heroes | 3 | 3 (unchanged) |

### What Changes Going On-Chain

| Aspect | Browser PoC | On-Chain (Athanor) |
|--------|-------------|-------------------|
| State | React useReducer + localStorage | Dojo models on Starknet |
| Exploration | 100ms client tick | **Computed at send_expedition, events emitted** |
| Claim | Instant | **Timer-locked until hero returns** |
| RNG | Mulberry32 (seeded PRNG) | Cartridge VRF (verifiable) |
| Multiplayer | Solo only | Solo with leaderboard ranking (fastest completion) |
| Wallet | None | Cartridge Controller (session keys) |
| Persistence | localStorage | Starknet L2 state |
| Events | In-memory notifications | Dojo events (indexed by Torii) |
| Floats | f64 everywhere | u32 fixed-point (x100) |
| Strings | JavaScript strings | u8 IDs (0-8 for ingredients) |

---

## 2. Exploration Architecture: Compute-at-Send

The browser PoC ticks 10x/sec and simulates exploration in real-time. On-chain, we compute the FULL expedition outcome at `send_expedition` time and emit events for each second of exploration.

### Why Compute at Send (not at Claim)

**The problem**: If we compute at claim time, a player who knows the seed could predict outcomes and choose an optimal claim moment.

**The solution**: Compute everything when the expedition starts. The outcome is committed to chain immediately and can't be manipulated.

### Flow

```
1. Player calls send_expedition(hero_id)
   ├─ Contract generates expedition sub-seed (VRF)
   ├─ Runs FULL simulation: second-by-second events until hero HP = 0
   ├─ Stores result on-chain: death_depth, gold, ingredients, return_at
   ├─ Emits events for every exploration event (trap, gold, heal, beast, drop)
   ├─ Sets hero.status = Exploring
   └─ Sets hero.return_at = now + death_depth + (death_depth / 2)

2. Client reads events from Torii
   ├─ Replays them as animations (zone progress, HP bar, event popups)
   └─ Shows countdown timer until hero returns

3. Player calls claim_loot(hero_id)
   ├─ Contract checks: get_block_timestamp() >= hero.return_at
   ├─ If too early → REVERT ("Hero hasn't returned yet")
   ├─ If ready → Transfer pre-computed loot to player inventory
   └─ Set hero.status = Idle, apply idle regen
```

### Timer Security

| Attack Vector | Defense |
|---------------|---------|
| Call claim_loot early | `assert!(timestamp >= hero.return_at)` — block timestamp set by sequencer, not caller |
| Call contract directly (bypass UI) | Same contract logic applies — timer check is on-chain |
| Predict seed to game expeditions | Outcome committed at send time — can't change it after |
| Manipulate block timestamp | Starknet sequencer sets timestamps — not manipulable by tx submitter |
| Replay/double claim | `hero.status` guard — must be `Idle` to send, `Returning` to claim |

### Gas Considerations

Worst case expedition: hero survives to zone 3 (Aether Spire) = ~90 seconds of simulation. That's 90 loop iterations of simple arithmetic (add, compare, modulo). Well within Starknet's step limit.

---

## 3. Tech Stack

| Layer | Technology | Version | Notes |
|-------|-----------|---------|-------|
| Smart Contracts | Cairo | 2.13.1 | Same as zkube |
| Framework | Dojo | 1.8.0 | ECS: models, systems, events |
| Game Standard | game-components | v2.13.1 | NFT-gated sessions (Provable Games) |
| Frontend | React 19 + TypeScript + Vite | Latest | Same as zkube client |
| Wallet | Cartridge Controller | ^0.13.9 | Session keys for gasless play |
| Indexer | Torii | ^1.8.2 | Real-time state sync via RECS |
| RNG | Cartridge VRF | - | Verifiable randomness |
| Deployment | Slot (dev) → Sepolia → Mainnet | - | Progressive rollout |

### Key Dependencies

**Contracts (Scarb.toml)**:
```toml
dojo = "1.8.0"
starknet = "2.13.1"
origami_random = { git = "dojoengine/origami", tag = "v1.7.0" }
game_components_minigame = { git = "Provable-Games/game-components", tag = "v2.13.1" }
game_components_token = { git = "Provable-Games/game-components", tag = "v2.13.1" }
```

**Client (package.json)**:
```json
"@dojoengine/sdk": "^1.9.0",
"@dojoengine/core": "^1.8.8",
"@dojoengine/react": "^1.8.11",
"@dojoengine/recs": "2.0.13",
"@cartridge/connector": "^0.13.9",
"@cartridge/controller": "^0.13.9",
"@starknet-react/core": "^5.0.1",
"starknet": "8.5.2"
```

---

## 4. User Flow

Following zkube's pattern: landing page → play/resume → leaderboard → profile.

### Page Map

```
home            → Landing page (connect, new game, my games, leaderboard)
play            → Active game screen (heroes, crafting, grimoire, inventory)
mygames         → Resume / game history
leaderboard     → Rankings (fastest grimoire completion)
settings        → Audio, theme, account
profile         → Player stats, best runs
```

### Navigation (Zustand store, zkube pattern)

```typescript
navigationStore: {
  currentPage: "home" | "play" | "mygames" | "leaderboard" | "settings" | "profile",
  gameId: number | null,
  navigate(page, gameId?),
  goBack(),
}
```

### Complete User Journey

```
1. LANDING PAGE (home)
   ├─ If not connected → "Connect" button (Cartridge Controller)
   ├─ If connected:
   │  ├─ "NEW GAME" → freeMint() → create(game_id) → navigate("play", game_id)
   │  ├─ "MY GAMES" → shows active game count badge → navigate("mygames")
   │  ├─ "LEADERBOARD" → navigate("leaderboard")
   │  └─ "SETTINGS" → navigate("settings")
   └─ Top bar: profile, settings, CUBE/gold balance

2. MY GAMES PAGE (mygames)
   ├─ List of owned game NFTs
   ├─ Active games: show heroes status, recipes discovered, "Resume" button
   ├─ Finished games: show final stats, grimoire completion
   └─ Click "Resume" → navigate("play", gameId)

3. GAME SCREEN (play) — Main gameplay
   ├─ LEFT PANEL: Hero cards (HP bar, stats, status, Explore/Claim buttons)
   ├─ CENTER: Exploration feed (events from Torii, animated)
   ├─ RIGHT PANEL: Craft panel + Grimoire + Inventory
   └─ Win: all 10 recipes discovered → Victory overlay

4. LEADERBOARD PAGE
   ├─ Ranked by: fastest grimoire completion time
   ├─ Shows: player name, time, recipes found, heroes used
   └─ Filters: all time / this week / today
```

### Game Creation Flow (matches zkube exactly)

```
User clicks "NEW GAME"
  ↓
freeMint(settingsId=0) on FullTokenContract → ERC721 minted → game_id = token_id
  ↓
create(game_id) on game_system
  ├─ pre_action(token_address, game_id)  // game-components: lock token
  ├─ assert_token_ownership + is_playable check
  ├─ VRF seed generation
  ├─ Generate 10 recipes from seed (deterministic)
  ├─ Spawn Hero #0 (Alaric)
  ├─ Write GameSession, GameSeed, Recipe[0..9], Hero models
  ├─ Emit GameCreated event
  └─ post_action(token_address, game_id)  // game-components: release token
  ↓
Client navigates to play screen
```

---

## 5. Game-Components Integration (Embeddable Game Standard)

Following zkube's exact pattern with Provable Games' game-components library.

### What game-components provides

| Component | Purpose | Used By |
|-----------|---------|---------|
| `MinigameComponent` | Core framework: token registration, metadata | game_system |
| `FullTokenContract` | Soulbound ERC721 NFT for game sessions | External deploy |
| `MinigameRegistryContract` | Registry for minigame tokens | External deploy |
| `SettingsComponent` | Game settings management | config_system |
| `pre_action / post_action` | Token lifecycle hooks (lock/release) | All systems |
| `assert_token_ownership` | Verify caller owns the game NFT | All systems |
| `LifecycleTrait` | Check if token is in playable state | All systems |

### Required Trait Implementations (in our game_system)

```cairo
// 1. Embed MinigameComponent
component!(path: MinigameComponent, storage: minigame, event: MinigameEvent);

// 2. Implement IMinigameTokenData (score + game_over for NFT metadata)
impl GameTokenDataImpl of IMinigameTokenData<ContractState> {
    fn score(self: @ContractState, token_id: u64) -> u32 { ... }
    fn game_over(self: @ContractState, token_id: u64) -> bool { ... }
}

// 3. Initialize in dojo_init
self.minigame.initializer(
    creator_address, "Athanor", "On-chain grimoire race",
    "djizus", "djizus", "Strategy",
    "icon_url", Option::Some("#color"),
    Option::None, Option::Some(renderer_address),
    Option::Some(config_system_address), Option::None,
    denshokan_address,  // FullTokenContract address
);
```

### Every Game Action Wraps with Token Lifecycle

```cairo
fn send_expedition(ref self: ContractState, game_id: u64, hero_id: u8) {
    let token_address = self.token_address();
    pre_action(token_address, game_id);               // Lock token

    let token_metadata = token_dispatcher.token_metadata(game_id);
    assert!(token_metadata.lifecycle.is_playable(get_block_timestamp()));
    assert_token_ownership(token_address, game_id);

    // ... game logic ...

    post_action(token_address, game_id);              // Release token
}
```

---

## 6. Settings System

### Settings Presets (0-5)

| ID | Name | Description | Active |
|----|------|-------------|:------:|
| 0 | Default | Standard balancing, official games | ✅ |
| 1-5 | Reserved | For future game modes / daily challenges | ❌ (v0.2+) |

### GameSettings Model (Athanor-specific)

```cairo
#[dojo::model]
struct GameSettings {
    #[key]
    settings_id: u32,

    // Zone configuration
    zone_count: u8,                    // 3 (MVP)
    ingredients_per_zone: u8,          // 3 (MVP)
    recipes_to_discover: u8,           // 10 (MVP)

    // Hero configuration
    max_heroes: u8,                    // 3
    hero_base_hp: u16,                 // 10000 (x100 fixed-point = 100.00 HP)
    hero_base_power: u16,              // 500 (x100 = 5.00)
    hero_base_regen: u16,              // 100 (x100 = 1.00 HP/s)
    hero_costs: felt252,               // Packed: [0, 8000, 20000] (x100)

    // Crafting
    hint_base_cost: u16,               // 1000 (10 gold)
    hint_cost_multiplier: u8,          // 3
    soup_gold_value: u8,               // 1

    // Progressive discovery
    progressive_cap: u16,              // 8000 (x10000 = 0.80)
}
```

### Initialization (dojo_init)

```cairo
fn dojo_init(ref self: ContractState, creator_address: ContractAddress, ...) {
    // Create only preset 0 (official default)
    world.write_model(@get_default_settings());
    world.write_model(@get_default_settings_metadata(timestamp, creator_address));
    self.settings_counter.write(0);
}
```

Only games using `settings_id = 0` are considered "official" for leaderboard ranking.

---

## 7. Contract Architecture

### 7.1 Project Structure

```
athanor/
├── contracts/
│   ├── Scarb.toml
│   ├── src/
│   │   ├── lib.cairo
│   │   ├── constants.cairo         # Zones, ingredients, probabilities, namespace
│   │   ├── types.cairo             # Enums (HeroStatus, EventKind, EffectType, Zone)
│   │   ├── models/
│   │   │   ├── game.cairo          # GameSession, GameSeed
│   │   │   ├── hero.cairo          # Hero, HeroPendingIngredient
│   │   │   ├── recipe.cairo        # Recipe (10 per session)
│   │   │   ├── inventory.cairo     # Inventory (packed ingredients), PotionItem
│   │   │   ├── crafting.cairo      # FailedCombo, HintedRecipe
│   │   │   ├── config.cairo        # GameSettings, GameSettingsMetadata
│   │   │   └── player.cairo        # PlayerMeta (persistent across games)
│   │   ├── systems/
│   │   │   ├── game.cairo          # create, surrender + MinigameComponent
│   │   │   ├── exploration.cairo   # send_expedition (VRF + compute + emit), claim_loot (timer + transfer)
│   │   │   ├── crafting.cairo      # craft, craft_recipe, buy_hint (VRF)
│   │   │   ├── hero.cairo          # recruit_hero, apply_potion
│   │   │   ├── config.cairo        # GameSettings + IMinigameSettings
│   │   │   └── renderer.cairo      # IMinigameDetails, IMinigameDetailsSVG
│   │   ├── helpers/
│   │   │   ├── random.cairo        # VRF wrapper (from zkube)
│   │   │   ├── recipes.cairo       # Deterministic 10-recipe generation
│   │   │   ├── exploration.cairo   # Full expedition simulation engine
│   │   │   └── math.cairo          # Fixed-point helpers
│   │   ├── events.cairo            # All Dojo events
│   │   └── tests/
│   └── Scarb.toml
├── client/
│   ├── package.json
│   ├── vite.config.ts
│   ├── dojo.config.ts
│   ├── src/
│   │   ├── main.tsx                # Provider hierarchy (StarknetConfig → DojoProvider)
│   │   ├── App.tsx                 # Page router
│   │   ├── cartridgeConnector.tsx  # Controller + session policies from manifest
│   │   ├── stores/
│   │   │   └── navigationStore.ts  # Page navigation (zustand)
│   │   ├── dojo/
│   │   │   ├── setup.ts            # Dojo SDK init + Torii sync
│   │   │   ├── context.tsx         # DojoProvider
│   │   │   ├── useDojo.tsx
│   │   │   ├── contractModels.ts   # RECS definitions
│   │   │   ├── systems.ts          # System call wrappers
│   │   │   └── world.ts            # RECS world instance
│   │   ├── hooks/
│   │   │   ├── useGame.tsx         # Fetch game state + entity ID normalization
│   │   │   ├── useGameTokens.tsx   # Owned game NFTs (active/finished)
│   │   │   └── useSettings.tsx     # GameSettings from RECS
│   │   ├── ui/
│   │   │   ├── pages/
│   │   │   │   ├── HomePage.tsx
│   │   │   │   ├── PlayScreen.tsx
│   │   │   │   ├── MyGamesPage.tsx
│   │   │   │   ├── LeaderboardPage.tsx
│   │   │   │   └── SettingsPage.tsx
│   │   │   ├── components/         # Reusable UI components
│   │   │   └── navigation/
│   │   │       ├── TopBar.tsx
│   │   │       └── PageNavigator.tsx  # Slide transitions
│   │   └── styles/
│   └── index.html
├── Scarb.toml                      # Workspace root
├── dojo_dev.toml                   # Local Katana config
├── dojo_slot.toml                  # Slot deployment config
├── .gitignore
├── PLAN.md
└── references/                     # (gitignored)
```

### 7.2 Models

#### GameSession
```cairo
#[dojo::model]
struct GameSession {
    #[key]
    game_id: u64,                     // = NFT token_id (game-components pattern)
    player: ContractAddress,
    seed: felt252,                    // VRF seed (set once)
    settings_id: u32,                 // Always 0 for v0.1
    discovered_count: u8,             // 0-10
    craft_attempts: u16,
    hints_used: u8,
    gold: u32,
    hero_count: u8,                   // 1-3
    potion_count: u16,                // Auto-incrementing potion index
    game_over: bool,
    started_at: u64,
}
```

#### Hero
```cairo
#[dojo::model]
struct Hero {
    #[key]
    game_id: u64,
    #[key]
    hero_id: u8,                      // 0, 1, 2
    hp: u16,                          // x100 fixed-point (10000 = 100.00 HP)
    max_hp: u16,
    power: u16,                       // x100
    regen_per_sec: u16,               // x100
    status: u8,                       // 0=Idle, 1=Exploring, 2=Returning
    // Expedition result (computed at send_expedition)
    expedition_seed: felt252,
    expedition_start: u64,            // Timestamp
    return_at: u64,                   // Timestamp when hero is back with loot
    death_depth: u16,                 // Seconds explored (max 300)
    // Pre-computed loot
    pending_gold: u32,
}
```

#### HeroPendingIngredient — Loot from expedition
```cairo
#[dojo::model]
struct HeroPendingIngredient {
    #[key]
    game_id: u64,
    #[key]
    hero_id: u8,
    #[key]
    ingredient_id: u8,                // 0-8
    quantity: u16,
}
```

#### Recipe — 10 per game, generated from seed
```cairo
#[dojo::model]
struct Recipe {
    #[key]
    game_id: u64,
    #[key]
    recipe_id: u8,                    // 0-9
    ingredient_a: u8,                 // 0-8 (sorted: a < b)
    ingredient_b: u8,
    effect_type: u8,                  // 0=max_hp, 1=power, 2=regen
    effect_value: u8,
    discovered: bool,
}
```

#### IngredientBalance — Player's inventory (could pack all 9 into one felt252)
```cairo
#[dojo::model]
struct IngredientBalance {
    #[key]
    game_id: u64,
    #[key]
    ingredient_id: u8,                // 0-8
    quantity: u16,
}
```

#### PotionItem — Crafted potions in inventory
```cairo
#[dojo::model]
struct PotionItem {
    #[key]
    game_id: u64,
    #[key]
    potion_index: u16,
    recipe_id: u8,
    effect_type: u8,
    effect_value: u8,
}
```

#### FailedCombo — Tried and failed combos
```cairo
#[dojo::model]
struct FailedCombo {
    #[key]
    game_id: u64,
    #[key]
    combo_key: u16,                   // ingredient_a * 9 + ingredient_b (unique per pair)
    attempted: bool,                  // Dojo requires at least one non-key member
}
```

#### PlayerMeta — Persistent across games
```cairo
#[dojo::model]
struct PlayerMeta {
    #[key]
    player: ContractAddress,
    total_games: u32,
    best_time: u64,                   // Fastest grimoire completion (seconds)
    total_recipes_discovered: u32,
}
```

### 7.3 Systems

#### game_system — Lifecycle (embeds MinigameComponent)

```
create(game_id)     → pre_action, VRF seed, generate 10 recipes, spawn hero #0, post_action
surrender(game_id)  → pre_action, set game_over, update PlayerMeta, post_action
```

#### exploration_system — Expedition compute + claim

```
send_expedition(game_id, hero_id)
  → pre_action
  → Validate: hero idle, HP > 0
  → Generate expedition seed via VRF (unique salt = poseidon(game_id, hero_id, timestamp))
  → Run full simulation (loop until HP=0 or max_depth=300):
      for each second:
        zone = get_zone(depth)
        hp -= zone.drain
        roll event (trap/gold/heal/beast/nothing)
        roll ingredient drop
        emit ExplorationEvent for each event
  → Store: death_depth, pending_gold, pending ingredients, return_at, remaining_hp
  → Set hero.status = Exploring, hero.hp = remaining_hp (0 if died, >0 if survived)
  → post_action

claim_loot(game_id, hero_id)
  → pre_action
  → Validate: get_block_timestamp() >= hero.return_at (allowed even if game_over)
  → If too early → REVERT ("Hero hasn't returned yet")
  → If ready → Transfer pre-computed loot to player inventory
  → Apply idle regen: (rest_time * regen_per_sec) + existing_hp, capped at max_hp
  → Set hero.status = Idle
  → post_action
```
send_expedition(game_id, hero_id)
  → pre_action
  → Validate: hero idle, no pending loot, HP > 0
  → Generate expedition sub-seed
  → Run full simulation (loop until HP=0):
      for each second:
        zone = get_zone(depth)
        hp -= zone.drain
        roll event (trap/gold/heal/beast/nothing)
        roll ingredient drop
        emit ExplorationEvent for each event
  → Store: death_depth, pending_gold, pending ingredients, return_at
  → Set hero.status = Exploring
  → post_action

claim_loot(game_id, hero_id)
  → pre_action
  → Validate: get_block_timestamp() >= hero.return_at
  → Transfer pending_gold → session.gold
  → Transfer pending ingredients → IngredientBalance
  → Apply idle regen: elapsed_since_return * regen_per_sec
  → Set hero.status = Idle
  → post_action
```

#### crafting_system

```
craft(game_id, ingredient_a, ingredient_b)
  → Consume ingredients, check recipe match
  → If match: mark discovered, create PotionItem, emit RecipeDiscovered
  → If no match: record FailedCombo, roll progressive luck, or +1 gold soup

craft_recipe(game_id, recipe_id)
  → Re-brew known recipe (max possible from inventory)

buy_hint(game_id)
  → Spend gold (10 * 3^n), VRF-seeded selection of random undiscovered recipe, reveal one ingredient
```

#### hero_system

```
recruit_hero(game_id)    → Spend gold [0, 80, 200], add hero
apply_potion(game_id, potion_index, hero_id)  → Consume potion, permanent stat buff
```

#### config_system — Settings (embeds SettingsComponent)

```
dojo_init()              → Create preset 0 (default)
add_game_settings()      → Create custom preset (future)
get_game_settings()      → Read settings by ID
```

### 7.4 Events (emitted, indexed by Torii)

```cairo
// Exploration events (emitted per-second during send_expedition)
#[dojo::event]
struct ExplorationEvent {
    #[key] game_id: u64,
    #[key] event_index: u16,         // Sequential within expedition
    hero_id: u8,
    depth: u16,                       // Second of exploration
    zone_id: u8,                      // 0, 1, 2
    event_kind: u8,                   // 0=nothing, 1=trap, 2=gold, 3=heal, 4=beast_win, 5=beast_lose, 6=ingredient
    value: u16,                       // Damage, gold, heal amount, ingredient_id, etc.
    hp_after: u16,                    // Hero HP after event (x100)
}

// Lifecycle events
#[dojo::event]
struct GameCreated { ... }

#[dojo::event]
struct ExpeditionStarted {
    #[key] game_id: u64,
    hero_id: u8,
    death_depth: u16,
    return_at: u64,
}

#[dojo::event]
struct LootClaimed { ... }

#[dojo::event]
struct RecipeDiscovered { ... }

#[dojo::event]
struct PotionApplied { ... }

#[dojo::event]
struct HeroRecruited { ... }

#[dojo::event]
struct GrimoireCompleted {
    #[key] game_id: u64,
    player: ContractAddress,
    completion_time: u64,             // Seconds from game start
}
```

### 7.5 MVP Constants

```cairo
// Zones (3 for MVP)
const ZONE_COUNT: u8 = 3;
const INGREDIENTS_PER_ZONE: u8 = 3;
const TOTAL_INGREDIENTS: u8 = 9;    // 3 * 3

// Zone 0: Verdant Meadow — depth 0s, drain 1 HP/s
//   Ingredients: Moonpetal (0), Dewmoss (1), River Clay (2)
// Zone 1: Crystal Cavern — depth 20s, drain 2 HP/s
//   Ingredients: Crystal Shard (3), Drake Moss (4), Sulfur Bloom (5)
// Zone 2: Aether Spire — depth 45s, drain 3 HP/s
//   Ingredients: Dragon Scale (6), Aether Core (7), Titan Blood (8)

// Recipes
const RECIPES_TO_DISCOVER: u8 = 10;

// Heroes
const MAX_HEROES: u8 = 3;
const HERO_BASE_HP: u16 = 10000;     // 100.00 HP (x100)
const HERO_BASE_POWER: u16 = 500;    // 5.00 (x100)
const HERO_BASE_REGEN: u16 = 100;    // 1.00 HP/s (x100)

// Event probabilities (x10000)
//                     Zone 0    Zone 1    Zone 2
// Trap:               500       1000      1400
// Gold:               1000      700       500
// Heal:               800       500       300
// Beast:              300       700       1200
// Nothing:            7400      7100      6600
// Ingredient drop:    2500      1800      1200
```

---

## 8. Implementation Phases

### Phase 0: Project Scaffolding ✅
- [x] Scarb workspace with game-components v2.13.1, dojo 1.8.0, origami_random
- [x] All models defined (GameSession, GameSeed, Hero, HeroPendingIngredient, Recipe, IngredientBalance, PotionItem, FailedCombo, GameSettings, GameSettingsMetadata, PlayerMeta)
- [x] All events defined (8 Dojo events)
- [x] dojo_dev.toml for local Katana
- [ ] Set up client with Vite + React 19 + TypeScript
- [ ] Wire Dojo SDK, Torii, Controller connector
- [ ] Deploy empty world to local Katana
- [ ] Verify round-trip: client → Katana → Torii → client

### Phase 1: Game Lifecycle + MinigameComponent ✅
- [x] Integrate MinigameComponent into game_system (dojo_init, IMinigameTokenData)
- [x] Config system with preset 0 (GameSettings defaults in dojo_init)
- [x] VRF random helper (from_vrf_address + pseudo-random fallback)
- [x] Recipe generation (Phase 1: 3 pinned per zone, Phase 2: 7 random cross-zone biased)
- [x] Full create() flow: pre_action → seed → recipes → hero #0 → PlayerMeta → post_action
- [x] Full surrender() flow: pre_action → game_over → post_action
- [ ] Tests: recipe determinism, game creation, config init

### Phase 2: Exploration System ✅
- [x] Expedition simulation engine (helpers/exploration.cairo) — tick-by-tick, 3 zones, events + drops
- [x] send_expedition: full compute + event emission + pending loot storage
- [x] claim_loot: timer check + gold/ingredient transfer + idle regen
- [x] Idle regen calculation (rest_time * regen_per_sec, capped at max_hp)
- [ ] Tests: known seed → known outcome, timer enforcement, gas profiling

### Phase 3: Crafting System ✅
- [x] craft: recipe lookup, discovery, PotionItem creation, FailedCombo recording, soup gold
- [x] craft_recipe: batch re-brew (max possible from inventory)
- [x] buy_hint: exponential cost (10 * 3^n gold), random undiscovered recipe, partial reveal
- [x] Win condition: discovered_count >= 10 → game_over + GrimoireCompleted event
- [ ] Tests: all crafting paths

### Phase 4: Hero System ✅
- [x] recruit_hero: gold cost [0, 80, 200], base stats spawn
- [x] apply_potion: permanent stat buff (max_hp +val×100, power +val×100, regen +val×10)
- [ ] Tests

### Phase 4.5: Architecture Refactor (nums patterns) ✅

Adopt Store pattern, centralized Config, model assertions, and event constructors from the
`references/nums/` codebase. **NOT adopting** full component architecture — Athanor's systems
are independent enough that thin components add complexity without payoff.

**Goal**: Eliminate raw `world.read_model()`/`world.write_model()` calls from systems, centralize
external addresses, DRY up validation, and make events self-constructing.

#### Step 1: Config model (foundation)

Add a singleton `Config` model to store external addresses. Currently `token_address` and
`vrf_address` are duplicated across 4 systems' Storage + dojo_init.

**File: `models/config.cairo`** — Add:
```cairo
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Config {
    #[key]
    pub key: felt252,                   // singleton, always 0
    pub token_address: ContractAddress,
    pub vrf_address: ContractAddress,
}
```

**File: `systems/game.cairo`** — In `dojo_init`, write Config:
```cairo
world.write_model(@Config { key: 0, token_address: denshokan_address, vrf_address });
```

**Other systems** — Remove `token_address` / `vrf_address` from Storage and dojo_init.
Read via Store instead.

- [x] Add Config model to models/config.cairo
- [x] Write Config in game_system.dojo_init
- [x] Remove token_address/vrf_address from exploration_system, crafting_system, hero_system Storage
- [x] Remove their dojo_init functions (no longer needed)

#### Step 2: Store abstraction

**New file: `store.cairo`** — Wraps WorldStorage with typed accessors.

```cairo
#[derive(Copy, Drop)]
pub struct Store {
    world: WorldStorage,
}

#[generate_trait]
pub impl StoreImpl of StoreTrait {
    fn new(world: WorldStorage) -> Store { Store { world } }

    // --- Config ---
    fn config(self: @Store) -> Config { self.world.read_model(0) }

    // --- Dispatchers (from Config) ---
    fn token_disp(self: @Store) -> IMinigameTokenDispatcher { ... }
    fn vrf_disp(self: @Store) -> IVrfProviderDispatcher { ... }

    // --- Model getters ---
    fn session(self: @Store, game_id: u64) -> GameSession { ... }
    fn hero(self: @Store, game_id: u64, hero_id: u8) -> Hero { ... }
    fn recipe(self: @Store, game_id: u64, recipe_id: u8) -> Recipe { ... }
    fn ingredient(self: @Store, game_id: u64, ingredient_id: u8) -> IngredientBalance { ... }
    fn potion(self: @Store, game_id: u64, potion_index: u16) -> PotionItem { ... }
    fn failed_combo(self: @Store, game_id: u64, combo_key: u16) -> FailedCombo { ... }
    fn pending_ingredient(self: @Store, game_id: u64, hero_id: u8, ing_id: u8) -> HeroPendingIngredient { ... }
    fn player(self: @Store, addr: ContractAddress) -> PlayerMeta { ... }
    fn settings(self: @Store, settings_id: u32) -> GameSettings { ... }

    // --- Model setters ---
    fn set_session(mut self: Store, model: @GameSession) { ... }
    fn set_hero(mut self: Store, model: @Hero) { ... }
    fn set_recipe(mut self: Store, model: @Recipe) { ... }
    // ... etc for all models

    // --- Event emitters ---
    fn emit_game_created(mut self: Store, game_id: u64, player: ContractAddress, ...) { ... }
    fn emit_expedition_started(mut self: Store, ...) { ... }
    fn emit_exploration_event(mut self: Store, ...) { ... }
    fn emit_loot_claimed(mut self: Store, ...) { ... }
    fn emit_recipe_discovered(mut self: Store, ...) { ... }
    fn emit_potion_applied(mut self: Store, ...) { ... }
    fn emit_hero_recruited(mut self: Store, ...) { ... }
    fn emit_grimoire_completed(mut self: Store, ...) { ... }
}
```

- [x] Create store.cairo with Store struct
- [x] Add typed getters for all 11 models
- [x] Add typed setters for all 11 models
- [x] Add dispatcher getters (token, vrf) reading from Config
- [x] Add event emission methods for all 8 events
- [x] Export from lib.cairo

#### Step 3: Event constructors

Split `events.cairo` into individual files with `new()` constructors that auto-populate
`time` fields where applicable.

**New structure:**
```
events/
├── index.cairo        # All event struct definitions (#[dojo::event])
├── exploration.cairo  # ExplorationEvent + ExpeditionStarted constructors
├── game.cairo         # GameCreated + GrimoireCompleted constructors
├── crafting.cairo      # RecipeDiscovered constructors
├── hero.cairo         # HeroRecruited + PotionApplied constructors
└── loot.cairo         # LootClaimed constructor
```

Each constructor file follows the pattern:
```cairo
pub use crate::events::index::GameCreated;

#[generate_trait]
pub impl GameCreatedImpl of GameCreatedTrait {
    fn new(game_id: u64, player: ContractAddress, settings_id: u32, seed: felt252) -> GameCreated {
        GameCreated { game_id, player, settings_id, seed }
    }
}
```

- [x] Create events/index.cairo (move struct definitions from events.cairo)
- [x] Create constructor files for each event group
- [x] Delete old events.cairo
- [x] Update lib.cairo module tree
- [x] Update Store event methods to use constructors

#### Step 4: Model assertions

Add `AssertTrait` implementations to key models. Extracts repeated inline assertions
into reusable, self-documenting methods.

**File: `models/game.cairo`** — Add:
```cairo
pub mod errors {
    pub const GAME_OVER: felt252 = 'Game is over';
    pub const GAME_NOT_OVER: felt252 = 'Game not over';
}

#[generate_trait]
pub impl GameSessionAssert of GameSessionAssertTrait {
    fn assert_not_over(self: @GameSession) { assert!(!*self.game_over, "Game is over"); }
    fn assert_is_playing(self: @GameSession) { assert!(!*self.game_over, "Game is over"); }
}
```

**File: `models/hero.cairo`** — Add:
```cairo
#[generate_trait]
pub impl HeroAssert of HeroAssertTrait {
    fn assert_idle(self: @Hero) { assert!(*self.status == types::HERO_STATUS_IDLE, "Hero not idle"); }
    fn assert_exploring(self: @Hero) { assert!(*self.status == types::HERO_STATUS_EXPLORING, "Hero not on expedition"); }
    fn assert_alive(self: @Hero) { assert!(*self.hp > 0, "Hero has no HP"); }
    fn assert_recruited(self: @Hero, session: @GameSession) {
        assert!(*self.hero_id < *session.hero_count, "Hero not recruited");
    }
}
```

- [x] Add GameSessionAssert to models/game.cairo
- [x] Add HeroAssert to models/hero.cairo
- [x] Replace inline assertions in systems with trait method calls

#### Step 5: Model logic traits

Move repeated logic from systems into model trait methods. Makes models "smart" and
systems thin.

**File: `models/hero.cairo`** — Add `HeroTrait`:
```cairo
#[generate_trait]
pub impl HeroImpl of HeroTrait {
    fn new(game_id: u64, hero_id: u8) -> Hero { ... }  // Base stats from constants
    fn apply_buff(ref self: Hero, effect_type: u8, effect_value: u8) { ... }
    fn idle_regen(ref self: Hero, rest_time: u64) { ... }  // Regen + cap
    fn start_expedition(ref self: Hero, seed: felt252, timestamp: u64, result: @ExpeditionResult) { ... }
    fn complete_expedition(ref self: Hero) { ... }  // Reset expedition fields
}
```

**File: `models/game.cairo`** — Add `GameSessionTrait`:
```cairo
#[generate_trait]
pub impl GameSessionImpl of GameSessionTrait {
    fn new(game_id: u64, player: ContractAddress, seed: felt252, timestamp: u64) -> GameSession { ... }
}
```

- [x] Add HeroTrait to models/hero.cairo (new, apply_buff, idle_regen, complete_expedition)
- [x] Add GameSessionTrait to models/game.cairo (new)
- [x] Update systems to use model methods

#### Step 6: System migration

Rewrite each system to use Store. This is the largest step but mechanical — replace
`world.read_model()` → `store.session()`, `world.write_model()` → `store.set_session()`,
`world.emit_event()` → `store.emit_*()`.

**For each system:**
1. Replace `let mut world = self.world(@DEFAULT_NS())` → `let mut store = StoreImpl::new(self.world(@DEFAULT_NS()))`
2. Replace model reads → store getters
3. Replace model writes → store setters
4. Replace event emissions → store event methods
5. Replace inline assertions → model assert trait calls
6. Replace inline logic → model trait method calls
7. Read token_address/vrf_address from Store config instead of self.storage

**Systems to migrate (in order):**
- [x] game_system (MinigameComponent kept, Storage reduced to component-only, reads Config via Store)
- [x] exploration_system (Storage removed entirely, reads Config via Store)
- [x] crafting_system (Storage removed entirely, reads Config via Store)
- [x] hero_system (Storage removed entirely, reads Config via Store)
- [x] config_system (SettingsComponent kept, uses Store for model access)

#### Step 7: Module tree + cleanup

**Update `lib.cairo`:**
```cairo
pub mod constants;
pub mod types;
pub mod store;

pub mod events {
    pub mod index;
    pub mod exploration;
    pub mod game;
    pub mod crafting;
    pub mod hero;
    pub mod loot;
}

pub mod models { ... }  // unchanged
pub mod helpers { ... }  // unchanged
pub mod interfaces { ... }  // unchanged
pub mod systems { ... }  // unchanged
```

- [x] Update lib.cairo (events/ module tree, store module)
- [x] Remove dead imports (zero warnings from our code)
- [x] `sozo build` passes clean
- [x] Update PLAN.md decision 9.4 + 9.5 (architecture decisions documented)

#### Verification

After each step, run `sozo build` to verify. The refactor is purely structural —
no behavioral changes. Every system call produces identical state transitions.

### Phase 5: Client MVP
- [ ] Dojo setup, Torii sync, Controller connector
- [ ] Navigation store (zustand) + page transitions
- [ ] HomePage: connect, new game, my games, leaderboard
- [ ] PlayScreen: hero panel, exploration feed (from events), craft panel, grimoire, inventory
- [ ] MyGamesPage: active/finished games list
- [ ] LeaderboardPage: fastest completion times
- [ ] SettingsPage: basic settings
- [ ] Session policies for Controller

### Phase 6: Polish + Deploy
- [ ] Deploy to Slot for testing
- [ ] VRF integration on Sepolia
- [ ] Balancing pass
- [ ] Error handling + edge cases
- [ ] Deploy to Sepolia testnet

---

## 9. Resolved Decisions

### 9.1 Session Identity — NFT-based (soulbound)

Each game session mints a soulbound NFT via `FullTokenContract.free_mint()`. `game_id = token_id`. The NFT is non-transferable — it represents a player's game history on-chain, not a tradeable asset. Follows the zkube pattern exactly.

### 9.2 Competitive Mode — Leaderboard

Solo play only. Each player races to complete their grimoire independently. Ranked by:
1. **Time to completion** — fastest grimoire completion wins
2. **Tiebreaker** — on-chain timestamp (first submission stays first)

Leaderboard periods: all-time / weekly / daily. Only games using `settings_id = 0` are leaderboard-eligible.

For full game (v1.0+): 30 recipes to discover. For MVP (v0.1): 10 recipes, same ranking logic.

### 9.3 Exploration Timing — Real-time (block-based)

Expeditions use actual wall-clock time via Starknet block timestamps. Hero explores while the player crafts, manages other heroes, or goes AFK. This gives the intended idle-game feel. The `return_at` timestamp is enforced on-chain; `claim_loot` reverts until the hero has returned.

### 9.4 VRF Per Action — Expedition + Hint

Cartridge VRF is called per expedition start and per hint purchase (not just at game creation). This prevents players from predicting expedition outcomes or hint targets by reading the on-chain game seed.

**Pattern** (matches zkube's per-level-transition VRF):
- Salt = `poseidon(game_id, hero_id, timestamp)` for expeditions
- Salt = `poseidon(game_id, hints_used, timestamp)` for hints
- `from_vrf_address(vrf_addr, salt)` abstracts VRF vs pseudo-random fallback (zero address = dev mode)
- `vrf_address` stored in centralized Config model, read via Store (not per-system Storage)

### 9.5 Architecture — Store Pattern (not Components)

Adopting the nums Store pattern: a `Store` struct wraps `WorldStorage` and provides typed
accessors for all models, dispatcher getters from centralized Config, and event emission helpers.

**NOT** adopting nums' full component architecture (`#[starknet::component]`). Reasons:
- Athanor's systems are independent (no cross-system quest/achievement dependencies)
- Component architecture adds indirection without payoff at this codebase size (~1200 LOC)
- The Store pattern alone gives 80% of the cleanup for 20% of the effort
- Can migrate to components later if cross-cutting concerns emerge (e.g., achievements)

The key architectural changes:
1. **Store** — All world access goes through `Store` (reads, writes, events)
2. **Config model** — Single source of truth for `token_address` + `vrf_address`
3. **Model assertions** — `GameSessionAssert`, `HeroAssert` traits on model files
4. **Model logic** — `HeroTrait`, `GameSessionTrait` for repeated operations
5. **Event constructors** — Each event gets a `new()` constructor in its own file

### 9.6 Token Economy — None

No ATHANOR token for v0.1. No entry fees, no ingredient/potion trading. Gold is an in-game-only resource scoped to each game session. Revisit for v0.2+ if competitive modes need staking or prize pools.

---

## 10. Reference Map

| Athanor Component | Reference File |
|-------------------|---------------|
| MinigameComponent setup | `references/zkube/contracts/src/systems/game.cairo` |
| pre_action/post_action | `references/zkube/contracts/src/systems/moves.cairo` |
| VRF/Random | `references/zkube/contracts/src/helpers/random.cairo` |
| Config system + settings | `references/zkube/contracts/src/systems/config.cairo` |
| Default settings init | `references/zkube/contracts/src/constants.cairo` |
| Settings model | `references/zkube/contracts/src/models/config.cairo` |
| Client Dojo setup | `references/zkube/client-budokan/src/dojo/setup.ts` |
| Controller config | `references/zkube/client-budokan/src/cartridgeConnector.tsx` |
| Navigation store | `references/zkube/client-budokan/src/stores/navigationStore.ts` |
| System calls | `references/zkube/client-budokan/src/dojo/systems.ts` |
| Entity ID normalization | `references/zkube/client-budokan/src/hooks/useGame.tsx` |
| Page structure | `references/zkube/client-budokan/src/App.tsx` |
| Landing page | `references/zkube/client-budokan/src/ui/pages/HomePage.tsx` |
| Game logic (TypeScript) | `references/alchemist/src/game/engine.ts` |
| Recipe generation | `references/alchemist/src/game/recipes.ts` |
| RNG system | `references/alchemist/src/game/rng.ts` |
| Game constants | `references/alchemist/src/game/constants.ts` |
| Full game spec | `references/alchemist/Alchemist_POC.md` |
