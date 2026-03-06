#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Game {
    #[key]
    pub id: u64,
    pub heroes: u8,
    pub started_at: u64,
    pub ended_at: u64,
    pub remaining_tries: u16,
    pub gold: u32,
    pub hint_price: u32,
    pub grimoire: u32, // Bitmap of recipes that have been discovered
    pub hints: u32, // Bitmap of recipes with hints
    pub tries: u128, // Number of tries done per ingredient: 25 ingredients x 5 bits = 125 bits
    pub ingredients: felt252, // Balance of ingredients: 25 ingredients x 10 bits = 250 bits
    pub effects: felt252, // Balance of effects: 30 effects x 8 bits = 240 bits
    pub seed: felt252,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Discovery {
    #[key]
    pub game_id: u64,
    #[key]
    pub ingredient_a: u8,
    #[key]
    pub ingredient_b: u8,
    pub effect: u8,
    pub discovered: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Hint {
    #[key]
    pub game_id: u64,
    #[key]
    pub ingredient: u8,
    pub recipes: u32 // Bitmap of recipes that can be crafted with this ingredient
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Character {
    #[key]
    pub game_id: u64,
    #[key]
    pub id: u8,
    pub role: u8,
    pub health: u16,
    pub max_health: u16,
    pub power: u16,
    pub regen: u16,
    pub gold: u32,
    pub available_at: u64,
    pub ingredients: felt252,
}
