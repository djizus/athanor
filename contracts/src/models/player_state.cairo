#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerState {
    #[key]
    pub player: starknet::ContractAddress,
    pub game_count: u32,
}
