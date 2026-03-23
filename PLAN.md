# Athanor — Visual & Gameplay Polish Implementation Plan

## Overview

Transform the working Athanor PoC (functional turn-based combat, zone navigation, onchain state) into a visually polished, game-feel-rich experience. This plan covers all 10 priorities from the design spec: atmosphere/lighting, shadows, backgrounds, combat juice, FF-style combat UI with mock skills, animations, UI polish, zone transitions, audio, and VFX. All work is client-side. New gameplay mechanics (skills, defend) are implemented as local-only mock logic — wired to contracts in a future phase.

## Goals

- Atmospheric lighting system with per-zone presets (CanvasModulate + PointLight2D)
- Full combat juice: hit freeze, particles, sequenced hit chain, enhanced damage numbers
- FF-style command panel with Skills/Defend/Items (mock gameplay), stamina preview, turn order display
- Unique AI-generated room backgrounds per zone (replacing procedural stone shader)
- Multi-frame sprite animations for all characters (hero: 6 frames, mobs: 4 frames per animation)
- Polished UI with NinePatchRect panels, textured bars, proper fonts
- Complete audio: ambient drones, combat SFX, UI sounds
- VFX particle system for attacks, skills, status effects
- Clean 3D artifact removal (GLB models, unused zone scenes, spatial shaders)

## Non-Goals

- Contract changes (no new Cairo actions — skills/defend are client-side mock)
- Mobile/web export or platform-specific optimization
- Multiplayer / shared world features
- Procedural dungeon generation (zone graph stays hardcoded)
- Controller/auth flow changes (CEF browser implementation is complete)

## Assumptions and Constraints

- Godot 4.5+ with Forward Plus renderer (can use PointLight2D, CanvasModulate)
- GDScript only — no C#, no GDExtension beyond existing godot-dojo + godot-cef
- Art pipeline available for AI-generated assets (fal.ai Nano Banana model)
- Contract-locked values: stamina=100, AA_cost=30, mob_HP=20, power=10, mob_power=5
- Existing autoloads preserved: game_state, dojo_bridge, audio_manager, sprite_loader, transition_manager
- `arena.tscn` is the single gameplay scene — no per-zone scene switching
- Y-sort not currently used (entities at fixed positions) — add if needed for depth

## Requirements

### Functional

- Player and enemies emit light (PointLight2D) in a globally darkened scene (CanvasModulate)
- Each zone has a unique atmosphere preset (ambient color, light tint, vignette intensity)
- Combat hits produce: freeze frame → white flash → camera shake → particles → damage number
- Player can select: Attack (30 ST), Heavy Attack (50 ST), Defend (0 ST), End Turn
- Defend reduces incoming damage by 50% for 1 turn and ends the player's turn (client-side mock)
- Heavy Attack deals 2x damage (client-side mock — contract still does 10 damage, UI shows 20)
- Turn order bar shows upcoming turns at top of screen
- Stamina bar shows preview (ghost section) when hovering a skill
- Enemy info panel shows name, HP, status effects
- Zone transitions use fade-through with zone name title card
- Each enemy type has 4+ frames per animation (idle, attack, hit, death)
- Audio: zone ambient loops, hit/slash SFX, UI button sounds, turn transition sounds
- VFX: slash particles, impact sparks, defend shield, skill-specific effects

### Non-Functional

- All visual changes pass `godot --headless --quit` (no parse errors)
- Lighting/particle effects maintain 60 FPS at 1920×1080
- UI panels and buttons use NinePatchRect for resolution-independent scaling
- Shader uniforms tween smoothly during zone transitions (0.5s)
- No `as any` / `@ts-ignore` equivalent — all GDScript must be type-safe where practical

---

## Technical Design

### Architecture Changes

```
Arena (arena.gd) — existing, extended
├── LightingLayer (Node2D) — NEW
│   └── CanvasModulate — NEW (ambient darkening)
├── DungeonWorld (dungeon_view.gd) — existing, extended
│   ├── RoomBackground (Sprite2D) — NEW (replaces ZoneBackground ColorRect)
│   ├── PlayerAnchor (player_controller.gd) — existing
│   │   ├── AnimatedSprite2D — existing
│   │   ├── Sprite2D (blob shadow) — existing, polished
│   │   └── PointLight2D — NEW (player light)
│   └── MobAnchor — existing
│       └── Mob0-3 (containers) — existing
│           ├── AnimatedSprite2D — existing, more frames
│           ├── Sprite2D (blob shadow) — existing
│           ├── PointLight2D — NEW (enemy light)
│           └── ColorRect (HP bar) — existing
├── TargetingSystem — existing
├── GameCamera — existing, enhanced
├── VFXLayer (CanvasLayer, layer=1) — NEW
│   └── VignetteRect (ColorRect + shader) — NEW
├── UILayer (CanvasLayer, layer=2) — existing, overhauled
│   └── UIRoot — existing
│       ├── TurnOrderBar (HBoxContainer) — NEW
│       ├── Minimap — existing, polished
│       ├── TopBar — existing, extended with enemy info
│       ├── CommandPanel (PanelContainer) — NEW (replaces BottomBar)
│       │   ├── PlayerStatus (portrait, HP, ST, status icons)
│       │   ├── CommandMenu (Attack, Skills, Defend, End Turn)
│       │   ├── SkillSubmenu (hidden, slides in)
│       │   └── ContextInfo (stamina preview, turn status)
│       ├── DoorPanel — existing
│       └── ResultPanel — existing
└── OverlayLayer — existing (pause menu)
```

