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
            mode: 'Endless',
            grid_size: 8,
            hero_class: 0,
            hero_hp: 100,
            hero_stamina: 80,
            archetype_count: 5,
            max_enemy_count: 8,
            ramp_curve_id: 0,
        }
    }

    fn exists(self: @GameSettings) -> bool {
        *self.grid_size > 0
    }
}
