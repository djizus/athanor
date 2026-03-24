use dojo::model::{ModelStorage, ModelStorageTest};
use dojo::world::WorldStorageTrait;
use dojo::world::world;
use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, spawn_test_world,
};
use dojo_cairo_test::world::WorldStorageTestTrait;
use starknet::syscalls::call_contract_syscall;
use starknet::{ContractAddress, SyscallResultTrait, get_contract_address};

use athanor::constants::{AA_COST, MAX_HEALTH, MAX_STAMINA, MOB_HEALTH, MOB_POWER, POWER};
use athanor::events::index::{
    e_CharacterSpawned, e_DungeonCompleted, e_DungeonCreated, e_DungeonFailed, e_FightEnded,
    e_FightStarted, e_MobDamaged, e_MobDied, e_PlayerDamaged, e_TurnEnded, e_ZoneEntered,
};
use athanor::helpers::packing::get_mob_health;
use athanor::models::character::{Character, m_Character};
use athanor::models::dungeon::{Dungeon, m_Dungeon};
use athanor::models::fight::{Fight, m_Fight};
use athanor::models::player_state::{PlayerState, m_PlayerState};
use athanor::systems::actions::actions;
use athanor::types::direction::Direction;

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

fn namespace_def() -> NamespaceDef {
    NamespaceDef {
        namespace: "athanor",
        resources: [
            TestResource::Model(m_PlayerState::TEST_CLASS_HASH),
            TestResource::Model(m_Character::TEST_CLASS_HASH),
            TestResource::Model(m_Dungeon::TEST_CLASS_HASH),
            TestResource::Model(m_Fight::TEST_CLASS_HASH),
            TestResource::Event(e_CharacterSpawned::TEST_CLASS_HASH),
            TestResource::Event(e_DungeonCreated::TEST_CLASS_HASH),
            TestResource::Event(e_ZoneEntered::TEST_CLASS_HASH),
            TestResource::Event(e_FightStarted::TEST_CLASS_HASH),
            TestResource::Event(e_MobDamaged::TEST_CLASS_HASH),
            TestResource::Event(e_MobDied::TEST_CLASS_HASH),
            TestResource::Event(e_PlayerDamaged::TEST_CLASS_HASH),
            TestResource::Event(e_TurnEnded::TEST_CLASS_HASH),
            TestResource::Event(e_FightEnded::TEST_CLASS_HASH),
            TestResource::Event(e_DungeonCompleted::TEST_CLASS_HASH),
            TestResource::Event(e_DungeonFailed::TEST_CLASS_HASH),
            TestResource::Contract(actions::TEST_CLASS_HASH),
        ]
            .span(),
    }
}

fn contract_defs() -> Span<ContractDef> {
    [
        ContractDefTrait::new(@"athanor", @"actions")
            .with_writer_of([dojo::utils::bytearray_hash(@"athanor")].span()),
    ]
        .span()
}

fn setup() -> (dojo::world::WorldStorage, ContractAddress, ContractAddress) {
    let player = get_contract_address();

    let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
    world.sync_perms_and_inits(contract_defs());

    let (contract_address, _) = world.dns(@"actions").unwrap();
    (world, contract_address, player)
}

fn action_spawn(contract_address: ContractAddress, class_id: u8) {
    call_contract_syscall(
        contract_address, selector!("spawn"), [class_id.into()].span(),
    )
        .unwrap_syscall();
}

fn action_choose(contract_address: ContractAddress, game_id: u32, direction: Direction) {
    let direction_raw: u8 = match direction {
        Direction::Left => 0,
        Direction::Right => 1,
    };

    call_contract_syscall(
        contract_address,
        selector!("choose"),
        [game_id.into(), direction_raw.into()].span(),
    )
        .unwrap_syscall();
}

fn action_start(contract_address: ContractAddress, game_id: u32) {
    call_contract_syscall(contract_address, selector!("start"), [game_id.into()].span())
        .unwrap_syscall();
}

fn action_cast(contract_address: ContractAddress, game_id: u32, mob_id: u8, skill_id: u8) {
    call_contract_syscall(
        contract_address,
        selector!("cast"),
        [game_id.into(), mob_id.into(), skill_id.into()].span(),
    )
        .unwrap_syscall();
}

