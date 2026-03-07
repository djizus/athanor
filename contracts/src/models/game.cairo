use core::num::traits::{Bounded, Pow};
use crate::constants::{
    DEFAULT_HERO_COSTS, DEFAULT_HINT_COST, DEFAULT_HINT_MULTIPLIER, DEFAULT_INGREDIENTS,
    DEFAULT_MAX_HEROES,
};
use crate::helpers::bitmap::Bitmap;
use crate::helpers::crafter::Crafter;
use crate::helpers::packer::Packer;
pub use crate::models::index::Game;
use crate::typess::effect::{ALL_EFFECTS, EFFECT_COUNT, Effect, EffectTrait};
use crate::typess::ingredient::{INGREDIENT_COUNT, Ingredient, IngredientTrait};
use crate::typess::role::{Role, RoleTrait};

pub const TRY_SIZE: u16 = 2_u16.pow(5);
pub const INGREDIENT_SIZE: u16 = 2_u16.pow(10);
pub const EFFECT_SIZE: u16 = 2_u16.pow(8);
pub const MULTIPLIER: u32 = 10_000;

pub mod Errors {
    pub const GAME_OVER: felt252 = 'Game is over';
    pub const GAME_NOT_OVER: felt252 = 'Game not over';
    pub const GAME_MISSING_EFFECTS: felt252 = 'Game: missing effects';
    pub const GAME_MISSING_INGREDIENTS: felt252 = 'Game: missing ingredients';
    pub const GAME_INVALID_INGREDIENTS: felt252 = 'Game: invalid ingredients';
    pub const GAME_NOT_ENOUGH_GOLD: felt252 = 'Game: not enough gold';
    pub const GAME_NOT_STARTED: felt252 = 'Game: not started';
    pub const GAME_IS_STARTED: felt252 = 'Game: is started';
    pub const GAME_MAX_HEROES: felt252 = 'Game: max heroes';
    pub const GAME_NO_ELIGIBLE_EFFECTS: felt252 = 'Game: no eligible effects';
    pub const GAME_NO_ELIGIBLE_INGREDIENTS: felt252 = 'Game: no eligible ingredients';
}

#[generate_trait]
pub impl GameImpl of GameTrait {
    #[inline]
    fn new(id: u64, seed: felt252) -> Game {
        Game {
            id,
            heroes: 0,
            started_at: 0,
            ended_at: 0,
            remaining_tries: INGREDIENT_COUNT.into() * (INGREDIENT_COUNT.into() - 1) / 2,
            gold: 0,
            hint_price: DEFAULT_HINT_COST,
            grimoire: 0,
            hints: 0,
            ingredients: DEFAULT_INGREDIENTS,
            effects: 0,
            tries: 0,
            seed: seed,
        }
    }

    #[inline]
    fn is_over(self: @Game) -> bool {
        self.ended_at != @0
    }

    #[inline]
    fn score(self: @Game) -> u32 {
        if self.ended_at < self.started_at {
            return 0;
        }
        return (*self.ended_at - *self.started_at).try_into().unwrap();
    }

    #[inline]
    fn start(ref self: Game) -> (u8, Role) {
        self.started_at = starknet::get_block_timestamp();
        self.recruit(self.seed.into())
    }

    #[inline]
    fn assess(ref self: Game) {
        // [Check] All recipes must be discovered
        if Bitmap::popcount(self.grimoire) != EFFECT_COUNT {
            return;
        }
        self.ended_at = starknet::get_block_timestamp();
    }

    #[inline]
    fn learn(ref self: Game, ingredient_a: Ingredient, ingredient_b: Ingredient, recipe: Effect) {
        // [Effect] Reduce remaining tries
        let index_a = ingredient_a.index().into();
        let index_b = ingredient_b.index().into();
        let mut counts = Packer::unpack(self.tries, TRY_SIZE, INGREDIENT_COUNT);
        for index in 0_u32..INGREDIENT_COUNT.into() {
            let mut count = counts.pop_front().unwrap();
            if index == index_a || index == index_b {
                count += 1;
            }
            counts.append(count);
        }
        self.tries = Packer::pack(counts, TRY_SIZE);
        self.remaining_tries -= 1;
        // [Effect] Give 1 gold if recipe is none
        if recipe == Effect::None {
            return;
        }
        // [Effect] Update grimoire
        self.grimoire = Bitmap::set(self.grimoire, recipe.index());
    }

