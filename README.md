# Athanor

**Onchain tactical dungeon crawler on Starknet.**

Athanor is a turn-based tactical RPG where players spawn a hero, navigate a branching dungeon graph, and fight mobs in onchain combat. Built with [Dojo](https://www.dojoengine.org/) (Cairo contracts) and [Godot 4](https://godotengine.org/) (3D client with fixed isometric camera).

Named after the *athanor*, the self-feeding philosophical furnace of medieval alchemy. The dungeon is the furnace; clearing it is the Great Work.

> **Previous version**: The grimoire-race idle game from Game Jam VIII is preserved on the [`game-jam-viii`](../../tree/game-jam-viii) branch and tag.

---

## Game Design (PoC)

### Core Loop

```
Spawn Hero --> Navigate Dungeon --> Fight Mobs --> Clear Zones --> Complete Dungeon
```

### Dungeon Graph (Diamond / Branching)

```
        [Zone 1: Spawn]
           /        \
    [Zone 2a]    [Zone 2b]      <-- 1 mob each
           \        /
        [Zone 3]                <-- 2 mobs
           |
        [Zone 4]                <-- 4 mobs (final)
```

Players choose their path through the diamond via `choose(direction)`. Each zone contains turn-based combat encounters.

### Combat

| Action | Effect |
|--------|--------|
| `cast(mob_id, AA)` | Spend 30 stamina, deal 10 damage |
| `finish()` | End turn -- all surviving mobs attack (5 dmg each), stamina regens |

Combat continues until all mobs in the zone are dead or the player's HP hits 0.

### Stats

| | Player | Mob |
|---|--------|-----|
| Health | 100 | 20 |
| Power | 10 | 5 |
| Stamina | 100 | -- |

### Contract Actions

| Action | Purpose |
|--------|---------|
| `spawn(class_id)` | Create character + dungeon |
| `choose(direction)` | Navigate to next zone |
| `start()` | Begin combat in current zone |
| `cast(mob_id, skill_id)` | Attack a mob |
| `finish()` | End turn, resolve mob attacks |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Contracts | [Cairo](https://www.cairo-lang.org/) + [Dojo](https://www.dojoengine.org/) 1.8 |
| Client | [Godot 4.3+](https://godotengine.org/) (GDScript, 3D isometric) |
| Dojo SDK | [godot-dojo](https://github.com/lonewolftechnology/godot-dojo) v0.7.4 (gRPC streaming) |
| Wallet | [Cartridge Controller](https://docs.cartridge.gg/controller/overview) (session keys, passkey auth) |
| Indexer | [Torii](https://book.dojoengine.org/toolchain/torii) (real-time entity sync) |
| Deployment | [Slot](https://docs.cartridge.gg/slot/overview) / Sepolia |

---

## Project Structure

```
athanor/
+-- contracts/          # Cairo smart contracts (Dojo ECS)
+-- client/             # Godot 4 project
|   +-- addons/godot-dojo/  # Dojo SDK (download from releases)
|   +-- scenes/
|   +-- scripts/
|   +-- project.godot
+-- .agents/skills/     # AI agent skills (installed via npx, gitignored)
+-- PLAN.md             # Detailed implementation plan
+-- .gitignore
```

---

## Getting Started

### Prerequisites

- [Dojo](https://book.dojoengine.org/getting-started) 1.8.0+ (`sozo`, `katana`, `torii`)
- [Godot 4.3+](https://godotengine.org/download/) (editor or headless)
- [Scarb](https://docs.swmansion.com/scarb/) (Cairo package manager)

### Setup

```bash
git clone git@github.com:djizus/athanor.git
cd athanor

# Install godot-dojo SDK
# Download v0.7.4 from: https://github.com/lonewolftechnology/godot-dojo/releases/tag/v0.7.4
# Extract addons/godot-dojo/ into client/addons/godot-dojo/
```

### Install AI Skills (for contributors using AI agents)

```bash
# Godot skills (task executor + 862 API docs, GDScript reference, scene/script generation)
npx skills add htdt/godogen -y
# Then remove the auto-pilot orchestrator (we orchestrate manually):
rm -rf .agents/skills/godogen

# Dojo skills (12 skills -- models, systems, deploy, testing, etc.)
npx skills add dojoengine/book -y

# Controller + Slot skills (15 skills -- wallet, sessions, deploy, paymaster, etc.)
npx skills add cartridge-gg/docs -y
```

### Local Development

```bash
# Terminal 1: Start Katana
katana --dev

# Terminal 2: Build and deploy contracts
sozo build && sozo migrate --dev

# Terminal 3: Start Torii indexer
torii --world <WORLD_ADDRESS> --rpc http://localhost:5050

# Terminal 4: Open Godot client
cd client && godot
```

---

## Architecture

### Onchain State (Dojo ECS)

| Model | Purpose |
|-------|---------|
| `Character` | Hero stats -- HP, power, stamina, current zone |
| `Dungeon` | Zone graph, cleared zones, completion status |
| `Fight` | Active combat -- mob HPs (bit-packed), mob power, turn counter |

### Events (Indexed by Torii)

| Event | Trigger |
|-------|---------|
| `CharacterSpawned` | New hero created |
| `ZoneEntered` | Player moves to next zone |
| `FightStarted` | Combat begins |
| `MobDamaged` | Player attacks a mob |
| `PlayerDamaged` | Mobs attack on finish() |
| `FightEnded` | All mobs dead or player died |
| `DungeonCompleted` | Zone 4 cleared |

### Client Architecture (Godot)

- `ToriiClient` node subscribes to Character/Dungeon/Fight entity updates via gRPC streaming
- Typed GDScript wrapper converts raw Dictionary API to typed classes
- Fixed isometric camera, 3D zone platforms in diamond layout
- Combat UI overlay with mob HP bars, action buttons, stamina display

---

## Roadmap

- [ ] **PoC**: Core loop (spawn, navigate, fight, clear)
- [ ] **v2.1**: Multiple hero classes, skill trees
- [ ] **v2.2**: Procedural dungeon generation
- [ ] **v2.3**: Async MMO (shared world, trading, PvP)
- [ ] **v2.4**: Loot, progression, leaderboard

See [`PLAN.md`](PLAN.md) for the detailed implementation plan.

---

## License

MIT
