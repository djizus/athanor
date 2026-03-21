#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Fight {
    #[key]
    pub player: starknet::ContractAddress,
    #[key]
    pub game_id: u32,
    #[key]
    pub zone_id: u8,
    pub mob_count: u8,
    pub mob_healths: u64,
    pub mob_power: u16,
    pub active: bool,
}
