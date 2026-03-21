use starknet::ContractAddress;
use dojo::world::WorldStorage;
use dojo::model::ModelStorage;
use dojo::event::EventStorage;

use athanor::models::index::{Character, Dungeon, Fight, PlayerState};
use athanor::events::index::{
    CharacterSpawned, DungeonCreated, ZoneEntered, FightStarted,
    MobDamaged, MobDied, PlayerDamaged, TurnEnded, FightEnded,
    DungeonCompleted, DungeonFailed,
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

    fn get_player_state(ref self: Store, player: ContractAddress) -> PlayerState {
        self.world.read_model(player)
    }

    fn get_character(ref self: Store, player: ContractAddress, game_id: u32) -> Character {
        self.world.read_model((player, game_id))
    }

    fn get_dungeon(ref self: Store, player: ContractAddress, game_id: u32) -> Dungeon {
        self.world.read_model((player, game_id))
    }

    fn get_fight(
        ref self: Store, player: ContractAddress, game_id: u32, zone_id: u8
    ) -> Fight {
        self.world.read_model((player, game_id, zone_id))
    }

    // --- Model writes ---

    fn set_player_state(ref self: Store, model: @PlayerState) {
        self.world.write_model(model);
    }

    fn set_character(ref self: Store, model: @Character) {
        self.world.write_model(model);
    }

    fn set_dungeon(ref self: Store, model: @Dungeon) {
        self.world.write_model(model);
    }

    fn set_fight(ref self: Store, model: @Fight) {
        self.world.write_model(model);
    }

    // --- Event emitters ---

    fn emit_character_spawned(
        ref self: Store,
        player: ContractAddress,
        game_id: u32,
        class_id: u8,
        health: u16,
        power: u16,
        stamina: u16,
    ) {
        self.world.emit_event(@CharacterSpawned { player, game_id, class_id, health, power, stamina });
    }

    fn emit_dungeon_created(ref self: Store, player: ContractAddress, game_id: u32) {
        self.world.emit_event(@DungeonCreated { player, game_id });
    }

    fn emit_zone_entered(ref self: Store, player: ContractAddress, game_id: u32, zone_id: u8) {
        self.world.emit_event(@ZoneEntered { player, game_id, zone_id });
    }

    fn emit_fight_started(
        ref self: Store, player: ContractAddress, game_id: u32, zone_id: u8, mob_count: u8,
    ) {
        self.world.emit_event(@FightStarted { player, game_id, zone_id, mob_count });
    }

    fn emit_mob_damaged(
        ref self: Store,
        player: ContractAddress,
        game_id: u32,
        zone_id: u8,
        mob_id: u8,
        damage: u16,
        remaining_hp: u16,
    ) {
        self.world.emit_event(@MobDamaged { player, game_id, zone_id, mob_id, damage, remaining_hp });
    }

    fn emit_mob_died(
        ref self: Store, player: ContractAddress, game_id: u32, zone_id: u8, mob_id: u8,
    ) {
        self.world.emit_event(@MobDied { player, game_id, zone_id, mob_id });
    }

    fn emit_player_damaged(
        ref self: Store, player: ContractAddress, game_id: u32, damage: u16, remaining_hp: u16,
    ) {
        self.world.emit_event(@PlayerDamaged { player, game_id, damage, remaining_hp });
    }

    fn emit_turn_ended(
        ref self: Store, player: ContractAddress, game_id: u32, zone_id: u8,
    ) {
        self.world.emit_event(@TurnEnded { player, game_id, zone_id });
    }

    fn emit_fight_ended(
        ref self: Store, player: ContractAddress, game_id: u32, zone_id: u8,
    ) {
        self.world.emit_event(@FightEnded { player, game_id, zone_id });
    }

    fn emit_dungeon_completed(ref self: Store, player: ContractAddress, game_id: u32) {
        self.world.emit_event(@DungeonCompleted { player, game_id });
    }

    fn emit_dungeon_failed(ref self: Store, player: ContractAddress, game_id: u32) {
        self.world.emit_event(@DungeonFailed { player, game_id });
    }
}
