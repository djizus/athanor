import type { ImageAssetDef } from './types';

const GLOBAL_ART_STYLE = `Art style: neo-futurist nature 2D illustration. Organic flowing forms merged with sleek geometric precision. Bioluminescent accents, clean vector-like linework, lush natural textures with subtle tech undertones. Flat 2D composition with layered depth. NOT photographic, NOT pixel art, NOT 3D rendered.`;

export function buildBackgroundPrompt(asset: ImageAssetDef): string {
  if (asset.id === 'lab-bg') {
    return [
      `A dark medieval alchemist's laboratory interior, viewed from slight overhead angle.`,
      `Wooden shelves lined with glowing potion bottles in various colors. Stone walls with arcane rune carvings.`,
      `Central wooden workbench with mortar and pestle. Candelabras casting warm flickering light.`,
      `Bubbling cauldron in corner with green steam. Dark moody atmosphere with rich warm shadows.`,
      GLOBAL_ART_STYLE,
      `Color palette centered on background color #080810 with warm accent #f0c040.`,
      `Full-bleed seamless scene extending edge-to-edge. No borders, no frames, no framing elements.`,
      `No people, no text, no UI elements, no watermarks.`,
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
    `A wide panoramic top-down bird's-eye view fantasy world map for an alchemy RPG game.`,
    `Ultra-wide horizontal composition (3.5:1 aspect ratio), three distinct biome zones arranged left-to-right filling the entire width:`,
    `LEFT THIRD: Verdant Meadow — lush green fields seen from above, scattered wildflowers, ancient standing stones, a small glowing alchemist camp at the far left edge. Soft golden-green light.`,
    `CENTER THIRD: Crystal Cavern — exposed underground cavern viewed from above, clusters of amber and amethyst crystal formations jutting up, dark stone walls, warm mineral glow from crystal veins.`,
    `RIGHT THIRD: Aether Spire — ethereal purple floating platforms with a central arcane tower, swirling energy trails on the ground, glowing rune circles, starlit purple atmosphere.`,
    `A winding dirt path runs horizontally through all three zones from left to right, clearly visible.`,
    `The zones fill the full width edge-to-edge with smooth transitions between biomes.`,
    GLOBAL_ART_STYLE,
    `Color palette: dark background #080810, green #4a9e4a for meadow, amber #b8860b for cavern, purple #9e4a9e for spire.`,
    `Full-bleed seamless panoramic scene. Vignette: left and right 5% fades to near-black #080810.`,
    `Top-down orthographic perspective, like a tabletop RPG battle map viewed from directly above.`,
    `No people, no text, no labels, no UI elements, no watermarks, no icons.`,
  ].join(' ');
}

export function buildHeroPortraitPrompt(asset: ImageAssetDef): string {
  return [
    `Portrait bust of ${asset.description}.`,
    `Dramatic lighting from below. Dark background #080810 with subtle organic glow.`,
    `Determined expression. Square composition, centered face filling 80% of frame.`,
    GLOBAL_ART_STYLE,
    `No text, no watermarks.`,
  ].join(' ');
}

export function buildIngredientIconPrompt(asset: ImageAssetDef): string {
  const desc = asset.description.replace(/^(A|An)\s+/i, '');
  return [
    `A single ${desc}.`,
    `Centered on dark background #0a0a14. Bioluminescent ${asset.zoneColor ?? '#ffffff'} accent glow.`,
    GLOBAL_ART_STYLE,
    `Clean, instantly readable at small sizes. Square composition.`,
    `Single item only, no multiples. No text, no people, no UI.`,
  ].join(' ');
}

export function buildPotionIconPrompt(asset: ImageAssetDef): string {
  return [
    `${asset.description}.`,
    `Centered on dark background #0a0a14. Organic glass shapes with bioluminescent liquid glow.`,
    GLOBAL_ART_STYLE,
    `Clean, instantly readable at small sizes. Square composition.`,
    `Single item only. No text, no people, no UI.`,
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
