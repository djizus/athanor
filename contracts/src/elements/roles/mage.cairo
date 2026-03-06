use super::index::{Character, HeroTrait};

pub impl Mage of HeroTrait {
    fn spawn(ref character: Character) {
        character.max_health = 50;
        character.power = 20;
        character.regen = 1;
    }
}
