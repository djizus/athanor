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
