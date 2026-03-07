import type { ImageAssetDef } from './types';

const GLOBAL_ART_STYLE = `Art style: neo-futurist nature 2D illustration. Organic flowing forms merged with sleek geometric precision. Bioluminescent accents, clean vector-like linework, lush natural textures with subtle tech undertones. Flat 2D composition with layered depth. NOT photographic, NOT pixel art, NOT 3D rendered.`;

export function buildBackgroundPrompt(asset: ImageAssetDef): string {
  if (asset.id === 'lab-bg') {
    return [
      `A vast dark alchemist sanctum interior in the same visual language as the loading screen: obsidian stone walls, molten amber furnace glow, floating ember motes, and soft violet arcane haze.`,
      `Composition is side-weighted: shelves, tools, candles, and cauldrons stay on the far left and far right edges with depth layering.`,
      `The center area must remain mostly empty and calm: open dark stone floor and soft atmospheric haze, with no table, no cauldron, no brazier, and no large props in the middle 50% of the frame, so menu UI stays highly readable.`,
      `Arcane circles and alchemical symbols appear as abstract decorative marks on walls only, never readable text.`,
      GLOBAL_ART_STYLE,
      `Color palette centered on #080810, with controlled warm highlights #f0c040 and restrained purple energy accents #7a5cff.`,
      `Full-bleed seamless scene extending edge-to-edge. No borders, no frames, no framing elements.`,
      `No people, no readable text, no UI elements, no logos, no watermarks.`,
    ].join(' ');
  }

  if (asset.id === 'world-map') {
    return buildWorldMapPrompt();
  }

  return [
    `${asset.description}.`,
    `Painted as a wide panoramic scene suitable as a full-screen game background.`,
    GLOBAL_ART_STYLE,
    `Primary color tones: ${asset.zoneColor ?? '#080810'}. Dark moody atmosphere.`,
    `Full-bleed seamless scene extending edge-to-edge. No borders, no frames.`,
    `Vignette edges: outermost 8% on all sides smoothly fades to near-black #080810.`,
    `No people, no text, no UI elements, no watermarks.`,
  ].join(' ');
}

export function buildWorldMapPrompt(): string {
  return [
    `A top-down bird's-eye view fantasy world map for an alchemy RPG game. 16:9 widescreen composition (2560x1440).`,
    `LAYOUT: A narrow VERTICAL corridor of biome zones runs through the HORIZONTAL CENTER of the image (occupying the central 35% of the width, full height). The LEFT and RIGHT sides (each ~32% of the width) are dark atmospheric filler only.`,
    `BOTTOM OF CENTER CORRIDOR — THE ATHANOR: A glowing alchemist's athanor furnace platform at the very bottom center. Circular stone platform with a molten-gold furnace at its heart, arcane circles etched into the stone, warm amber (#c8a040) light radiating outward. This is the origin point.`,
    `ZONE 1 (just above athanor): Amber Hollows — warm golden cavern openings, amber-tinted rock formations, copper veins glowing in dark stone, soft golden (#c8a040) light filtering up.`,
    `ZONE 2 (above zone 1): Ember Cavern — volcanic fissures, smoldering dragon-fire residue, sulfur crystal formations, dark stone with orange-red (#b85030) magma glow. Heat haze rising.`,
    `ZONE 3 (center of corridor): Aether Spire — ethereal purple (#9e4a9e) floating platforms, swirling arcane energy trails, glowing rune circles, starlit atmosphere.`,
    `ZONE 4 (above zone 3): Sunken Abyss — deep flooded cavern, bioluminescent blue (#2a5a8a) cave pearls, dripping stalactites, dark river channels cutting through stone.`,
    `ZONE 5 (top of corridor): Crystalveil Reach — crystalline frost formations, emerald (#2a8a6a) gemstone outcrops, frozen flower blooms, teal aurora wisps. The peak.`,
    `A winding path connects all zones VERTICALLY from the athanor at the bottom up through each zone to the peak. The path should be clearly visible — worn stone steps transitioning through each biome.`,
    `LEFT AND RIGHT FILLER: Dense dark enchanted forest, misty void, jagged dark cliffs, and swirling black fog. Completely dark and atmospheric — no landmarks, no structures, no points of interest. Just moody dark wilderness that frames the central corridor. Fades smoothly into near-black at the edges.`,
    GLOBAL_ART_STYLE,
    `Color palette: dark filler #080810, golden amber #c8a040 at bottom graduating through burnt orange #b85030, purple #9e4a9e, deep blue #2a5a8a, to emerald teal #2a8a6a at top. The color temperature shifts from warm (bottom) to cold (top).`,
    `Full-bleed seamless scene extending edge-to-edge. Vignette: outermost 8% on ALL sides smoothly fades to near-black #080810.`,
    `Top-down orthographic perspective, looking straight down. The vertical zone corridor is the ONLY area with detail and color — everything else is dark background.`,
    `No people, no text, no labels, no UI elements, no watermarks, no icons.`,
  ].join(' ');
}