fn action_finish(contract_address: ContractAddress, game_id: u32) {
    call_contract_syscall(contract_address, selector!("finish"), [game_id.into()].span())
        .unwrap_syscall();
}

fn zone_bit(zone_id: u8) -> u8 {
    let mut bit: u8 = 1;
    let mut i: u8 = 0;
    while i < zone_id {
        bit *= 2;
        i += 1;
    };
    bit
}

#[test]
fn test_spawn_creates_initial_state_and_increments_game_count() {
    let (world, contract_address, player) = setup();

    action_spawn(contract_address, 0);

    let ps: PlayerState = world.read_model(player);
    assert(ps.game_count == 1, 'game_count should be 1');

    let character: Character = world.read_model((player, 1_u32));
    assert(character.class_id == 0, 'class_id mismatch');
    assert(character.health == MAX_HEALTH, 'health mismatch');
    assert(character.power == POWER, 'power mismatch');
    assert(character.stamina == MAX_STAMINA, 'stamina mismatch');
    assert(character.current_zone == 0, 'zone mismatch');

    let dungeon: Dungeon = world.read_model((player, 1_u32));
    assert(dungeon.zones_cleared == 0, 'zones_cleared mismatch');
    assert(!dungeon.completed, 'dungeon should not be completed');
    assert(!dungeon.failed, 'dungeon should not be failed');
}

#[test]
fn test_spawn_twice_creates_independent_games() {
    let (world, contract_address, player) = setup();

    action_spawn(contract_address, 0);
    action_spawn(contract_address, 0);

    let ps: PlayerState = world.read_model(player);
    assert(ps.game_count == 2, 'game_count should be 2');

    let game1: Character = world.read_model((player, 1_u32));
    let game2: Character = world.read_model((player, 2_u32));

    assert(game1.game_id == 1, 'game1 id mismatch');
    assert(game2.game_id == 2, 'game2 id mismatch');

    let game2_zone = 2;
    action_choose(contract_address, 2, Direction::Right);

    let game1_after: Character = world.read_model((player, 1_u32));
    let game2_after: Character = world.read_model((player, 2_u32));

    assert(game1_after.current_zone == 0, 'game1 should remain in zone 0');
    assert(game2_after.current_zone == game2_zone, 'game2 should move to zone 2');
}

#[test]
fn test_choose_left_from_zone_zero_moves_to_zone_one() {
    let (world, contract_address, player) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Left);

    let character: Character = world.read_model((player, 1_u32));
    assert(character.current_zone == 1, 'left should go to zone 1');
}

#[test]
fn test_choose_right_from_zone_zero_moves_to_zone_two() {
    let (world, contract_address, player) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Right);

    let character: Character = world.read_model((player, 1_u32));
    assert(character.current_zone == 2, 'right should go to zone 2');
}

#[test]
#[should_panic]
fn test_choose_at_non_fork_panics() {
    let (_, contract_address, _) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Left);
    action_choose(contract_address, 1, Direction::Right);
}

#[test]
fn test_start_in_zone_one_creates_fight_with_packed_hp() {
    let (world, contract_address, player) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Left);
    action_start(contract_address, 1);

    let fight: Fight = world.read_model((player, 1_u32, 1_u8));
    assert(fight.active, 'fight should be active');
    assert(fight.mob_count == 1, 'zone 1 should have one mob');
    assert(fight.mob_power == MOB_POWER, 'mob power mismatch');
    assert(get_mob_health(fight.mob_healths, 0) == MOB_HEALTH, 'mob 0 hp mismatch');
    assert(get_mob_health(fight.mob_healths, 1) == 0, 'mob 1 should be empty');
}

#[test]
#[should_panic]
fn test_start_in_zone_zero_panics() {
    let (_, contract_address, _) = setup();

    action_spawn(contract_address, 0);
    action_start(contract_address, 1);
}

#[test]
fn test_cast_deals_damage_and_spends_stamina() {
    let (world, contract_address, player) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Left);
    action_start(contract_address, 1);
    action_cast(contract_address, 1, 0, 0);

    let character: Character = world.read_model((player, 1_u32));
    assert(character.stamina == MAX_STAMINA - AA_COST, 'stamina not reduced by AA cost');

    let fight: Fight = world.read_model((player, 1_u32, 1_u8));
    assert(get_mob_health(fight.mob_healths, 0) == MOB_HEALTH - POWER, 'mob hp not reduced');
}

