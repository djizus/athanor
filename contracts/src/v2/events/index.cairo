use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct RunSpawned {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub game_id: u32,
    pub room_id: u8,
    pub player_actor_id: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct RoomEntered {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub game_id: u32,
    pub room_id: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ActorMoved {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub game_id: u32,
    pub actor_id: u8,
    pub room_id: u8,
    pub from_x: u8,
    pub from_y: u8,
    pub to_x: u8,
    pub to_y: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct AbilityUsed {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub game_id: u32,
    pub actor_id: u8,
    pub ability_id: u8,
    pub room_id: u8,
    pub target_actor_id: u8,
    pub target_x: u8,
    pub target_y: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct TelegraphCreated {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub game_id: u32,
    pub telegraph_id: u8,
    pub source_actor_id: u8,
    pub room_id: u8,
    pub resolves_turn: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct TelegraphResolved {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub game_id: u32,
    pub telegraph_id: u8,
    pub room_id: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct EnemyTurnComputed {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub game_id: u32,
    pub room_id: u8,
    pub turn_index: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct TurnEnded {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub game_id: u32,
    pub room_id: u8,
    pub turn_index: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ActorDamaged {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub game_id: u32,
    pub actor_id: u8,
    pub source_actor_id: u8,
    pub damage: u16,
    pub remaining_hp: u16,
    pub room_id: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ActorDied {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub game_id: u32,
    pub actor_id: u8,
    pub room_id: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct RoomCleared {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub game_id: u32,
    pub room_id: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct RunCompleted {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub game_id: u32,
    pub turn_index: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct RunFailed {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub game_id: u32,
    pub turn_index: u16,
}
