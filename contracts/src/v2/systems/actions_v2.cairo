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

#[dojo::contract]
pub mod actions_v2 {
    use super::IActionsV2;

    use starknet::{ContractAddress, get_caller_address};

    use athanor::v2::constants::{
        GRID_WIDTH, GRID_HEIGHT, BASE_STAMINA, MOVE_COST_PER_TILE, HERO_HP, HERO_OFFENSE,
        HERO_DEFENSE, HERO_SPEED, BRUTE_HP, BRUTE_OFFENSE, BRUTE_DEFENSE, BRUTE_SPEED, CASTER_HP,
        CASTER_OFFENSE, CASTER_DEFENSE, CASTER_SPEED, FLANKER_HP, FLANKER_OFFENSE,
        FLANKER_DEFENSE, FLANKER_SPEED, HEAVY_HP, HEAVY_OFFENSE, HEAVY_DEFENSE, HEAVY_SPEED,
        PULLER_HP, PULLER_OFFENSE, PULLER_DEFENSE, PULLER_SPEED, STRIKE_DAMAGE, DASH_DAMAGE,
        HEAL_AMOUNT, SHOVE_DAMAGE, SHOVE_PUSH_DISTANCE, SLAM_DAMAGE, SLAM_PUSH_DISTANCE,
        COLLISION_DAMAGE, KILL_STAMINA_BONUS,
    };
    use athanor::v2::helpers::bitmap;
    use athanor::v2::models::index::{RunState, RoomState, ActorState, AbilitySlotState, TelegraphState};
    use athanor::v2::store::{Store, StoreTrait};
    use athanor::v2::systems::phase::{
        PHASE_EXPLORE, PHASE_PLAYER_TURN, PHASE_ENEMY_TURN, PHASE_COMPLETE, PHASE_FAILED,
        FACTION_PLAYER, FACTION_ENEMY, ARCHETYPE_HERO, ARCHETYPE_BRUTE, ARCHETYPE_CASTER,
        ARCHETYPE_FLANKER, ARCHETYPE_HEAVY, ARCHETYPE_PULLER, ABILITY_STRIKE, ABILITY_DASH,
        ABILITY_HEAL, ABILITY_SHOVE, ABILITY_SLAM, TARGET_DIRECTIONAL, SHAPE_SINGLE_TILE,
        SHAPE_CIRCLE, SHAPE_CROSS, TELEGRAPH_TYPE_DAMAGE, TELEGRAPH_TYPE_PULL,
    };
    use athanor::v2::systems::{movement, abilities, telegraph, enemy_ai};

    const PLAYER_ACTOR_ID: u8 = 0;
    const ENEMY_ACTOR_ID_1: u8 = 1;
    const ENEMY_ACTOR_ID_2: u8 = 2;
    const ENEMY_ACTOR_ID_3: u8 = 3;
    const ENEMY_ACTOR_ID_4: u8 = 4;
    const ENEMY_ACTOR_ID_5: u8 = 5;
    const MAX_ACTOR_ID: u8 = 5;
    const MAX_ABILITY_SLOTS: u8 = 5;
    const INVALID_ACTOR_ID: u8 = 255;

    const DIRECTION_NORTH: u8 = 0;
    const DIRECTION_EAST: u8 = 1;
    const DIRECTION_SOUTH: u8 = 2;
    const DIRECTION_WEST: u8 = 3;

    const ENTRY_X: u8 = 1;
    const ENTRY_Y: u8 = 1;

    const ROOM0_BRUTE_A_X: u8 = 6;
    const ROOM0_BRUTE_A_Y: u8 = 2;
    const ROOM0_BRUTE_B_X: u8 = 5;
    const ROOM0_BRUTE_B_Y: u8 = 2;
    const ROOM0_CASTER_X: u8 = 5;
    const ROOM0_CASTER_Y: u8 = 6;

    const ROOM1_BRUTE_X: u8 = 6;
    const ROOM1_BRUTE_Y: u8 = 2;
    const ROOM1_FLANKER_X: u8 = 5;
    const ROOM1_FLANKER_Y: u8 = 5;
    const ROOM1_HEAVY_X: u8 = 6;
    const ROOM1_HEAVY_Y: u8 = 6;

    const ROOM2_HEAVY_X: u8 = 6;
    const ROOM2_HEAVY_Y: u8 = 3;
    const ROOM2_PULLER_X: u8 = 6;
    const ROOM2_PULLER_Y: u8 = 6;
    const ROOM2_FLANKER_A_X: u8 = 3;
    const ROOM2_FLANKER_A_Y: u8 = 3;
    const ROOM2_FLANKER_B_X: u8 = 1;
    const ROOM2_FLANKER_B_Y: u8 = 5;

    #[abi(embed_v0)]
    impl ActionsV2Impl of IActionsV2<ContractState> {
        fn spawn_v2(ref self: ContractState, class_id: u8) {
            let mut store = self.store();
            let player = get_caller_address();
            let game_id: u32 = dojo::world::IWorldDispatcherTrait::uuid(
                self.world_default().dispatcher,
            )
                .try_into()
                .unwrap();

            let run = RunState {
                player,
                game_id,
                phase: PHASE_EXPLORE,
                room_id: 0,
                turn_index: 0,
                player_actor_id: PLAYER_ACTOR_ID,
                status_flags: 0,
                last_player_direction: DIRECTION_EAST,
            };
            store.set_run_state(@run);

            let actor = ActorState {
                player,
                game_id,
                actor_id: PLAYER_ACTOR_ID,
                faction: FACTION_PLAYER,
                archetype: ARCHETYPE_HERO,
                hp: HERO_HP,
                max_hp: HERO_HP,
                stamina: BASE_STAMINA,
                max_stamina: BASE_STAMINA,
                offense: HERO_OFFENSE,
                defense: HERO_DEFENSE,
                speed: HERO_SPEED,
                move_cost: MOVE_COST_PER_TILE,
                pos_x: 0,
                pos_y: 0,
                alive: true,
                guard_active: false,
                is_immovable: false,
                room_id: 0,
            };
            store.set_actor_state(@actor);

            self.init_ability_slots(ref store, player, game_id, PLAYER_ACTOR_ID);

            store.emit_run_spawned_v2(player, game_id, 0, PLAYER_ACTOR_ID);

            let _ = class_id;
        }

        fn enter_room_v2(ref self: ContractState, game_id: u32, room_id: u8) {
            let mut store = self.store();
            let player = get_caller_address();

            let mut run = store.get_run_state(player, game_id);
            assert(run.phase != PHASE_COMPLETE, 'Run complete');
            assert(run.phase != PHASE_FAILED, 'Run failed');
            assert(run.phase == PHASE_EXPLORE, 'Cannot enter room');
            assert(room_id <= 2, 'Invalid room id');

            let mut player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);

            let mut room = RoomState {
                player,
                game_id,
                room_id,
                width: GRID_WIDTH,
                height: GRID_HEIGHT,
                blocked: self.room_blocked_bitmap(room_id),
                occupancy: 0_u64,
                enemy_count: 0,
                cleared: false,
            };

            room.occupancy = bitmap::set_bit(room.occupancy, ENTRY_X, ENTRY_Y);

