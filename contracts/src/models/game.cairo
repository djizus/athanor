use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GameSession {
    #[key]
    pub game_id: u64,
    pub player: ContractAddress,
    pub seed: felt252,
    pub settings_id: u32,
    pub discovered_count: u8,
    pub craft_attempts: u16,
    pub hints_used: u8,
    pub gold: u32,
    pub hero_count: u8,
    pub potion_count: u16,
    pub game_over: bool,
    pub started_at: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GameSeed {
    #[key]
    pub game_id: u64,
    pub seed: felt252,
}