### Mock Gameplay Design (Client-Side Only)

**Skills** (local simulation — contract still processes auto-attack):

| Skill | Stamina Cost | Effect (Client Mock) | Notes |
|-------|-------------|---------------------|-------|
| Attack | 30 ST | 10 damage (contract real) | Existing behavior |
| Heavy Attack | 50 ST | 20 damage (displayed, contract does 10) | Client shows 20, actual is 10 |
| Defend | 0 ST | -50% incoming damage for 1 turn, ends turn | Client-side flag, doesn't affect contract `finish()` |

**Implementation approach**: `arena.gd` tracks a `_mock_skills` dictionary. When Heavy Attack is used, client calls `dojo_bridge.cast()` (same as auto-attack) but displays double damage number. When Defend is used, client sets `_defending = true` and immediately calls `dojo_bridge.finish()` — damage number display is halved on next mob attack. The contract still processes normally; mock skills are purely visual sugar.

### Art Pipeline Requirements

All assets generated via fal.ai Nano Banana model. Organized by priority:

**Batch 1 — Backgrounds (P3)**: 5 room backgrounds (2048×2048 PNG)
**Batch 2 — Sprites (P6)**: 4 mobs × 4 animations × 3 additional frames = 48 new PNGs
**Batch 3 — UI (P7)**: Panel frame, button states (3), bar frame = 5 UI textures
**Batch 4 — VFX (P10)**: Slash, fire burst, shield glow, impact sparks = 4 particle textures
**Batch 5 — Misc**: Light gradient texture, vignette texture (can be procedural)

---

## Implementation Plan

### Phase 0: Cleanup & Asset Generation (Serial — Foundation)

**Prerequisite for:** All subsequent phases

| Task | Description | Output | Files Affected |
|------|-------------|--------|----------------|
| 0.1 | Delete 3D model assets: `client/assets/models/` directory (15 GLB files) | Clean asset tree | assets/models/ removed |
| 0.2 | Delete unused 3D zone scenes: `client/scenes/zones/zone_0.tscn` through `zone_4.tscn` | No orphan scenes | scenes/zones/ removed |
| 0.3 | Delete spatial shader: `client/shaders/emissive_pulse.gdshader` + `.uid` | No 3D shaders | shaders/emissive_pulse.* removed |
| 0.4 | Remove `msaa_3d=1` from `project.godot` rendering section | Clean project config | project.godot |
| 0.5 | Generate PointLight2D texture: white-to-transparent radial gradient, 512×512 PNG | `assets/vfx/light_gradient.png` | New file |
| 0.6 | **Art Pipeline — Batch 1**: Generate 5 room backgrounds (see prompts below) | `assets/backgrounds/zone_0.png` through `zone_4.png` | New files |
| 0.7 | **Art Pipeline — Batch 2**: Generate mob sprite frames (see prompts below) | 48 new PNGs in `assets/sprites/mob_*/` | New files |
| 0.8 | **Art Pipeline — Batch 3**: Generate UI textures (panel frame, button states, bar frame) | PNGs in `assets/ui/` | New files |
| 0.9 | **Art Pipeline — Batch 4**: Generate VFX particle textures (slash, fire, shield, sparks) | PNGs in `assets/vfx/` | New files |

**Art Pipeline Prompts:**

Background prompts (2048×2048):
- Zone 0 (Entrance): `"dark dungeon entrance floor seen from above, top-down view, hand-painted style, golden amber and dark grey palette, crumbling archway stones, torch sconces, atmospheric lighting, Hades game art style, 2048x2048"`
- Zone 1 (Left Cavern): `"volcanic cavern floor from above, top-down perspective, hand-painted, deep red and burnt orange palette, lava cracks with glowing embers, obsidian stone, Hades Supergiant art style, 2048x2048"`
- Zone 2 (Right Passage): `"arcane passage floor from above, top-down view, hand-painted, purple and dark mauve palette, runic inscriptions glowing faintly, crystal formations, Hades art style, 2048x2048"`
- Zone 3 (Deep Hall): `"underwater temple floor seen from above, top-down, hand-painted, dark blue and teal palette, wet stone with barnacles and coral, bioluminescent accents, Hades art style, 2048x2048"`
- Zone 4 (Final Chamber): `"dark ritual chamber floor from above, top-down, hand-painted, deep green and black, cracked obsidian with glowing emerald veins, crystal throne platform, Hades art style, 2048x2048"`

