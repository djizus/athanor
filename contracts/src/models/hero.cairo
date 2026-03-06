#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Hero {
    #[key]
    pub game_id: u64,
    #[key]
    pub hero_id: u8,
    pub hp: u16,
    pub max_hp: u16,
    pub power: u16,
    pub regen_per_sec: u16,
    pub status: u8,
    pub expedition_seed: felt252,
    pub expedition_start: u64,
    pub return_at: u64,
    pub death_depth: u16,
    pub pending_gold: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct HeroPendingIngredient {
    #[key]
    pub game_id: u64,
    #[key]
    pub hero_id: u8,
    #[key]
    pub ingredient_id: u8,
    pub quantity: u16,
}