    #[inline]
    fn earn(ref self: Game, gold: u32) {
        self.gold += gold;
    }

    #[inline]
    fn spend(ref self: Game, gold: u32) {
        // [Check] Enough gold
        assert(self.gold >= gold, Errors::GAME_NOT_ENOUGH_GOLD);
        // [Effect] Subtract gold
        self.gold -= gold;
    }

    #[inline]
    fn recruit(ref self: Game, rng: u256) -> (u8, Role) {
        // [Check] Not at max heroes
        let count = Bitmap::popcount(self.heroes);
        assert(count < DEFAULT_MAX_HEROES, Errors::GAME_MAX_HEROES);
        // [Effect] Spend gold
        let cost = DEFAULT_HERO_COSTS.span().at(count.into());
        self.spend(*cost);
        // [Effect] Add hero
        let role: Role = RoleTrait::draw(self.heroes, rng.low);
        self.heroes = Bitmap::set(self.heroes, role.index());
        // [Return] Role
        (count, role)
    }

    #[inline]
    fn merge(ref self: Game, ingredients: u256) {
        // [Effect] Add ingredient to the balance
        let mut quantities: Array<u16> = Packer::unpack(
            ingredients, INGREDIENT_SIZE, INGREDIENT_COUNT.into(),
        );
        let ingredients: u256 = self.ingredients.into();
        let mut balances: Array<u16> = Packer::unpack(
            ingredients, INGREDIENT_SIZE, INGREDIENT_COUNT.into(),
        );
        for _index in 0_u32..INGREDIENT_COUNT.into() {
            let quantity: u32 = quantities.pop_front().unwrap().into();
            let balance: u32 = balances.pop_front().unwrap().into();
            // [Info] Handle overflow
            let value: u32 = core::cmp::min(balance + quantity, Bounded::<u16>::MAX.into());
            balances.append(value.try_into().unwrap());
        }
        let ingredients: u256 = Packer::pack(balances, INGREDIENT_SIZE);
        self.ingredients = ingredients.try_into().unwrap();
    }

    #[inline]
    fn store(ref self: Game, effect: Effect, quantity: u16) {
        // [Check] Skip if effect is none
        if effect == Effect::None {
            // [Effect] Earn 1 gold
            self.earn(1);
            return;
        }
        // [Effect] Add effect to the balance
        let balance_index: u32 = effect.index().into();
        let effects: u256 = self.effects.into();
        let mut balances: Array<u16> = Packer::unpack(effects, EFFECT_SIZE, EFFECT_COUNT.into());
        for index in 0_u32..EFFECT_COUNT.into() {
            let mut balance: u32 = balances.pop_front().unwrap().into();
            if index == balance_index {
                balance = core::cmp::min(balance + quantity.into(), Bounded::<u16>::MAX.into());
            }
            balances.append(balance.try_into().unwrap());
        }
        let effects: u256 = Packer::pack(balances, EFFECT_SIZE);
        self.effects = effects.try_into().unwrap();
    }

    #[inline]
    fn consume(ref self: Game, effect: Effect, quantity: u16) {
        // [Check] Skip if effect is none
        if effect == Effect::None {
            return;
        }
        // [Effect] Remove effect from the balance
        let balance_index: u32 = effect.index().into();
        let effects: u256 = self.effects.into();
        let mut balances: Array<u16> = Packer::unpack(effects, EFFECT_SIZE, EFFECT_COUNT.into());
        for index in 0_u32..EFFECT_COUNT.into() {
            let mut balance = balances.pop_front().unwrap();
            if index == balance_index {
                assert(balance >= quantity, Errors::GAME_MISSING_EFFECTS);
                balance -= quantity;
            }
            balances.append(balance);
        }
        let effects: u256 = Packer::pack(balances, EFFECT_SIZE);
        self.effects = effects.try_into().unwrap();
    }

