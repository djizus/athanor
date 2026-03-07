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
    `A top-down bird's-eye view fantasy world map for an alchemy RPG game. 16:9 widescreen composition.`,
    `Three distinct biome zones arranged LEFT-TO-RIGHT in the CENTER of the image, occupying the central 65% of the width and 50% of the height:`,
    `LEFT ZONE: Verdant Meadow — lush green fields, scattered wildflowers, ancient standing stones, a small glowing alchemist base camp on the far left. Soft golden-green light.`,
    `CENTER ZONE: Crystal Cavern — exposed underground cavern, clusters of amber and amethyst crystal formations, dark stone walls, warm mineral glow from crystal veins.`,
    `RIGHT ZONE: Aether Spire — ethereal purple floating platforms with a central arcane tower, swirling energy trails, glowing rune circles, starlit purple atmosphere.`,
    `A clearly visible winding dirt path runs horizontally through all three zones from left to right, connecting them in sequence.`,
    `SURROUNDING AREAS (outside the zones): Dense dark enchanted forest, misty mountains, deep ravines, dark wilderness terrain. This decorative filler extends to all edges of the image.`,
    `The three zones are CENTERED in the image — they do NOT touch the edges. Dark wilderness filler surrounds them on all four sides.`,
    GLOBAL_ART_STYLE,
    `Color palette: dark background #080810, green #4a9e4a for meadow, amber #b8860b for cavern, purple #9e4a9e for spire, dark greens and blacks for surrounding wilderness.`,
    `Full-bleed seamless scene extending edge-to-edge. Vignette: outermost 10% on ALL sides smoothly fades to near-black #080810.`,
    `Top-down orthographic perspective, like a tabletop RPG battle map viewed from directly above.`,
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
