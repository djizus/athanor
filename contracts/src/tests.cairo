use dojo::model::{ModelStorage, ModelStorageTest};
use dojo::world::WorldStorageTrait;
use dojo::world::world;
use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, spawn_test_world,
};
use dojo_cairo_test::world::WorldStorageTestTrait;
use starknet::syscalls::call_contract_syscall;
use starknet::{ContractAddress, SyscallResultTrait, get_contract_address};

use athanor::v2::helpers::bitmap as bitmap_v2;
use athanor::v2::events::index::{
    e_RunSpawnedV2, e_RoomEnteredV2, e_ActorMoved, e_AbilityUsed, e_GuardApplied,
    e_TelegraphCreated, e_TelegraphResolved, e_EnemyTurnComputed, e_TurnEnded as e_TurnEndedV2,
    e_ActorDamaged, e_ActorDied, e_RoomCleared, e_RunCompleted, e_RunFailed,
};
use athanor::v2::models::index::{
    RunState, RoomState, ActorState, AbilitySlotState, TelegraphState,
};
use athanor::v2::models::run_state::m_RunState;
use athanor::v2::models::room_state::m_RoomState;
use athanor::v2::models::actor_state::m_ActorState;
use athanor::v2::models::ability_slot::m_AbilitySlotState;
use athanor::v2::models::telegraph_state::m_TelegraphState;
use athanor::v2::systems::actions_v2::actions_v2;
use athanor::v2::systems::phase::{
    PHASE_EXPLORE, PHASE_PLAYER_TURN, PHASE_ENEMY_TURN, PHASE_COMPLETE, PHASE_FAILED,
    FACTION_PLAYER,
    ARCHETYPE_HERO, ARCHETYPE_BRUTE, ARCHETYPE_CASTER,
    ABILITY_STRIKE, ABILITY_DASH, ABILITY_CLEAVE, ABILITY_FIREBALL, ABILITY_GUARD,
    TARGET_SINGLE, TARGET_DIRECTIONAL, TARGET_POSITIONAL, TARGET_SELF,
};

#[starknet::interface]
trait IActionsV2<T> {
    fn spawn_v2(ref self: T, class_id: u8);
    fn enter_room_v2(ref self: T, game_id: u32, room_id: u8);
    fn move_v2(ref self: T, game_id: u32, target_x: u8, target_y: u8);
    fn use_ability_v2(
        ref self: T, game_id: u32, ability_id: u8, target_mode: u8, target_a: u8, target_b: u8,
    );
    fn end_player_phase_v2(ref self: T, game_id: u32);
    fn step_enemy_phase_v2(ref self: T, game_id: u32);
}

fn namespace_def_v2() -> NamespaceDef {
    NamespaceDef {
        namespace: "athanor_v2",
        resources: [
            TestResource::Model(m_RunState::TEST_CLASS_HASH),
            TestResource::Model(m_RoomState::TEST_CLASS_HASH),
            TestResource::Model(m_ActorState::TEST_CLASS_HASH),
            TestResource::Model(m_AbilitySlotState::TEST_CLASS_HASH),
            TestResource::Model(m_TelegraphState::TEST_CLASS_HASH),
            TestResource::Event(e_RunSpawnedV2::TEST_CLASS_HASH),
            TestResource::Event(e_RoomEnteredV2::TEST_CLASS_HASH),
            TestResource::Event(e_ActorMoved::TEST_CLASS_HASH),
            TestResource::Event(e_AbilityUsed::TEST_CLASS_HASH),
            TestResource::Event(e_GuardApplied::TEST_CLASS_HASH),
            TestResource::Event(e_TelegraphCreated::TEST_CLASS_HASH),
            TestResource::Event(e_TelegraphResolved::TEST_CLASS_HASH),
            TestResource::Event(e_EnemyTurnComputed::TEST_CLASS_HASH),
            TestResource::Event(e_TurnEndedV2::TEST_CLASS_HASH),
            TestResource::Event(e_ActorDamaged::TEST_CLASS_HASH),
            TestResource::Event(e_ActorDied::TEST_CLASS_HASH),
            TestResource::Event(e_RoomCleared::TEST_CLASS_HASH),
            TestResource::Event(e_RunCompleted::TEST_CLASS_HASH),
            TestResource::Event(e_RunFailed::TEST_CLASS_HASH),
            TestResource::Contract(actions_v2::TEST_CLASS_HASH),
        ]
            .span(),
    }
}

fn contract_defs_v2() -> Span<ContractDef> {
    [
        ContractDefTrait::new(@"athanor_v2", @"actions_v2")
            .with_writer_of([dojo::utils::bytearray_hash(@"athanor_v2")].span()),
    ]
        .span()
}

