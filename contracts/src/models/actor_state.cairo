// ActorState uses a bitpacked on-chain representation to cut storage writes.
// Callers work with the familiar `ActorState` struct (16 fields, typed); the
// Store layer converts to/from `ActorStatePacked` (2 data slots) transparently.
//
// Layout of `ActorStatePacked.resources` (u64):
//   [ 0..16] hp
//   [16..32] max_hp
//   [32..48] stamina
//   [48..64] max_stamina
//
// Layout of `ActorStatePacked.stats` (u64):
//   [ 0..1]  alive
//   [ 1..2]  guard_active
//   [ 2..3]  is_immovable
//   [ 3..4]  faction (0=player, 1=enemy)
//   [ 4..7]  archetype (3 bits, values 0-5)
//   [ 7..15] offense (u8)
//   [15..23] defense (u8)
//   [23..31] speed (u8)
//   [31..39] move_cost (u8)
//   [39..42] pos_x (3 bits)
//   [42..45] pos_y (3 bits)
//   [45..53] room_id (u8)
//   total: 53 bits (11 reserved)

use athanor::helpers::packing;

#[derive(Copy, Drop, Serde)]
pub struct ActorState {
    pub player: starknet::ContractAddress,
    pub game_id: u32,
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
    pub is_immovable: bool,
    pub room_id: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ActorStatePacked {
    #[key]
    pub player: starknet::ContractAddress,
    #[key]
    pub game_id: u32,
    #[key]
    pub actor_id: u8,
    pub resources: u64,
    pub stats: u64,
}

#[generate_trait]
pub impl ActorStatePackingImpl of ActorStatePackingTrait {
    fn unpack(self: @ActorStatePacked) -> ActorState {
        let r = *self.resources;
        let s = *self.stats;

        ActorState {
            player: *self.player,
            game_id: *self.game_id,
            actor_id: *self.actor_id,
            hp: (r & 0xFFFF).try_into().unwrap(),
            max_hp: (packing::shr64(r, 16) & 0xFFFF).try_into().unwrap(),
            stamina: (packing::shr64(r, 32) & 0xFFFF).try_into().unwrap(),
            max_stamina: (packing::shr64(r, 48) & 0xFFFF).try_into().unwrap(),
            alive: (s & 1) == 1,
            guard_active: (packing::shr64(s, 1) & 1) == 1,
            is_immovable: (packing::shr64(s, 2) & 1) == 1,
            faction: (packing::shr64(s, 3) & 1).try_into().unwrap(),
            archetype: (packing::shr64(s, 4) & 0b111).try_into().unwrap(),
            offense: (packing::shr64(s, 7) & 0xFF).try_into().unwrap(),
            defense: (packing::shr64(s, 15) & 0xFF).try_into().unwrap(),
            speed: (packing::shr64(s, 23) & 0xFF).try_into().unwrap(),
            move_cost: (packing::shr64(s, 31) & 0xFF).try_into().unwrap(),
            pos_x: (packing::shr64(s, 39) & 0b111).try_into().unwrap(),
            pos_y: (packing::shr64(s, 42) & 0b111).try_into().unwrap(),
            room_id: (packing::shr64(s, 45) & 0xFF).try_into().unwrap(),
        }
    }

    fn pack(actor: @ActorState) -> ActorStatePacked {
        let hp: u64 = (*actor.hp).into();
        let max_hp: u64 = (*actor.max_hp).into();
        let stamina: u64 = (*actor.stamina).into();
        let max_stamina: u64 = (*actor.max_stamina).into();
        let resources = hp
            | packing::shl64(max_hp, 16)
            | packing::shl64(stamina, 32)
            | packing::shl64(max_stamina, 48);

        let alive: u64 = if *actor.alive {
            1
        } else {
            0
        };
        let guard: u64 = if *actor.guard_active {
            1
        } else {
            0
        };
        let immov: u64 = if *actor.is_immovable {
            1
        } else {
            0
        };
        let faction: u64 = ((*actor.faction) & 1).into();
        let archetype: u64 = ((*actor.archetype) & 0b111).into();
        let offense: u64 = (*actor.offense).into();
        let defense: u64 = (*actor.defense).into();
        let speed: u64 = (*actor.speed).into();
        let move_cost: u64 = (*actor.move_cost).into();
        let pos_x: u64 = ((*actor.pos_x) & 0b111).into();
        let pos_y: u64 = ((*actor.pos_y) & 0b111).into();
        let room_id: u64 = (*actor.room_id).into();

        let stats = alive
            | packing::shl64(guard, 1)
            | packing::shl64(immov, 2)
            | packing::shl64(faction, 3)
            | packing::shl64(archetype, 4)
            | packing::shl64(offense, 7)
            | packing::shl64(defense, 15)
            | packing::shl64(speed, 23)
            | packing::shl64(move_cost, 31)
            | packing::shl64(pos_x, 39)
            | packing::shl64(pos_y, 42)
            | packing::shl64(room_id, 45);

        ActorStatePacked {
            player: *actor.player,
            game_id: *actor.game_id,
            actor_id: *actor.actor_id,
            resources,
            stats,
        }
    }
}