#[test]
#[should_panic]
fn test_cast_on_dead_mob_panics() {
    let (_, contract_address, _) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Left);
    action_start(contract_address, 1);
    action_cast(contract_address, 1, 0, 0);
    action_cast(contract_address, 1, 0, 0);
    action_cast(contract_address, 1, 0, 0);
}

#[test]
#[should_panic]
fn test_cast_with_no_stamina_panics() {
    let (mut world, contract_address, player) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Left);
    action_start(contract_address, 1);

    // Set stamina below AA_COST (30) to properly test the stamina check
    let mut character: Character = world.read_model((player, 1_u32));
    character.stamina = 20;
    world.write_model_test(@character);

    action_cast(contract_address, 1, 0, 0); // panics: Not enough stamina
}

#[test]
fn test_finish_applies_simultaneous_damage_and_resets_stamina() {
    let (world, contract_address, player) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Left);
    action_start(contract_address, 1);
    action_cast(contract_address, 1, 0, 0);
    action_finish(contract_address, 1);

    let character: Character = world.read_model((player, 1_u32));
    assert(character.health == MAX_HEALTH - MOB_POWER, 'health mismatch');
    assert(character.stamina == MAX_STAMINA, 'stamina mismatch');

    let fight: Fight = world.read_model((player, 1_u32, 1_u8));
    assert(fight.active, 'fight active mismatch');
}

#[test]
fn test_finish_when_all_mobs_dead_clears_zone_and_auto_advances() {
    let (world, contract_address, player) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Left);
    action_start(contract_address, 1);
    action_cast(contract_address, 1, 0, 0);
    action_cast(contract_address, 1, 0, 0);
    action_finish(contract_address, 1);

    let fight: Fight = world.read_model((player, 1_u32, 1_u8));
    assert(!fight.active, 'fight active mismatch');

    let dungeon: Dungeon = world.read_model((player, 1_u32));
    assert(dungeon.zones_cleared & zone_bit(1) != 0, 'zone 1 should be marked cleared');

    let character: Character = world.read_model((player, 1_u32));
    assert(character.current_zone == 3, 'zone mismatch');
}

#[test]
fn test_finish_when_player_dies_marks_dungeon_failed() {
    let (mut world, contract_address, player) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Left);
    action_start(contract_address, 1);

    let mut character: Character = world.read_model((player, 1_u32));
    character.health = 1;
    world.write_model_test(@character);

    action_finish(contract_address, 1);

    let dungeon: Dungeon = world.read_model((player, 1_u32));
    assert(dungeon.failed, 'dungeon should be marked failed');

    let character_after: Character = world.read_model((player, 1_u32));
    assert(character_after.health == 0, 'health mismatch');

    let fight: Fight = world.read_model((player, 1_u32, 1_u8));
    assert(!fight.active, 'fight active mismatch');
}

#[test]
fn test_full_run_reaches_dungeon_completed() {
    let (world, contract_address, player) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Left);

    // Zone 1 (1 mob)
    action_start(contract_address, 1);
    action_cast(contract_address, 1, 0, 0);
    action_cast(contract_address, 1, 0, 0);
    action_finish(contract_address, 1);

    // Auto-advanced to Zone 3 (2 mobs)
    action_start(contract_address, 1);
    action_cast(contract_address, 1, 0, 0);
    action_cast(contract_address, 1, 0, 0);
    action_finish(contract_address, 1);
    action_cast(contract_address, 1, 1, 0);
    action_cast(contract_address, 1, 1, 0);
    action_finish(contract_address, 1);

    // Auto-advanced to Zone 4 (4 mobs)
    action_start(contract_address, 1);

    // Turn 1: 3 casts + finish
    action_cast(contract_address, 1, 0, 0);
    action_cast(contract_address, 1, 0, 0);
    action_cast(contract_address, 1, 1, 0);
    action_finish(contract_address, 1);

    // Turn 2: 3 casts + finish
    action_cast(contract_address, 1, 1, 0);
    action_cast(contract_address, 1, 2, 0);
    action_cast(contract_address, 1, 2, 0);
    action_finish(contract_address, 1);

    // Turn 3: 2 casts + finish (remaining mob)
    action_cast(contract_address, 1, 3, 0);
    action_cast(contract_address, 1, 3, 0);
    action_finish(contract_address, 1);

    let dungeon: Dungeon = world.read_model((player, 1_u32));
    assert(dungeon.completed, 'completed mismatch');
    assert(!dungeon.failed, 'failed mismatch');

    let character: Character = world.read_model((player, 1_u32));
    assert(character.current_zone == 4, 'zone mismatch');

    let fight: Fight = world.read_model((player, 1_u32, 4_u8));
    assert(!fight.active, 'fight active mismatch');
}

