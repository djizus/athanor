/** Reference dimensions of the background image (for cover-fit calculation) */
export const MAP_WIDTH = 2560;
export const MAP_HEIGHT = 1440;

/** Preferred gameplay strip width on desktop (auto-shrinks on small screens) */
export const GAMEPLAY_PREFERRED_WIDTH = 1400;

/** Corridor width as fraction of gameplay width (matches world-map prompt: 35%) */
export const CORRIDOR_FRACTION = 0.35;

/** Zone node aspect ratio matching generation size 2048×512 */
export const NODE_ASPECT_RATIO = 4;

/** Total zone nodes: Athanor (rest) + 5 exploration zones */
export const NODE_COUNT = 6;

export const NODE_TOP_PADDING = 64;
export const NODE_BOTTOM_PADDING = 24;

export const HERO_SLOT_SIZE = 80;
export const HERO_SLOT_SPACING = 12;

/** Compute actual gameplay strip width for current screen */
export function getGameplayWidth(screenWidth: number): number {
  return Math.min(GAMEPLAY_PREFERRED_WIDTH, screenWidth * 0.9);
}

// ─── Node graph layout ───

export interface NodeLayout {
  /** Center X of all nodes (corridor center) */
  centerX: number;
  /** Display width of each node */
  nodeWidth: number;
  /** Display height of each node */
  nodeHeight: number;
  /** Center-to-center vertical spacing */
  nodeSpacing: number;
  /** Y coordinate for each node index (0=Athanor at bottom, 5=Crystalveil at top) */
  nodeY: (zoneIndex: number) => number;
}

/** Compute full node graph layout for current screen dimensions */
export function computeNodeLayout(screenWidth: number, screenHeight: number): NodeLayout {
  const gpWidth = getGameplayWidth(screenWidth);
  const corridorWidth = gpWidth * CORRIDOR_FRACTION;
  const centerX = screenWidth / 2;

  const availableHeight = screenHeight - NODE_TOP_PADDING - NODE_BOTTOM_PADDING;
  const nodeSpacing = availableHeight / NODE_COUNT;

  /* Node height: constrained by corridor width (aspect ratio) AND vertical fit */
  const maxHeightFromWidth = corridorWidth / NODE_ASPECT_RATIO;
  const maxHeightFromFit = nodeSpacing * 0.62;
  const nodeHeight = Math.min(maxHeightFromWidth, maxHeightFromFit);
  const nodeWidth = nodeHeight * NODE_ASPECT_RATIO;

  const bottomY = screenHeight - NODE_BOTTOM_PADDING - nodeSpacing / 2;

  return {
    centerX,
    nodeWidth,
    nodeHeight,
    nodeSpacing,
    nodeY: (zoneIndex: number) => bottomY - zoneIndex * nodeSpacing,
  };
}

/** Get hero slot positions within a node (up to 3 heroes, centered horizontally) */
export function getHeroSlotX(slotIndex: number, heroCount: number): number {
  const totalWidth = heroCount * HERO_SLOT_SIZE + (heroCount - 1) * HERO_SLOT_SPACING;
  const startX = -totalWidth / 2 + HERO_SLOT_SIZE / 2;
  return startX + slotIndex * (HERO_SLOT_SIZE + HERO_SLOT_SPACING);
}

/** Y offset for hero slots below the node center */
export const HERO_SLOT_Y_OFFSET = 8;

export const FONTS = {
  title: {
    fontFamily: 'MedievalSharp, serif',
    fontSize: '18px',
    color: '#f0c040',
    fontStyle: 'bold',
  },
  body: {
    fontFamily: 'Cormorant Garamond, serif',
    fontSize: '15px',
    color: '#e4e4f0',
  },
  bodySmall: {
    fontFamily: 'Cormorant Garamond, serif',
    fontSize: '13px',
    color: '#9090b0',
  },
  stat: {
    fontFamily: 'Cormorant Garamond, serif',
    fontSize: '12px',
    color: '#9090b0',
  },
  gold: {
    fontFamily: 'MedievalSharp, serif',
    fontSize: '16px',
    color: '#f0c040',
    fontStyle: 'bold',
  },
} as const;
