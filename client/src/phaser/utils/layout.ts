export const PORTAL_COUNT = 5;

export interface PortalLayout {
  cauldronX: number;
  cauldronY: number;
  portalPositions: { x: number; y: number }[];
  /** Idle hero positions near the cauldron */
  heroIdleX: number;
  heroIdleY: number;
}

export function computePortalLayout(screenWidth: number, screenHeight: number): PortalLayout {
  const centerX = screenWidth / 2;

  const cauldronX = centerX;
  const cauldronY = screenHeight * 0.78;

  const arcCenterY = screenHeight * 0.38;
  const arcRadius = Math.min(
    Math.max(screenHeight * 0.28, 100),
    Math.min(screenWidth * 0.38, 300),
  );

  const arcDegrees = [-70, -35, 0, 35, 70];
  const portalPositions = arcDegrees.map((deg) => {
    const rad = ((deg - 90) * Math.PI) / 180; // offset -90° so 0° points upward
    return {
      x: centerX + Math.cos(rad) * arcRadius,
      y: arcCenterY + Math.sin(rad) * arcRadius,
    };
  });

  return {
    cauldronX,
    cauldronY,
    portalPositions,
    heroIdleX: cauldronX,
    heroIdleY: cauldronY - 50,
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
