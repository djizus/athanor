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

// Token-id → player mapping. Written on spawn; lets EGC score(token_id) and
// game_over(token_id) resolve the composite (player, game_id) key without
// refactoring the RunState schema.
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct RunOwner {
    #[key]
    pub game_id: u32,
    pub player: starknet::ContractAddress,
}

// Per-player run index for RPC discovery without Torii. On spawn, append the
// new game_id at `count`, then increment count.
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerRunCursor {
    #[key]
    pub player: starknet::ContractAddress,
    pub count: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerRunIndex {
    #[key]
    pub player: starknet::ContractAddress,
    #[key]
    pub index: u32,
    pub game_id: u32,
}
