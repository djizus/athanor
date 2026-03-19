# Athanor

**Fully onchain competitive grimoire race on Starknet.**

Athanor is a strategy RPG where players send heroes on expeditions through dangerous alchemical zones, gather rare ingredients, craft potions by trial-and-error, and race to discover all 30 recipes in their grimoire. Every action — exploration, crafting, buffing, recruiting — happens onchain with verifiable randomness.

Named after the *athanor*, the self-feeding philosophical furnace of medieval alchemy used in the pursuit of the Philosopher's Stone. The blockchain is the eternal fire; your grimoire is the Great Work.

---

## Game Design

### Core Loop

```
Explore → Gather → Craft → Buff Heroes → Explore Deeper → Complete Grimoire
```

Players manage a party of up to 3 heroes, each with distinct roles and stats. Heroes venture into progressively harder zones, returning with gold and ingredients. Ingredients are combined in pairs to discover potion recipes — some combinations yield powerful effects, others produce worthless soup. The first player to discover all 30 recipes wins.

### Heroes

Three hero classes, each randomly assigned on recruitment:

| Role | HP | Power | Regen | Playstyle |
|------|----|-------|-------|-----------|
| **Mage** | 50 | 20 | 2/s | Glass cannon — high power mitigates traps and beasts, but low HP limits expedition depth |
| **Rogue** | 100 | 5 | 10/s | Sustain — fast regeneration between expeditions, balanced survivability |
| **Warrior** | 150 | 5 | 4/s | Tank — deep exploration runs with high HP pool, slow to recover |

- First hero is free. Second costs 80 gold. Third costs 200 gold.
- Heroes regenerate HP passively while idle (regen per second, capped at max HP).
- Potions permanently buff hero stats (max HP, power, or regen).

### Zones

Five alchemical zones of escalating danger. Each zone has a unique set of 5 ingredients and distinct encounter probabilities:

| Zone | Drain | Traps | Beasts | Ingredients |
|------|-------|-------|--------|-------------|
| **Amber Hollows** | 1 HP/s | Low | Rare | Amber Sap, Copper Dust, Fog Essence, Iron Filing, Moonpetal |
| **Ember Cavern** | 2 HP/s | Medium | Uncommon | Nightberry, Crystal Shard, Drake Moss, Sulfur Bloom, Dragon Scale |
| **Aether Spire** | 3 HP/s | High | Common | Aether Core, Titan Blood, Void Salt, Aether Bloom, Star Dust |
| **Sunken Abyss** | 4 HP/s | Very High | Frequent | Cave Pearl, River Clay, Echo Moss, Dripstone, Starfall |
| **Crystalveil Reach** | 5 HP/s | Extreme | Dangerous | Echoleaf, Crystalbloom, Feather, Frostbloom, Gemstone |

During each tick of an expedition, heroes may encounter:
- **Traps** — damage mitigated by hero power
- **Gold** — currency for recruiting heroes and buying hints
- **Healing** — restores HP mid-expedition
- **Beasts** — win (loot gold) or lose (take damage), based on power vs beast strength
- **Ingredient drops** — zone-specific materials for crafting

### Crafting

Combine any two different ingredients to attempt a recipe:

- **Discovery** — if the pair matches an undiscovered recipe, you learn a potion effect and add it to your grimoire. The probability of discovery depends on how many untried combinations remain for those ingredients.
- **Soup** — if no recipe matches, you earn 1 gold consolation and the failed combination is recorded.
- **Hints** — spend gold (exponentially increasing cost: 10 × 3^n) to reveal which ingredient is used in a random undiscovered recipe.
- **Batch crafting** — re-brew known recipes in bulk to stockpile potions for hero buffs.

### Potion Effects

30 distinct potion effects across three stat categories:

| Category | Effects | Buff Range |
|----------|---------|------------|
| **Health** | Blue, Green, Red, Yellow, Purple, Orange, Pink, Brown, Gray, Black | +5 to +20 max HP per potion |
| **Power** | White, Cyan, Magenta, Lime, Teal, Maroon, Navy, Indigo, Violet, Gold | +1 to +5 power per potion |
| **Regen** | Silver, Copper, Mauve, Ruby, Sapphire, Emerald, Diamond, Amethyst, Topaz, Aquamarine | +1 to +3 regen/s per potion |

### Win Condition

Discover all 30 recipes in your grimoire. Ranked by fastest completion time on the leaderboard. Only games using the official default settings (settings ID 0) are leaderboard-eligible.

---

## Architecture

### Compute-at-Send Exploration

Unlike traditional idle games that simulate in real-time, Athanor computes the **entire expedition outcome at transaction time**:

1. Player calls `explore(game_id, character_id, zone_id)`
2. Contract generates a VRF-seeded random sequence
3. Full tick-by-tick simulation runs onchain (up to 30 ticks per expedition)
4. Results are committed: death depth, gold earned, ingredients found, return timestamp
5. Events are emitted for every encounter (indexed by Torii for client replay)
6. Hero becomes available after a time delay proportional to exploration depth