Mob sprite prompts (512×512, transparent background):
- Pattern: `"sprite sheet, [mob description], [animation] pose, top-down isometric view, hand-painted dark fantasy style, transparent background, game asset, consistent proportions, single frame"`
- Generate frames 1-3 for each existing animation (frame 0 already exists)

UI prompts:
- Panel: `"dark ornate game UI panel frame, gold and bronze border, dark semi-transparent center, gothic fantasy style, Hades game interface aesthetic, rectangular horizontal, 512x128"`
- Button normal: `"dark fantasy game button, gold trim, rectangular, gothic style, game UI element, Hades Supergiant style, 256x64"`
- Button hover: Same but `"brighter, glowing gold edges"`
- Button disabled: Same but `"desaturated, dark, grey tones"`
- Bar frame: `"game UI health bar frame, ornate dark metal, horizontal, game interface element, 256x32"`

VFX prompts (256×256, transparent):
- Slash: `"white energy slash arc VFX, transparent background, game particle effect, stylized, 256x256"`
- Fire burst: `"orange flame burst VFX sprite, transparent background, game particle, 256x256"`
- Shield: `"golden shield aura VFX, transparent background, game particle, 256x256"`
- Sparks: `"white impact sparks VFX, transparent background, game particle, 256x256"`

**Verification**: `cd client && godot --headless --quit` — no errors after cleanup

---

### Parallel Workstreams (After Phase 0)

---

#### Workstream A: Atmosphere & Lighting (Priority 1)

**Dependencies:** Phase 0 (light texture, cleanup)
**Can parallelize with:** Workstreams B, C (different files)
**Primary files:** `arena.tscn`, `dungeon_view.gd` (new nodes only)

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| A.1 | Add `LightingLayer` (Node2D) as first child of Arena in `arena.tscn`. Add `CanvasModulate` child with default color `Color(0.35, 0.35, 0.45, 1.0)` | Global ambient darkening visible | Scene loads |
| A.2 | In `dungeon_view.gd:spawn_hero()`: add `PointLight2D` child to `_player_sprite`. Texture = `light_gradient.png`, scale=3.0, energy=0.8, color=`Color(1.0, 0.95, 0.85)`, blend_mode=Add | Player emits warm light | Light visible around player |
| A.3 | In `dungeon_view.gd:spawn_mobs()`: add `PointLight2D` per mob container. Per-zone colors: ember=`Color(1.0, 0.5, 0.2)`, aether=`Color(0.6, 0.4, 0.7)`, sunken=`Color(0.3, 0.9, 0.8)`, crystal=`Color(0.2, 0.7, 0.5)`. Energy=0.4, scale=1.5 | Enemies glow with type-appropriate color | Lights visible |
| A.4 | Add `VFXLayer` (CanvasLayer, layer=1) to `arena.tscn`. Add `VignetteRect` (ColorRect, full screen) with vignette shader (see spec). Set `mouse_filter = IGNORE` | Screen edges darkened | Vignette visible, doesn't block input |
| A.5 | Create `zone_atmospheres` dictionary in `dungeon_view.gd` mapping zone_id to `{ambient_color, player_light_color, vignette_intensity, enemy_light_energy}`. Extend `load_zone()` to tween CanvasModulate color and vignette intensity over 0.5s when zone changes | Smooth atmosphere transitions between zones | Zone change triggers color tween |
| A.6 | **Polish**: Review and tune all light values in-game. Ensure: dark areas feel dark, lit areas feel warm, enemy lights don't overpower, vignette isn't too aggressive | Balanced atmosphere | Visual review |

**Vignette shader** (`shaders/vignette.gdshader`):
```gdshader
shader_type canvas_item;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    float dist = distance(UV, vec2(0.5));
    float vignette = smoothstep(vignette_softness, vignette_softness - 0.3, dist);
    COLOR = vec4(0.0, 0.0, 0.0, (1.0 - vignette) * vignette_intensity);
}
```

**Zone atmosphere presets**:
```gdscript
const ZONE_ATMOSPHERES := {
    0: {ambient = Color(0.40, 0.35, 0.30), player_light = Color(1.0, 0.95, 0.85), vignette = 0.35},
    1: {ambient = Color(0.35, 0.25, 0.20), player_light = Color(1.0, 0.90, 0.80), vignette = 0.40},
    2: {ambient = Color(0.30, 0.25, 0.35), player_light = Color(0.90, 0.85, 1.0), vignette = 0.40},
    3: {ambient = Color(0.20, 0.25, 0.35), player_light = Color(0.85, 0.90, 1.0), vignette = 0.45},
    4: {ambient = Color(0.20, 0.30, 0.25), player_light = Color(0.85, 1.0, 0.90), vignette = 0.45},
}
```

---

#### Workstream B: Environment & Animations (Priority 2, 3, 6)

