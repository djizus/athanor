// TelegraphState uses a bitpacked on-chain representation. Callers work with
// the plain `TelegraphState` struct; the Store layer converts to/from
// `TelegraphStatePacked` transparently.
//
// packed_a layout (u64):
//   [ 0..8 ] source_actor_id (u8)
//   [ 8..12] shape_type      (4 bits, holds 0..4)
//   [12..14] telegraph_type  (2 bits, holds 0..1)
//   [14..15] resolved        (1 bit)
//   [15..23] param_a         (u8)
//   [23..31] param_b         (u8)
//   [31..39] param_c         (u8)
//   [39..47] pull_source_x   (u8)
//   [47..55] pull_source_y   (u8)
//   [55..63] room_id         (u8)
//
// packed_b layout (u64):
//   [ 0..8 ] pull_distance   (u8)
//   [ 8..24] damage          (u16)
//   [24..40] created_turn    (u16)
//   [40..56] resolves_turn   (u16)

use athanor::helpers::packing;

#[derive(Copy, Drop, Serde)]
pub struct TelegraphState {
    pub player: starknet::ContractAddress,
    pub game_id: u32,
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

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TelegraphStatePacked {
    #[key]
    pub player: starknet::ContractAddress,
    #[key]
    pub game_id: u32,
    #[key]
    pub telegraph_id: u8,
    pub packed_a: u64,
    pub packed_b: u64,
}

#[generate_trait]
pub impl TelegraphStatePackingImpl of TelegraphStatePackingTrait {
    fn unpack(self: @TelegraphStatePacked) -> TelegraphState {
        let a = *self.packed_a;
        let b = *self.packed_b;

        TelegraphState {
            player: *self.player,
            game_id: *self.game_id,
            telegraph_id: *self.telegraph_id,
            source_actor_id: (a & 0xFF).try_into().unwrap(),
            shape_type: (packing::shr64(a, 8) & 0xF).try_into().unwrap(),
            telegraph_type: (packing::shr64(a, 12) & 0x3).try_into().unwrap(),
            resolved: (packing::shr64(a, 14) & 1) == 1,
            param_a: (packing::shr64(a, 15) & 0xFF).try_into().unwrap(),
            param_b: (packing::shr64(a, 23) & 0xFF).try_into().unwrap(),
            param_c: (packing::shr64(a, 31) & 0xFF).try_into().unwrap(),
            pull_source_x: (packing::shr64(a, 39) & 0xFF).try_into().unwrap(),
            pull_source_y: (packing::shr64(a, 47) & 0xFF).try_into().unwrap(),
            room_id: (packing::shr64(a, 55) & 0xFF).try_into().unwrap(),
            pull_distance: (b & 0xFF).try_into().unwrap(),
            damage: (packing::shr64(b, 8) & 0xFFFF).try_into().unwrap(),
            created_turn: (packing::shr64(b, 24) & 0xFFFF).try_into().unwrap(),
            resolves_turn: (packing::shr64(b, 40) & 0xFFFF).try_into().unwrap(),
        }
    }

    fn pack(tg: @TelegraphState) -> TelegraphStatePacked {
        let source: u64 = (*tg.source_actor_id).into();
        let shape: u64 = ((*tg.shape_type) & 0xF).into();
        let tg_type: u64 = ((*tg.telegraph_type) & 0x3).into();
        let resolved: u64 = if *tg.resolved {
            1
        } else {
            0
        };
        let pa: u64 = (*tg.param_a).into();
        let pb: u64 = (*tg.param_b).into();
        let pc: u64 = (*tg.param_c).into();
        let psx: u64 = (*tg.pull_source_x).into();
        let psy: u64 = (*tg.pull_source_y).into();
        let room_id: u64 = (*tg.room_id).into();

        let packed_a = source
            | packing::shl64(shape, 8)
            | packing::shl64(tg_type, 12)
            | packing::shl64(resolved, 14)
            | packing::shl64(pa, 15)
            | packing::shl64(pb, 23)
            | packing::shl64(pc, 31)
            | packing::shl64(psx, 39)
            | packing::shl64(psy, 47)
            | packing::shl64(room_id, 55);

        let pull_distance: u64 = (*tg.pull_distance).into();
        let damage: u64 = (*tg.damage).into();
        let created: u64 = (*tg.created_turn).into();
        let resolves: u64 = (*tg.resolves_turn).into();

        let packed_b = pull_distance
            | packing::shl64(damage, 8)
            | packing::shl64(created, 24)
            | packing::shl64(resolves, 40);

        TelegraphStatePacked {
            player: *tg.player,
            game_id: *tg.game_id,
            telegraph_id: *tg.telegraph_id,
            packed_a,
            packed_b,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{TelegraphState, TelegraphStatePackingTrait};

    #[test]
    fn test_telegraph_state_round_trip_max_values() {
        let original = TelegraphState {
            player: starknet::contract_address_const::<0xdeadbeef>(),
            game_id: 99,
            telegraph_id: 7,
            source_actor_id: 255,
            shape_type: 4, // SHAPE_CROSS
            telegraph_type: 1, // TELEGRAPH_TYPE_PULL
            param_a: 255,
            param_b: 200,
            param_c: 100,
            pull_source_x: 7,
            pull_source_y: 6,
            pull_distance: 2,
            damage: 65535,
            created_turn: 40000,
            resolves_turn: 40001,
            resolved: true,
            room_id: 200,
        };
        let packed = TelegraphStatePackingTrait::pack(@original);
        let unpacked = packed.unpack();
        assert!(unpacked.source_actor_id == 255, "source_actor_id");
        assert!(unpacked.shape_type == 4, "shape_type");
        assert!(unpacked.telegraph_type == 1, "telegraph_type");
        assert!(unpacked.param_a == 255, "param_a");
        assert!(unpacked.param_b == 200, "param_b");
        assert!(unpacked.param_c == 100, "param_c");
        assert!(unpacked.pull_source_x == 7, "pull_source_x");
        assert!(unpacked.pull_source_y == 6, "pull_source_y");
        assert!(unpacked.pull_distance == 2, "pull_distance");
        assert!(unpacked.damage == 65535, "damage");
        assert!(unpacked.created_turn == 40000, "created_turn");
        assert!(unpacked.resolves_turn == 40001, "resolves_turn");
        assert!(unpacked.resolved, "resolved");
        assert!(unpacked.room_id == 200, "room_id");
    }

    #[test]
    fn test_telegraph_state_round_trip_typical() {
        let original = TelegraphState {
            player: starknet::contract_address_const::<0x1>(),
            game_id: 1,
            telegraph_id: 0,
            source_actor_id: 1,
            shape_type: 0, // SHAPE_SINGLE_TILE
            telegraph_type: 0, // TELEGRAPH_TYPE_DAMAGE
            param_a: 4,
            param_b: 4,
            param_c: 0,
            pull_source_x: 0,
            pull_source_y: 0,
            pull_distance: 0,
            damage: 15,
            created_turn: 3,
            resolves_turn: 4,
            resolved: false,
            room_id: 2,
        };
        let packed = TelegraphStatePackingTrait::pack(@original);
        let unpacked = packed.unpack();
        assert!(unpacked.damage == 15, "damage");
        assert!(unpacked.created_turn == 3, "created_turn");
        assert!(unpacked.resolves_turn == 4, "resolves_turn");
        assert!(!unpacked.resolved, "resolved=false");
    }
}
