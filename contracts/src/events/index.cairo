use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct CharacterSpawned {
    #[key]
    pub player: ContractAddress,
    pub game_id: u32,
    pub class_id: u8,
    pub health: u16,
    pub power: u16,
    pub stamina: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct DungeonCreated {
    #[key]
    pub player: ContractAddress,
    pub game_id: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ZoneEntered {
    #[key]
    pub player: ContractAddress,
    pub game_id: u32,
    pub zone_id: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct FightStarted {
    #[key]
    pub player: ContractAddress,
    pub game_id: u32,
    pub zone_id: u8,
    pub mob_count: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MobDamaged {
    #[key]
    pub player: ContractAddress,
    pub game_id: u32,
    pub zone_id: u8,
    pub mob_id: u8,
    pub damage: u16,
    pub remaining_hp: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MobDied {
    #[key]
    pub player: ContractAddress,
    pub game_id: u32,
    pub zone_id: u8,
    pub mob_id: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct PlayerDamaged {
    #[key]
    pub player: ContractAddress,
    pub game_id: u32,
    pub damage: u16,
    pub remaining_hp: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct TurnEnded {
    #[key]
    pub player: ContractAddress,
    pub game_id: u32,
    pub zone_id: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct FightEnded {
    #[key]
    pub player: ContractAddress,
    pub game_id: u32,
    pub zone_id: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct DungeonCompleted {
    #[key]
    pub player: ContractAddress,
    pub game_id: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct DungeonFailed {
    #[key]
    pub player: ContractAddress,
    pub game_id: u32,
}
