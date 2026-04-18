#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct RoomState {
    #[key]
    pub player: starknet::ContractAddress,
    #[key]
    pub game_id: u32,
    #[key]
    pub room_id: u8,
    pub width: u8,
    pub height: u8,
    pub blocked: u64,
    pub occupancy: u64,
    pub enemy_count: u8,
    pub cleared: bool,
    // Ascend additions:
    pub orbs_fresh: u64,
    pub orbs_aged: u64,
}
