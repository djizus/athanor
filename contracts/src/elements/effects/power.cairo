use super::index::{Character, EffectTrait};

pub impl Power of EffectTrait {
    fn apply(ref character: Character, quantity: u16) {
        character.power += quantity;
    }
}