            player_actor.pos_x = ENTRY_X;
            player_actor.pos_y = ENTRY_Y;
            player_actor.stamina = BASE_STAMINA;
            player_actor.guard_active = false;
            player_actor.is_immovable = false;
            player_actor.room_id = room_id;
            store.set_actor_state(@player_actor);

            self.reset_enemy_slots(ref store, player, game_id, room_id);

            if room_id == 0 {
                let (next_occupancy, enemy_count) = self.spawn_room_0_enemies(
                    ref store, player, game_id, room_id, room.occupancy,
                );
                room.occupancy = next_occupancy;
                room.enemy_count = enemy_count;
            } else if room_id == 1 {
                let (next_occupancy, enemy_count) = self.spawn_room_1_enemies(
                    ref store, player, game_id, room_id, room.occupancy,
                );
                room.occupancy = next_occupancy;
                room.enemy_count = enemy_count;
            } else {
                let (next_occupancy, enemy_count) = self.spawn_room_2_enemies(
                    ref store, player, game_id, room_id, room.occupancy,
                );
                room.occupancy = next_occupancy;
                room.enemy_count = enemy_count;
            };

            run.phase = PHASE_PLAYER_TURN;
            run.room_id = room_id;
            run.status_flags = 0;
            run.last_player_direction = DIRECTION_EAST;

            store.set_room_state(@room);
            store.set_run_state(@run);

            store.emit_room_entered_v2(player, game_id, room_id);
        }

        fn move_v2(ref self: ContractState, game_id: u32, target_x: u8, target_y: u8) {
            let mut store = self.store();
            let player = get_caller_address();

            let mut run = store.get_run_state(player, game_id);
            assert(run.phase == PHASE_PLAYER_TURN, 'Not player turn');
            assert(movement::in_bounds(target_x, target_y), 'Target out of bounds');

            let mut room = store.get_room_state(player, game_id, run.room_id);
            assert(!bitmap::get_bit(room.blocked, target_x, target_y), 'Target blocked');

            let mut player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
            let from_x = player_actor.pos_x;
            let from_y = player_actor.pos_y;

            let dist = movement::manhattan_distance(from_x, from_y, target_x, target_y);
            let stamina_cost: u16 = dist.into() * player_actor.move_cost.into();
            assert(player_actor.stamina >= stamina_cost, 'Not enough stamina');
            player_actor.stamina -= stamina_cost;

            let mut did_move = false;
            let mut move_to_x = from_x;
            let mut move_to_y = from_y;

            if !bitmap::get_bit(room.occupancy, target_x, target_y) {
                move_to_x = target_x;
                move_to_y = target_y;
                did_move = true;
            } else {
                let target_actor_id = self.actor_at_position(
                    ref store, player, game_id, run.room_id, target_x, target_y,
                );
                assert(target_actor_id != INVALID_ACTOR_ID, 'Target occupied');

                let target_actor = store.get_actor_state(player, game_id, target_actor_id);
                assert(target_actor.alive, 'Target occupied');
                assert(target_actor.faction == FACTION_ENEMY, 'Target occupied');
                assert(target_actor.room_id == run.room_id, 'Target occupied');

                let push_direction = self.direction_from_delta(from_x, from_y, target_x, target_y);
                let target_was_immovable = target_actor.is_immovable;

                let (updated_room, pushed) = self.push_actor_steps(
                    ref store,
                    player,
                    game_id,
                    room,
                    run.room_id,
                    target_actor_id,
                    push_direction,
                    1,
                    PLAYER_ACTOR_ID,
                );
                room = updated_room;

                if pushed {
                    move_to_x = target_x;
                    move_to_y = target_y;
                    did_move = true;
                } else if !target_was_immovable {
                    let target_after = store.get_actor_state(player, game_id, target_actor_id);
                    if !target_after.alive {
                        move_to_x = target_x;
                        move_to_y = target_y;
                        did_move = true;
                    };
                };
            };

            if did_move {
                player_actor.pos_x = move_to_x;
                player_actor.pos_y = move_to_y;

                room.occupancy = bitmap::clear_bit(room.occupancy, from_x, from_y);
                room.occupancy = bitmap::set_bit(room.occupancy, move_to_x, move_to_y);

                run.last_player_direction = self.direction_from_delta(from_x, from_y, move_to_x, move_to_y);

                store.emit_actor_moved(
                    player,
                    game_id,
                    PLAYER_ACTOR_ID,
                    run.room_id,
                    from_x,
                    from_y,
                    move_to_x,
                    move_to_y,
                );
            };

            store.set_actor_state(@player_actor);
            store.set_room_state(@room);
            store.set_run_state(@run);

            if room.enemy_count == 0 {
                let _ = self.maybe_finalize_room(ref store, player, game_id, ref run, ref room);
            };
        }

