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
    `A vast dark alchemist's sanctum viewed from within, cinematic key art.`,
    `Towering stone walls covered in faintly glowing arcane runes and alchemical diagrams.`,
    `Central massive athanor furnace radiating warm amber-gold light (#f0c040) from its core.`,
    `Shelves of potions and ingredients line the walls, their contents softly bioluminescent.`,
    `Floating motes of golden light drift upward like embers. Wisps of purple (#a050d0) arcane energy curl through the air.`,
    `Deep shadows in indigo-black (#080810) with warm highlights from the furnace.`,
    `Mysterious, reverent, magical atmosphere - the moment before a grand transmutation.`,
    GLOBAL_ART_STYLE,
    `Full-bleed seamless scene extending edge-to-edge. No borders, no frames, no framing elements.`,
    `Vignette edges: outermost 10% on all sides smoothly fades to near-black #080810.`,
    `No people, no text, no UI elements, no watermarks.`,
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
