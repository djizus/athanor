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
    /// Single-mode POC: "Standard". Low HP / tight stamina per turn, endless run.
    /// `hero_stamina` is the PER-TURN cap, refilled each player turn — it is
    /// NOT a run-total budget. See systems::actions for refill logic.
    fn new_default() -> GameSettings {
        GameSettings {
            settings_id: 1,
            mode: 'Standard',
            grid_size: 8,
            hero_class: 0,
            hero_hp: 80,
            hero_stamina: 80,
            // 7 archetypes: Brute, Caster, Flanker, Heavy, Puller, Drainer, Marksman.
            archetype_count: 7,
            max_enemy_count: 8,
            ramp_curve_id: 0,
            // 100 mLORDS × 10^18
            entry_fee_lords: 100_000_000_000_000_000_000_u128,
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
    fn test_standard_mode() {
        let s = GameSettingsTrait::new_default();
        assert!(s.settings_id == 1, "settings_id");
        assert!(s.mode == 'Standard', "mode");
        // Per-turn stamina cap, NOT run-total budget.
        assert!(s.hero_stamina == 80, "per-turn stamina cap");
        assert!(s.hero_hp == 80, "hero hp");
        assert!(s.archetype_count == 6, "drainer archetype included");
        assert!(s.entry_fee_lords == 100_u128 * LORDS_WEI, "entry fee");
    }
}
