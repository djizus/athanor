/** Zone node native size (matches generated asset dimensions) */
export const NODE_NATIVE_WIDTH = 2048;
export const NODE_NATIVE_HEIGHT = 512;
export const NODE_ASPECT_RATIO = NODE_NATIVE_WIDTH / NODE_NATIVE_HEIGHT;

export const NODE_COUNT = 6;

export const NODE_TOP_PADDING = 64;
export const NODE_BOTTOM_PADDING = 24;

export const HERO_SLOT_SIZE = 80;
export const HERO_SLOT_SPACING = 12;

// ─── Node graph layout ───

export interface NodeLayout {
  centerX: number;
  nodeWidth: number;
  nodeHeight: number;
  nodeSpacing: number;
  nodeY: (zoneIndex: number) => number;
}

export function computeNodeLayout(screenWidth: number, screenHeight: number): NodeLayout {
  const centerX = screenWidth / 2;

  const availableHeight = screenHeight - NODE_TOP_PADDING - NODE_BOTTOM_PADDING;
  const nodeSpacing = availableHeight / NODE_COUNT;

  const maxWidthFromScreen = screenWidth * 0.82;
  const maxHeightFromFit = nodeSpacing * 0.62;
  const maxHeightFromWidth = maxWidthFromScreen / NODE_ASPECT_RATIO;

  let nodeHeight = Math.min(maxHeightFromWidth, maxHeightFromFit);

  // Never upscale past native resolution
  nodeHeight = Math.min(nodeHeight, NODE_NATIVE_HEIGHT);
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

export function getHeroSlotX(slotIndex: number, heroCount: number): number {
  const totalWidth = heroCount * HERO_SLOT_SIZE + (heroCount - 1) * HERO_SLOT_SPACING;
  const startX = -totalWidth / 2 + HERO_SLOT_SIZE / 2;
  return startX + slotIndex * (HERO_SLOT_SIZE + HERO_SLOT_SPACING);
}

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