        fn use_ability_v2(
            ref self: ContractState,
            game_id: u32,
            ability_id: u8,
            target_mode: u8,
            target_a: u8,
            target_b: u8,
        ) {
            let mut store = self.store();
            let player = get_caller_address();

            let mut run = store.get_run_state(player, game_id);
            assert(run.phase == PHASE_PLAYER_TURN, 'Not player turn');

            let expected_mode = abilities::expected_target_mode(ability_id);
            assert(target_mode == expected_mode, 'Invalid target mode');

            let mut player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
            let mut room = store.get_room_state(player, game_id, run.room_id);

            let mut slot = store.get_ability_slot_state(player, game_id, PLAYER_ACTOR_ID, ability_id);
            assert(slot.ability_id == ability_id, 'Unknown ability');
            assert(slot.cooldown_remaining == 0, 'Ability on cooldown');

            let stamina_cost = abilities::ability_cost(ability_id);
            assert(stamina_cost > 0, 'Invalid ability');
            assert(player_actor.stamina >= stamina_cost, 'Not enough stamina');

            player_actor.stamina -= stamina_cost;
            slot.cooldown_remaining = abilities::ability_cooldown(ability_id);

            let mut used_target_actor_id: u8 = INVALID_ACTOR_ID;
            let mut used_target_x: u8 = INVALID_ACTOR_ID;
            let mut used_target_y: u8 = INVALID_ACTOR_ID;

            if ability_id == ABILITY_STRIKE {
                let target_actor_id = target_a;
                let target_actor = store.get_actor_state(player, game_id, target_actor_id);
                assert(target_actor.alive, 'Target not alive');
                assert(target_actor.faction == FACTION_ENEMY, 'Target must be enemy');
                assert(target_actor.room_id == run.room_id, 'Target wrong room');

                let dist = movement::manhattan_distance(
                    player_actor.pos_x, player_actor.pos_y, target_actor.pos_x, target_actor.pos_y,
                );
                assert(dist <= 1, 'Target not adjacent');

                let (updated_room, _) = self.apply_damage_to_actor(
                    ref store,
                    player,
                    game_id,
                    room,
                    run.room_id,
                    target_actor_id,
                    PLAYER_ACTOR_ID,
                    STRIKE_DAMAGE,
                    player_actor.offense,
                    true,
                );
                room = updated_room;

                used_target_actor_id = target_actor_id;
                used_target_x = target_actor.pos_x;
                used_target_y = target_actor.pos_y;
            } else if ability_id == ABILITY_DASH {
                assert(target_mode == TARGET_DIRECTIONAL, 'Dash needs direction');
                let direction = target_a;
                assert(direction < 4, 'Invalid direction');

                let mut cur_x = player_actor.pos_x;
                let mut cur_y = player_actor.pos_y;
                let mut final_x = cur_x;
                let mut final_y = cur_y;
                let mut moved = false;
                let mut hit_actor_id: u8 = INVALID_ACTOR_ID;

                let mut step: u8 = 0;
                while step < 3 {
                    let (next_x, next_y, ok) = movement::step_in_direction(cur_x, cur_y, direction);
                    if !ok {
                        break;
                    };

                    if bitmap::get_bit(room.blocked, next_x, next_y) {
                        break;
                    };

                    if bitmap::get_bit(room.occupancy, next_x, next_y) {
                        let actor_id_at = self.actor_at_position(
                            ref store, player, game_id, run.room_id, next_x, next_y,
                        );
                        if actor_id_at != INVALID_ACTOR_ID {
                            hit_actor_id = actor_id_at;
                        };
                        break;
                    };

                    final_x = next_x;
                    final_y = next_y;
                    cur_x = next_x;
                    cur_y = next_y;
                    moved = true;
                    step += 1;
                };

                assert(moved || hit_actor_id != INVALID_ACTOR_ID, 'Dash has no path');

                if moved {
                    let from_x = player_actor.pos_x;
                    let from_y = player_actor.pos_y;

                    player_actor.pos_x = final_x;
                    player_actor.pos_y = final_y;

                    room.occupancy = bitmap::clear_bit(room.occupancy, from_x, from_y);
                    room.occupancy = bitmap::set_bit(room.occupancy, final_x, final_y);

                    run.last_player_direction = direction;

                    store.emit_actor_moved(
                        player,
                        game_id,
                        PLAYER_ACTOR_ID,
                        run.room_id,
                        from_x,
                        from_y,
                        final_x,
                        final_y,
                    );
                };

                if hit_actor_id != INVALID_ACTOR_ID {
                    let (updated_room, _) = self.apply_damage_to_actor(
                        ref store,
                        player,
                        game_id,
                        room,
                        run.room_id,
                        hit_actor_id,
                        PLAYER_ACTOR_ID,
                        DASH_DAMAGE,
                        player_actor.offense,
                        true,
                    );
                    room = updated_room;
                };

                used_target_actor_id = hit_actor_id;
                used_target_x = final_x;
                used_target_y = final_y;
            } else if ability_id == ABILITY_HEAL {
                player_actor.hp = self.add_hp_capped(player_actor.hp, player_actor.max_hp, HEAL_AMOUNT);
                used_target_actor_id = PLAYER_ACTOR_ID;
                used_target_x = player_actor.pos_x;
                used_target_y = player_actor.pos_y;
            } else if ability_id == ABILITY_SHOVE {
                let target_actor_id = target_a;
                let target_actor = store.get_actor_state(player, game_id, target_actor_id);
                assert(target_actor.alive, 'Target not alive');
                assert(target_actor.faction == FACTION_ENEMY, 'Target must be enemy');
                assert(target_actor.room_id == run.room_id, 'Target wrong room');

                let dist = movement::manhattan_distance(
                    player_actor.pos_x, player_actor.pos_y, target_actor.pos_x, target_actor.pos_y,
                );
                assert(dist == 1, 'Target not adjacent');

                let (updated_room, _) = self.apply_damage_to_actor(
                    ref store,
                    player,
                    game_id,
                    room,
                    run.room_id,
                    target_actor_id,
                    PLAYER_ACTOR_ID,
                    SHOVE_DAMAGE,
                    player_actor.offense,
                    true,
                );
                room = updated_room;

                let target_after_hit = store.get_actor_state(player, game_id, target_actor_id);
                if target_after_hit.alive {
                    let shove_direction = self.direction_from_delta(
                        player_actor.pos_x,
                        player_actor.pos_y,
                        target_after_hit.pos_x,
                        target_after_hit.pos_y,
                    );
                    let (updated_after_push, _) = self.push_actor_steps(
                        ref store,
                        player,
                        game_id,
                        room,
                        run.room_id,
                        target_actor_id,
                        shove_direction,
                        SHOVE_PUSH_DISTANCE,
                        PLAYER_ACTOR_ID,
                    );
                    room = updated_after_push;
                };

                used_target_actor_id = target_actor_id;
                used_target_x = target_actor.pos_x;
                used_target_y = target_actor.pos_y;
            } else {
                assert(ability_id == ABILITY_SLAM, 'Invalid ability');

                let mut actor_id: u8 = 1;
                while actor_id <= MAX_ACTOR_ID {
                    let actor = store.get_actor_state(player, game_id, actor_id);
                    if actor.alive && actor.faction == FACTION_ENEMY && actor.room_id == run.room_id {
                        let dist = movement::manhattan_distance(
                            player_actor.pos_x,
                            player_actor.pos_y,
                            actor.pos_x,
                            actor.pos_y,
                        );
                        if dist == 1 {
                            let (updated_room, _) = self.apply_damage_to_actor(
                                ref store,
                                player,
                                game_id,
                                room,
                                run.room_id,
                                actor_id,
                                PLAYER_ACTOR_ID,
                                SLAM_DAMAGE,
                                player_actor.offense,
                                true,
                            );
                            room = updated_room;

                            let actor_after_hit = store.get_actor_state(player, game_id, actor_id);
                            if actor_after_hit.alive {
                                let slam_direction = self.direction_from_delta(
                                    player_actor.pos_x,
                                    player_actor.pos_y,
                                    actor_after_hit.pos_x,
                                    actor_after_hit.pos_y,
                                );
                                let (updated_after_push, _) = self.push_actor_steps(
                                    ref store,
                                    player,
                                    game_id,
                                    room,
                                    run.room_id,
                                    actor_id,
                                    slam_direction,
                                    SLAM_PUSH_DISTANCE,
                                    PLAYER_ACTOR_ID,
                                );
                                room = updated_after_push;
                            };
                        };
                    };
                    actor_id += 1;
                };

                used_target_actor_id = PLAYER_ACTOR_ID;
                used_target_x = player_actor.pos_x;
                used_target_y = player_actor.pos_y;
            };

            store.set_actor_state(@player_actor);
            store.set_room_state(@room);
            store.set_ability_slot_state(@slot);
            store.set_run_state(@run);

            store.emit_ability_used(
                player,
                game_id,
                PLAYER_ACTOR_ID,
                ability_id,
                run.room_id,
                used_target_actor_id,
                used_target_x,
                used_target_y,
            );

            player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
            if !player_actor.alive || player_actor.hp == 0 {
                run.phase = PHASE_FAILED;
                store.set_run_state(@run);
                store.emit_run_failed(player, game_id, run.turn_index);
                return;
            }

            if room.enemy_count == 0 {
                let _ = self.maybe_finalize_room(ref store, player, game_id, ref run, ref room);
            }

            let _ = target_b;
        }

