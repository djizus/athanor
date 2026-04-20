// Mirrors contracts/src/models/config.cairo GameSettingsTrait::new_default.
// Single-mode POC: one "Standard" config, passed as settings_id=1 to spawn().
// The Tier type stays so the rest of the client keeps a single run-config
// object; re-adding tiers later just means more entries in TIERS.
// entryFeeLords is stored on-chain in raw u128 wei (18 decimals); this mirror
// lets the client display the cost before submitting.

export interface Tier {
  settingsId: number;
  name: string;
  /** Per-turn stamina cap. Refilled each player turn — NOT a run-total budget. */
  staminaPerTurn: number;
  /** Starting hero HP. Run ends only when HP hits 0. */
  heroHp: number;
  /** Whole-token entry fee (human-readable). Raw u128 = entryFeeLords * 1e18. */
  entryFeeLords: bigint;
}

export const TIER_STANDARD: Tier = {
  settingsId: 1,
  name: "Standard",
  staminaPerTurn: 80,
  heroHp: 80,
  entryFeeLords: 100n,
};

export const TIERS: Tier[] = [TIER_STANDARD];

export const LORDS_DECIMALS = 18n;
export const LORDS_WEI = 10n ** LORDS_DECIMALS;

export function tierById(settingsId: number): Tier {
  return TIERS.find((t) => t.settingsId === settingsId) ?? TIER_STANDARD;
}

export function tierFeeRaw(tier: Tier): bigint {
  return tier.entryFeeLords * LORDS_WEI;
}
