// AbilitySlotState uses a bitpacked on-chain representation. Callers use the
// plain `AbilitySlotState` struct; the Store layer converts to/from
// `AbilitySlotStatePacked` transparently.
//
// packed layout (u16):
//   [0..8]  ability_id
//   [8..16] cooldown_remaining

#[derive(Copy, Drop, Serde)]
pub struct AbilitySlotState {
    pub player: starknet::ContractAddress,
    pub game_id: u32,
    pub actor_id: u8,
    pub slot_index: u8,
    pub ability_id: u8,
    pub cooldown_remaining: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct AbilitySlotStatePacked {
    #[key]
    pub player: starknet::ContractAddress,
    #[key]
    pub game_id: u32,
    #[key]
    pub actor_id: u8,
    #[key]
    pub slot_index: u8,
    pub packed: u16,
}

#[generate_trait]
pub impl AbilitySlotStatePackingImpl of AbilitySlotStatePackingTrait {
    fn unpack(self: @AbilitySlotStatePacked) -> AbilitySlotState {
        let p = *self.packed;
        AbilitySlotState {
            player: *self.player,
            game_id: *self.game_id,
            actor_id: *self.actor_id,
            slot_index: *self.slot_index,
            ability_id: (p & 0xFF).try_into().unwrap(),
            cooldown_remaining: ((p / 0x100) & 0xFF).try_into().unwrap(),
        }
    }

    fn pack(slot: @AbilitySlotState) -> AbilitySlotStatePacked {
        let ability_id: u16 = (*slot.ability_id).into();
        let cooldown: u16 = (*slot.cooldown_remaining).into();
        let packed = ability_id | (cooldown * 0x100);

        AbilitySlotStatePacked {
            player: *slot.player,
            game_id: *slot.game_id,
            actor_id: *slot.actor_id,
            slot_index: *slot.slot_index,
            packed,
        }
    }
}
