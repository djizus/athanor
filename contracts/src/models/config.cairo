use athanor::constants;
use starknet::ContractAddress;

// --- Singleton system config (key = 0) ---
// Stores external addresses used by all systems.
// Written once in game_system.dojo_init, read via Store.

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
    pub zone_count: u8,
    pub ingredients_per_zone: u8,
    pub recipes_to_discover: u8,
    pub max_heroes: u8,
    pub hero_base_hp: u16,
    pub hero_base_power: u16,
    pub hero_base_regen: u16,
    pub hint_base_cost: u16,
    pub hint_cost_multiplier: u8,
    pub soup_gold_value: u8,
    pub progressive_cap: u16,
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
            settings_id: 0,
            zone_count: constants::ZONE_COUNT,
            ingredients_per_zone: constants::INGREDIENTS_PER_ZONE,
            recipes_to_discover: constants::RECIPES_TO_DISCOVER,
            max_heroes: constants::MAX_HEROES,
            hero_base_hp: constants::HERO_BASE_HP,
            hero_base_power: constants::HERO_BASE_POWER,
            hero_base_regen: constants::HERO_BASE_REGEN,
            hint_base_cost: constants::HINT_BASE_COST,
            hint_cost_multiplier: constants::DEFAULT_HINT_MULTIPLIER,
            soup_gold_value: constants::SOUP_GOLD_VALUE,
            progressive_cap: constants::PROGRESSIVE_CAP,
        }
    }

    fn exists(self: @GameSettings) -> bool {
        *self.zone_count > 0
    }
}
