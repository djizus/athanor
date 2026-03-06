pub const HERO_COUNT: u8 = 3;

#[derive(Drop, Copy, Serde, PartialEq, Debug)]
pub enum Hero {
    None,
    Alaric,
    Brynn,
    Cassiel,
}

#[generate_trait]
pub impl HeroImpl of HeroTrait {}

pub impl HeroIntoU8 of Into<Hero, u8> {
    fn into(self: Hero) -> u8 {
        match self {
            Hero::None => 0,
            Hero::Alaric => 1,
            Hero::Brynn => 2,
            Hero::Cassiel => 3,
        }
    }
}

pub impl U8IntoHero of Into<u8, Hero> {
    fn into(self: u8) -> Hero {
        match self {
            0 => Hero::None,
            1 => Hero::Alaric,
            2 => Hero::Brynn,
            3 => Hero::Cassiel,
            _ => Hero::None,
        }
    }
}
