#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Character {
    #[key]
    pub player: starknet::ContractAddress,
    #[key]
    pub game_id: u32,
    pub class_id: u8,
    pub health: u16,
    pub max_health: u16,
    pub power: u16,
    pub stamina: u16,
    pub max_stamina: u16,
    pub current_zone: u8,
}