        fn end_player_phase_v2(ref self: ContractState, game_id: u32) {
            let mut store = self.store();
            let player = get_caller_address();

            let mut run = store.get_run_state(player, game_id);
            assert(run.phase == PHASE_PLAYER_TURN, 'Not player turn');

            run.phase = PHASE_ENEMY_TURN;
            store.set_run_state(@run);
            store.emit_turn_ended(player, game_id, run.room_id, run.turn_index);
        }

        fn step_enemy_phase_v2(ref self: ContractState, game_id: u32) {
            let mut store = self.store();
            let player = get_caller_address();

            let mut run = store.get_run_state(player, game_id);
            assert(run.phase == PHASE_ENEMY_TURN, 'Not enemy turn');

            let mut room = store.get_room_state(player, game_id, run.room_id);
            let telegraph_count = run.status_flags;

            // Step 1a: resolve PULL telegraphs first.
            let mut telegraph_id: u8 = 0;
            while telegraph_id < telegraph_count {
                let mut tg = store.get_telegraph_state(player, game_id, telegraph_id);
                if !tg.resolved
                    && tg.room_id == run.room_id
                    && tg.resolves_turn == run.turn_index
                    && tg.telegraph_type == TELEGRAPH_TYPE_PULL
                {
                    room = self.resolve_pull_telegraph(
                        ref store,
                        player,
                        game_id,
                        room,
                        run.room_id,
                        tg,
                    );

                    tg.resolved = true;
                    store.set_telegraph_state(@tg);
                    store.emit_telegraph_resolved(player, game_id, telegraph_id, run.room_id);
                };

                telegraph_id += 1;
            };

            // Step 1b: resolve DAMAGE telegraphs.
            telegraph_id = 0;
            while telegraph_id < telegraph_count {
                let mut tg = store.get_telegraph_state(player, game_id, telegraph_id);
                if !tg.resolved
                    && tg.room_id == run.room_id
                    && tg.resolves_turn == run.turn_index
                    && tg.telegraph_type == TELEGRAPH_TYPE_DAMAGE
                {
                    let mut actor_id: u8 = 0;
                    while actor_id <= MAX_ACTOR_ID {
                        let actor = store.get_actor_state(player, game_id, actor_id);
                        if actor.alive && actor.room_id == run.room_id {
                            let hit = telegraph::tile_in_shape(
                                tg.shape_type,
                                tg.param_a,
                                tg.param_b,
                                tg.param_c,
                                actor.pos_x,
                                actor.pos_y,
                            );
                            if hit {
                                let (updated_room, _) = self.apply_telegraph_damage_to_actor(
                                    ref store,
                                    player,
                                    game_id,
                                    room,
                                    run.room_id,
                                    actor_id,
                                    tg.source_actor_id,
                                    tg.damage,
                                );
                                room = updated_room;
                            };
                        };
                        actor_id += 1;
                    };

                    tg.resolved = true;
                    store.set_telegraph_state(@tg);
                    store.emit_telegraph_resolved(player, game_id, telegraph_id, run.room_id);

                    let player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
                    if !player_actor.alive || player_actor.hp == 0 {
                        run.phase = PHASE_FAILED;
                        store.set_room_state(@room);
                        store.set_run_state(@run);
                        store.emit_run_failed(player, game_id, run.turn_index);
                        return;
                    }
                };

                telegraph_id += 1;
            };

            if room.enemy_count == 0 {
                let _ = self.maybe_finalize_room(ref store, player, game_id, ref run, ref room);
                return;
            }

            // Step 2: enemies act by speed desc, actor_id asc tie-break.
            self.process_enemies_by_speed(ref store, player, game_id, ref run, ref room);

            // Step 3: phase transition.
            run.turn_index += 1;
            run.phase = PHASE_PLAYER_TURN;
            store.set_run_state(@run);

            let mut player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
            player_actor.stamina = BASE_STAMINA;
            store.set_actor_state(@player_actor);

            let mut slot_index: u8 = 0;
            while slot_index < MAX_ABILITY_SLOTS {
                let mut slot = store.get_ability_slot_state(player, game_id, PLAYER_ACTOR_ID, slot_index);
                if slot.cooldown_remaining > 0 {
                    slot.cooldown_remaining -= 1;
                    store.set_ability_slot_state(@slot);
                };
                slot_index += 1;
            };

            store.set_room_state(@room);
            store.emit_enemy_turn_computed(player, game_id, run.room_id, run.turn_index);
            store.emit_turn_ended(player, game_id, run.room_id, run.turn_index);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn store(self: @ContractState) -> Store {
            StoreTrait::new(self.world_default())
        }

        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"athanor_v2")
        }

        fn init_ability_slots(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            actor_id: u8,
        ) {
            let slot0 = AbilitySlotState {
                player,
                game_id,
                actor_id,
                slot_index: 0,
                ability_id: ABILITY_STRIKE,
                cooldown_remaining: 0,
            };
            store.set_ability_slot_state(@slot0);

            let slot1 = AbilitySlotState {
                player,
                game_id,
                actor_id,
                slot_index: 1,
                ability_id: ABILITY_DASH,
                cooldown_remaining: 0,
            };
            store.set_ability_slot_state(@slot1);

            let slot2 = AbilitySlotState {
                player,
                game_id,
                actor_id,
                slot_index: 2,
                ability_id: ABILITY_HEAL,
                cooldown_remaining: 0,
            };
            store.set_ability_slot_state(@slot2);

            let slot3 = AbilitySlotState {
                player,
                game_id,
                actor_id,
                slot_index: 3,
                ability_id: ABILITY_SHOVE,
                cooldown_remaining: 0,
            };
            store.set_ability_slot_state(@slot3);

            let slot4 = AbilitySlotState {
                player,
                game_id,
                actor_id,
                slot_index: 4,
                ability_id: ABILITY_SLAM,
                cooldown_remaining: 0,
            };
            store.set_ability_slot_state(@slot4);
        }

        fn room_blocked_bitmap(self: @ContractState, room_id: u8) -> u64 {
            if room_id == 0 {
                return self.room_0_blocked_bitmap();
            };
            if room_id == 1 {
                return self.room_1_blocked_bitmap();
            };
            self.room_2_blocked_bitmap()
        }

        fn reset_enemy_slots(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            room_id: u8,
        ) {
            let mut actor_id: u8 = 1;
            while actor_id <= MAX_ACTOR_ID {
                let enemy = ActorState {
                    player,
                    game_id,
                    actor_id,
                    faction: FACTION_ENEMY,
                    archetype: ARCHETYPE_BRUTE,
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
                    room_id,
                };
                store.set_actor_state(@enemy);
                actor_id += 1;
            };
        }

        fn spawn_enemy_actor(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            room_id: u8,
            occupancy: u64,
            actor_id: u8,
            archetype: u8,
            hp: u16,
            offense: u8,
            defense: u8,
            speed: u8,
            pos_x: u8,
            pos_y: u8,
            is_immovable: bool,
        ) -> u64 {
            let enemy = ActorState {
                player,
                game_id,
                actor_id,
                faction: FACTION_ENEMY,
                archetype,
                hp,
                max_hp: hp,
                stamina: 0,
                max_stamina: 0,
                offense,
                defense,
                speed,
                move_cost: 0,
                pos_x,
                pos_y,
                alive: true,
                guard_active: false,
                is_immovable,
                room_id,
            };
            store.set_actor_state(@enemy);
            bitmap::set_bit(occupancy, pos_x, pos_y)
        }

        fn spawn_room_0_enemies(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            room_id: u8,
            occupancy: u64,
        ) -> (u64, u8) {
            let mut next_occupancy = occupancy;

            next_occupancy = self.spawn_enemy_actor(
                ref store,
                player,
                game_id,
                room_id,
                next_occupancy,
                ENEMY_ACTOR_ID_1,
                ARCHETYPE_BRUTE,
                BRUTE_HP,
                BRUTE_OFFENSE,
                BRUTE_DEFENSE,
                BRUTE_SPEED,
                ROOM0_BRUTE_A_X,
                ROOM0_BRUTE_A_Y,
                false,
            );

            next_occupancy = self.spawn_enemy_actor(
                ref store,
                player,
                game_id,
                room_id,
                next_occupancy,
                ENEMY_ACTOR_ID_2,
                ARCHETYPE_BRUTE,
                BRUTE_HP,
                BRUTE_OFFENSE,
                BRUTE_DEFENSE,
                BRUTE_SPEED,
                ROOM0_BRUTE_B_X,
                ROOM0_BRUTE_B_Y,
                false,
            );

            next_occupancy = self.spawn_enemy_actor(
                ref store,
                player,
                game_id,
                room_id,
                next_occupancy,
                ENEMY_ACTOR_ID_3,
                ARCHETYPE_CASTER,
                CASTER_HP,
                CASTER_OFFENSE,
                CASTER_DEFENSE,
                CASTER_SPEED,
                ROOM0_CASTER_X,
                ROOM0_CASTER_Y,
                false,
            );

            (next_occupancy, 3)
        }

        fn spawn_room_1_enemies(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            room_id: u8,
            occupancy: u64,
        ) -> (u64, u8) {
            let mut next_occupancy = occupancy;

            next_occupancy = self.spawn_enemy_actor(
                ref store,
                player,
                game_id,
                room_id,
                next_occupancy,
                ENEMY_ACTOR_ID_1,
                ARCHETYPE_BRUTE,
                BRUTE_HP,
                BRUTE_OFFENSE,
                BRUTE_DEFENSE,
                BRUTE_SPEED,
                ROOM1_BRUTE_X,
                ROOM1_BRUTE_Y,
                false,
            );

            next_occupancy = self.spawn_enemy_actor(
                ref store,
                player,
                game_id,
                room_id,
                next_occupancy,
                ENEMY_ACTOR_ID_2,
                ARCHETYPE_FLANKER,
                FLANKER_HP,
                FLANKER_OFFENSE,
                FLANKER_DEFENSE,
                FLANKER_SPEED,
                ROOM1_FLANKER_X,
                ROOM1_FLANKER_Y,
                false,
            );

            next_occupancy = self.spawn_enemy_actor(
                ref store,
                player,
                game_id,
                room_id,
                next_occupancy,
                ENEMY_ACTOR_ID_3,
                ARCHETYPE_HEAVY,
                HEAVY_HP,
                HEAVY_OFFENSE,
                HEAVY_DEFENSE,
                HEAVY_SPEED,
                ROOM1_HEAVY_X,
                ROOM1_HEAVY_Y,
                true,
            );

            (next_occupancy, 3)
        }

        fn spawn_room_2_enemies(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            room_id: u8,
            occupancy: u64,
        ) -> (u64, u8) {
            let mut next_occupancy = occupancy;

            next_occupancy = self.spawn_enemy_actor(
                ref store,
                player,
                game_id,
                room_id,
                next_occupancy,
                ENEMY_ACTOR_ID_1,
                ARCHETYPE_HEAVY,
                HEAVY_HP,
                HEAVY_OFFENSE,
                HEAVY_DEFENSE,
                HEAVY_SPEED,
                ROOM2_HEAVY_X,
                ROOM2_HEAVY_Y,
                true,
            );

            next_occupancy = self.spawn_enemy_actor(
                ref store,
                player,
                game_id,
                room_id,
                next_occupancy,
                ENEMY_ACTOR_ID_2,
                ARCHETYPE_PULLER,
                PULLER_HP,
                PULLER_OFFENSE,
                PULLER_DEFENSE,
                PULLER_SPEED,
                ROOM2_PULLER_X,
                ROOM2_PULLER_Y,
                false,
            );

            next_occupancy = self.spawn_enemy_actor(
                ref store,
                player,
                game_id,
                room_id,
                next_occupancy,
                ENEMY_ACTOR_ID_3,
                ARCHETYPE_FLANKER,
                FLANKER_HP,
                FLANKER_OFFENSE,
                FLANKER_DEFENSE,
                FLANKER_SPEED,
                ROOM2_FLANKER_A_X,
                ROOM2_FLANKER_A_Y,
                false,
            );

            next_occupancy = self.spawn_enemy_actor(
                ref store,
                player,
                game_id,
                room_id,
                next_occupancy,
                ENEMY_ACTOR_ID_4,
                ARCHETYPE_FLANKER,
                FLANKER_HP,
                FLANKER_OFFENSE,
                FLANKER_DEFENSE,
                FLANKER_SPEED,
                ROOM2_FLANKER_B_X,
                ROOM2_FLANKER_B_Y,
                false,
            );

            (next_occupancy, 4)
        }

        fn actor_at_position(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            room_id: u8,
            x: u8,
            y: u8,
        ) -> u8 {
            let mut actor_id: u8 = 1;
            while actor_id <= MAX_ACTOR_ID {
                let actor = store.get_actor_state(player, game_id, actor_id);
                if actor.alive && actor.room_id == room_id && actor.pos_x == x && actor.pos_y == y {
                    return actor_id;
                };
                actor_id += 1;
            };

            INVALID_ACTOR_ID
        }

        fn maybe_finalize_room(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            ref run: RunState,
            ref room: RoomState,
        ) -> bool {
            if room.enemy_count > 0 {
                return false;
            };

            room.cleared = true;
            store.set_room_state(@room);
            store.emit_room_cleared(player, game_id, run.room_id);

            if run.room_id >= 2 {
                run.phase = PHASE_COMPLETE;
                store.set_run_state(@run);
                store.emit_run_completed(player, game_id, run.turn_index);
            } else {
                run.phase = PHASE_EXPLORE;
                store.set_run_state(@run);
            };

            true
        }

        fn direction_from_delta(
            self: @ContractState, from_x: u8, from_y: u8, to_x: u8, to_y: u8,
        ) -> u8 {
            let dx = movement::abs_diff_u8(to_x, from_x);
            let dy = movement::abs_diff_u8(to_y, from_y);

            if dx >= dy {
                if to_x >= from_x {
                    return DIRECTION_EAST;
                };
                return DIRECTION_WEST;
            };

            if to_y >= from_y {
                DIRECTION_SOUTH
            } else {
                DIRECTION_NORTH
            }
        }

        fn opposite_direction(self: @ContractState, direction: u8) -> u8 {
            if direction == DIRECTION_NORTH {
                return DIRECTION_SOUTH;
            };
            if direction == DIRECTION_EAST {
                return DIRECTION_WEST;
            };
            if direction == DIRECTION_SOUTH {
                return DIRECTION_NORTH;
            };
            DIRECTION_EAST
        }

        fn flank_target_for_player(
            self: @ContractState, player_x: u8, player_y: u8, last_player_direction: u8,
        ) -> (u8, u8, bool) {
            let behind_direction = self.opposite_direction(last_player_direction);
            movement::step_in_direction(player_x, player_y, behind_direction)
        }

        fn step_toward(
            self: @ContractState, from_x: u8, from_y: u8, to_x: u8, to_y: u8,
        ) -> (u8, u8, bool) {
            if from_x == to_x && from_y == to_y {
                return (from_x, from_y, false);
            };

            let dx = movement::abs_diff_u8(to_x, from_x);
            let dy = movement::abs_diff_u8(to_y, from_y);

            if dx >= dy && to_x != from_x {
                if to_x > from_x {
                    if from_x >= 7 {
                        return (from_x, from_y, false);
                    };
                    return (from_x + 1, from_y, true);
                };

                if from_x == 0 {
                    return (from_x, from_y, false);
                };
                return (from_x - 1, from_y, true);
            };

            if to_y > from_y {
                if from_y >= 7 {
                    return (from_x, from_y, false);
                };
                return (from_x, from_y + 1, true);
            };

            if to_y < from_y {
                if from_y == 0 {
                    return (from_x, from_y, false);
                };
                return (from_x, from_y - 1, true);
            };

            (from_x, from_y, false)
        }

        fn resolve_pull_telegraph(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            mut room: RoomState,
            room_id: u8,
            tg: TelegraphState,
        ) -> RoomState {
            let mut player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
            if !player_actor.alive || player_actor.room_id != room_id {
                return room;
            }

            let in_shape = telegraph::tile_in_shape(
                tg.shape_type,
                tg.param_a,
                tg.param_b,
                tg.param_c,
                player_actor.pos_x,
                player_actor.pos_y,
            );
            if !in_shape {
                return room;
            }

            let from_x = player_actor.pos_x;
            let from_y = player_actor.pos_y;
            let mut cur_x = from_x;
            let mut cur_y = from_y;

            let occupancy_without_player = bitmap::clear_bit(room.occupancy, from_x, from_y);

            let mut step: u8 = 0;
            while step < tg.pull_distance {
                let (next_x, next_y, ok) = self.step_toward(
                    cur_x, cur_y, tg.pull_source_x, tg.pull_source_y,
                );
                if !ok {
                    break;
                };

                if bitmap::get_bit(room.blocked, next_x, next_y)
                    || bitmap::get_bit(occupancy_without_player, next_x, next_y)
                {
                    break;
                };

                cur_x = next_x;
                cur_y = next_y;
                step += 1;
            };

            if cur_x != from_x || cur_y != from_y {
                player_actor.pos_x = cur_x;
                player_actor.pos_y = cur_y;

                room.occupancy = bitmap::clear_bit(room.occupancy, from_x, from_y);
                room.occupancy = bitmap::set_bit(room.occupancy, cur_x, cur_y);

                store.set_actor_state(@player_actor);
                store.emit_actor_moved(
                    player,
                    game_id,
                    PLAYER_ACTOR_ID,
                    room_id,
                    from_x,
                    from_y,
                    cur_x,
                    cur_y,
                );
            };

            room
        }

        fn push_actor_steps(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            mut room: RoomState,
            room_id: u8,
            target_actor_id: u8,
            direction: u8,
            push_distance: u8,
            source_actor_id: u8,
        ) -> (RoomState, bool) {
            let mut target = store.get_actor_state(player, game_id, target_actor_id);
            if !target.alive || target.room_id != room_id {
                return (room, false);
            }

            if target.is_immovable {
                let (updated_room, _) = self.apply_flat_damage_to_actor(
                    ref store,
                    player,
                    game_id,
                    room,
                    room_id,
                    target_actor_id,
                    source_actor_id,
                    COLLISION_DAMAGE,
                );
                return (updated_room, false);
            }

            let mut moved = false;
            let mut step: u8 = 0;
            while step < push_distance {
                let (next_x, next_y, ok) = movement::step_in_direction(
                    target.pos_x, target.pos_y, direction,
                );

                if !ok
                    || bitmap::get_bit(room.blocked, next_x, next_y)
                    || bitmap::get_bit(room.occupancy, next_x, next_y)
                {
                    let (updated_room, _) = self.apply_flat_damage_to_actor(
                        ref store,
                        player,
                        game_id,
                        room,
                        room_id,
                        target_actor_id,
                        source_actor_id,
                        COLLISION_DAMAGE,
                    );
                    room = updated_room;
                    break;
                };

                let from_x = target.pos_x;
                let from_y = target.pos_y;

                target.pos_x = next_x;
                target.pos_y = next_y;

                room.occupancy = bitmap::clear_bit(room.occupancy, from_x, from_y);
                room.occupancy = bitmap::set_bit(room.occupancy, next_x, next_y);

                store.set_actor_state(@target);
                store.emit_actor_moved(
                    player,
                    game_id,
                    target_actor_id,
                    room_id,
                    from_x,
                    from_y,
                    next_x,
                    next_y,
                );

                moved = true;
                step += 1;
            };

            (room, moved)
        }

        fn add_hp_capped(self: @ContractState, hp: u16, max_hp: u16, amount: u16) -> u16 {
            if hp >= max_hp {
                return max_hp;
            };

            let gap = max_hp - hp;
            if amount >= gap {
                max_hp
            } else {
                hp + amount
            }
        }

        fn apply_damage_to_actor(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            room: RoomState,
            room_id: u8,
            target_actor_id: u8,
            source_actor_id: u8,
            base_damage: u16,
            source_offense: u8,
            include_offense: bool,
        ) -> (RoomState, bool) {
            let target = store.get_actor_state(player, game_id, target_actor_id);
            if !target.alive {
                return (room, false);
            }

            let damage = if include_offense {
                abilities::compute_damage_with_stats(base_damage, source_offense, target.defense)
            } else {
                abilities::compute_telegraph_damage(base_damage, target.defense)
            };

            self.apply_resolved_damage_to_actor(
                ref store,
                player,
                game_id,
                room,
                room_id,
                target_actor_id,
                source_actor_id,
                damage,
            )
        }

        fn apply_flat_damage_to_actor(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            room: RoomState,
            room_id: u8,
            target_actor_id: u8,
            source_actor_id: u8,
            damage: u16,
        ) -> (RoomState, bool) {
            self.apply_resolved_damage_to_actor(
                ref store,
                player,
                game_id,
                room,
                room_id,
                target_actor_id,
                source_actor_id,
                damage,
            )
        }

        fn apply_resolved_damage_to_actor(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            mut room: RoomState,
            room_id: u8,
            target_actor_id: u8,
            source_actor_id: u8,
            damage: u16,
        ) -> (RoomState, bool) {
            let mut target = store.get_actor_state(player, game_id, target_actor_id);
            if !target.alive {
                return (room, false);
            }

            let final_damage = if damage == 0 { 1 } else { damage };

            if final_damage >= target.hp {
                target.hp = 0;
            } else {
                target.hp -= final_damage;
            };

            let died = target.hp == 0;
            if died {
                target.alive = false;
                target.guard_active = false;
                target.is_immovable = false;

                room.occupancy = bitmap::clear_bit(room.occupancy, target.pos_x, target.pos_y);
                if target.faction == FACTION_ENEMY && room.enemy_count > 0 {
                    room.enemy_count -= 1;
                };
            };

            store.set_actor_state(@target);
            store.emit_actor_damaged(
                player,
                game_id,
                target_actor_id,
                source_actor_id,
                final_damage,
                target.hp,
                room_id,
            );

            if died {
                store.emit_actor_died(player, game_id, target_actor_id, room_id);

                if target.faction == FACTION_ENEMY {
                    let mut player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
                    if player_actor.alive {
                        player_actor.stamina += KILL_STAMINA_BONUS;
                        store.set_actor_state(@player_actor);
                    };
                };
            };

            (room, died)
        }

        fn apply_telegraph_damage_to_actor(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            room: RoomState,
            room_id: u8,
            target_actor_id: u8,
            source_actor_id: u8,
            base_damage: u16,
        ) -> (RoomState, bool) {
            self.apply_damage_to_actor(
                ref store,
                player,
                game_id,
                room,
                room_id,
                target_actor_id,
                source_actor_id,
                base_damage,
                0,
                false,
            )
        }

        fn process_enemies_by_speed(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            ref run: RunState,
            ref room: RoomState,
        ) {
            // speed desc + actor_id asc.
            self.process_enemies_of_archetype(
                ref store, player, game_id, ref run, ref room, ARCHETYPE_CASTER,
            );
            self.process_enemies_of_archetype(
                ref store, player, game_id, ref run, ref room, ARCHETYPE_FLANKER,
            );
            self.process_enemies_of_archetype(
                ref store, player, game_id, ref run, ref room, ARCHETYPE_PULLER,
            );
            self.process_enemies_of_archetype(
                ref store, player, game_id, ref run, ref room, ARCHETYPE_BRUTE,
            );
            self.process_enemies_of_archetype(
                ref store, player, game_id, ref run, ref room, ARCHETYPE_HEAVY,
            );
        }

        fn process_enemies_of_archetype(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            ref run: RunState,
            ref room: RoomState,
            archetype: u8,
        ) {
            let mut actor_id: u8 = 1;
            while actor_id <= MAX_ACTOR_ID {
                let actor = store.get_actor_state(player, game_id, actor_id);
                if actor.alive
                    && actor.room_id == run.room_id
                    && actor.faction == FACTION_ENEMY
                    && actor.archetype == archetype
                {
                    self.process_enemy_action(
                        ref store, player, game_id, ref run, ref room, actor_id,
                    );
                };
                actor_id += 1;
            };
        }

        fn process_enemy_action(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            ref run: RunState,
            ref room: RoomState,
            enemy_actor_id: u8,
        ) {
            let mut enemy = store.get_actor_state(player, game_id, enemy_actor_id);
            if !enemy.alive || enemy.room_id != run.room_id || enemy.faction != FACTION_ENEMY {
                return;
            }

            let player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
            let from_x = enemy.pos_x;
            let from_y = enemy.pos_y;

            let occupancy_without_self = bitmap::clear_bit(room.occupancy, enemy.pos_x, enemy.pos_y);
            let mut moved = false;

            if enemy.archetype == ARCHETYPE_BRUTE {
                let (next_x, next_y, can_move) = enemy_ai::choose_step_toward(
                    enemy.pos_x,
                    enemy.pos_y,
                    player_actor.pos_x,
                    player_actor.pos_y,
                    room.blocked,
                    occupancy_without_self,
                );

                if can_move {
                    enemy.pos_x = next_x;
                    enemy.pos_y = next_y;
                    moved = true;
                };
            } else if enemy.archetype == ARCHETYPE_CASTER {
                let (next_x, next_y, can_move) = enemy_ai::choose_step_away(
                    enemy.pos_x,
                    enemy.pos_y,
                    player_actor.pos_x,
                    player_actor.pos_y,
                    room.blocked,
                    occupancy_without_self,
                );

                if can_move {
                    enemy.pos_x = next_x;
                    enemy.pos_y = next_y;
                    moved = true;
                };
            } else if enemy.archetype == ARCHETYPE_FLANKER {
                let (flank_x, flank_y, has_flank) = self.flank_target_for_player(
                    player_actor.pos_x, player_actor.pos_y, run.last_player_direction,
                );

                let (next_x, next_y, can_move) = if has_flank {
                    enemy_ai::choose_step_toward_exact(
                        enemy.pos_x,
                        enemy.pos_y,
                        flank_x,
                        flank_y,
                        room.blocked,
                        occupancy_without_self,
                    )
                } else {
                    enemy_ai::choose_step_toward(
                        enemy.pos_x,
                        enemy.pos_y,
                        player_actor.pos_x,
                        player_actor.pos_y,
                        room.blocked,
                        occupancy_without_self,
                    )
                };

                if can_move {
                    enemy.pos_x = next_x;
                    enemy.pos_y = next_y;
                    moved = true;
                } else {
                    let (fallback_x, fallback_y, fallback_ok) = enemy_ai::choose_step_toward(
                        enemy.pos_x,
                        enemy.pos_y,
                        player_actor.pos_x,
                        player_actor.pos_y,
                        room.blocked,
                        occupancy_without_self,
                    );
                    if fallback_ok {
                        enemy.pos_x = fallback_x;
                        enemy.pos_y = fallback_y;
                        moved = true;
                    };
                };
            } else if enemy.archetype == ARCHETYPE_HEAVY {
                enemy.is_immovable = true;

                let (next_x, next_y, can_move) = enemy_ai::choose_step_toward(
                    enemy.pos_x,
                    enemy.pos_y,
                    player_actor.pos_x,
                    player_actor.pos_y,
                    room.blocked,
                    occupancy_without_self,
                );

                if can_move {
                    enemy.pos_x = next_x;
                    enemy.pos_y = next_y;
                    moved = true;
                };
            } else if enemy.archetype == ARCHETYPE_PULLER {
                let (next_x, next_y, can_move) = enemy_ai::choose_step_away(
                    enemy.pos_x,
                    enemy.pos_y,
                    player_actor.pos_x,
                    player_actor.pos_y,
                    room.blocked,
                    occupancy_without_self,
                );

                if can_move {
                    enemy.pos_x = next_x;
                    enemy.pos_y = next_y;
                    moved = true;
                };
            };

            if moved {
                room.occupancy = occupancy_without_self;
                room.occupancy = bitmap::set_bit(room.occupancy, enemy.pos_x, enemy.pos_y);
                store.emit_actor_moved(
                    player,
                    game_id,
                    enemy_actor_id,
                    run.room_id,
                    from_x,
                    from_y,
                    enemy.pos_x,
                    enemy.pos_y,
                );
            };

            store.set_actor_state(@enemy);

            let player_after_move = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);

            if enemy.archetype == ARCHETYPE_BRUTE || enemy.archetype == ARCHETYPE_FLANKER {
                let dist = movement::manhattan_distance(
                    enemy.pos_x,
                    enemy.pos_y,
                    player_after_move.pos_x,
                    player_after_move.pos_y,
                );
                if dist <= 1 {
                    self.create_telegraph(
                        ref store,
                        player,
                        game_id,
                        ref run,
                        enemy_actor_id,
                        TELEGRAPH_TYPE_DAMAGE,
                        SHAPE_SINGLE_TILE,
                        player_after_move.pos_x,
                        player_after_move.pos_y,
                        0,
                        enemy.offense.into(),
                        0,
                        0,
                        0,
                    );
                };
            } else if enemy.archetype == ARCHETYPE_CASTER {
                self.create_telegraph(
                    ref store,
                    player,
                    game_id,
                    ref run,
                    enemy_actor_id,
                    TELEGRAPH_TYPE_DAMAGE,
                    SHAPE_CIRCLE,
                    player_after_move.pos_x,
                    player_after_move.pos_y,
                    0,
                    enemy.offense.into(),
                    0,
                    0,
                    0,
                );
            } else if enemy.archetype == ARCHETYPE_HEAVY {
                self.create_telegraph(
                    ref store,
                    player,
                    game_id,
                    ref run,
                    enemy_actor_id,
                    TELEGRAPH_TYPE_DAMAGE,
                    SHAPE_CROSS,
                    player_after_move.pos_x,
                    player_after_move.pos_y,
                    0,
                    enemy.offense.into(),
                    0,
                    0,
                    0,
                );
            } else if enemy.archetype == ARCHETYPE_PULLER {
                self.create_telegraph(
                    ref store,
                    player,
                    game_id,
                    ref run,
                    enemy_actor_id,
                    TELEGRAPH_TYPE_PULL,
                    SHAPE_CIRCLE,
                    player_after_move.pos_x,
                    player_after_move.pos_y,
                    0,
                    0,
                    enemy.pos_x,
                    enemy.pos_y,
                    2,
                );
            };
        }

        fn create_telegraph(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            ref run: RunState,
            source_actor_id: u8,
            telegraph_type: u8,
            shape_type: u8,
            param_a: u8,
            param_b: u8,
            param_c: u8,
            damage: u16,
            pull_source_x: u8,
            pull_source_y: u8,
            pull_distance: u8,
        ) {
            assert(run.status_flags < 255, 'Too many telegraphs');
            let telegraph_id = run.status_flags;
            run.status_flags += 1;
            store.set_run_state(@run);

            let tg = TelegraphState {
                player,
                game_id,
                telegraph_id,
                source_actor_id,
                shape_type,
                telegraph_type,
                param_a,
                param_b,
                param_c,
                pull_source_x,
                pull_source_y,
                pull_distance,
                damage,
                created_turn: run.turn_index,
                resolves_turn: run.turn_index + 1,
                resolved: false,
                room_id: run.room_id,
            };
            store.set_telegraph_state(@tg);
            store.emit_telegraph_created(
                player,
                game_id,
                telegraph_id,
                source_actor_id,
                run.room_id,
                tg.resolves_turn,
            );
        }

        fn room_0_blocked_bitmap(self: @ContractState) -> u64 {
            let mut blocked = 0_u64;

            blocked = bitmap::set_bit(blocked, 0, 0);
            blocked = bitmap::set_bit(blocked, 1, 0);
            blocked = bitmap::set_bit(blocked, 6, 0);
            blocked = bitmap::set_bit(blocked, 7, 0);

            blocked = bitmap::set_bit(blocked, 0, 1);
            blocked = bitmap::set_bit(blocked, 7, 1);

            blocked = bitmap::set_bit(blocked, 0, 2);
            blocked = bitmap::set_bit(blocked, 3, 2);
            blocked = bitmap::set_bit(blocked, 4, 2);
            blocked = bitmap::set_bit(blocked, 7, 2);

            blocked = bitmap::set_bit(blocked, 1, 3);
            blocked = bitmap::set_bit(blocked, 6, 3);

            blocked = bitmap::set_bit(blocked, 1, 4);
            blocked = bitmap::set_bit(blocked, 6, 4);

            blocked = bitmap::set_bit(blocked, 0, 5);
            blocked = bitmap::set_bit(blocked, 7, 5);

            blocked = bitmap::set_bit(blocked, 0, 6);
            blocked = bitmap::set_bit(blocked, 2, 6);
            blocked = bitmap::set_bit(blocked, 7, 6);

            blocked = bitmap::set_bit(blocked, 0, 7);
            blocked = bitmap::set_bit(blocked, 7, 7);

            blocked
        }

        fn room_1_blocked_bitmap(self: @ContractState) -> u64 {
            let mut blocked = 0_u64;

            blocked = bitmap::set_bit(blocked, 0, 0);
            blocked = bitmap::set_bit(blocked, 7, 0);
            blocked = bitmap::set_bit(blocked, 0, 1);
            blocked = bitmap::set_bit(blocked, 7, 1);
            blocked = bitmap::set_bit(blocked, 0, 2);
            blocked = bitmap::set_bit(blocked, 7, 2);
            blocked = bitmap::set_bit(blocked, 0, 7);
            blocked = bitmap::set_bit(blocked, 7, 7);

            blocked = bitmap::set_bit(blocked, 2, 2);
            blocked = bitmap::set_bit(blocked, 3, 2);
            blocked = bitmap::set_bit(blocked, 4, 3);
            blocked = bitmap::set_bit(blocked, 4, 4);
            blocked = bitmap::set_bit(blocked, 1, 5);
            blocked = bitmap::set_bit(blocked, 2, 5);
            blocked = bitmap::set_bit(blocked, 5, 1);
            blocked = bitmap::set_bit(blocked, 6, 1);

            blocked
        }

        fn room_2_blocked_bitmap(self: @ContractState) -> u64 {
            let mut blocked = 0_u64;

            blocked = bitmap::set_bit(blocked, 0, 0);
            blocked = bitmap::set_bit(blocked, 1, 0);
            blocked = bitmap::set_bit(blocked, 6, 0);
            blocked = bitmap::set_bit(blocked, 7, 0);

            blocked = bitmap::set_bit(blocked, 0, 1);
            blocked = bitmap::set_bit(blocked, 7, 1);

            blocked = bitmap::set_bit(blocked, 2, 2);
            blocked = bitmap::set_bit(blocked, 3, 2);
            blocked = bitmap::set_bit(blocked, 4, 2);
            blocked = bitmap::set_bit(blocked, 5, 2);

            blocked = bitmap::set_bit(blocked, 2, 5);
            blocked = bitmap::set_bit(blocked, 3, 5);
            blocked = bitmap::set_bit(blocked, 4, 5);
            blocked = bitmap::set_bit(blocked, 5, 5);

            blocked = bitmap::set_bit(blocked, 0, 6);
            blocked = bitmap::set_bit(blocked, 7, 6);

            blocked = bitmap::set_bit(blocked, 0, 7);
            blocked = bitmap::set_bit(blocked, 1, 7);
            blocked = bitmap::set_bit(blocked, 6, 7);
            blocked = bitmap::set_bit(blocked, 7, 7);

            blocked
        }
    }
}
