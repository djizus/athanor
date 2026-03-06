use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerMeta {
    #[key]
    pub player: ContractAddress,
    pub total_games: u32,
    pub best_time: u64,
    pub total_recipes_discovered: u32,
}
