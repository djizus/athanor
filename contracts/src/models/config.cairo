use starknet::ContractAddress;

// --- Singleton system config (key = 0) ---
// Stores external addresses used by all systems.
// Written once in dojo_init, read via Store.

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Config {
    #[key]
    pub key: felt252,
    pub token_address: ContractAddress,
    pub vrf_address: ContractAddress,
    pub lords_address: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GameSettings {
    #[key]
    pub settings_id: u32,
    pub mode: felt252,
    pub grid_size: u8,
    pub hero_class: u8,
    pub hero_hp: u16,
    pub hero_stamina: u16,
    pub archetype_count: u8,
    pub max_enemy_count: u8,
    pub ramp_curve_id: u8,
    // Entry fee in mLORDS smallest units (18 decimals). 0 = free tier (offline / dev).
    pub entry_fee_lords: u128,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GameSettingsMetadata {
    #[key]
    pub settings_id: u32,
    pub name: felt252,
    pub created_by: ContractAddress,
    pub created_at: u64,
    pub is_active: bool,
}

#[generate_trait]
pub impl GameSettingsImpl of GameSettingsTrait {
    fn new_default() -> GameSettings {
        GameSettings {
            settings_id: 1,
            mode: 'Bronze',
            grid_size: 8,
            hero_class: 0,
            hero_hp: 100,
            hero_stamina: 500,
            archetype_count: 5,
            max_enemy_count: 8,
            ramp_curve_id: 0,
            // 100 mLORDS × 10^18
            entry_fee_lords: 100_000_000_000_000_000_000_u128,
        }
    }

    fn new_silver() -> GameSettings {
        GameSettings {
            settings_id: 2,
            mode: 'Silver',
            grid_size: 8,
            hero_class: 0,
            hero_hp: 100,
            hero_stamina: 1500,
            archetype_count: 5,
            max_enemy_count: 8,
            ramp_curve_id: 0,
            // 500 mLORDS × 10^18
            entry_fee_lords: 500_000_000_000_000_000_000_u128,
        }
    }

    fn new_gold() -> GameSettings {
        GameSettings {
            settings_id: 3,
            mode: 'Gold',
            grid_size: 8,
            hero_class: 0,
            hero_hp: 100,
            hero_stamina: 4000,
            archetype_count: 5,
            max_enemy_count: 8,
            ramp_curve_id: 0,
            // 1000 mLORDS × 10^18
            entry_fee_lords: 1000_000_000_000_000_000_000_u128,
        }
    }

    fn exists(self: @GameSettings) -> bool {
        *self.grid_size > 0
    }
}

#[cfg(test)]
mod tests {
    use super::GameSettingsTrait;

    const LORDS_WEI: u128 = 1_000_000_000_000_000_000_u128;

    #[test]
    fn test_bronze_tier() {
        let s = GameSettingsTrait::new_default();
        assert!(s.settings_id == 1, "bronze settings_id");
        assert!(s.mode == 'Bronze', "bronze mode");
        assert!(s.hero_stamina == 500, "bronze stamina");
        assert!(s.hero_hp == 100, "bronze hp unchanged");
        assert!(s.entry_fee_lords == 100_u128 * LORDS_WEI, "bronze entry fee");
    }

    #[test]
    fn test_silver_tier() {
        let s = GameSettingsTrait::new_silver();
        assert!(s.settings_id == 2, "silver settings_id");
        assert!(s.mode == 'Silver', "silver mode");
        assert!(s.hero_stamina == 1500, "silver stamina");
        assert!(s.entry_fee_lords == 500_u128 * LORDS_WEI, "silver entry fee");
    }

    #[test]
    fn test_gold_tier() {
        let s = GameSettingsTrait::new_gold();
        assert!(s.settings_id == 3, "gold settings_id");
        assert!(s.mode == 'Gold', "gold mode");
        assert!(s.hero_stamina == 4000, "gold stamina");
        assert!(s.entry_fee_lords == 1000_u128 * LORDS_WEI, "gold entry fee");
    }

    #[test]
    fn test_tier_ratio_1_3_8() {
        // Bronze:Silver:Gold = 1:3:8 ratio is a design invariant; if you change a tier
        // number, update this test and the main-menu labels together.
        let b = GameSettingsTrait::new_default();
        let s = GameSettingsTrait::new_silver();
        let g = GameSettingsTrait::new_gold();
        assert!(s.hero_stamina == b.hero_stamina * 3, "silver = 3x bronze");
        assert!(g.hero_stamina == b.hero_stamina * 8, "gold = 8x bronze");
    }
}