This design prevents outcome manipulation — once submitted, the expedition result is immutable. The client replays events as animations while the hero's return timer counts down.

### Onchain State (Cairo / Dojo ECS)

All game state lives as Dojo models on Starknet:

| Model | Purpose |
|-------|---------|
| `Game` | Session state — grimoire bitmap, ingredient/effect balances (bit-packed), gold, seed, tries |
| `Character` | Hero stats — HP, max HP, power, regen, role, loot bag, availability timestamp |
| `Discovery` | Per-ingredient-pair recipe discovery status |
| `Hint` | Per-ingredient hint bitmap (which recipes an ingredient participates in) |
| `Config` | Singleton — token address, VRF address |
| `GameSettings` | Zone count, ingredient count, recipe count, hero costs, balancing parameters |

Key architectural patterns:
- **Store pattern** — all world access goes through a typed `Store` abstraction (no raw `world.read_model()` calls)
- **Model assertions** — `GameAssert` and `CharacterAssert` traits for reusable validation
- **Model logic** — `GameTrait` and `CharacterTrait` encapsulate game rules (crafting, exploring, buffing)
- **Event constructors** — each Dojo event type has a dedicated constructor module
- **Bit-packed state** — ingredients (25 × 10 bits), effects (30 × 8 bits), tries (25 × 5 bits), grimoire (30-bit bitmap) are packed into felt252/u128 fields for gas efficiency

### Systems

| System | Actions |
|--------|---------|
| **Play** | `create`, `explore`, `claim`, `craft`, `crafts`, `clue`, `recruit`, `buff`, `buffs`, `surrender` |
| **Setup** | Settings initialization, VRF address management, game settings queries |