    #[inline]
    fn clue(ref self: Game, rng: u256) -> (Effect, Ingredient) {
        // TODO: Can be optimized by unpacking directly inside this function
        // [Effect] Spend gold and update hint price
        self.spend(self.hint_price);
        self.hint_price *= DEFAULT_HINT_MULTIPLIER.into();
        // [Compute] Randomly select an unknown recipe withtout hint
        let mut bitmap: u32 = self.hints | self.grimoire;
        let mut eligibles: Array<Effect> = array![];
        let mut index: u8 = 0;
        while index != EFFECT_COUNT {
            index += 1;
            if bitmap % 2 == 0 {
                let effect: Effect = index.into();
                eligibles.append(effect);
            }
            bitmap /= 2;
        }
        let len = eligibles.len();
        assert(len != 0, Errors::GAME_NO_ELIGIBLE_EFFECTS);
        let index: u32 = (rng.low % len.into()).try_into().unwrap();
        let effect: Effect = *eligibles.at(index);

        // [Compute] Randomly select an ingredient with remaining tries
        let mut counts: Array<u8> = Packer::unpack(self.tries, TRY_SIZE, INGREDIENT_COUNT);
        let mut eligibles: Array<Ingredient> = array![];
        let len: u8 = counts.len().try_into().unwrap();
        for index in 0..len {
            let count = *counts.at(index.into());
            let remaining: u8 = INGREDIENT_COUNT - count - 1;
            if remaining == 0 {
                continue;
            }
            let ingredient: Ingredient = (index + 1).into();
            eligibles.append(ingredient);
        }
        let len = eligibles.len();
        assert(len != 0, Errors::GAME_NO_ELIGIBLE_INGREDIENTS);
        let index: u32 = (rng.high % len.into()).try_into().unwrap();
        let ingredient: Ingredient = *eligibles.at(index);

        // [Effect] Remove a try from that ingredient to avoid infinite hints on the same ingredient
        // [Info] It will be added back when the ingredient is discovered
        let target: u32 = ingredient.index().into();
        let len: u32 = counts.len();
        for index in 0..len {
            let mut count = counts.pop_front().unwrap();
            if index == target {
                count += 1;
            }
            counts.append(count);
        }
        self.tries = Packer::pack(counts, TRY_SIZE);

        // [Return] Effect and ingredient
        (effect, ingredient)
    }

    #[inline]
    fn craft(ref self: Game, ingredient_a: Ingredient, ingredient_b: Ingredient, quantity: u16) {
        // [Check] Ingredients are valid
        assert(ingredient_a != ingredient_b, Errors::GAME_INVALID_INGREDIENTS);
        assert(ingredient_a != Ingredient::None, Errors::GAME_INVALID_INGREDIENTS);
        assert(ingredient_b != Ingredient::None, Errors::GAME_INVALID_INGREDIENTS);
        // [Effect] Remove ingredients from the balance
        let ingredients: u256 = self.ingredients.into();
        let mut balances: Array<u16> = Packer::unpack(
            ingredients, INGREDIENT_SIZE, INGREDIENT_COUNT.into(),
        );
        let index_a = ingredient_a.index();
        let index_b = ingredient_b.index();
        let len: u32 = balances.len();
        for index in 0..len {
            let mut balance = balances.pop_front().unwrap();
            if index == index_a.into() {
                assert(balance >= quantity, Errors::GAME_MISSING_INGREDIENTS);
                balance -= quantity;
            } else if index == index_b.into() {
                assert(balance >= quantity, Errors::GAME_MISSING_INGREDIENTS);
                balance -= quantity;
            }
            balances.append(balance);
        }
        let ingredients: u256 = Packer::pack(balances, INGREDIENT_SIZE);
        self.ingredients = ingredients.try_into().unwrap();
    }

