pub use crate::events::index::LootClaimed;

#[generate_trait]
pub impl LootClaimedImpl of LootClaimedTrait {
    fn new(game_id: u64, hero_id: u8, gold: u32) -> LootClaimed {
        LootClaimed { game_id, hero_id, gold }
    }
}
