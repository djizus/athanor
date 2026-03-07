/** Reference dimensions of the world-map image (for cover-fit calculation) */
export const MAP_WIDTH = 2560;
export const MAP_HEIGHT = 1440;

/** Preferred gameplay strip width on desktop (auto-shrinks on small screens) */
export const GAMEPLAY_PREFERRED_WIDTH = 1400;

/** Base camp X offset from left edge of gameplay strip */
export const BASE_CAMP_X = 80;

/** Zone boundaries as fractions of gameplay width */
export const ZONE_FRAC_0 = 0;
export const ZONE_FRAC_1 = 1 / 3;
export const ZONE_FRAC_2 = 2 / 3;

/** Hero vertical position as fraction of screen height (bottom of visible map) */
export const HERO_Y_RATIO = 0.82;
export const HERO_ROW_SPACING = 48;

/** Compute actual gameplay strip width for current screen */
export function getGameplayWidth(screenWidth: number): number {
  return Math.min(GAMEPLAY_PREFERRED_WIDTH, screenWidth * 0.9);
}

/** Compute left-edge offset of gameplay strip (centered) */
export function getGameplayOffsetX(screenWidth: number): number {
  return (screenWidth - getGameplayWidth(screenWidth)) / 2;
}

/** Compute zone X boundary in screen coordinates */
export function zoneWorldX(zoneFraction: number, screenWidth: number): number {
  const gpWidth = getGameplayWidth(screenWidth);
  const offsetX = (screenWidth - gpWidth) / 2;
  return offsetX + zoneFraction * gpWidth;
}

/** Compute hero screen X from exploration depth (0-60) */
export function heroWorldX(depth: number, screenWidth: number): number {
  const gpWidth = getGameplayWidth(screenWidth);
  const offsetX = (screenWidth - gpWidth) / 2;
  const progress = Math.min(Math.max(depth / 60, 0), 1);
  return offsetX + BASE_CAMP_X + progress * (gpWidth - BASE_CAMP_X - 60);
}

/** Compute base camp screen X (horizontal center) */
export function baseCampWorldX(screenWidth: number): number {
  return screenWidth / 2;
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
