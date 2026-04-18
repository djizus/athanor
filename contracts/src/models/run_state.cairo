#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct RunState {
    #[key]
    pub player: starknet::ContractAddress,
    #[key]
    pub game_id: u32,
    pub phase: u8,
    pub room_id: u8,
    pub turn_index: u16,
    pub player_actor_id: u8,
    pub status_flags: u8,
    pub last_player_direction: u8,
    // Ascend additions:
    pub seed: felt252,
    pub score: u32,
    pub rooms_cleared: u16,
    pub started_at: u64,
    pub ended_at: u64,
}