    #[inline]
    fn discover(
        ref self: Game,
        ingredient_a: Ingredient,
        ingredient_b: Ingredient,
        recipes_a: u32,
        recipes_b: u32,
        rng: u256,
    ) -> Effect {
        // [Check] Ingredients are valid
        assert(ingredient_a != ingredient_b, Errors::GAME_INVALID_INGREDIENTS);
        assert(ingredient_a != Ingredient::None, Errors::GAME_INVALID_INGREDIENTS);
        assert(ingredient_b != Ingredient::None, Errors::GAME_INVALID_INGREDIENTS);
        // [Effect] Perform the discovery with hinted recipes for ingredient_a
        let recipes: u32 = self.grimoire & recipes_a ^ recipes_a;
        let counts = Packer::unpack(self.tries, TRY_SIZE, INGREDIENT_COUNT);
        let tries = *counts.at(ingredient_a.index().into());
        let remaining = INGREDIENT_COUNT - tries; // Add 1 try previously removed from clue
        let recipe = Crafter::craft(remaining.into(), recipes, rng.low);
        if (recipe != Effect::None) {
            return recipe;
        }
        // [Effect] Perform the discovery with hinted recipes for ingredient_b
        let recipes: u32 = self.grimoire & recipes_b ^ recipes_b;
        let counts = Packer::unpack(self.tries, TRY_SIZE, INGREDIENT_COUNT);
        let tries = *counts.at(ingredient_b.index().into());
        let remaining = INGREDIENT_COUNT - tries; // Add 1 try previously removed from clue
        let recipe = Crafter::craft(remaining.into(), recipes, rng.low);
        if (recipe != Effect::None) {
            return recipe;
        }
        // [Effect] Otherwise perform the discovery without hinted recipes
        let recipes = ALL_EFFECTS & ~(self.grimoire | self.hints);
        return Crafter::craft(self.remaining_tries, recipes, rng.low);
    }
}

#[generate_trait]
pub impl GameAssert of AssertTrait {
    #[inline]
    fn assert_not_over(self: @Game) {
        assert(!self.is_over(), Errors::GAME_OVER);
    }

    #[inline]
    fn assert_is_over(self: @Game) {
        assert(self.is_over(), Errors::GAME_OVER);
    }

    #[inline]
    fn assert_not_started(self: @Game) {
        assert(self.started_at == @0, Errors::GAME_NOT_STARTED);
    }

