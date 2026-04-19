use starknet::ContractAddress;
use dojo::world::WorldStorage;
use dojo::model::ModelStorage;
use dojo::event::EventStorage;

use athanor::models::index::{
    RunState, RunOwner, RoomState, ActorState, ActorStatePacked, AbilitySlotState,
    AbilitySlotStatePacked, TelegraphState, TelegraphStatePacked,
};
use athanor::models::actor_state::ActorStatePackingTrait;
use athanor::models::ability_slot::AbilitySlotStatePackingTrait;
use athanor::models::telegraph_state::TelegraphStatePackingTrait;
use athanor::models::config::{Config, GameSettings, GameSettingsMetadata};
use athanor::events::index::{
    RunSpawned, RoomEntered, ActorMoved, AbilityUsed, TelegraphCreated, TelegraphResolved,
    EnemyTurnComputed, TurnEnded,
    ActorDamaged, ActorDied, RoomCleared, RunCompleted, RunFailed,
    OrbSpawned, OrbCollected, RunEnded,
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

    fn get_run_owner(ref self: Store, game_id: u32) -> RunOwner {
        self.world.read_model(game_id)
    }

    fn set_run_owner(ref self: Store, model: @RunOwner) {
        self.world.write_model(model);
    }

    fn get_room_state(ref self: Store, player: ContractAddress, game_id: u32, room_id: u8) -> RoomState {
        self.world.read_model((player, game_id, room_id))
    }

    fn get_actor_state(ref self: Store, player: ContractAddress, game_id: u32, actor_id: u8) -> ActorState {
        let packed: ActorStatePacked = self.world.read_model((player, game_id, actor_id));
        packed.unpack()
    }

    fn get_ability_slot_state(
        ref self: Store, player: ContractAddress, game_id: u32, actor_id: u8, slot_index: u8,
    ) -> AbilitySlotState {
        let packed: AbilitySlotStatePacked = self
            .world
            .read_model((player, game_id, actor_id, slot_index));
        packed.unpack()
    }

    fn get_telegraph_state(ref self: Store, player: ContractAddress, game_id: u32, telegraph_id: u8) -> TelegraphState {
        let packed: TelegraphStatePacked = self.world.read_model((player, game_id, telegraph_id));
        packed.unpack()
    }

    // --- Model writes ---

    fn set_run_state(ref self: Store, model: @RunState) {
        self.world.write_model(model);
    }

    fn set_room_state(ref self: Store, model: @RoomState) {
        self.world.write_model(model);
    }

    fn set_actor_state(ref self: Store, model: @ActorState) {
        let packed = ActorStatePackingTrait::pack(model);
        self.world.write_model(@packed);
    }

    fn set_ability_slot_state(ref self: Store, model: @AbilitySlotState) {
        let packed = AbilitySlotStatePackingTrait::pack(model);
        self.world.write_model(@packed);
    }

    fn set_telegraph_state(ref self: Store, model: @TelegraphState) {
        let packed = TelegraphStatePackingTrait::pack(model);
        self.world.write_model(@packed);
    }

    // --- Config / Settings ---

    fn get_config(ref self: Store) -> Config {
        self.world.read_model(0)
    }

    fn set_config(ref self: Store, model: @Config) {
        self.world.write_model(model);
    }

    fn get_game_settings(ref self: Store, settings_id: u32) -> GameSettings {
        self.world.read_model(settings_id)
    }

    fn set_game_settings(ref self: Store, model: @GameSettings) {
        self.world.write_model(model);
    }

    fn get_game_settings_metadata(ref self: Store, settings_id: u32) -> GameSettingsMetadata {
        self.world.read_model(settings_id)
    }

    fn set_game_settings_metadata(ref self: Store, model: @GameSettingsMetadata) {
        self.world.write_model(model);
    }

    // --- Event emitters ---

    fn emit_run_spawned(
        ref self: Store, player: ContractAddress, game_id: u32, room_id: u8, player_actor_id: u8,
    ) {
        self.world.emit_event(@RunSpawned { player, game_id, room_id, player_actor_id });
    }

    fn emit_room_entered(ref self: Store, player: ContractAddress, game_id: u32, room_id: u8) {
        self.world.emit_event(@RoomEntered { player, game_id, room_id });
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

    fn emit_orb_spawned(
        ref self: Store,
        player: ContractAddress,
        game_id: u32,
        room_id: u8,
        pos_x: u8,
        pos_y: u8,
        turn_index: u16,
    ) {
        self
            .world
            .emit_event(
                @OrbSpawned { player, game_id, room_id, pos_x, pos_y, turn_index },
            );
    }

    fn emit_orb_collected(
        ref self: Store,
        player: ContractAddress,
        game_id: u32,
        room_id: u8,
        pos_x: u8,
        pos_y: u8,
        stamina_after: u16,
    ) {
        self
            .world
            .emit_event(
                @OrbCollected { player, game_id, room_id, pos_x, pos_y, stamina_after },
            );
    }

    fn emit_run_ended(
        ref self: Store,
        player: ContractAddress,
        game_id: u32,
        score: u32,
        rooms_cleared: u16,
        turn_index: u16,
        ended_at: u64,
    ) {
        self
            .world
            .emit_event(
                @RunEnded {
                    player, game_id, score, rooms_cleared, turn_index, ended_at,
                },
            );
    }
}
