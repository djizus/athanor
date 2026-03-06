#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Recipe {
    #[key]
    pub game_id: u64,
    #[key]
    pub recipe_id: u8,
    pub ingredient_a: u8,
    pub ingredient_b: u8,
    pub effect_type: u8,
    pub effect_value: u8,
    pub discovered: bool,
}