export function buildHeroPortraitPrompt(asset: ImageAssetDef): string {
  return [
    `Close-up face portrait: ${asset.description}.`,
    `Face fills 85% of the frame, tightly cropped at forehead and chin for circular avatar use.`,
    `Dark obsidian background #080810 with warm amber #f0c040 rim lighting on one side and faint bioluminescent accents.`,
    GLOBAL_ART_STYLE,
    `Square composition. No shoulders, no body, no armor, no weapons, no hands.`,
    `No text, no watermarks, no UI.`,
  ].join(' ');
}

export function buildIngredientIconPrompt(asset: ImageAssetDef): string {
  const desc = asset.description.replace(/^(A|An)\s+/i, '');
  const zone = asset.zoneColor ?? '#ffffff';
  return [
    `A single ${desc}.`,
    `Centered in frame with generous margins on all sides for circular crop.`,
    `Dark obsidian background #0a0a14 with a soft diffuse ${zone} ambient glow emanating from behind the item — subtle enough to tint the atmosphere without overpowering the ingredient.`,
    `Warm amber light #f0c040 rim-highlights the item edges. Faint floating ember motes and bioluminescent accents.`,
    GLOBAL_ART_STYLE,
    `Single item only, no multiples, no surface or table. Item floating in space.`,
    `Square composition, item occupying central 60% of frame. No text, no people, no UI.`,
  ].join(' ');
}

export function buildPotionIconPrompt(asset: ImageAssetDef): string {
  return [
    `${asset.description}.`,
    `Centered in frame with generous margins on all sides for circular crop.`,
    `Dark obsidian background #0a0a14. Organic glass shapes with bioluminescent liquid glow radiating outward.`,
    `Warm amber light #f0c040 rim-highlights the glass edges. Faint floating ember motes.`,
    GLOBAL_ART_STYLE,
    `Single item only, no surface or table. Bottle floating in space.`,
    `Square composition, item occupying central 60% of frame. No text, no people, no UI.`,
  ].join(' ');
}

export function buildLogoPrompt(): string {
  return [
    `The word "ATHANOR" as a bold flat 2D game logo on a solid black background.`,
    `Chunky serif letterforms inspired by medieval alchemical manuscripts.`,
    `Each letter filled with a molten gold-to-amber gradient (#f0c040 to #a08020), with subtle cracks revealing inner fire glow.`,
    `Thin arcane rune engravings within the letterforms. Faint alchemical circle halo behind the text.`,
    `Completely flat 2D design, no depth, no shadows, no 3D perspective.`,
    `Clean sharp edges, centered composition on pure black #000000 background.`,
    GLOBAL_ART_STYLE,
    `No other elements - just the text centered on black. 1024x1024 pixels.`,
  ].join(' ');
}

export function buildLoadingBgPrompt(): string {
  return [
    `A vast dark alchemist's sanctum — towering stone walls with glowing arcane runes, massive athanor furnace at center radiating warm amber light, shelves of bioluminescent potions, floating golden motes like embers, wisps of purple arcane energy.`,
    `Painted as a wide panoramic scene suitable as a full-screen game background.`,
    GLOBAL_ART_STYLE,
    `Primary color tones: #080810 with warm accent #f0c040. Dark moody atmosphere.`,
    `Full-bleed seamless scene extending edge-to-edge. No borders, no frames.`,
    `Vignette edges: outermost 8% on all sides smoothly fades to near-black #080810.`,
    `No people, no text, no letters, no runic glyphs as readable text, no UI elements, no logos, no signatures, no artist marks, no watermarks.`,
  ].join(' ');
}

export function buildPrompt(asset: ImageAssetDef): string {
  switch (asset.category) {
    case 'backgrounds': return buildBackgroundPrompt(asset);
    case 'heroes': return buildHeroPortraitPrompt(asset);
    case 'ingredients': return buildIngredientIconPrompt(asset);
    case 'potions': return buildPotionIconPrompt(asset);
    case 'branding': {
      if (asset.id === 'logo') return buildLogoPrompt();
      if (asset.id === 'loading-bg') return buildLoadingBgPrompt();
      return buildBackgroundPrompt(asset);
    }
  }
}