**Dependencies:** Phase 0 (backgrounds, sprite frames)
**Can parallelize with:** Workstreams A, C
**Primary files:** `dungeon_view.gd`, `sprite_loader.gd`

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| B.1 | **Polish shadows**: In `_create_blob_shadow()`, make shadow scale configurable per entity type. Player=`Vector2(1.2, 0.7)`, small mob=`Vector2(1.0, 0.6)`, large mob=`Vector2(1.5, 0.9)`. Pass entity type to function | Shadows sized proportionally | Visual check |
| B.2 | Replace `ZoneBackground` ColorRect with `Sprite2D` for room backgrounds. Load from `res://assets/backgrounds/zone_X.png`. Keep `ground_stone.gdshader` as fallback if background not found. Set z_index=-10, centered=true | Unique painted background per zone | Background visible |
| B.3 | Add edge treatment: create a `ColorRect` frame around the room background that fades to void color `Color(0.05, 0.05, 0.08)`. Or use a gradient shader on the background edges | Room edges blend into darkness | No hard cutoff |
| B.4 | Import new mob sprite frames into `assets/sprites/mob_*/`. Verify naming convention: `{mob_type}_{animation}_{frame}.png` | sprite_loader auto-detects new frames | Mobs have multi-frame animations |
| B.5 | Update `sprite_loader.gd` FPS values: idle=6 (was 2), attack=10 (was 6), hit=8 (was 6), death=6 (was 4). These speeds better suit 4-frame animations | Smoother animations | Animations play at correct speed |
| B.6 | Add hero `defend` and `skill_cast` animations: generate 4 frames each via pipeline, import to `assets/sprites/hero/`. Add to ANIM_ALIASES in dungeon_view.gd | Hero has defend and cast poses | Animations play |
| B.7 | Add `face_toward()` calls during combat: hero faces first alive mob during player turn, mobs face player during mob turn. Already partially implemented — verify and polish | Entities face correct direction | Visual check |

---

#### Workstream C: Combat Juice (Priority 4)

**Dependencies:** Phase 0 (VFX textures)
**Can parallelize with:** Workstreams A, B
**Primary files:** `dungeon_view.gd`, `game_camera.gd`, new `combat_fx.gd`

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| C.1 | **Polish hit flash**: Modify `hit_flash.gdshader` to use `flash_amount` (float 0-1) instead of `flash_active` (bool). Add tween-based fade: set to 0.8, tween to 0.0 over 0.08s. More controlled than on/off | Smoother flash effect | Flash fades instead of snapping |
| C.2 | **Polish camera shake**: Modify `game_camera.gd:shake()` to use exponential decay instead of linear steps. Add `shake_intensity` parameter scaling: normal hit=4.0, heavy=6.0, mob turn=3.0 per alive mob | Better shake feel | Shake decays naturally |
| C.3 | **Polish damage numbers**: Add color coding in `spawn_damage_number()`: white=normal, yellow=heavy attack, red=damage to player, green=heal. Add font size variation: normal=24, heavy=32, crit=36. Add slight random rotation (-5° to 5°) | Damage numbers are expressive | Colors match damage type |
| C.4 | **New: Hit freeze frame**. Create `combat_fx.gd` utility script (autoload or child of Arena). Add `hit_freeze(duration: float = 0.04)` that pauses scene tree briefly. Timer uses `process_always = true` to ignore pause | Brief pause on hit impact | Game pauses ~40ms on hit |
| C.5 | **New: Hit particles**. In `combat_fx.gd`, add `spawn_hit_particles(pos: Vector2, color: Color)`. Create `GPUParticles2D` at position: one_shot=true, amount=8, lifetime=0.3, explosiveness=0.9, gravity=0. Load slash texture from `assets/vfx/slash.png` | Particle burst on hit | Particles visible at hit location |
| C.6 | **New: Attack slide enhancement**. Extend `play_attack()` in `dungeon_view.gd`: increase lunge distance from 26px to 40px. Add return ease: `EASE_OUT_BACK` for a slight overshoot on return | Attack feels weightier | Lunge is more dramatic |
| C.7 | **Wire full hit sequence**. In `arena.gd:_on_attack_pressed()`, orchestrate: (1) attack slide starts → (2) at peak: hit_freeze(0.04) → (3) flash_white(target) → (4) camera.shake(4.0) → (5) spawn_hit_particles → (6) spawn_damage_number → (7) slide return. Use `await` chain or timer callbacks | Complete hit sequence feels impactful | All 7 steps execute in order |
| C.8 | **Wire mob turn sequence**. In `arena.gd:_on_end_turn_pressed()`, orchestrate: (1) all mobs play attack → (2) 0.3s delay → (3) hit_freeze(0.03) → (4) flash player → (5) shake(mob_count * 2.0) → (6) damage number on player → (7) mobs return to idle | Mob attacks feel threatening | Sequence plays correctly |
| C.9 | **Polish targeting ring**. In `targeting_system.gd`: add pulsing animation (modulate alpha oscillates 0.5-1.0 via sine wave in `_process`). Change ring color to gold `Color(1.0, 0.85, 0.3)` | Target indicator pulses | Ring pulses smoothly |

