use crate::helpers::exploration::{TickEvent, simulate_expedition};
use crate::helpers::packer::Packer;
use crate::models::game::INGREDIENT_SIZE;
pub use crate::models::index::Character;
use crate::typess::effect::{Effect, EffectTrait};
use crate::typess::ingredient::INGREDIENT_COUNT;
use crate::typess::role::{Role, RoleTrait};

pub mod Errors {
    pub const CHARACTER_NOT_SPAWNED: felt252 = 'Character: not spawned';
    pub const CHARACTER_NOT_AVAILABLE: felt252 = 'Character: not available';
}

#[generate_trait]
pub impl CharacterImpl of CharacterTrait {
    #[inline]
    fn new(game_id: u64, id: u8, role: Role) -> Character {
        let mut character = Character {
            game_id,
            id,
            role: role.into(),
            health: 0,
            max_health: 0,
            power: 0,
            regen: 0,
            gold: 0,
            available_at: starknet::get_block_timestamp(),
            ingredients: 0,
        };
        role.spawn(ref character);
        character
    }

    #[inline]
    fn heal(ref self: Character, health: u16) {
        self.health = core::cmp::min(self.health + health, self.max_health);
    }

    #[inline]
    fn buff(ref self: Character, effect: Effect, quantity: u16) {
        // [Check] Character is spawned
        self.assert_has_spawned();
        // [Effect] Apply effect
        effect.apply(ref self, quantity);
    }

    #[inline]
    fn explore(ref self: Character, rng: felt252) -> Array<TickEvent> {
        // [Check] Character is spawned
        self.assert_has_spawned();
        // [Check] Character is available
        let now: u64 = starknet::get_block_timestamp();
        self.assert_is_available(now);
        // [Effect] Heal
        let timedelta = now - self.available_at;
        let regen: u16 = self.regen * timedelta.try_into().expect('Character: timedelta too big');
        self.heal(regen);
        // [Effect] Apply expedition results
        let mut result = simulate_expedition(
            hp: self.health, max_hp: self.max_health, power: self.power, seed: rng,
        );
        self.available_at = now + 3 * result.death_depth.into() / 2;
        self.health = result.remaining_hp;
        self.gold = result.gold;
        let mut ingredients: Array<u16> = array![];
        for index in 0_u32..INGREDIENT_COUNT.into() {
            let quantity: u16 = result.bag.get(index.into());
            ingredients.append(quantity);
        }
        let ingredients: u256 = Packer::pack(ingredients, INGREDIENT_SIZE);
        self.ingredients = ingredients.try_into().expect('Character: pack ingredients');
        // [Return] Logs
        result.events
    }

    #[inline]
    fn claim(ref self: Character) -> (felt252, u32) {
        // [Check] Character is spawned
        self.assert_has_spawned();
        // [Check] Character is available
        let now: u64 = starknet::get_block_timestamp();
        self.assert_is_available(now);
        // [Effect] Claim loot
        let ingredients = self.ingredients;
        let gold = self.gold;
        // [Effect] Reset rewards
        self.gold = 0;
        self.ingredients = 0;
        // [Return] Ingredients and gold
        (ingredients, gold)
    }
}

#[generate_trait]
pub impl CharacterAssert of AssertTrait {
    #[inline]
    fn assert_has_spawned(self: @Character) {
        assert(self.max_health != @0, Errors::CHARACTER_NOT_SPAWNED);
    }

    #[inline]
    fn assert_is_available(self: @Character, now: u64) {
        assert(@now > self.available_at, Errors::CHARACTER_NOT_AVAILABLE);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const GAME_ID: u64 = 1;
    const CHARACTER_ID: u8 = 0;

    #[test]
    fn test_character_new() {
        let character = CharacterTrait::new(GAME_ID, CHARACTER_ID, Role::Mage);
        assert_eq!(character.game_id, 1);
        assert_eq!(character.id, 0);
        assert_eq!(character.role, Role::Mage.into());
    }

    #[test]
    fn test_character_heal() {
        let mut character = CharacterTrait::new(GAME_ID, CHARACTER_ID, Role::Mage);
        character.health = 0;
        character.heal(character.max_health + 1);
        assert_eq!(character.health, character.max_health);
    }

    #[test]
    fn test_character_buff() {
        let mut character = CharacterTrait::new(GAME_ID, CHARACTER_ID, Role::Mage);
        let max_health = character.max_health;
        character.buff(Effect::Blue, 10);
        assert_eq!(character.max_health, max_health + 50);
    }

    #[test]
    fn test_character_explore() {
        let mut character = CharacterTrait::new(GAME_ID, CHARACTER_ID, Role::Mage);
        starknet::testing::set_block_timestamp(1);
        character.explore(core::poseidon::poseidon_hash_span([0, 0].span()));
    }
}
