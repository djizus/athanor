use super::index::{Character, EffectTrait};

pub impl Health of EffectTrait {
    fn apply(ref character: Character, quantity: u16) {
        character.max_health += quantity;
    }
}