---

### Merge Phase 1: Visual Integration

**Dependencies:** Workstreams A, B, C all complete

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| M1.1 | Integration test: load each zone (0-4), verify lighting + background + atmosphere tween together. Check that PointLight2D interacts correctly with CanvasModulate | All zones visually distinct and atmospheric | Manual playthrough |
| M1.2 | Integration test: run full combat sequence in zone 3 (2 mobs). Verify hit sequence (freeze + flash + shake + particles + number) fires correctly for both attack and mob turn | Combat feels complete | No visual glitches |
| M1.3 | Performance test: check FPS in zone 4 (4 mobs, 4 lights + player light + particles). Must maintain 60 FPS | No performance regression | FPS counter |
| M1.4 | Fix any file conflicts between workstreams (dungeon_view.gd touched by A, B, C) | Clean merge | `godot --headless --quit` passes |

---

#### Workstream D: Combat UI Overhaul (Priority 5)

**Dependencies:** Merge Phase 1 (needs combat juice wired for animation timing)
**Can parallelize with:** Workstream E
**Primary files:** `arena.gd`, `arena.tscn` (heavy UI changes)

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| D.1 | **Turn order display**. Add `TurnOrderBar` (HBoxContainer) to UIRoot top area. Show 6-8 upcoming turn slots as small panels (48×48). Current turn highlighted gold (player) or red (enemy). Since combat is "player acts freely then ends turn," show: [Player → All Enemies → Player → ...] pattern. Update on turn start/end | Turn order visible at top | Bar updates on turn change |
| D.2 | **Command panel layout**. Replace existing `BottomBar` with new `CommandPanel` (PanelContainer). Layout: LeftSection (player portrait/HP/ST/status), CenterSection (command buttons), RightSection (stamina preview, turn status) | New command panel visible | Panel renders correctly |
| D.3 | **Player status section**. In CommandPanel left: portrait frame (TextureRect 64×64, placeholder), name label, HP bar (TextureProgressBar), ST bar (TextureProgressBar), status icon row (HBoxContainer) | Player stats always visible | HP/ST bars update |
| D.4 | **Command buttons**. Create reusable `CmdButton` scene: PanelContainer with icon (TextureRect 32×32), name (Label), cost (Label). Four commands: ⚔ Attack (30 ST), ⚡ Heavy Attack (50 ST), 🛡 Defend (0 ST), ⏭ End Turn. States: available (full color), cannot-afford (greyed, red cost), disabled (dark) | Four styled command buttons | Buttons show correct states |
| D.5 | **Skill submenu placeholder**. Add a "Skills" button that shows a submenu with Heavy Attack. The submenu slides up (tween 0.15s) when opened, has a "← Back" button. Skills that cost more than current stamina are greyed out | Submenu opens/closes smoothly | Grey-out works |
| D.6 | **Mock skill execution: Heavy Attack**. When Heavy Attack selected + target confirmed: call `dojo_bridge.cast()` (same as attack) but `spawn_damage_number()` shows `power * 2` (20). Deduct 50 stamina from display. Client-side tracking in `arena.gd:_mock_stamina` | Heavy Attack appears to do double damage | Stamina deducted correctly |
| D.7 | **Mock skill execution: Defend**. When Defend selected: set `_defending = true` in `arena.gd`. Play defend animation on hero. Immediately call `dojo_bridge.finish()`. On next mob attack, display damage number as `(mob_damage / 2)`. Play shield VFX. Reset `_defending` after mob turn | Defend halves displayed damage | Shield VFX visible |
| D.8 | **Targeting mode**. After selecting Attack/Heavy Attack, enter targeting state: "Select Target" text, valid targets get pulsing highlight (extend targeting_system.gd), click confirms, right-click/Escape cancels back to command select. For Defend/End Turn, skip targeting | Targeting works for attack skills | Cancel returns to command select |
| D.9 | **Stamina cost preview**. When hovering any command button: show cost in RightSection ("Cost: 30 ST"), show remaining ("Remaining: 70 ST"). On actual ST bar, overlay a darker section showing projected cost. Use a second ProgressBar or shader trick | Ghost stamina visible on hover | Preview disappears on unhover |
| D.10 | **Enemy info panel**. Extend TopBar: show hovered/selected enemy name, HP bar (with numeric), and status effect icons. When targeting, update as mouse moves between enemies | Enemy details visible during targeting | Updates on hover |
| D.11 | **Status effect icons** (visual only). Create small icon textures (20×20): shield (blue, for Defend), attack_up (red sword, unused for now), stun (yellow stars, unused). Show active statuses on player and enemies with turn count. Only Defend status is functional in this phase | Defend icon shows with "1" turn count | Icon appears/disappears correctly |
| D.12 | **Turn state visuals**. Player's turn: command panel lit, "Your Turn" in RightSection, gold pulse on panel border. Enemy turn: panel greyed out (modulate 0.4), buttons disabled, "Enemy Turn" text. Animating: all input disabled | Clear whose turn it is | States match combat phase |
| D.13 | **Turn start/end juice**. On player turn start: brief flash/pulse on command panel (modulate 1.2→1.0 over 0.3s), enable buttons, refresh stamina. On player turn end: grey out panel (tween 0.3s), disable buttons | Turn transitions feel responsive | Pulse visible on turn start |
| D.14 | **Multiple actions loop**. After each action resolves (attack/heavy attack), return to COMMAND_SELECT state — do NOT end turn. Grey out commands that cost more than remaining stamina. End Turn always available. This already works for Attack; verify it works with the new UI flow for Heavy Attack too | Multiple actions per turn work | Can attack twice then end turn |
| D.15 | **Keyboard shortcuts**. Map: 1=Attack, 2=Heavy Attack, 3=Defend, 4=End Turn. Tab=cycle targets (existing). Enter=confirm target. Escape=cancel targeting | All commands keyboard-accessible | Shortcuts work |

