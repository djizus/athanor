use starknet::ContractAddress;
use dojo::world::WorldStorage;
use dojo::model::ModelStorage;
use dojo::event::EventStorage;

use athanor::v2::models::index::{
    RunState, RoomState, ActorState, AbilitySlotState, TelegraphState,
};
use athanor::v2::events::index::{
    RunSpawnedV2, RoomEnteredV2, ActorMoved, AbilityUsed, TelegraphCreated, TelegraphResolved,
    EnemyTurnComputed, TurnEnded,
    ActorDamaged, ActorDied, RoomCleared, RunCompleted, RunFailed,
};

#[derive(Copy, Drop)]
pub struct Store {
    pub world: WorldStorage,
}

#[generate_trait]
pub impl StoreImpl of StoreTrait {
    fn new(world: WorldStorage) -> Store {
        Store { world }
    }

    // --- Model reads ---

    fn get_run_state(ref self: Store, player: ContractAddress, game_id: u32) -> RunState {
        self.world.read_model((player, game_id))
    }

    fn get_room_state(ref self: Store, player: ContractAddress, game_id: u32, room_id: u8) -> RoomState {
        self.world.read_model((player, game_id, room_id))
    }

    fn get_actor_state(ref self: Store, player: ContractAddress, game_id: u32, actor_id: u8) -> ActorState {
        self.world.read_model((player, game_id, actor_id))
    }

    fn get_ability_slot_state(
        ref self: Store, player: ContractAddress, game_id: u32, actor_id: u8, slot_index: u8,
    ) -> AbilitySlotState {
        self.world.read_model((player, game_id, actor_id, slot_index))
    }

    fn get_telegraph_state(ref self: Store, player: ContractAddress, game_id: u32, telegraph_id: u8) -> TelegraphState {
        self.world.read_model((player, game_id, telegraph_id))
    }

    // --- Model writes ---

    fn set_run_state(ref self: Store, model: @RunState) {
        self.world.write_model(model);
    }

    fn set_room_state(ref self: Store, model: @RoomState) {
        self.world.write_model(model);
    }

    fn set_actor_state(ref self: Store, model: @ActorState) {
        self.world.write_model(model);
    }

    fn set_ability_slot_state(ref self: Store, model: @AbilitySlotState) {
        self.world.write_model(model);
    }

    fn set_telegraph_state(ref self: Store, model: @TelegraphState) {
        self.world.write_model(model);
    }

    // --- Event emitters ---

    fn emit_run_spawned_v2(
        ref self: Store, player: ContractAddress, game_id: u32, room_id: u8, player_actor_id: u8,
    ) {
        self.world.emit_event(@RunSpawnedV2 { player, game_id, room_id, player_actor_id });
    }

    fn emit_room_entered_v2(ref self: Store, player: ContractAddress, game_id: u32, room_id: u8) {
        self.world.emit_event(@RoomEnteredV2 { player, game_id, room_id });
    }

    fn emit_actor_moved(
        ref self: Store,
        player: ContractAddress,
        game_id: u32,
        actor_id: u8,
        room_id: u8,
        from_x: u8,
        from_y: u8,
        to_x: u8,
        to_y: u8,
    ) {
        self.world.emit_event(@ActorMoved {
            player, game_id, actor_id, room_id, from_x, from_y, to_x, to_y,
        });
    }

    fn emit_ability_used(
        ref self: Store,
        player: ContractAddress,
        game_id: u32,
        actor_id: u8,
        ability_id: u8,
        room_id: u8,
        target_actor_id: u8,
        target_x: u8,
        target_y: u8,
    ) {
        self.world.emit_event(@AbilityUsed {
            player, game_id, actor_id, ability_id, room_id, target_actor_id, target_x, target_y,
        });
    }

    fn emit_telegraph_created(
        ref self: Store,
        player: ContractAddress,
        game_id: u32,
        telegraph_id: u8,
        source_actor_id: u8,
        room_id: u8,
        resolves_turn: u16,
    ) {
        self.world.emit_event(@TelegraphCreated {
            player, game_id, telegraph_id, source_actor_id, room_id, resolves_turn,
        });
    }

    fn emit_telegraph_resolved(
        ref self: Store, player: ContractAddress, game_id: u32, telegraph_id: u8, room_id: u8,
    ) {
        self.world.emit_event(@TelegraphResolved { player, game_id, telegraph_id, room_id });
    }

    fn emit_enemy_turn_computed(
        ref self: Store, player: ContractAddress, game_id: u32, room_id: u8, turn_index: u16,
    ) {
        self.world.emit_event(@EnemyTurnComputed { player, game_id, room_id, turn_index });
    }

    fn emit_turn_ended(
        ref self: Store, player: ContractAddress, game_id: u32, room_id: u8, turn_index: u16,
    ) {
        self.world.emit_event(@TurnEnded { player, game_id, room_id, turn_index });
    }

    fn emit_actor_damaged(
        ref self: Store,
        player: ContractAddress,
        game_id: u32,
        actor_id: u8,
        source_actor_id: u8,
        damage: u16,
        remaining_hp: u16,
        room_id: u8,
    ) {
        self.world.emit_event(@ActorDamaged {
            player, game_id, actor_id, source_actor_id, damage, remaining_hp, room_id,
        });
    }

    fn emit_actor_died(ref self: Store, player: ContractAddress, game_id: u32, actor_id: u8, room_id: u8) {
        self.world.emit_event(@ActorDied { player, game_id, actor_id, room_id });
    }

    fn emit_room_cleared(ref self: Store, player: ContractAddress, game_id: u32, room_id: u8) {
        self.world.emit_event(@RoomCleared { player, game_id, room_id });
    }

    fn emit_run_completed(ref self: Store, player: ContractAddress, game_id: u32, turn_index: u16) {
        self.world.emit_event(@RunCompleted { player, game_id, turn_index });
    }

    fn emit_run_failed(ref self: Store, player: ContractAddress, game_id: u32, turn_index: u16) {
        self.world.emit_event(@RunFailed { player, game_id, turn_index });
    }
}
