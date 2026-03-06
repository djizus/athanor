use starknet::ContractAddress;
pub use crate::events::index::{GameCreated, GrimoireCompleted};

#[generate_trait]
pub impl GameCreatedImpl of GameCreatedTrait {
    fn new(game_id: u64, player: ContractAddress, settings_id: u32, seed: felt252) -> GameCreated {
        GameCreated { game_id, player, settings_id, seed }
    }
}

#[generate_trait]
pub impl GrimoireCompletedImpl of GrimoireCompletedTrait {
    fn new(game_id: u64, player: ContractAddress, completion_time: u64) -> GrimoireCompleted {
        GrimoireCompleted { game_id, player, completion_time }
    }
}