---

#### Workstream E: Audio & Transitions (Priority 8, 9)

**Dependencies:** Merge Phase 1
**Can parallelize with:** Workstream D
**Primary files:** `audio_manager.gd`, `transition_manager.gd`, `arena.gd` (minimal touches)

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| E.1 | **Audio bus setup**. In Godot project settings, create audio buses: Master → Music (-6dB), SFX (0dB), UI (-3dB), Ambient (-6dB). Update `audio_manager.gd` to assign players to correct buses | Audio properly routed | Bus assignments correct |
| E.2 | **Source/generate combat SFX**. Acquire via freesound.org or AI generation: `sword_slash.mp3`, `heavy_hit.mp3`, `shield_block.mp3`, `enemy_attack.mp3`, `player_hurt.mp3`, `enemy_death.mp3`. Place in `assets/sounds/effects/` | 6 new SFX files | Files load in audio_manager |
| E.3 | **Source/generate UI SFX**. Acquire: `button_hover.mp3`, `turn_start.mp3`, `enemy_turn.mp3`, `skill_select.mp3`. Place in `assets/sounds/effects/` | 4 new SFX files | Files load |
| E.4 | **Source/generate ambient drones**. Acquire 2-3 ambient loops: `ambient_dungeon.mp3` (default), `ambient_deep.mp3` (zones 3-4). Place in `assets/sounds/music/` | Ambient audio files | Files load |
| E.5 | **Wire combat SFX**. In `arena.gd` and `dungeon_view.gd`: play `sword_slash` when attack animation starts, `heavy_hit` on hit impact, `shield_block` on defend, `enemy_attack` when mobs attack, `player_hurt` when player takes damage, `enemy_death` when mob dies | SFX play at correct moments | Audio synced to animations |
| E.6 | **Wire UI SFX**. Add `button_hover` SFX on command button hover (connect `mouse_entered` signal). Play `turn_start` on player turn begin, `enemy_turn` on enemy turn begin, `skill_select` when choosing a skill | UI has audio feedback | Sounds on hover/select |
| E.7 | **Zone ambient music**. In `dungeon_view.gd:load_zone()`, crossfade ambient track based on zone. Zones 0-2 use `ambient_dungeon`, zones 3-4 use `ambient_deep`. Crossfade over 1.0s | Ambient changes per zone | Smooth crossfade |
| E.8 | **Polish zone transitions**. Extend `transition_manager.gd`: during fade-to-black, play `zone_transition` SFX. On fade-from-black, show zone name title card (large Label, centered, fades in over 0.5s then fades out over 1.0s) | Zone name appears on entry | Title card visible |
| E.9 | **Enemy spawn animation**. In `dungeon_view.gd:spawn_mobs()`, spawn each mob with 0.1s stagger delay, scale from 0.0→1.0 (0.3s ease-out), and fade from 0.0→1.0 alpha | Enemies appear dramatically | Staggered entrance |

---

### Merge Phase 2: UI + Audio Integration

**Dependencies:** Workstreams D, E complete

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| M2.1 | Integration test: full combat loop with new UI. Spawn → choose path → begin combat → Attack → Heavy Attack → Defend → End Turn → mob turn → continue | All commands work end-to-end | No crashes or stuck states |
| M2.2 | Verify audio sync: attack SFX fires at animation peak (not start), damage number appears after flash, turn start sound plays before panel lights up | Audio matches visuals | Timing feels right |
| M2.3 | Verify stamina tracking: mock stamina deduction for Heavy Attack stays in sync with contract state after Torii update | No stamina desync | Bars match contract values |
| M2.4 | Verify keyboard shortcuts work with new command panel | All 4 commands + Tab + Enter + Esc work | Keyboard-only playable |

---

#### Workstream F: Final Polish (Priority 7, 10)

