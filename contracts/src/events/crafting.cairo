pub use crate::events::index::RecipeDiscovered;

#[generate_trait]
pub impl RecipeDiscoveredImpl of RecipeDiscoveredTrait {
    fn new(
        game_id: u64,
        recipe_id: u8,
        ingredient_a: u8,
        ingredient_b: u8,
        effect_type: u8,
        discovered_count: u8,
    ) -> RecipeDiscovered {
        RecipeDiscovered {
            game_id, recipe_id, ingredient_a, ingredient_b, effect_type, discovered_count,
        }
    }
}
