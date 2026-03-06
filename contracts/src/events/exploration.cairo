pub use crate::events::index::{ExplorationEvent, ExpeditionStarted};

#[generate_trait]
pub impl ExplorationEventImpl of ExplorationEventTrait {
    fn new(
        game_id: u64,
        event_index: u16,
        hero_id: u8,
        depth: u16,
        zone_id: u8,
        event_kind: u8,
        value: u16,
        hp_after: u16,
    ) -> ExplorationEvent {
        ExplorationEvent { game_id, event_index, hero_id, depth, zone_id, event_kind, value, hp_after }
    }
}

#[generate_trait]
pub impl ExpeditionStartedImpl of ExpeditionStartedTrait {
    fn new(game_id: u64, hero_id: u8, death_depth: u16, return_at: u64) -> ExpeditionStarted {
        ExpeditionStarted { game_id, hero_id, death_depth, return_at }
    }
}