Both systems integrate with the [Provable Games Embeddable Game Standard](https://github.com/Provable-Games/game-components):
- `MinigameComponent` — NFT-gated game sessions (each game mints a soulbound ERC721)
- `SettingsComponent` — configurable game presets
- `pre_action / post_action` — token lifecycle hooks wrapping every game action

### Events (Indexed by Torii)

| Event | Emitted When |
|-------|-------------|
| `GameCreated` | New game session starts |
| `ExplorationEvent` | Each tick during expedition simulation |
| `ExpeditionStarted` | Expedition begins (includes death depth, return time) |
| `LootClaimed` | Hero returns and loot is transferred to inventory |
| `RecipeDiscovered` | New recipe found through crafting |
| `PotionApplied` | Potion consumed to buff a hero |
| `HeroRecruited` | New hero added to the party |
| `GrimoireCompleted` | All 30 recipes discovered — game won |

---

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Smart Contracts | [Cairo](https://www.cairo-lang.org/) 2.15 | Game logic, state management |
| Framework | [Dojo](https://www.dojoengine.org/) 1.8 | ECS architecture, world contract, deployment tooling |
| Game Standard | [game-components](https://github.com/Provable-Games/game-components) | NFT-gated sessions, settings, token lifecycle |
| Frontend | React 19 + TypeScript + Vite | UI, state management, animations |
| Animations | Framer Motion | Page transitions, hero animations, UI effects |
| Audio | Howler.js | Sound effects and music |
| State Management | Zustand | Client-side stores (navigation, settings, toasts, pending txs) |
| Wallet | [Cartridge Controller](https://docs.cartridge.gg/controller/overview) | Session keys, passkey auth, gasless transactions |
| Indexer | [Torii](https://book.dojoengine.org/toolchain/torii) | Real-time state sync via GraphQL/gRPC |
| RNG | [Cartridge vRNG](https://docs.cartridge.gg/slot/vrng) | Atomic verifiable randomness (same-transaction) |
| Deployment | [Slot](https://docs.cartridge.gg/slot/overview) → Sepolia → Mainnet | Progressive rollout |

---

## Project Structure

```
athanor/
├── contracts/                    # Cairo smart contracts
│   ├── src/
│   │   ├── constants.cairo       # Zones, ingredients, probabilities, balancing
│   │   ├── store.cairo           # Typed Store abstraction over WorldStorage
│   │   ├── models/
│   │   │   ├── index.cairo       # Model struct definitions (Game, Character, Discovery, Hint)
│   │   │   ├── game.cairo        # GameTrait — crafting, discovery, recruitment logic
│   │   │   ├── character.cairo   # CharacterTrait — exploration, claiming, buffing
│   │   │   ├── config.cairo      # Config, GameSettings, GameSettingsMetadata
│   │   │   ├── discovery.cairo   # Discovery tracking per ingredient pair
│   │   │   └── hint.cairo        # Hint bitmap management
│   │   ├── systems/
│   │   │   ├── play.cairo        # Main game system (MinigameComponent integration)
│   │   │   └── setup.cairo       # Settings system (SettingsComponent integration)
│   │   ├── elements/
│   │   │   ├── roles/            # Mage, Rogue, Warrior stat definitions
│   │   │   └── effects/          # Health, Power, Regen buff implementations
│   │   ├── types/
│   │   │   ├── category.cairo    # Exploration event categories (Trap, Gold, Heal, Beast)
│   │   │   ├── role.cairo        # Hero roles enum + random draw
│   │   │   ├── effect.cairo      # 30 potion effects + stat application
│   │   │   └── ingredient.cairo  # 25 ingredients enum
│   │   ├── helpers/
│   │   │   ├── exploration.cairo # Tick-by-tick expedition simulation engine
│   │   │   ├── crafter.cairo     # Probabilistic recipe discovery
│   │   │   ├── random.cairo      # VRF wrapper (Cartridge vRNG + pseudo-random fallback)
│   │   │   ├── bitmap.cairo      # Bit manipulation for grimoire/hints
│   │   │   ├── packer.cairo      # Bit-packing for ingredient/effect balances
│   │   │   └── power.cairo       # Power calculation helpers
│   │   ├── events/               # Dojo event definitions + constructors
│   │   ├── interfaces/           # VRF provider interface
│   │   ├── components/           # PlayableComponent (game lifecycle)
│   │   └── metadata/             # SVG image generation for NFT metadata
│   └── Scarb.toml
├── client/                       # React frontend
│   ├── src/
│   │   ├── main.tsx              # Provider hierarchy (Starknet → Dojo)
│   │   ├── App.tsx               # Page router
│   │   ├── cartridgeConnector.ts # Controller + session policies
│   │   ├── dojo/
│   │   │   ├── setup.ts          # Dojo SDK init + Torii sync
│   │   │   ├── systems.ts        # System call wrappers (explore, craft, etc.)
│   │   │   ├── txBatcher.ts      # Transaction batching with toast notifications
│   │   │   ├── contractModels.ts # RECS model definitions
│   │   │   └── world.ts          # RECS world instance
│   │   ├── hooks/                # React hooks (useGame, useHeroes, useRecipes, useInventory, etc.)
│   │   ├── stores/               # Zustand stores (navigation, settings, toasts, pending txs)
│   │   ├── game/
│   │   │   ├── constants.ts      # Zone/ingredient/effect names, asset URLs, display helpers
│   │   │   └── packer.ts         # Client-side bit unpacking
│   │   ├── sound/                # SoundManager (Howler.js)
│   │   └── ui/
│   │       ├── pages/            # HomePage, PlayScreen, MyGamesPage, LeaderboardPage, HowToPlayPage
│   │       └── components/       # StatusHUD, ActionBar, JourneyMap, RightPanel, HotkeyBar, etc.
│   └── package.json
├── scripts/
│   └── generate-assets/          # AI asset generation pipeline (fal.ai Flux 2 Pro)
├── Scarb.toml                    # Workspace root
├── dojo_dev.toml                 # Local Katana config
├── dojo_slot.toml                # Slot deployment config
├── dojo_sepolia.toml             # Sepolia deployment config
└── PLAN.md                       # Detailed implementation plan
```

---

## Development

### Prerequisites

- [Dojo](https://book.dojoengine.org/getting-started) 1.8.0+ (includes `sozo`, `katana`, `torii`)
- [Scarb](https://docs.swmansion.com/scarb/) (Cairo package manager)
- [Node.js](https://nodejs.org/) 18+ with [pnpm](https://pnpm.io/)

### Build Contracts

```bash
sozo build
```

### Local Development

Start a local Katana sequencer and deploy:

```bash
# Terminal 1: Start Katana
katana --dev

# Terminal 2: Deploy contracts
sozo migrate --dev

# Terminal 3: Start Torii indexer
torii --world <WORLD_ADDRESS> --rpc http://localhost:5050

# Terminal 4: Start client
cd client && pnpm install && pnpm dev
```

### Deploy to Slot

```bash
sozo migrate --profile slot
```

### Deploy to Sepolia

```bash
sozo migrate --profile sepolia
```

---

## Game Flow

```
1. Connect wallet (Cartridge Controller)
2. Mint game NFT → Create game session (VRF seed generated)
3. First hero spawned (random role: Mage/Rogue/Warrior)
4. Send hero to explore a zone
   └─ Full expedition computed onchain → events emitted → timer starts
5. Wait for hero to return (time proportional to depth explored)
6. Claim loot (gold + ingredients transferred to inventory)
7. Craft potions by combining ingredient pairs
   ├─ Recipe match → Potion discovered, added to grimoire
   └─ No match → 1 gold, failed combo recorded
8. Apply potions to heroes (permanent stat buffs)
9. Recruit additional heroes (up to 3)
10. Buy hints to narrow down undiscovered recipes
11. Repeat until all 30 recipes are discovered
12. Grimoire complete → Completion time recorded → Leaderboard rank
```

---

## License

MIT
