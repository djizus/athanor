export const PORTAL_COUNT = 5;

const TOP_PADDING = 70;

export interface PortalLayout {
  cauldronX: number;
  cauldronY: number;
  portalPositions: { x: number; y: number }[];
  heroIdleX: number;
  heroIdleY: number;
}

export function computePortalLayout(screenWidth: number, screenHeight: number): PortalLayout {
  const centerX = screenWidth / 2;
  const cauldronX = centerX;
  const cauldronY = screenHeight * 0.88;
  const zigzagOffset = screenWidth * 0.12;

  const topY = TOP_PADDING + 60;
  const bottomY = cauldronY - 100;
  const spacing = (bottomY - topY) / (PORTAL_COUNT - 1);

  const portalPositions: { x: number; y: number }[] = [];
  for (let i = 0; i < PORTAL_COUNT; i++) {
    const xOffset = i % 2 === 0 ? -zigzagOffset : zigzagOffset;
    portalPositions.push({
      x: centerX + xOffset,
      y: bottomY - i * spacing,
    });
  }

  return {
    cauldronX,
    cauldronY,
    portalPositions,
    heroIdleX: cauldronX,
    heroIdleY: cauldronY - 40,
  };
}

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