fn setup_v2() -> (dojo::world::WorldStorage, IActionsV2Dispatcher, ContractAddress) {
    let player = get_contract_address();
    starknet::testing::set_contract_address(player);

    let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def_v2()].span());
    world.sync_perms_and_inits(contract_defs_v2());

    let (contract_address, _) = world.dns(@"actions_v2").unwrap();
    let dispatcher = IActionsV2Dispatcher { contract_address };

    (world, dispatcher, player)
}

fn latest_game_id(world: dojo::world::WorldStorage) -> u32 {
    let next_uuid: u32 = dojo::world::IWorldDispatcherTrait::uuid(world.dispatcher)
        .try_into()
        .unwrap();
    next_uuid - 1_u32
}

#[test]
fn test_spawn_v2() {
    let (world, actions, player) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);

    let run: RunState = world.read_model((player, game_id));
    assert(run.phase == PHASE_EXPLORE, 'phase');
    assert(run.room_id == 0, 'room');
    assert(run.turn_index == 0, 'turn');

    let actor: ActorState = world.read_model((player, game_id, 0_u8));
    assert(actor.faction == FACTION_PLAYER, 'faction');
    assert(actor.archetype == ARCHETYPE_HERO, 'archetype');
    assert(actor.hp == 100, 'hp');
    assert(actor.stamina == 100, 'stamina');
    assert(actor.alive, 'alive');

    let mut slot_index: u8 = 0;
    while slot_index < 5 {
        let slot: AbilitySlotState = world.read_model((player, game_id, 0_u8, slot_index));
        assert(slot.cooldown_remaining == 0, 'cd');
        assert(slot.ability_id == slot_index, 'ability id');
        slot_index += 1;
    };
}

#[test]
fn test_enter_room_v2() {
    let (world, actions, player) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);
    actions.enter_room_v2(game_id, 0);

    let room: RoomState = world.read_model((player, game_id, 0_u8));
    assert(room.width == 8, 'width');
    assert(room.height == 8, 'height');
    assert(bitmap_v2::get_bit(room.blocked, 0, 0), 'blocked 0,0');
    assert(bitmap_v2::get_bit(room.blocked, 3, 2), 'blocked 3,2');
    assert(room.enemy_count == 2, 'enemy count');

    let brute: ActorState = world.read_model((player, game_id, 1_u8));
    assert(brute.archetype == ARCHETYPE_BRUTE, 'brute type');
    assert(brute.pos_x == 6 && brute.pos_y == 2, 'brute pos');
    assert(brute.alive, 'brute alive');

    let caster: ActorState = world.read_model((player, game_id, 2_u8));
    assert(caster.archetype == ARCHETYPE_CASTER, 'caster type');
    assert(caster.pos_x == 5 && caster.pos_y == 6, 'caster pos');
    assert(caster.alive, 'caster alive');

    let run: RunState = world.read_model((player, game_id));
    assert(run.phase == PHASE_PLAYER_TURN, 'phase');

    let hero: ActorState = world.read_model((player, game_id, 0_u8));
    assert(hero.stamina == 100, 'stamina reset');
}

#[test]
fn test_move_v2() {
    let (world, actions, player) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);
    actions.enter_room_v2(game_id, 0);

    let before_room: RoomState = world.read_model((player, game_id, 0_u8));
    assert(bitmap_v2::get_bit(before_room.occupancy, 1, 1), 'old set');
    assert(!bitmap_v2::get_bit(before_room.occupancy, 2, 1), 'new clear');

    actions.move_v2(game_id, 2, 1);

    let hero: ActorState = world.read_model((player, game_id, 0_u8));
    assert(hero.pos_x == 2 && hero.pos_y == 1, 'hero moved');
    assert(hero.stamina == 90, 'stamina');

    let after_room: RoomState = world.read_model((player, game_id, 0_u8));
    assert(!bitmap_v2::get_bit(after_room.occupancy, 1, 1), 'old cleared');
    assert(bitmap_v2::get_bit(after_room.occupancy, 2, 1), 'new set');
}

#[test]
#[should_panic]
fn test_move_v2_blocked() {
    let (world, actions, _) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);
    actions.enter_room_v2(game_id, 0);
    actions.move_v2(game_id, 1, 0);
}

#[test]
#[should_panic]
fn test_move_v2_out_of_stamina() {
    let (world, actions, _) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);
    actions.enter_room_v2(game_id, 0);

    let mut i: u8 = 0;
    let mut target_x: u8 = 2;
    while i < 10 {
        actions.move_v2(game_id, target_x, 1);
        if target_x == 2 {
            target_x = 1;
        } else {
            target_x = 2;
        };
        i += 1;
    };

    actions.move_v2(game_id, 2, 1);
}

