#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ActorState {
    #[key]
    pub player: starknet::ContractAddress,
    #[key]
    pub game_id: u32,
    #[key]
    pub actor_id: u8,
    pub faction: u8,
    pub archetype: u8,
    pub hp: u16,
    pub max_hp: u16,
    pub stamina: u16,
    pub max_stamina: u16,
    pub offense: u8,
    pub defense: u8,
    pub speed: u8,
    pub move_cost: u8,
    pub pos_x: u8,
    pub pos_y: u8,
    pub alive: bool,
    pub guard_active: bool,
    pub room_id: u8,
}
