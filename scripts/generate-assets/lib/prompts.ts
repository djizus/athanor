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

  if (asset.id === 'world-bg') {
    return buildWorldBgPrompt();
  }

  if (asset.id.startsWith('zone-')) {
    return buildZoneNodePrompt(asset);
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

export function buildWorldBgPrompt(): string {
  return [
    `A top-down bird's-eye view dark atmospheric background for a fantasy alchemy RPG game. 16:9 widescreen composition (2560x1440).`,
    `Dense dark enchanted forest, misty void, jagged dark cliffs, and swirling black fog covering the entire frame. Completely dark and atmospheric — no landmarks, no structures, no points of interest, no paths, no corridors.`,
    `Just moody dark wilderness with subtle variations in darkness — hints of dark blue-black, dark purple-black, and dark green-black in the deepest shadows. Occasional faint bioluminescent motes barely visible in the darkness.`,
    `The central vertical band (35% of the width) should be very subtly lighter than the far edges to provide gentle framing, but still very dark — no features, just a slightly lifted darkness.`,
    GLOBAL_ART_STYLE,
    `Color palette: predominantly #080810 near-black with very subtle hints of #1a1d38 and #0a0a14. The center band is marginally less dark than edges.`,
    `Vignette: outermost 8% on all sides fades to pure black #080810.`,
    `No people, no text, no paths, no structures, no corridors, no UI elements, no watermarks.`,
  ].join(' ');
}

const ZONE_NODE_SUFFIX = [
  GLOBAL_ART_STYLE,
  `Wide horizontal floating platform composition, top-down bird's-eye perspective. The platform floats in dark void — edges dissolve smoothly, the outermost 12% on all sides fades to near-black #080810.`,
  `No people, no text, no labels, no UI elements, no watermarks.`,
].join(' ');

const ZONE_NODE_PROMPTS: Record<string, string> = {
  'zone-athanor': [
    `A top-down floating stone platform for an alchemy RPG. Circular alchemist's athanor furnace at center, cracked stone platform with concentric arcane circles etched into the surface, molten-gold (#c8a040) glow radiating from the central furnace, warm amber light, faint alchemical symbols glowing softly. Small braziers at platform edges. Ancient weathered stone with golden veins.`,
    `The warm glow creates a sense of safety and home. Primary tint: #c8a040 amber-gold. Warm inviting atmosphere.`,
  ].join(' '),
  'zone-hollows': [
    `A top-down floating cavern platform for an alchemy RPG. Golden cavern openings carved into amber-tinted rock, copper veins glowing in dark stone, stalactite fragments, scattered amber crystals catching warm light, small pools of liquid gold. Moss and bioluminescent lichen on rock edges.`,
    `Soft golden (#c8a040) illumination emanating from within the rock. Primary tint: #c8a040 golden amber. Warm underground atmosphere.`,
  ].join(' '),
  'zone-cavern': [
    `A top-down floating volcanic platform for an alchemy RPG. Volcanic fissures with molten lava visible below, smoldering dragon-fire residue on blackened stone, sulfur crystal formations, dark obsidian rock with orange-red (#b85030) magma glow seeping through cracks. Heat haze and ember particles rising.`,
    `Charred stone bridges over magma channels. Primary tint: #b85030 burnt orange. Hot volcanic atmosphere.`,
  ].join(' '),
  'zone-spire': [
    `A top-down floating ethereal platform for an alchemy RPG. Purple (#9e4a9e) crystalline structures, swirling arcane energy trails as faint light streams, glowing rune circles etched into polished dark stone, starlit atmosphere with floating motes of arcane light.`,
    `Fragmented floating stone pieces orbiting the main platform. Translucent crystal pillars. Primary tint: #9e4a9e purple. Mystical arcane atmosphere.`,
  ].join(' '),
  'zone-abyss': [
    `A top-down floating deep-water platform for an alchemy RPG. Partially submerged ancient stone ruins, bioluminescent blue (#2a5a8a) cave pearls embedded in rock, dripping stalactite formations, dark river channels cutting through weathered stone.`,
    `Glowing deep-sea flora, jellyfish-like bioluminescent organisms floating nearby. Wet reflective stone surfaces. Primary tint: #2a5a8a deep blue. Cold deep-water atmosphere.`,
  ].join(' '),
  'zone-crystalveil': [
    `A top-down floating crystalline frost platform for an alchemy RPG. Massive emerald (#2a8a6a) gemstone outcrops, crystalline frost formations catching teal light, frozen flower blooms preserved in ice, aurora wisps trailing across the surface.`,
    `Prismatic crystal clusters refracting light. Ice-covered ancient stone with embedded gems. The pinnacle of the journey. Primary tint: #2a8a6a emerald teal. Cold crystalline atmosphere.`,
  ].join(' '),
};

export function buildZoneNodePrompt(asset: ImageAssetDef): string {
  const body = ZONE_NODE_PROMPTS[asset.id];
  if (!body) {
    throw new Error(`No zone node prompt for asset id: ${asset.id}`);
  }
  return `${body} ${ZONE_NODE_SUFFIX}`;
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
