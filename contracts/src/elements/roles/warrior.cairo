use super::index::{Character, HeroTrait};

pub impl Warrior of HeroTrait {
    fn spawn(ref character: Character) {
        character.max_health = 150;
        character.power = 5;
        character.regen = 2;
    }
}
