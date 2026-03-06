pub use crate::events::index::{HeroRecruited, PotionApplied};

#[generate_trait]
pub impl HeroRecruitedImpl of HeroRecruitedTrait {
    fn new(game_id: u64, hero_id: u8, cost: u32) -> HeroRecruited {
        HeroRecruited { game_id, hero_id, cost }
    }
}

#[generate_trait]
pub impl PotionAppliedImpl of PotionAppliedTrait {
    fn new(game_id: u64, hero_id: u8, potion_index: u16, effect_type: u8, effect_value: u8) -> PotionApplied {
        PotionApplied { game_id, hero_id, potion_index, effect_type, effect_value }
    }
}
