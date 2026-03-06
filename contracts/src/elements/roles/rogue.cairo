use super::index::{Character, HeroTrait};

pub impl Rogue of HeroTrait {
    fn spawn(ref character: Character) {
        character.max_health = 100;
        character.power = 5;
        character.regen = 5;
    }
}
