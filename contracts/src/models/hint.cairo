use crate::helpers::bitmap::Bitmap;
pub use crate::models::index::Hint;
use crate::typess::effect::{Effect, EffectTrait};
use crate::typess::ingredient::Ingredient;

pub mod Errors {
    pub const RECIPE_ALREADY_IN_HINT: felt252 = 'Recipe already in hint';
}

#[generate_trait]
pub impl HintImpl of HintTrait {
    fn new(game_id: u64, ingredient: Ingredient) -> Hint {
        Hint { game_id, ingredient: ingredient.into(), recipes: 0 }
    }

    fn add(ref self: Hint, recipe: Effect) {
        // [Check] Recipe is not already in the hint
        let index = recipe.index();
        let bit = Bitmap::get(self.recipes, index);
        assert(bit == 0, Errors::RECIPE_ALREADY_IN_HINT);
        // [Effect] Add recipe to the hint
        self.recipes = Bitmap::set(self.recipes, recipe.index());
    }
}
