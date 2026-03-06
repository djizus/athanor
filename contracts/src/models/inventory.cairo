#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct IngredientBalance {
    #[key]
    pub game_id: u64,
    #[key]
    pub ingredient_id: u8,
    pub quantity: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PotionItem {
    #[key]
    pub game_id: u64,
    #[key]
    pub potion_index: u16,
    pub recipe_id: u8,
    pub effect_type: u8,
    pub effect_value: u8,
}
