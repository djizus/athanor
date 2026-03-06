use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ExplorationEvent {
    #[key]
    pub game_id: u64,
    #[key]
    pub event_index: u16,
    pub hero_id: u8,
    pub depth: u16,
    pub zone_id: u8,
    pub event_kind: u8,
    pub value: u16,
    pub hp_after: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct GameCreated {
    #[key]
    pub game_id: u64,
    pub player: ContractAddress,
    pub settings_id: u32,
    pub seed: felt252,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ExpeditionStarted {
    #[key]
    pub game_id: u64,
    pub hero_id: u8,
    pub death_depth: u16,
    pub return_at: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct LootClaimed {
    #[key]
    pub game_id: u64,
    pub hero_id: u8,
    pub gold: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct RecipeDiscovered {
    #[key]
    pub game_id: u64,
    pub recipe_id: u8,
    pub ingredient_a: u8,
    pub ingredient_b: u8,
    pub effect_type: u8,
    pub discovered_count: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct PotionApplied {
    #[key]
    pub game_id: u64,
    pub hero_id: u8,
    pub potion_index: u16,
    pub effect_type: u8,
    pub effect_value: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct HeroRecruited {
    #[key]
    pub game_id: u64,
    pub hero_id: u8,
    pub cost: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct GrimoireCompleted {
    #[key]
    pub game_id: u64,
    pub player: ContractAddress,
    pub completion_time: u64,
}
