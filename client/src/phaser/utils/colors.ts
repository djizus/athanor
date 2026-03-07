export const COLORS = {
  bgPrimary: 0x080810,
  bgSecondary: 0x111122,
  bgPanel: 0x13152a,
  bgCard: 0x1a1d38,

  textPrimary: 0xe4e4f0,
  textSecondary: 0x9090b0,
  textMuted: 0x5a5a7a,

  gold: 0xf0c040,
  goldDim: 0xa08020,
  green: 0x40c060,
  red: 0xd04050,
  blue: 0x4080d0,
  purple: 0xa050d0,

  border: 0x252848,
  borderGlow: 0x353868,

  hpGreen: 0x50c040,
  hpRed: 0xd04040,

  white: 0xffffff,
  black: 0x000000,
} as const;

export const ZONE_TINTS: readonly number[] = [
  0xc8a040, // Zone 0 — Amber Hollows
  0xb85030, // Zone 1 — Ember Cavern
  0x9e4a9e, // Zone 2 — Aether Spire
  0x2a5a8a, // Zone 3 — Sunken Abyss
  0x2a8a6a, // Zone 4 — Crystalveil Reach
];

export function hexToCSS(hex: number): string {
  return '#' + hex.toString(16).padStart(6, '0');
}
