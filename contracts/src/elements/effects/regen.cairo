use super::index::{Character, EffectTrait};

pub impl Regen of EffectTrait {
    fn apply(ref character: Character, quantity: u16) {
        character.regen += quantity;
    }
}
