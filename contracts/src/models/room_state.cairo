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
    // Energy (stamina) orbs — same-turn only. Fresh → aged → expired each turn.
    // Brute / Flanker / Drainer kills drop these.
    pub orbs_fresh: u64,
    pub orbs_aged: u64,
    // HP orbs — 2-turn lifetime, grant HP instead of stamina.
    // Caster / Heavy / Puller kills drop these.
    pub hp_orbs_fresh: u64,
    pub hp_orbs_aged: u64,
}
