# Athanor v2 Art Pipeline Specification

## Perspective
Isometric 2:1 ratio (2 horizontal pixels per 1 vertical pixel of depth).

## Sprite Dimensions
- Character sprites: **32×32 pixels** (fits 8×8 grid with 32px tile size)
- Tile size: **32×32 pixels** isometric diamond
- UI icons (abilities): **16×16 pixels**

## Naming Convention
```
{character}_{animation}_{frame}.png

Examples:
  hero_idle_0.png
  hero_idle_1.png
  hero_walk_0.png
  brute_attack_0.png
  caster_death_2.png
```

## Required Animations Per Character

| Animation | Frames | FPS | Loop | Notes |
|-----------|--------|-----|------|-------|
| idle | 4 | 4 | yes | Breathing / subtle motion |
| walk | 4 | 8 | yes | Moving between tiles |
| attack | 4 | 12 | no | Ability activation |
| hit | 2 | 8 | no | Taking damage |
| death | 4 | 6 | no | Last frame holds |

## Characters (M1)

| Character | Color Scheme | Silhouette |
|-----------|-------------|------------|
| Hero | Blue/silver | Humanoid with staff/sword |
| Melee Brute | Red/dark | Large, bulky, heavy arms |
| Ranged Caster | Purple/glow | Thin, robed, floating orb |

## Pivot Points
All sprites use **bottom-center** pivot (Vector2(0.5, 1.0)) for isometric depth sorting. The feet/base of the character sits at the tile's center point.

## Layer Ordering (Y-Sort)
Entities are depth-sorted by their tile Y coordinate. Higher Y = drawn later (in front). Within the same Y, sort by X ascending.

## Placeholder Strategy (M1)
For M1, use simple colored rectangles with a 1px outline:
- Hero: 16×24 blue rectangle, white outline
- Brute: 20×24 red rectangle, white outline  
- Caster: 14×24 purple rectangle, white outline

These are generated procedurally in GDScript — no actual PNG files needed for M1.

## SpriteFrames Format
Each character uses a `SpriteFrames` resource with animations named exactly as the animation column above. Frame duration = 1.0 / FPS.

## Post-M1 Production Pipeline
1. Artist delivers PNG spritesheets per character
2. Each sheet is sliced into individual frames following naming convention
3. SpriteFrames resources are created in Godot editor
4. Pivot/offset adjusted per character in the editor
5. All sprites placed in `client/assets/sprites/{character}/`
