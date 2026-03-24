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
        GRID_WIDTH, GRID_HEIGHT, MAX_STAMINA, MOVE_COST_PER_TILE,
        HERO_HP, HERO_OFFENSE, HERO_DEFENSE, HERO_SPEED,
        BRUTE_HP, BRUTE_OFFENSE, BRUTE_DEFENSE, BRUTE_SPEED,
        CASTER_HP, CASTER_OFFENSE, CASTER_DEFENSE, CASTER_SPEED,
        STRIKE_DAMAGE, DASH_DAMAGE, CLEAVE_DAMAGE, FIREBALL_DAMAGE,
    };
    use athanor::v2::helpers::bitmap;
    use athanor::v2::models::index::{RunState, RoomState, ActorState, AbilitySlotState, TelegraphState};
    use athanor::v2::store::{Store, StoreTrait};
    use athanor::v2::systems::phase::{
        PHASE_EXPLORE, PHASE_PLAYER_TURN, PHASE_ENEMY_TURN, PHASE_COMPLETE, PHASE_FAILED,
        FACTION_PLAYER, FACTION_ENEMY,
        ARCHETYPE_HERO, ARCHETYPE_BRUTE, ARCHETYPE_CASTER,
        ABILITY_STRIKE, ABILITY_DASH, ABILITY_CLEAVE, ABILITY_FIREBALL, ABILITY_GUARD,
        TARGET_DIRECTIONAL,
        SHAPE_SINGLE_TILE, SHAPE_CIRCLE,
    };
    use athanor::v2::systems::{movement, abilities, telegraph, enemy_ai};

    const PLAYER_ACTOR_ID: u8 = 0;
    const BRUTE_ACTOR_ID: u8 = 1;
    const CASTER_ACTOR_ID: u8 = 2;
    const MAX_ACTOR_ID: u8 = 2;

    const ENTRY_X: u8 = 1;
    const ENTRY_Y: u8 = 1;
    const BRUTE_X: u8 = 6;
    const BRUTE_Y: u8 = 2;
    const CASTER_X: u8 = 5;
    const CASTER_Y: u8 = 6;

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
                stamina: MAX_STAMINA,
                max_stamina: MAX_STAMINA,
                offense: HERO_OFFENSE,
                defense: HERO_DEFENSE,
                speed: HERO_SPEED,
                move_cost: MOVE_COST_PER_TILE,
                pos_x: 0,
                pos_y: 0,
                alive: true,
                guard_active: false,
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
            assert(run.phase != PHASE_COMPLETE, 'Run already complete');
            assert(run.phase != PHASE_FAILED, 'Run already failed');
            assert(room_id == 0, 'Invalid room id');

            let mut player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);

            let mut occupancy = 0_u64;
            occupancy = bitmap::set_bit(occupancy, ENTRY_X, ENTRY_Y);
            occupancy = bitmap::set_bit(occupancy, BRUTE_X, BRUTE_Y);
            occupancy = bitmap::set_bit(occupancy, CASTER_X, CASTER_Y);

            let room = RoomState {
                player,
                game_id,
                room_id,
                width: GRID_WIDTH,
                height: GRID_HEIGHT,
                blocked: self.m1_blocked_bitmap(),
                occupancy,
                enemy_count: 2,
                cleared: false,
            };
            store.set_room_state(@room);

            player_actor.pos_x = ENTRY_X;
            player_actor.pos_y = ENTRY_Y;
            player_actor.stamina = player_actor.max_stamina;
            player_actor.guard_active = false;
            player_actor.room_id = room_id;
            store.set_actor_state(@player_actor);

            let brute = ActorState {
                player,
                game_id,
                actor_id: BRUTE_ACTOR_ID,
                faction: FACTION_ENEMY,
                archetype: ARCHETYPE_BRUTE,
                hp: BRUTE_HP,
                max_hp: BRUTE_HP,
                stamina: 0,
                max_stamina: 0,
                offense: BRUTE_OFFENSE,
                defense: BRUTE_DEFENSE,
                speed: BRUTE_SPEED,
                move_cost: 0,
                pos_x: BRUTE_X,
                pos_y: BRUTE_Y,
                alive: true,
                guard_active: false,
                room_id,
            };
            store.set_actor_state(@brute);

            let caster = ActorState {
                player,
                game_id,
                actor_id: CASTER_ACTOR_ID,
                faction: FACTION_ENEMY,
                archetype: ARCHETYPE_CASTER,
                hp: CASTER_HP,
                max_hp: CASTER_HP,
                stamina: 0,
                max_stamina: 0,
                offense: CASTER_OFFENSE,
                defense: CASTER_DEFENSE,
                speed: CASTER_SPEED,
                move_cost: 0,
                pos_x: CASTER_X,
                pos_y: CASTER_Y,
                alive: true,
                guard_active: false,
                room_id,
            };
            store.set_actor_state(@caster);

            run.phase = PHASE_PLAYER_TURN;
            run.room_id = room_id;
            store.set_run_state(@run);

            store.emit_room_entered_v2(player, game_id, room_id);
        }

        fn move_v2(ref self: ContractState, game_id: u32, target_x: u8, target_y: u8) {
            let mut store = self.store();
            let player = get_caller_address();

            let run = store.get_run_state(player, game_id);
            assert(run.phase == PHASE_PLAYER_TURN, 'Not player turn');
            assert(movement::in_bounds(target_x, target_y), 'Target out of bounds');

            let mut room = store.get_room_state(player, game_id, run.room_id);
            assert(!bitmap::get_bit(room.blocked, target_x, target_y), 'Target blocked');
            assert(!bitmap::get_bit(room.occupancy, target_x, target_y), 'Target occupied');

            let mut player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
            let from_x = player_actor.pos_x;
            let from_y = player_actor.pos_y;

            let dist = movement::manhattan_distance(from_x, from_y, target_x, target_y);
            let stamina_cost: u16 = dist.into() * player_actor.move_cost.into();
            assert(player_actor.stamina >= stamina_cost, 'Not enough stamina');

            player_actor.stamina -= stamina_cost;
            player_actor.pos_x = target_x;
            player_actor.pos_y = target_y;

            room.occupancy = bitmap::clear_bit(room.occupancy, from_x, from_y);
            room.occupancy = bitmap::set_bit(room.occupancy, target_x, target_y);

            store.set_actor_state(@player_actor);
            store.set_room_state(@room);
            store.emit_actor_moved(player, game_id, PLAYER_ACTOR_ID, run.room_id, from_x, from_y, target_x, target_y);
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

            let mut used_target_actor_id: u8 = 255;
            let mut used_target_x: u8 = 255;
            let mut used_target_y: u8 = 255;

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

                assert(player_actor.stamina >= stamina_cost, 'Not enough stamina');
                player_actor.stamina -= stamina_cost;

                slot.cooldown_remaining = abilities::ability_cooldown(ability_id);

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
                let mut hit_actor_id: u8 = 255;

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
                        let actor_id_at = self.actor_at_position(ref store, player, game_id, run.room_id, next_x, next_y);
                        if actor_id_at != 255 {
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

                assert(moved || hit_actor_id != 255, 'Dash has no path');
                assert(player_actor.stamina >= stamina_cost, 'Not enough stamina');
                player_actor.stamina -= stamina_cost;
                slot.cooldown_remaining = abilities::ability_cooldown(ability_id);

                if moved {
                    let from_x = player_actor.pos_x;
                    let from_y = player_actor.pos_y;
                    player_actor.pos_x = final_x;
                    player_actor.pos_y = final_y;

                    room.occupancy = bitmap::clear_bit(room.occupancy, from_x, from_y);
                    room.occupancy = bitmap::set_bit(room.occupancy, final_x, final_y);

                    store.emit_actor_moved(
                        player, game_id, PLAYER_ACTOR_ID, run.room_id, from_x, from_y, final_x, final_y,
                    );
                };

                if hit_actor_id != 255 {
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
            } else if ability_id == ABILITY_CLEAVE {
                let direction = target_a;
                assert(direction < 4, 'Invalid direction');

                assert(player_actor.stamina >= stamina_cost, 'Not enough stamina');
                player_actor.stamina -= stamina_cost;
                slot.cooldown_remaining = abilities::ability_cooldown(ability_id);

                let mut actor_id: u8 = 1;
                while actor_id <= MAX_ACTOR_ID {
                    let actor = store.get_actor_state(player, game_id, actor_id);
                    if actor.alive && actor.faction == FACTION_ENEMY && actor.room_id == run.room_id {
                        let in_cone = telegraph::tile_in_cone(
                            player_actor.pos_x, player_actor.pos_y, direction, actor.pos_x, actor.pos_y,
                        );
                        if in_cone {
                            let (updated_room, _) = self.apply_damage_to_actor(
                                ref store,
                                player,
                                game_id,
                                room,
                                run.room_id,
                                actor_id,
                                PLAYER_ACTOR_ID,
                                CLEAVE_DAMAGE,
                                player_actor.offense,
                                true,
                            );
                            room = updated_room;
                        };
                    };
                    actor_id += 1;
                };

                used_target_x = player_actor.pos_x;
                used_target_y = player_actor.pos_y;
            } else if ability_id == ABILITY_FIREBALL {
                let target_x = target_a;
                let target_y = target_b;

                assert(movement::in_bounds(target_x, target_y), 'Target out of bounds');
                let range = movement::manhattan_distance(player_actor.pos_x, player_actor.pos_y, target_x, target_y);
                assert(range <= 4, 'Target out of range');

                assert(player_actor.stamina >= stamina_cost, 'Not enough stamina');
                player_actor.stamina -= stamina_cost;
                slot.cooldown_remaining = abilities::ability_cooldown(ability_id);

                let mut actor_id: u8 = 0;
                while actor_id <= MAX_ACTOR_ID {
                    let actor = store.get_actor_state(player, game_id, actor_id);
                    if actor.alive && actor.room_id == run.room_id {
                        let in_aoe = telegraph::tile_in_circle_cross(target_x, target_y, actor.pos_x, actor.pos_y);
                        if in_aoe {
                            let (updated_room, _) = self.apply_damage_to_actor(
                                ref store,
                                player,
                                game_id,
                                room,
                                run.room_id,
                                actor_id,
                                PLAYER_ACTOR_ID,
                                FIREBALL_DAMAGE,
                                player_actor.offense,
                                true,
                            );
                            room = updated_room;
                        };
                    };
                    actor_id += 1;
                };

                used_target_x = target_x;
                used_target_y = target_y;
            } else {
                assert(ability_id == ABILITY_GUARD, 'Invalid ability');

                assert(player_actor.stamina >= stamina_cost, 'Not enough stamina');
                player_actor.stamina -= stamina_cost;
                slot.cooldown_remaining = abilities::ability_cooldown(ability_id);

                player_actor.guard_active = true;
                store.emit_guard_applied(player, game_id, PLAYER_ACTOR_ID, run.room_id);

                used_target_actor_id = PLAYER_ACTOR_ID;
                used_target_x = player_actor.pos_x;
                used_target_y = player_actor.pos_y;
            };

            store.set_actor_state(@player_actor);
            store.set_room_state(@room);
            store.set_ability_slot_state(@slot);

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
                room.cleared = true;
                run.phase = PHASE_COMPLETE;
                store.set_room_state(@room);
                store.set_run_state(@run);
                store.emit_room_cleared(player, game_id, run.room_id);
                store.emit_run_completed(player, game_id, run.turn_index);
            }
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

            // Step 1: resolve telegraphs due this turn.
            let telegraph_count = run.status_flags;
            let mut telegraph_id: u8 = 0;
            while telegraph_id < telegraph_count {
                let mut tg = store.get_telegraph_state(player, game_id, telegraph_id);
                if !tg.resolved && tg.room_id == run.room_id && tg.resolves_turn == run.turn_index {
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

            // Guard expires after telegraph resolution.
            let mut player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
            player_actor.guard_active = false;
            store.set_actor_state(@player_actor);

            if room.enemy_count == 0 {
                room.cleared = true;
                run.phase = PHASE_COMPLETE;
                store.set_room_state(@room);
                store.set_run_state(@run);
                store.emit_room_cleared(player, game_id, run.room_id);
                store.emit_run_completed(player, game_id, run.turn_index);
                return;
            }

            // Step 2: enemies act by speed desc, actor_id asc tie-break. In M1 this is caster(2) then brute(1).
            self.process_enemy_action(ref store, player, game_id, ref run, ref room, CASTER_ACTOR_ID);
            self.process_enemy_action(ref store, player, game_id, ref run, ref room, BRUTE_ACTOR_ID);

            // Step 3: phase transition.
            run.turn_index += 1;
            run.phase = PHASE_PLAYER_TURN;
            store.set_run_state(@run);

            player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
            player_actor.stamina = player_actor.max_stamina;
            store.set_actor_state(@player_actor);

            let mut slot_index: u8 = 0;
            while slot_index < 5 {
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
                ability_id: ABILITY_CLEAVE,
                cooldown_remaining: 0,
            };
            store.set_ability_slot_state(@slot2);

            let slot3 = AbilitySlotState {
                player,
                game_id,
                actor_id,
                slot_index: 3,
                ability_id: ABILITY_FIREBALL,
                cooldown_remaining: 0,
            };
            store.set_ability_slot_state(@slot3);

            let slot4 = AbilitySlotState {
                player,
                game_id,
                actor_id,
                slot_index: 4,
                ability_id: ABILITY_GUARD,
                cooldown_remaining: 0,
            };
            store.set_ability_slot_state(@slot4);
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

            255
        }

        fn apply_damage_to_actor(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            mut room: RoomState,
            room_id: u8,
            target_actor_id: u8,
            source_actor_id: u8,
            base_damage: u16,
            source_offense: u8,
            include_offense: bool,
        ) -> (RoomState, bool) {
            let mut target = store.get_actor_state(player, game_id, target_actor_id);
            if !target.alive {
                return (room, false);
            }

            let damage = if include_offense {
                abilities::compute_damage_with_stats(
                    base_damage,
                    source_offense,
                    target.defense,
                    target.guard_active,
                )
            } else {
                abilities::compute_telegraph_damage(base_damage, target.defense, target.guard_active)
            };

            if damage >= target.hp {
                target.hp = 0;
            } else {
                target.hp -= damage;
            };

            let died = target.hp == 0;
            if died {
                target.alive = false;
                target.guard_active = false;
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
                damage,
                target.hp,
                room_id,
            );

            if died {
                store.emit_actor_died(player, game_id, target_actor_id, room_id);
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

            if enemy.archetype == ARCHETYPE_BRUTE {
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
                        SHAPE_SINGLE_TILE,
                        player_after_move.pos_x,
                        player_after_move.pos_y,
                        0,
                        enemy.offense.into(),
                    );
                };
            } else if enemy.archetype == ARCHETYPE_CASTER {
                self.create_telegraph(
                    ref store,
                    player,
                    game_id,
                    ref run,
                    enemy_actor_id,
                    SHAPE_CIRCLE,
                    player_after_move.pos_x,
                    player_after_move.pos_y,
                    1,
                    enemy.offense.into(),
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
            shape_type: u8,
            param_a: u8,
            param_b: u8,
            param_c: u8,
            damage: u16,
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
                param_a,
                param_b,
                param_c,
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

        fn m1_blocked_bitmap(self: @ContractState) -> u64 {
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
    }
}
