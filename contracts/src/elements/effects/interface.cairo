use super::index::Character;

pub trait EffectTrait {
    fn apply(ref character: Character, quantity: u16);
}