#[test]
fn test_strike() {
    let (world, actions, player) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);
    actions.enter_room_v2(game_id, 0);
    actions.move_v2(game_id, 6, 1);
    actions.use_ability_v2(game_id, ABILITY_STRIKE, TARGET_SINGLE, 1, 0);

    let brute: ActorState = world.read_model((player, game_id, 1_u8));
    assert(brute.hp == 8, 'brute hp');

    let hero: ActorState = world.read_model((player, game_id, 0_u8));
    assert(hero.stamina == 35, 'hero stamina');

    let slot: AbilitySlotState = world.read_model((player, game_id, 0_u8, ABILITY_STRIKE));
    assert(slot.cooldown_remaining == 0, 'strike cd');
}

#[test]
fn test_dash() {
    let (world, actions, player) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);
    actions.enter_room_v2(game_id, 0);
    actions.use_ability_v2(game_id, ABILITY_DASH, TARGET_DIRECTIONAL, 1, 0);

    let hero: ActorState = world.read_model((player, game_id, 0_u8));
    assert(hero.pos_x == 4 && hero.pos_y == 1, 'dash pos');
    assert(hero.stamina == 80, 'dash stamina');

    let room: RoomState = world.read_model((player, game_id, 0_u8));
    assert(!bitmap_v2::get_bit(room.occupancy, 1, 1), 'start clear');
    assert(bitmap_v2::get_bit(room.occupancy, 4, 1), 'dash tile set');

    let slot: AbilitySlotState = world.read_model((player, game_id, 0_u8, ABILITY_DASH));
    assert(slot.cooldown_remaining == 2, 'dash cd');
}

#[test]
fn test_cleave() {
    let (world, actions, player) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);
    actions.enter_room_v2(game_id, 0);
    actions.move_v2(game_id, 5, 1);
    actions.use_ability_v2(game_id, ABILITY_CLEAVE, TARGET_DIRECTIONAL, 2, 0);

    let brute: ActorState = world.read_model((player, game_id, 1_u8));
    assert(brute.hp == 13, 'brute hp');

    let hero: ActorState = world.read_model((player, game_id, 0_u8));
    assert(hero.stamina == 35, 'hero stamina');

    let slot: AbilitySlotState = world.read_model((player, game_id, 0_u8, ABILITY_CLEAVE));
    assert(slot.cooldown_remaining == 1, 'cleave cd');
}

#[test]
fn test_guard() {
    let (world, actions, player) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);
    actions.enter_room_v2(game_id, 0);
    actions.use_ability_v2(game_id, ABILITY_GUARD, TARGET_SELF, 0, 0);

    let hero: ActorState = world.read_model((player, game_id, 0_u8));
    assert(hero.guard_active, 'guard active');
    assert(hero.stamina == 90, 'guard stamina');

    let slot: AbilitySlotState = world.read_model((player, game_id, 0_u8, ABILITY_GUARD));
    assert(slot.cooldown_remaining == 3, 'guard cd');
}

#[test]
fn test_fireball() {
    let (world, actions, player) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);
    actions.enter_room_v2(game_id, 0);
    actions.move_v2(game_id, 3, 1);
    actions.use_ability_v2(game_id, ABILITY_FIREBALL, TARGET_POSITIONAL, 6, 2);

    let brute: ActorState = world.read_model((player, game_id, 1_u8));
    let caster: ActorState = world.read_model((player, game_id, 2_u8));
    assert(brute.hp == 3, 'brute hp');
    assert(caster.hp == 25, 'caster hp');

    let hero: ActorState = world.read_model((player, game_id, 0_u8));
    assert(hero.stamina == 50, 'fireball stamina');

    let slot: AbilitySlotState = world.read_model((player, game_id, 0_u8, ABILITY_FIREBALL));
    assert(slot.cooldown_remaining == 2, 'fireball cd');
}

#[test]
fn test_end_player_phase() {
    let (world, actions, player) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);
    actions.enter_room_v2(game_id, 0);
    actions.end_player_phase_v2(game_id);

    let run: RunState = world.read_model((player, game_id));
    assert(run.phase == PHASE_ENEMY_TURN, 'phase');
}

#[test]
fn test_step_enemy_phase() {
    let (world, actions, player) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);
    actions.enter_room_v2(game_id, 0);
    actions.end_player_phase_v2(game_id);
    actions.step_enemy_phase_v2(game_id);

    let run: RunState = world.read_model((player, game_id));
    assert(run.phase == PHASE_PLAYER_TURN, 'phase');
    assert(run.turn_index == 1, 'turn index');
    assert(run.status_flags == 1, 'telegraph count');

    let hero: ActorState = world.read_model((player, game_id, 0_u8));
    assert(hero.stamina == 100, 'stamina reset');

    let brute: ActorState = world.read_model((player, game_id, 1_u8));
    let caster: ActorState = world.read_model((player, game_id, 2_u8));
    assert(brute.pos_x == 5 && brute.pos_y == 2, 'brute moved');
    assert(caster.pos_x == 5 && caster.pos_y == 6, 'caster kept dist');

    let tg0: TelegraphState = world.read_model((player, game_id, 0_u8));
    assert(!tg0.resolved, 'tg unresolved');
    assert(tg0.resolves_turn == 1, 'tg turn');
}