**Dependencies:** Merge Phase 2 (needs final UI layout)
**Primary files:** `arena.tscn`, `athanor_theme.tres`, `dungeon_view.gd`

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| F.1 | **NinePatchRect panels**. Replace PanelContainer backgrounds for CommandPanel, DoorPanel, ResultPanel with NinePatchRect using generated `panel_frame.png`. Set patch margins for proper scaling | Ornate panel frames | Panels scale correctly |
| F.2 | **Button textures**. Apply generated button textures to CmdButton scene: normal, hover, disabled states. Override theme for command buttons specifically | Styled buttons with states | Hover/disabled visible |
| F.3 | **Bar textures**. Replace ProgressBar theme overrides for HP and Stamina with TextureProgressBar using generated `bar_frame.png`. HP fill = red gradient, ST fill = cyan gradient | Textured health/stamina bars | Bars fill correctly |
| F.4 | **Font setup**. Import Cinzel (headers) and Inter/Lato (body) as `.ttf`. Set in `athanor_theme.tres`: HeaderLabel = Cinzel 24pt, default = Inter 16pt, SubtitleLabel = Inter 12pt | Consistent typography | Fonts render |
| F.5 | **Minimap polish**. Add semi-transparent dark panel behind minimap (NinePatchRect). Make current zone node glow (pulsing modulate). Use different colors for cleared (dim green) vs locked (dark grey) vs current (gold). Add small zone type icons if feasible | Minimap feels integrated | Zone states distinguishable |
| F.6 | **VFX: skill-specific particles**. For Heavy Attack: use `fire_burst.png` particle texture, orange tint. For Defend: use `shield_glow.png`, spawn shield particle at player position. For regular attack: use `slash.png`, white | Skills have unique VFX | Particles match skill type |
| F.7 | **VFX: hit screen flash**. On heavy hits (Heavy Attack, mob turn with 3+ mobs): briefly overlay white ColorRect at alpha 0.08 on VFXLayer for 2 frames, then fade to 0 | Subtle screen flash on big hits | Flash visible but not obnoxious |
| F.8 | **VFX: death smoke**. When mob dies: spawn dark purple smoke particles (`CPUParticles2D`, amount=12, one_shot, 0.5s lifetime) at mob position, in addition to existing scale-to-zero animation | Death feels more dramatic | Smoke visible |
| F.9 | **Polish pass: theme consistency**. Review all UI elements for consistent colors: gold `Color(0.831, 0.659, 0.286)` for highlights, dark panel backgrounds, proper label colors. Ensure new CommandPanel matches existing TopBar/Minimap style | Visual consistency | Cohesive look |

---

### Merge Phase 3: Final Integration & Testing

**Dependencies:** Workstream F complete

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| M3.1 | Full playthrough test: main menu → spawn → zone 0 → choose left → zone 1 combat (use all skills) → cleared → zone 3 combat → cleared → zone 4 combat → complete dungeon | Game plays start to finish | No errors |
| M3.2 | Full playthrough test: death path. Zone 4 with 4 mobs, intentionally use only Defend to lose. Verify death screen, mob turn VFX, damage display | Death handled correctly | Death screen shows |
| M3.3 | Headless validation: `cd client && timeout 60 godot --headless --quit 2>&1` — must exit clean | No parse errors | Exit code 0 |
| M3.4 | Performance: zone 4 (4 mobs, 5 lights, particles, full UI). Measure FPS. Target: stable 60 FPS | No performance issues | FPS ≥ 60 |
| M3.5 | Cleanup: remove any temporary debug code, ensure all placeholder textures have been replaced by pipeline art, verify no orphan files | Clean codebase | No TODOs left |

---

## Testing and Validation

### Automated
- `cd client && timeout 60 godot --headless --quit` — GDScript parse check (run after every workstream)
- `sozo build && sozo test` — contract regression (run once at start, should be 19/19 pass)

### Manual Test Matrix

| Scenario | Steps | Expected |
|----------|-------|----------|
| Zone atmosphere | Enter each zone (0-4) | Unique ambient color, player light tint, vignette intensity |
| Hit sequence | Attack a mob | Freeze → flash → shake → particles → number (in order) |
| Heavy Attack | Select Heavy Attack → target mob | 50 ST cost, double damage number, fire particles |
| Defend | Select Defend | Shield VFX, end turn, next mob damage halved (display only) |
| Stamina exhaustion | Use Attack + Heavy Attack (80 ST), try Heavy Attack again | Heavy Attack greyed out (need 50, have 20) |
| Mob death | Kill mob with attack | Death anim → smoke particles → scale to zero |
| Turn order | Watch top bar during combat | Accurate turn order, highlights current actor |
| Zone transition | Clear zone 1 → auto-advance to zone 3 | Fade → title card "Zone 3 — Deep Hall" → fade in |
| Audio sync | Attack during combat | Slash SFX at animation peak, not at button press |
| Keyboard combat | Use 1/2/3/4 keys + Tab + Enter | Full combat without mouse |
| Resume from death | Die → Return to Menu → Spawn new game | Clean state reset |

