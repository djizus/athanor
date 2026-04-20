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

#[cfg(test)]
mod tests {
    use super::{ActorState, ActorStatePackingTrait};

    fn sample_actor() -> ActorState {
        ActorState {
            player: starknet::contract_address_const::<0x1234abcd>(),
            game_id: 42,
            actor_id: 3,
            faction: 1,
            archetype: 5,
            hp: 65535,
            max_hp: 30000,
            stamina: 240,
            max_stamina: 80,
            offense: 255,
            defense: 200,
            speed: 9,
            move_cost: 10,
            pos_x: 7,
            pos_y: 6,
            alive: true,
            guard_active: false,
            is_immovable: true,
            room_id: 128,
        }
    }

    #[test]
    fn test_actor_state_round_trip_max_values() {
        let original = sample_actor();
        let packed = ActorStatePackingTrait::pack(@original);
        let unpacked = packed.unpack();

        assert!(unpacked.hp == original.hp, "hp");
        assert!(unpacked.max_hp == original.max_hp, "max_hp");
        assert!(unpacked.stamina == original.stamina, "stamina");
        assert!(unpacked.max_stamina == original.max_stamina, "max_stamina");
        assert!(unpacked.faction == original.faction, "faction");
        assert!(unpacked.archetype == original.archetype, "archetype");
        assert!(unpacked.offense == original.offense, "offense");
        assert!(unpacked.defense == original.defense, "defense");
        assert!(unpacked.speed == original.speed, "speed");
        assert!(unpacked.move_cost == original.move_cost, "move_cost");
        assert!(unpacked.pos_x == original.pos_x, "pos_x");
        assert!(unpacked.pos_y == original.pos_y, "pos_y");
        assert!(unpacked.alive == original.alive, "alive");
        assert!(unpacked.guard_active == original.guard_active, "guard_active");
        assert!(unpacked.is_immovable == original.is_immovable, "is_immovable");
        assert!(unpacked.room_id == original.room_id, "room_id");
        assert!(unpacked.player == original.player, "player");
        assert!(unpacked.game_id == original.game_id, "game_id");
        assert!(unpacked.actor_id == original.actor_id, "actor_id");
    }

    #[test]
    fn test_actor_state_round_trip_zero_values() {
        let original = ActorState {
            player: starknet::contract_address_const::<0x0>(),
            game_id: 0,
            actor_id: 0,
            faction: 0,
            archetype: 0,
            hp: 0,
            max_hp: 0,
            stamina: 0,
            max_stamina: 0,
            offense: 0,
            defense: 0,
            speed: 0,
            move_cost: 0,
            pos_x: 0,
            pos_y: 0,
            alive: false,
            guard_active: false,
            is_immovable: false,
            room_id: 0,
        };
        let packed = ActorStatePackingTrait::pack(@original);
        let unpacked = packed.unpack();
        assert!(unpacked.hp == 0, "hp");
        assert!(unpacked.alive == false, "alive");
        assert!(unpacked.faction == 0, "faction");
    }

    #[test]
    fn test_actor_state_round_trip_typical_player() {
        let original = ActorState {
            player: starknet::contract_address_const::<0xabc>(),
            game_id: 1,
            actor_id: 0,
            faction: 0,
            archetype: 0,
            hp: 85,
            max_hp: 100,
            stamina: 50,
            max_stamina: 80,
            offense: 20,
            defense: 5,
            speed: 10,
            move_cost: 10,
            pos_x: 3,
            pos_y: 4,
            alive: true,
            guard_active: false,
            is_immovable: false,
            room_id: 5,
        };
        let packed = ActorStatePackingTrait::pack(@original);
        let unpacked = packed.unpack();
        assert!(unpacked.hp == 85, "hp");
        assert!(unpacked.max_hp == 100, "max_hp");
        assert!(unpacked.stamina == 50, "stamina");
        assert!(unpacked.pos_x == 3 && unpacked.pos_y == 4, "pos");
        assert!(unpacked.alive, "alive");
        assert!(unpacked.room_id == 5, "room_id");
    }

    // Stamina field u16 round-trip headroom. Under the single-mode POC,
    // stamina rarely exceeds ~200 in practice, but the packing schema
    // allocates 16 bits so large values must still survive.
    #[test]
    fn test_actor_state_round_trip_high_stamina() {
        let original = ActorState {
            player: starknet::contract_address_const::<0xabc>(),
            game_id: 1,
            actor_id: 0,
            faction: 0,
            archetype: 0,
            hp: 80,
            max_hp: 80,
            stamina: 4000,
            max_stamina: 4000,
            offense: 20,
            defense: 5,
            speed: 10,
            move_cost: 10,
            pos_x: 1,
            pos_y: 1,
            alive: true,
            guard_active: false,
            is_immovable: false,
            room_id: 0,
        };
        let packed = ActorStatePackingTrait::pack(@original);
        let unpacked = packed.unpack();
        assert!(unpacked.stamina == 4000, "high stamina");
        assert!(unpacked.max_stamina == 4000, "high max_stamina");
    }

    // Verify the packed archetype field (3 bits) carries the new Drainer
    // archetype (6) cleanly.
    #[test]
    fn test_actor_state_round_trip_drainer_archetype() {
        let original = ActorState {
            player: starknet::contract_address_const::<0xabc>(),
            game_id: 1,
            actor_id: 1,
            faction: 1,
            archetype: 6, // ARCHETYPE_DRAINER
            hp: 22,
            max_hp: 22,
            stamina: 0,
            max_stamina: 0,
            offense: 0,
            defense: 4,
            speed: 6,
            move_cost: 0,
            pos_x: 5,
            pos_y: 5,
            alive: true,
            guard_active: false,
            is_immovable: false,
            room_id: 0,
        };
        let packed = ActorStatePackingTrait::pack(@original);
        let unpacked = packed.unpack();
        assert!(unpacked.archetype == 6, "drainer archetype round trip");
    }
}
