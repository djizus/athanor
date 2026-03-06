export const GAME_WIDTH = 1280;
export const GAME_HEIGHT = 720;
export const WORLD_WIDTH = 2560;

export const ZONE_0_X = 0;
export const ZONE_1_X = 854;
export const ZONE_2_X = 1707;

export const BASE_CAMP_X = 120;

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
