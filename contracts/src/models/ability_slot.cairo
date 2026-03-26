#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct AbilitySlotState {
    #[key]
    pub player: starknet::ContractAddress,
    #[key]
    pub game_id: u32,
    #[key]
    pub actor_id: u8,
    #[key]
    pub slot_index: u8,
    pub ability_id: u8,
    pub cooldown_remaining: u8,
}
