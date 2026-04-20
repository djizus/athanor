// Mirrors contracts/src/constants.cairo. Keep in sync when tuning.

export const GRID_WIDTH = 8;
export const GRID_HEIGHT = 8;

export const MOVE_COST_PER_TILE = 10;

export const STRIKE_COST = 20;
export const STRIKE_COOLDOWN = 0;
export const STRIKE_DAMAGE = 15;

export const DASH_COST = 20;
export const DASH_COOLDOWN = 1;
export const DASH_DAMAGE = 10;

export const HEAL_COST = 25;
export const HEAL_COOLDOWN = 3;
export const HEAL_AMOUNT = 20;

export const SHOVE_COST = 20;
export const SHOVE_COOLDOWN = 1;
export const SHOVE_DAMAGE = 5;
export const SHOVE_PUSH_DISTANCE = 2;

export const SLAM_COST = 35;
export const SLAM_COOLDOWN = 2;
export const SLAM_DAMAGE = 10;
export const SLAM_PUSH_DISTANCE = 1;

export const ORB_STAMINA_BONUS = 20;
export const ORB_HP_BONUS = 10;
export const STAMINA_DRAIN_AMOUNT = 20;

export const HERO_OFFENSE = 20;
export const HERO_DEFENSE = 5;
export const HERO_SPEED = 10;

// HERO_HP removed: hero HP now comes from the active Tier (see state/tiers.ts)
// so the single source of truth matches GameSettings.hero_hp on-chain.

export const ABILITY_STRIKE = 0;
export const ABILITY_DASH = 1;
export const ABILITY_HEAL = 2;
export const ABILITY_SHOVE = 3;
export const ABILITY_SLAM = 4;

export type AbilityId =
  | typeof ABILITY_STRIKE
  | typeof ABILITY_DASH
  | typeof ABILITY_HEAL
  | typeof ABILITY_SHOVE
  | typeof ABILITY_SLAM;

export type AbilityTargetKind = "adjacent" | "line" | "self";

export interface AbilityDef {
  id: AbilityId;
  name: string;
  cost: number;
  cooldown: number;
  target: AbilityTargetKind;
  rangeTiles: number;
  description: string;
}

export const ABILITIES: AbilityDef[] = [
  {
    id: ABILITY_STRIKE,
    name: "Strike",
    cost: STRIKE_COST,
    cooldown: STRIKE_COOLDOWN,
    target: "adjacent",
    rangeTiles: 1,
    description: "Melee attack against an adjacent target.",
  },
  {
    id: ABILITY_DASH,
    name: "Dash",
    cost: DASH_COST,
    cooldown: DASH_COOLDOWN,
    target: "line",
    rangeTiles: 3,
    description: "Move in a line and strike on impact.",
  },
  {
    id: ABILITY_HEAL,
    name: "Heal",
    cost: HEAL_COST,
    cooldown: HEAL_COOLDOWN,
    target: "self",
    rangeTiles: 0,
    description: "Restore 20 HP to yourself.",
  },
  {
    id: ABILITY_SHOVE,
    name: "Shove",
    cost: SHOVE_COST,
    cooldown: SHOVE_COOLDOWN,
    target: "adjacent",
    rangeTiles: 1,
    description: "Push an adjacent enemy 2 tiles, dealing damage first.",
  },
  {
    id: ABILITY_SLAM,
    name: "Slam",
    cost: SLAM_COST,
    cooldown: SLAM_COOLDOWN,
    target: "self",
    rangeTiles: 0,
    description: "Hit all adjacent enemies and push them back 1 tile.",
  },
];
