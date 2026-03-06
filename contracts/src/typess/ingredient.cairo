pub const INGREDIENT_COUNT: u8 = 25;

#[derive(Drop, Copy, Serde, PartialEq, Debug)]
pub enum Ingredient {
    None,
    AmberSap,
    CopperDust,
    FogEssence,
    IronFiling,
    Moonpetal,
    Nightberry,
    CrystalShard,
    DrakeMoss,
    SulfurBloom,
    DragonScale,
    AetherCore,
    TitanBlood,
    VoidSalt,
    AetherBloom,
    StarDust,
    CavePearl,
    RiverClay,
    EchoMoss,
    Dripstone,
    Starfall,
    Echoleaf,
    Crystalbloom,
    Feather,
    Frostbloom,
    Gemstone,
}

#[generate_trait]
pub impl IngredientImpl of IngredientTrait {
    #[inline]
    fn index(self: Ingredient) -> u8 {
        let id: u8 = self.into();
        id - 1
    }
}

pub impl IngredientIntoU8 of Into<Ingredient, u8> {
    fn into(self: Ingredient) -> u8 {
        match self {
            Ingredient::None => 0,
            Ingredient::AmberSap => 1,
            Ingredient::CopperDust => 2,
            Ingredient::FogEssence => 3,
            Ingredient::IronFiling => 4,
            Ingredient::Moonpetal => 5,
            Ingredient::Nightberry => 6,
            Ingredient::CrystalShard => 7,
            Ingredient::DrakeMoss => 8,
            Ingredient::SulfurBloom => 9,
            Ingredient::DragonScale => 10,
            Ingredient::AetherCore => 11,
            Ingredient::TitanBlood => 12,
            Ingredient::VoidSalt => 13,
            Ingredient::AetherBloom => 14,
            Ingredient::StarDust => 15,
            Ingredient::CavePearl => 16,
            Ingredient::RiverClay => 17,
            Ingredient::EchoMoss => 18,
            Ingredient::Dripstone => 19,
            Ingredient::Starfall => 20,
            Ingredient::Echoleaf => 21,
            Ingredient::Crystalbloom => 22,
            Ingredient::Feather => 23,
            Ingredient::Frostbloom => 24,
            Ingredient::Gemstone => 25,
        }
    }
}

pub impl U8IntoIngredient of Into<u8, Ingredient> {
    fn into(self: u8) -> Ingredient {
        match self {
            0 => Ingredient::None,
            1 => Ingredient::AmberSap,
            2 => Ingredient::CopperDust,
            3 => Ingredient::FogEssence,
            4 => Ingredient::IronFiling,
            5 => Ingredient::Moonpetal,
            6 => Ingredient::Nightberry,
            7 => Ingredient::CrystalShard,
            8 => Ingredient::DrakeMoss,
            9 => Ingredient::SulfurBloom,
            10 => Ingredient::DragonScale,
            11 => Ingredient::AetherCore,
            12 => Ingredient::TitanBlood,
            13 => Ingredient::VoidSalt,
            14 => Ingredient::AetherBloom,
            15 => Ingredient::StarDust,
            16 => Ingredient::CavePearl,
            17 => Ingredient::RiverClay,
            18 => Ingredient::EchoMoss,
            19 => Ingredient::Dripstone,
            20 => Ingredient::Starfall,
            21 => Ingredient::Echoleaf,
            22 => Ingredient::Crystalbloom,
            23 => Ingredient::Feather,
            24 => Ingredient::Frostbloom,
            25 => Ingredient::Gemstone,
            _ => Ingredient::None,
        }
    }
}