    #[inline]
    fn assert_is_started(self: @Game) {
        assert(self.started_at != @0, Errors::GAME_IS_STARTED);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SEED: felt252 = 'SEED';

    #[test]
    fn test_game_new() {
        let game = GameTrait::new(42, SEED);
        assert_eq!(game.id, 42);
        assert_eq!(game.grimoire, 0);
        assert_eq!(game.hints, 0);
        assert_eq!(game.ended_at, 0);
    }
    #[test]
    fn test_game_assess_not_over() {
        starknet::testing::set_block_timestamp(999);
        let mut game = GameTrait::new(1, SEED);
        game.assess();
        assert_eq!(game.ended_at, 0);
    }

    #[test]
    fn test_game_assess_over() {
        starknet::testing::set_block_timestamp(999);
        let mut game = GameTrait::new(1, SEED);
        game.grimoire = 2_u32.pow(EFFECT_COUNT.into()) - 1;
        game.assess();
        assert_eq!(game.ended_at, 999);
    }

    #[test]
    fn test_game_clue_two_left() {
        let mut game = GameTrait::new(1, SEED);
        // bits 1-29 set, bit 0 clear → only Effect::None (index 0) is eligible
        game.gold = 10 + 30;
        game.grimoire = 2_u32.pow(EFFECT_COUNT.into() - 1) - 2;
        let (effect, ingredient) = game.clue(0);
        assert_eq!(effect, Effect::Blue);
        assert_eq!(ingredient, Ingredient::AmberSap);
        assert_eq!(game.tries, 1);
        let (effect, ingredient) = game.clue(1);
        assert_eq!(effect, Effect::Aquamarine);
        assert_eq!(ingredient, Ingredient::AmberSap);
        assert_eq!(game.tries, 2);
    }

    #[test]
    fn test_game_craft() {
        let mut game = GameTrait::new(1, SEED);
        game.ingredients = 0b10000000001; // AmberSap: 1 left, CopperDust: 1 left
        game.craft(Ingredient::AmberSap, Ingredient::CopperDust, 1);
        assert_eq!(game.ingredients, 0);
    }

    #[test]
    fn test_game_discover_no_hint() {
        let mut game = GameTrait::new(1, SEED);
        let recipe = game.discover(Ingredient::AmberSap, Ingredient::CopperDust, 0, 0, 0);
        assert_eq!(recipe, Effect::Blue);
    }

    #[test]
    fn test_game_discover_nothing_left() {
        let mut game = GameTrait::new(1, SEED);
        game.grimoire = 2_u32.pow(EFFECT_COUNT.into()) - 1;
        let recipe = game.discover(Ingredient::AmberSap, Ingredient::CopperDust, 0, 0, 0);
        assert_eq!(recipe, Effect::None);
    }

    #[test]
    fn test_game_discover_hinted_left() {
        let mut game = GameTrait::new(1, SEED);
        let hint = 0b10; // AmberSap: used in Green
        game.tries = (INGREDIENT_COUNT - 2).into(); // AmberSap: 1 try left
        let recipe = game.discover(Ingredient::AmberSap, Ingredient::CopperDust, hint, 0, 0);
        assert_eq!(recipe, Effect::Green);
    }

    #[test]
    fn test_game_discover_hinted_right() {
        let mut game = GameTrait::new(1, SEED);
        let hint = 0b10; // AmberSap: used in Green
        game.tries = (INGREDIENT_COUNT - 2).into(); // AmberSap: 1 try left
        let recipe = game.discover(Ingredient::CopperDust, Ingredient::AmberSap, 0, hint, 0);
        assert_eq!(recipe, Effect::Green);
    }

    #[test]
    fn test_game_discover_case_001() {
        let seed: u256 = 0x1120543d570e59d8f4e5cd53f7a8adb7b89b5beee84d9c5539475ecab09387d;
        let mut game = GameTrait::new(0x15, SEED);
        let a: Ingredient = 2_u8.into();
        let b: Ingredient = 3_u8.into();
        let recipe = game.discover(a, b, 0, 0, seed);
        assert_eq!(recipe, Effect::None);
    }

    #[test]
    fn test_game_full_grimoire_no_hint() {
        let mut game = GameTrait::new(1, SEED);
        let target = 2_u32.pow(EFFECT_COUNT.into()) - 1;
        for index_a in 0_u8..INGREDIENT_COUNT {
            let a: Ingredient = IngredientTrait::from(index_a);
            for index_b in index_a..INGREDIENT_COUNT {
                let b: Ingredient = IngredientTrait::from(index_b);
                if a == b {
                    continue;
                }
                let seed = core::poseidon::poseidon_hash_span(
                    [index_a.into(), index_b.into()].span(),
                );
                let recipe = game.discover(a, b, 0, 0, seed.into());
                game.learn(a, b, recipe);
            }
        }
        assert_eq!(game.grimoire, target);
    }

    #[test]
    fn test_game_full_grimoire_with_hint() {
        let mut game = GameTrait::new(1, SEED);
        let target = 2_u32.pow(EFFECT_COUNT.into()) - 1;
        for index_a in 0_u8..INGREDIENT_COUNT {
            let a: Ingredient = IngredientTrait::from(index_a);
            for index_b in index_a..INGREDIENT_COUNT {
                let b: Ingredient = IngredientTrait::from(index_b);
                if a == b {
                    continue;
                }
                let seed = core::poseidon::poseidon_hash_span(
                    [index_a.into(), index_b.into()].span(),
                );
                let mut hints_a = 0;
                let mut hints_b = 0;
                if a == Ingredient::AmberSap {
                    hints_a = Bitmap::set(hints_a, Effect::White.index());
                }
                if b == Ingredient::Starfall {
                    hints_b = Bitmap::set(hints_b, Effect::Aquamarine.index());
                }
                let recipe = game.discover(a, b, hints_a, hints_b, seed.into());
                game.learn(a, b, recipe);
            }
        }
        assert_eq!(game.grimoire, target);
    }
}
