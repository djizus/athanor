// Mirrors contracts/src/models/config.cairo GameSettingsTrait.
// settings_id passed to spawn() on-chain; also sizes offline runs.
// entryFeeLords is stored on-chain in raw u128 wei (18 decimals); this mirror
// lets the client display the cost before submitting.

export interface Tier {
  settingsId: number;
  name: string;
  stamina: number;
  /** Whole-token entry fee (human-readable). Raw u128 = entryFeeLords * 1e18. */
  entryFeeLords: bigint;
}

export const TIER_BRONZE: Tier = {
  settingsId: 1,
  name: "Bronze",
  stamina: 500,
  entryFeeLords: 100n,
};
export const TIER_SILVER: Tier = {
  settingsId: 2,
  name: "Silver",
  stamina: 1500,
  entryFeeLords: 500n,
};
export const TIER_GOLD: Tier = {
  settingsId: 3,
  name: "Gold",
  stamina: 4000,
  entryFeeLords: 1000n,
};

export const TIERS: Tier[] = [TIER_BRONZE, TIER_SILVER, TIER_GOLD];

export const LORDS_DECIMALS = 18n;
export const LORDS_WEI = 10n ** LORDS_DECIMALS;

export function tierById(settingsId: number): Tier {
  return TIERS.find((t) => t.settingsId === settingsId) ?? TIER_BRONZE;
}

export function tierFeeRaw(tier: Tier): bigint {
  return tier.entryFeeLords * LORDS_WEI;
}