---

## Verification Checklist

```bash
# 1. GDScript parse check
cd client && timeout 60 godot --headless --quit 2>&1
# Expected: clean exit, no errors

# 2. Contract regression
sozo build && sozo test
# Expected: 19 passed, 0 failed

# 3. 3D cleanup verification
ls client/assets/models/ 2>&1
# Expected: "No such file or directory"

ls client/scenes/zones/ 2>&1
# Expected: "No such file or directory"

ls client/shaders/emissive_pulse.gdshader 2>&1
# Expected: "No such file or directory"

# 4. New assets present
ls client/assets/backgrounds/zone_*.png | wc -l
# Expected: 5

ls client/assets/vfx/*.png | wc -l
# Expected: 5+ (slash, fire, shield, sparks, light_gradient)

ls client/assets/ui/*.png | wc -l
# Expected: 5+ (panel_frame, button_normal, button_hover, button_disabled, bar_frame)

# 5. New shader present
ls client/shaders/vignette.gdshader
# Expected: file exists

# 6. Manual: full playthrough
# Open Godot editor → F5 → connect → spawn → play through entire dungeon
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Mock skills confuse players (display ≠ contract reality) | Medium | Medium | Clear UI labels ("Preview" or visual-only indicator). Document as PoC limitation. |
| Art pipeline generates inconsistent style across assets | Medium | Medium | Use consistent prompt templates. Generate in batches. Review before import. |
| PointLight2D performance with 4+ lights | Low | Medium | Lights are simple (no shadows). Reduce texture_scale if needed. Test in zone 4. |
| Hit freeze (`get_tree().paused`) conflicts with timer-based animations | Medium | High | Use `process_always = true` on freeze timer. Test carefully with all concurrent tweens. |
| New CommandPanel layout breaks on different resolutions | Medium | Medium | Use anchors and containers. Test at 1280×720 and 1920×1080. Stretch mode = `canvas_items`. |
| Stamina desync between mock display and contract state | High | Medium | On every `fight_updated` signal, reset displayed stamina to contract value. Mock only between tx send and confirmation. |
| sprite_loader frame naming conflicts with new art | Low | Low | Verify naming convention matches `{id}_{anim}_{frame}.png` before import. |
| Audio latency on hit SFX | Low | Medium | Use `AudioStreamPlayer` (non-positional) for combat SFX. Preload all streams. |

---

## Open Questions

- [ ] Exact asset generation prompts may need iteration — pipeline output quality varies. Budget 2-3 rounds per batch.
- [ ] Defend skill: should stamina regen faster on the following turn (bonus), or just standard reset? (Currently: standard reset via `finish()`)
- [ ] Turn order bar design: since combat is "player acts freely → all enemies," the turn order is always `[P, E, E, E, E, P, E, E, E, E, ...]`. Is a simpler "Phase Indicator" (Your Turn / Enemy Turn) better than fake individual slots?
- [ ] Heavy Attack damage: should contract `cast()` eventually support `skill_id=1` (heavy attack) with actual 2x damage, or keep it as permanent visual mock?

---

## Decision Log

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| Mock skills as client-side only | Avoids contract migration. Proves UI/UX before committing onchain. Can wire to contracts later. | Full contract rewrite (too much scope), skip skills entirely (loses FF feel) |
| Simple 3-skill set (Attack, Heavy, Defend) | Minimum viable to demonstrate command panel + stamina economy. Fewer VFX needed. | 5+ skills (too many VFX), skill-less UI (doesn't test the pattern) |
| Remove 3D assets | Eliminates confusion. Plan is 100% Node2D. 3D code paths are dead weight. | Keep for later (tech debt), hybrid 3D/2D (complexity) |
| Art pipeline for ALL generated assets | Consistent style. No manual art editing. Batch-friendly. | Manual art (slow, inconsistent), marketplace assets (wrong style), pure procedural (limited) |
| CanvasModulate for ambient darkening | Simplest approach. Works with PointLight2D out of the box. Per-zone tweening. | Custom shader (complex), WorldEnvironment (3D only), manual darkening (tedious) |
| Hit freeze via `get_tree().paused` | Matches Hades-style weight. Simple implementation. Short duration (40ms) is imperceptible lag. | Engine time_scale (affects physics), manual animation pause (complex) |
| Stamina mock with contract reconciliation | Allows instant UI response. Contract is source of truth on Torii update. Brief visual-only window. | Wait for contract confirmation (slow), pure local state (desync risk) |
| Single arena.tscn for all zones | Current architecture works. Zone switching is palette/background swap, not scene change. | Per-zone scenes (complex transitions, state management overhead) |
| Generate 4 frames per mob animation | Meaningful improvement over 1 frame. 48 new assets is pipeline-manageable. 6 frames would be 96. | Keep 1 frame (too static), 6 frames (too many assets), skeletal animation (wrong approach for pixel art) |
