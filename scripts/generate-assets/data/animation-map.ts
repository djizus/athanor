export const ANIMATION_MAP = {
  idle:   { actionId: 89,  loop: true  },
  attack: { actionId: 4,   loop: false },
  hit:    { actionId: 178, loop: false },
  death:  { actionId: 8,   loop: false },
} as const;

export const RIGGABLE_CHARACTERS = [
  { id: "hero",        filename: "characters/hero.glb",        heightMeters: 1.7 },
  { id: "mob_ember",   filename: "characters/mob_ember.glb",   heightMeters: 1.5 },
  { id: "mob_aether",  filename: "characters/mob_aether.glb",  heightMeters: 1.8 },
  { id: "mob_sunken",  filename: "characters/mob_sunken.glb",  heightMeters: 1.4 },
  { id: "mob_crystal", filename: "characters/mob_crystal.glb", heightMeters: 2.0 },
] as const;

export type AnimName = keyof typeof ANIMATION_MAP;
