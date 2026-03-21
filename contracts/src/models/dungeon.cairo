#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Dungeon {
    #[key]
    pub player: starknet::ContractAddress,
    #[key]
    pub game_id: u32,
    pub zones_cleared: u8,
    pub completed: bool,
    pub failed: bool,
}
