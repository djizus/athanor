use core::num::traits::Pow;

pub const EFFECT_COUNT: u8 = 30;
pub const ALL_EFFECTS: u32 = 2_u32.pow(EFFECT_COUNT.into()) - 1;

#[derive(Drop, Copy, Serde, PartialEq, Debug)]
pub enum Effect {
    None,
    Blue,
    Green,
    Red,
    Yellow,
    Purple,
    Orange,
    Pink,
    Brown,
    Gray,
    Black,
    White,
    Cyan,
    Magenta,
    Lime,
    Teal,
    Maroon,
    Navy,
    Indigo,
    Violet,
    Gold,
    Silver,
    Copper,
    Mauve,
    Ruby,
    Sapphire,
    Emerald,
    Diamond,
    Amethyst,
    Topaz,
    Aquamarine,
}

#[generate_trait]
pub impl EffectImpl of EffectTrait {
    #[inline]
    fn index(self: Effect) -> u8 {
        let id: u8 = self.into();
        id - 1
    }
}

pub impl EffectIntoU8 of Into<Effect, u8> {
    fn into(self: Effect) -> u8 {
        match self {
            Effect::None => 0,
            Effect::Blue => 1,
            Effect::Green => 2,
            Effect::Red => 3,
            Effect::Yellow => 4,
            Effect::Purple => 5,
            Effect::Orange => 6,
            Effect::Pink => 7,
            Effect::Brown => 8,
            Effect::Gray => 9,
            Effect::Black => 10,
            Effect::White => 11,
            Effect::Cyan => 12,
            Effect::Magenta => 13,
            Effect::Lime => 14,
            Effect::Teal => 15,
            Effect::Maroon => 16,
            Effect::Navy => 17,
            Effect::Indigo => 18,
            Effect::Violet => 19,
            Effect::Gold => 20,
            Effect::Silver => 21,
            Effect::Copper => 22,
            Effect::Mauve => 23,
            Effect::Ruby => 24,
            Effect::Sapphire => 25,
            Effect::Emerald => 26,
            Effect::Diamond => 27,
            Effect::Amethyst => 28,
            Effect::Topaz => 29,
            Effect::Aquamarine => 30,
        }
    }
}

pub impl U8IntoEffect of Into<u8, Effect> {
    fn into(self: u8) -> Effect {
        match self {
            0 => Effect::None,
            1 => Effect::Blue,
            2 => Effect::Green,
            3 => Effect::Red,
            4 => Effect::Yellow,
            5 => Effect::Purple,
            6 => Effect::Orange,
            7 => Effect::Pink,
            8 => Effect::Brown,
            9 => Effect::Gray,
            10 => Effect::Black,
            11 => Effect::White,
            12 => Effect::Cyan,
            13 => Effect::Magenta,
            14 => Effect::Lime,
            15 => Effect::Teal,
            16 => Effect::Maroon,
            17 => Effect::Navy,
            18 => Effect::Indigo,
            19 => Effect::Violet,
            20 => Effect::Gold,
            21 => Effect::Silver,
            22 => Effect::Copper,
            23 => Effect::Mauve,
            24 => Effect::Ruby,
            25 => Effect::Sapphire,
            26 => Effect::Emerald,
            27 => Effect::Diamond,
            28 => Effect::Amethyst,
            29 => Effect::Topaz,
            30 => Effect::Aquamarine,
            _ => Effect::None,
        }
    }
}