// --- Additional edge-case tests from PLAN.md ---

#[test]
#[should_panic]
fn test_start_when_fight_already_active_panics() {
    let (_, contract_address, _) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Left);
    action_start(contract_address, 1);
    action_start(contract_address, 1); // second start while fight active
}

#[test]
#[should_panic]
fn test_cast_when_no_active_fight_panics() {
    let (_, contract_address, _) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Left);
    // no start() — cast without an active fight
    action_cast(contract_address, 1, 0, 0);
}

#[test]
#[should_panic]
fn test_finish_when_no_active_fight_panics() {
    let (_, contract_address, _) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Left);
    // no start() — finish without an active fight
    action_finish(contract_address, 1);
}

// NOTE: "choose before clearing zone combat: reverts" is architecturally unreachable in the
// current dungeon graph — zone 0 is the only fork and zone_mob_count(0) == 0, so the
// `if mob_count > 0` guard in choose() is never entered. The validation code exists
// but cannot be triggered without a graph where a fork zone has mobs.

#[test]
#[should_panic]
fn test_start_zone_already_cleared_panics() {
    let (mut world, contract_address, player) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Left);
    action_start(contract_address, 1);
    action_cast(contract_address, 1, 0, 0);
    action_cast(contract_address, 1, 0, 0);
    action_finish(contract_address, 1);
    // Zone 1 cleared, auto-advanced to zone 3.
    // Move character back to zone 1 (already cleared) and try start.
    let mut character: Character = world.read_model((player, 1_u32));
    character.current_zone = 1;
    world.write_model_test(@character);

    action_start(contract_address, 1); // zone 1 already cleared — should panic
}

#[test]
fn test_full_run_via_right_path() {
    let (world, contract_address, player) = setup();

    action_spawn(contract_address, 0);
    action_choose(contract_address, 1, Direction::Right); // zone 0 -> zone 2

    // Zone 2 (1 mob)
    action_start(contract_address, 1);
    action_cast(contract_address, 1, 0, 0);
    action_cast(contract_address, 1, 0, 0);
    action_finish(contract_address, 1);

    // Auto-advanced to Zone 3 (2 mobs)
    action_start(contract_address, 1);
    action_cast(contract_address, 1, 0, 0);
    action_cast(contract_address, 1, 0, 0);
    action_finish(contract_address, 1);
    action_cast(contract_address, 1, 1, 0);
    action_cast(contract_address, 1, 1, 0);
    action_finish(contract_address, 1);

    // Auto-advanced to Zone 4 (4 mobs)
    action_start(contract_address, 1);

    action_cast(contract_address, 1, 0, 0);
    action_cast(contract_address, 1, 0, 0);
    action_cast(contract_address, 1, 1, 0);
    action_finish(contract_address, 1);

    action_cast(contract_address, 1, 1, 0);
    action_cast(contract_address, 1, 2, 0);
    action_cast(contract_address, 1, 2, 0);
    action_finish(contract_address, 1);

    action_cast(contract_address, 1, 3, 0);
    action_cast(contract_address, 1, 3, 0);
    action_finish(contract_address, 1);

    let dungeon: Dungeon = world.read_model((player, 1_u32));
    assert(dungeon.completed, 'completed mismatch');
    assert(!dungeon.failed, 'failed mismatch');

    let character: Character = world.read_model((player, 1_u32));
    assert(character.current_zone == 4, 'zone mismatch');

    // Verify zones_cleared bitmap has zone 2, 3, 4 set
    assert(dungeon.zones_cleared & zone_bit(2) != 0, 'zone 2 not cleared');
    assert(dungeon.zones_cleared & zone_bit(3) != 0, 'zone 3 not cleared');
    assert(dungeon.zones_cleared & zone_bit(4) != 0, 'zone 4 not cleared');
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
