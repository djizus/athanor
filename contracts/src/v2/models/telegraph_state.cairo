#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TelegraphState {
    #[key]
    pub player: starknet::ContractAddress,
    #[key]
    pub game_id: u32,
    #[key]
    pub telegraph_id: u8,
    pub source_actor_id: u8,
    pub shape_type: u8,
    pub telegraph_type: u8,
    pub param_a: u8,
    pub param_b: u8,
    pub param_c: u8,
    pub pull_source_x: u8,
    pub pull_source_y: u8,
    pub pull_distance: u8,
    pub damage: u16,
    pub created_turn: u16,
    pub resolves_turn: u16,
    pub resolved: bool,
    pub room_id: u8,
}