#[test]
fn test_telegraph_resolve() {
    let (world, actions, player) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);
    actions.enter_room_v2(game_id, 0);
    actions.end_player_phase_v2(game_id);
    actions.step_enemy_phase_v2(game_id);

    actions.end_player_phase_v2(game_id);
    actions.step_enemy_phase_v2(game_id);

    let hero: ActorState = world.read_model((player, game_id, 0_u8));
    assert(hero.hp == 85, 'telegraph dmg');

    let tg0: TelegraphState = world.read_model((player, game_id, 0_u8));
    assert(tg0.resolved, 'tg resolved');
}

#[test]
fn test_room_clear() {
    let (mut world, actions, player) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);
    actions.enter_room_v2(game_id, 0);

    let mut room: RoomState = world.read_model((player, game_id, 0_u8));
    let mut brute: ActorState = world.read_model((player, game_id, 1_u8));
    let mut caster: ActorState = world.read_model((player, game_id, 2_u8));

    brute.hp = 1;
    caster.hp = 1;
    room.occupancy = bitmap_v2::clear_bit(room.occupancy, caster.pos_x, caster.pos_y);
    caster.pos_x = 5;
    caster.pos_y = 2;
    room.occupancy = bitmap_v2::set_bit(room.occupancy, caster.pos_x, caster.pos_y);

    world.write_model_test(@brute);
    world.write_model_test(@caster);
    world.write_model_test(@room);

    actions.move_v2(game_id, 5, 1);
    actions.use_ability_v2(game_id, ABILITY_CLEAVE, TARGET_DIRECTIONAL, 2, 0);

    let room_after: RoomState = world.read_model((player, game_id, 0_u8));
    let run_after: RunState = world.read_model((player, game_id));
    let brute_after: ActorState = world.read_model((player, game_id, 1_u8));
    let caster_after: ActorState = world.read_model((player, game_id, 2_u8));

    assert(room_after.enemy_count == 0, 'enemy count');
    assert(room_after.cleared, 'room cleared');
    assert(run_after.phase == PHASE_COMPLETE, 'run complete');
    assert(!brute_after.alive, 'brute dead');
    assert(!caster_after.alive, 'caster dead');
}

#[test]
fn test_player_death() {
    let (mut world, actions, player) = setup_v2();

    actions.spawn_v2(0);
    let game_id = latest_game_id(world);
    actions.enter_room_v2(game_id, 0);

    let mut hero: ActorState = world.read_model((player, game_id, 0_u8));
    hero.hp = 1;
    world.write_model_test(@hero);

    actions.end_player_phase_v2(game_id);
    actions.step_enemy_phase_v2(game_id);

    actions.end_player_phase_v2(game_id);
    actions.step_enemy_phase_v2(game_id);

    let run: RunState = world.read_model((player, game_id));
    let hero_after: ActorState = world.read_model((player, game_id, 0_u8));
    assert(run.phase == PHASE_FAILED, 'failed');
    assert(!hero_after.alive, 'dead');
    assert(hero_after.hp == 0, 'hp 0');
}

#[test]
fn test_deterministic_enemy_behavior() {
    let (world, actions, player) = setup_v2();

    actions.spawn_v2(0);
    let game_1 = latest_game_id(world);
    actions.enter_room_v2(game_1, 0);
    actions.end_player_phase_v2(game_1);
    actions.step_enemy_phase_v2(game_1);

    actions.spawn_v2(0);
    let game_2 = latest_game_id(world);
    actions.enter_room_v2(game_2, 0);
    actions.end_player_phase_v2(game_2);
    actions.step_enemy_phase_v2(game_2);

    let brute_1: ActorState = world.read_model((player, game_1, 1_u8));
    let caster_1: ActorState = world.read_model((player, game_1, 2_u8));
    let brute_2: ActorState = world.read_model((player, game_2, 1_u8));
    let caster_2: ActorState = world.read_model((player, game_2, 2_u8));

    assert(brute_1.pos_x == 5 && brute_1.pos_y == 2, 'brute expected');
    assert(caster_1.pos_x == 5 && caster_1.pos_y == 6, 'caster expected');
    assert(brute_1.pos_x == brute_2.pos_x && brute_1.pos_y == brute_2.pos_y, 'brute deterministic');
    assert(caster_1.pos_x == caster_2.pos_x && caster_1.pos_y == caster_2.pos_y, 'caster deterministic');
}
