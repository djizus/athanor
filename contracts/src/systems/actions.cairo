#[starknet::interface]
trait IActions<T> {
    fn spawn(ref self: T, game_id: u32, settings_id: u32);
    fn enter_room(ref self: T, game_id: u32, room_id: u8);
    fn confirm_turn(ref self: T, game_id: u32, actions: Span<felt252>);
}

#[dojo::contract]
pub mod actions {
    use super::IActions;

    use dojo::world::{WorldStorage, WorldStorageTrait};
    use game_components_embeddable_game_standard::minigame::interface::IMinigameTokenData;
    use game_components_embeddable_game_standard::minigame::minigame_component::MinigameComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    use athanor::constants::{
        GRID_WIDTH, GRID_HEIGHT, MOVE_COST_PER_TILE, HERO_OFFENSE,
        HERO_DEFENSE, HERO_SPEED, STRIKE_DAMAGE, DASH_DAMAGE, HEAL_AMOUNT, SHOVE_DAMAGE,
        SHOVE_PUSH_DISTANCE, SLAM_DAMAGE, SLAM_PUSH_DISTANCE,
        ORB_STAMINA_BONUS, ORB_HP_BONUS, STAMINA_DRAIN_AMOUNT,
    };
    use athanor::helpers::bitmap;
    use athanor::helpers::procedural;
    use athanor::helpers::random::{RandomTrait};
    use athanor::models::config::{Config, GameSettingsTrait};
    use athanor::models::index::{RunState, RunOwner, RoomState, ActorState, AbilitySlotState, TelegraphState};
    use athanor::store::{Store, StoreTrait};
    use athanor::systems::phase::{
        PHASE_EXPLORE, PHASE_PLAYER_TURN, PHASE_ENEMY_TURN, PHASE_COMPLETE, PHASE_FAILED,
        PHASE_GAME_OVER,
        FACTION_PLAYER, FACTION_ENEMY, ARCHETYPE_HERO, ARCHETYPE_BRUTE, ARCHETYPE_CASTER,
        ARCHETYPE_FLANKER, ARCHETYPE_HEAVY, ARCHETYPE_PULLER, ARCHETYPE_DRAINER,
        ABILITY_STRIKE, ABILITY_DASH,
        ABILITY_HEAL, ABILITY_SHOVE, ABILITY_SLAM, TARGET_DIRECTIONAL, SHAPE_SINGLE_TILE,
        SHAPE_CIRCLE, SHAPE_CROSS, TELEGRAPH_TYPE_DAMAGE, TELEGRAPH_TYPE_PULL,
        TELEGRAPH_TYPE_STAMINA_DRAIN,
    };
    use athanor::systems::{movement, abilities, telegraph, enemy_ai};

    // --- EGC minigame components ---

    component!(path: MinigameComponent, storage: minigame, event: MinigameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl MinigameImpl = MinigameComponent::MinigameImpl<ContractState>;
    impl MinigameInternalImpl = MinigameComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        minigame: MinigameComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MinigameEvent: MinigameComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    fn dojo_init(
        ref self: ContractState,
        denshokan_address: ContractAddress,
        vrf_address: ContractAddress,
        lords_address: ContractAddress,
    ) {
        let world: WorldStorage = self.world(@"athanor_0_1");
        let creator_address = starknet::get_tx_info().unbox().account_contract_address;
        let (setup_address, _) = world.dns(@"setup").expect('actions: setup not found');

        // Only register with Denshokan when a real token contract is supplied.
        // Local dev (Katana) passes 0x0 because no Denshokan is deployed; calling
        // `initializer` with 0x0 would revert inside the minigame component when
        // it performs its ISRC5 supports_interface check.
        if denshokan_address.into() != 0_felt252 {
            self
                .minigame
                .initializer(
                    creator_address: creator_address,
                    name: "Athanor:Ascend",
                    description: "On-chain tactical roguelike - how deep can you go?",
                    developer: "djizus",
                    publisher: "djizus",
                    genre: "Tactics",
                    image: "",
                    color: Option::None,
                    client_url: Option::None,
                    renderer_address: Option::None,
                    settings_address: Option::Some(setup_address),
                    objectives_address: Option::None,
                    token_address: denshokan_address,
                    royalty_fraction: Option::None,
                    skills_address: Option::None,
                    version: 1,
                );
        }

        let mut store = StoreTrait::new(world);
        store
            .set_config(
                @Config {
                    key: 0,
                    token_address: denshokan_address,
                    vrf_address,
                    lords_address,
                },
            );
    }

    // --- EGC IMinigameTokenData ---
    // Placeholders until RunState gains score + ended_at (step 4/10). Returning
    // zero/false is safe: Denshokan treats any score as valid and any non-true
    // game_over as "still playing". Once fields land, swap these reads to real.

    #[abi(embed_v0)]
    impl TokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: felt252) -> u64 {
            let mut store = StoreTrait::new(self.world(@"athanor_0_1"));
            let game_id: u32 = match token_id.try_into() {
                Option::Some(v) => v,
                Option::None => { return 0; },
            };
            let owner = store.get_run_owner(game_id);
            if owner.player.into() == 0_felt252 {
                return 0;
            }
            let run = store.get_run_state(owner.player, game_id);
            run.score.into()
        }

        fn game_over(self: @ContractState, token_id: felt252) -> bool {
            let mut store = StoreTrait::new(self.world(@"athanor_0_1"));
            let game_id: u32 = match token_id.try_into() {
                Option::Some(v) => v,
                Option::None => { return false; },
            };
            let owner = store.get_run_owner(game_id);
            if owner.player.into() == 0_felt252 {
                return false;
            }
            let run = store.get_run_state(owner.player, game_id);
            run.ended_at != 0
        }

        fn score_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<u64> {
            let mut results = array![];
            let mut i: u32 = 0;
            while i < token_ids.len() {
                results.append(self.score(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn game_over_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<bool> {
            let mut results = array![];
            let mut i: u32 = 0;
            while i < token_ids.len() {
                results.append(self.game_over(*token_ids.at(i)));
                i += 1;
            }
            results
        }
    }

    const PLAYER_ACTOR_ID: u8 = 0;
    const ENEMY_ACTOR_ID_1: u8 = 1;
    const ENEMY_ACTOR_ID_2: u8 = 2;
    const ENEMY_ACTOR_ID_3: u8 = 3;
    const ENEMY_ACTOR_ID_4: u8 = 4;
    const ENEMY_ACTOR_ID_5: u8 = 5;
    const MAX_ACTOR_ID: u8 = 5;
    const MAX_ABILITY_SLOTS: u8 = 5;
    const INVALID_ACTOR_ID: u8 = 255;

    const ACTION_TYPE_MOVE: u8 = 0;
    const ACTION_TYPE_ABILITY: u8 = 1;

    const DIRECTION_NORTH: u8 = 0;
    const DIRECTION_EAST: u8 = 1;
    const DIRECTION_SOUTH: u8 = 2;
    const DIRECTION_WEST: u8 = 3;

    const ENTRY_X: u8 = 1;
    const ENTRY_Y: u8 = 1;

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn spawn(ref self: ContractState, game_id: u32, settings_id: u32) {
            let mut store = self.store();
            let player = get_caller_address();

            // TODO(ascend): once Denshokan is wired up in tests, assert token
            // ownership. For local dev this is skipped because no test
            // Denshokan mints `game_id` tokens.
            // self.minigame.assert_token_ownership(game_id.into());

            let settings = store.get_game_settings(settings_id);
            assert(settings.exists(), 'actions: settings not found');
            assert(settings.hero_class == 0, 'actions: class not supported');

            let config = store.get_config();

            // Collect the entry fee in mLORDS. Player must have approved this
            // contract for at least `entry_fee_lords` before calling spawn.
            // entry_fee_lords == 0 is treated as a free run (dev / offline).
            if settings.entry_fee_lords != 0 {
                let lords = IERC20Dispatcher { contract_address: config.lords_address };
                let amount: u256 = settings.entry_fee_lords.into();
                let ok = lords.transfer_from(player, get_contract_address(), amount);
                assert(ok, 'actions: fee transfer failed');
            }

            // Consume VRF once per run; every per-room derivation in step 6
            // will poseidon-hash this seed with room_id and other state bits.
            let random = RandomTrait::new(config.vrf_address, game_id.into());

            let run = RunState {
                player,
                game_id,
                phase: PHASE_EXPLORE,
                room_id: 0,
                turn_index: 0,
                player_actor_id: PLAYER_ACTOR_ID,
                status_flags: 0,
                last_player_direction: DIRECTION_EAST,
                seed: random.seed,
                score: 0,
                rooms_cleared: 0,
                started_at: starknet::get_block_timestamp(),
                ended_at: 0,
            };
            store.set_run_state(@run);
            store.set_run_owner(@RunOwner { game_id, player });

            let actor = ActorState {
                player,
                game_id,
                actor_id: PLAYER_ACTOR_ID,
                faction: FACTION_PLAYER,
                archetype: ARCHETYPE_HERO,
                hp: settings.hero_hp,
                max_hp: settings.hero_hp,
                stamina: settings.hero_stamina,
                max_stamina: settings.hero_stamina,
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

            store.emit_run_spawned(player, game_id, 0, PLAYER_ACTOR_ID);

            let _ = settings_id;
        }

        fn enter_room(ref self: ContractState, game_id: u32, room_id: u8) {
            let mut store = self.store();
            let player = get_caller_address();

            let mut run = store.get_run_state(player, game_id);
            assert(run.phase != PHASE_COMPLETE, 'Run complete');
            assert(run.phase != PHASE_FAILED, 'Run failed');
            assert(run.ended_at == 0, 'Run over');
            assert(run.phase == PHASE_EXPLORE, 'Cannot enter room');

            let mut player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);

            let mut room = RoomState {
                player,
                game_id,
                room_id,
                width: GRID_WIDTH,
                height: GRID_HEIGHT,
                blocked: procedural::generate_blocked_bitmap(
                    run.seed, room_id, ENTRY_X, ENTRY_Y,
                ),
                occupancy: 0_u64,
                enemy_count: 0,
                cleared: false,
                orbs_fresh: 0,
                orbs_aged: 0,
                hp_orbs_fresh: 0,
                hp_orbs_aged: 0,
            };

            room.occupancy = bitmap::set_bit(room.occupancy, ENTRY_X, ENTRY_Y);

            player_actor.pos_x = ENTRY_X;
            player_actor.pos_y = ENTRY_Y;
            player_actor.guard_active = false;
            player_actor.is_immovable = false;
            player_actor.room_id = room_id;
            store.set_actor_state(@player_actor);

            // Reset ability cooldowns — Ascend rule: fresh abilities per room.
            let mut slot_index: u8 = 0;
            while slot_index < MAX_ABILITY_SLOTS {
                let mut slot = store
                    .get_ability_slot_state(player, game_id, PLAYER_ACTOR_ID, slot_index);
                if slot.cooldown_remaining > 0 {
                    slot.cooldown_remaining = 0;
                    store.set_ability_slot_state(@slot);
                };
                slot_index += 1;
            };

            self.reset_enemy_slots(ref store, player, game_id, room_id);

            // Procedural enemy spawn with tier-weighted archetypes, anti-snowball
            // caps (2 Pullers / 2 Heavies / 2 Drainers max), and stat scaling.
            let total = procedural::enemy_count(room_id);
            let mut i: u8 = 0;
            let mut pullers_so_far: u8 = 0;
            let mut heavies_so_far: u8 = 0;
            let mut drainers_so_far: u8 = 0;
            while i < total {
                let actor_id: u8 = i + 1;
                let archetype = procedural::roll_archetype_capped(
                    run.seed, room_id, i, pullers_so_far, heavies_so_far, drainers_so_far,
                );
                if archetype == procedural::ARCH_PULLER {
                    pullers_so_far += 1;
                } else if archetype == procedural::ARCH_HEAVY {
                    heavies_so_far += 1;
                } else if archetype == procedural::ARCH_DRAINER {
                    drainers_so_far += 1;
                }
                let (hp, offense, defense, speed, is_immovable) =
                    procedural::scaled_archetype_stats(archetype, room_id);
                let (x, y) = procedural::pick_enemy_position(
                    run.seed, room_id, i, room.blocked, room.occupancy, ENTRY_X, ENTRY_Y,
                );
                room.occupancy = self
                    .spawn_enemy_actor(
                        ref store,
                        player,
                        game_id,
                        room_id,
                        room.occupancy,
                        actor_id,
                        archetype,
                        hp,
                        offense,
                        defense,
                        speed,
                        x,
                        y,
                        is_immovable,
                    );
                i += 1;
            };
            room.enemy_count = total;

            run.phase = PHASE_PLAYER_TURN;
            run.room_id = room_id;
            run.status_flags = 0;
            run.last_player_direction = DIRECTION_EAST;

            store.set_room_state(@room);
            store.set_run_state(@run);

            store.emit_room_entered(player, game_id, room_id);
        }

        fn confirm_turn(ref self: ContractState, game_id: u32, actions: Span<felt252>) {
            let mut store = self.store();
            let player = get_caller_address();

            let run = store.get_run_state(player, game_id);
            assert(run.ended_at == 0, 'Run over');
            assert(run.phase == PHASE_PLAYER_TURN, 'Not player turn');

            let mut actions = actions;

            loop {
                match actions.pop_front() {
                    Option::Some(action_type_felt) => {
                        let action_type: u8 = (*action_type_felt).try_into().unwrap();

                        if action_type == ACTION_TYPE_MOVE {
                            let target_x: u8 = (*actions.pop_front().unwrap()).try_into().unwrap();
                            let target_y: u8 = (*actions.pop_front().unwrap()).try_into().unwrap();
                            if !self.process_move(ref store, player, game_id, target_x, target_y) {
                                return;
                            }
                        } else {
                            assert(action_type == ACTION_TYPE_ABILITY, 'Invalid action type');
                            let ability_id: u8 = (*actions.pop_front().unwrap()).try_into().unwrap();
                            let target_mode: u8 = (*actions.pop_front().unwrap()).try_into().unwrap();
                            let target_a: u8 = (*actions.pop_front().unwrap()).try_into().unwrap();
                            let target_b: u8 = (*actions.pop_front().unwrap()).try_into().unwrap();
                            if !self.process_ability(
                                ref store, player, game_id, ability_id, target_mode, target_a, target_b,
                            ) {
                                return;
                            }
                        }
                    },
                    Option::None => { break; }
                }
            };

            // Only run enemy phase if still in player turn (room not cleared, player not dead)
            let run_after = store.get_run_state(player, game_id);
            if run_after.phase == PHASE_PLAYER_TURN {
                self.process_enemy_phase(ref store, player, game_id);
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn store(self: @ContractState) -> Store {
            StoreTrait::new(self.world_default())
        }

        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"athanor_0_1")
        }

        // --- Batched turn action processors ---

        /// Process a single move action within a batched turn.
        /// Returns true to continue processing, false if turn should stop (room cleared).
        fn process_move(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            target_x: u8,
            target_y: u8,
        ) -> bool {
            let mut run = store.get_run_state(player, game_id);
            assert(run.phase == PHASE_PLAYER_TURN, 'Not player turn');
            assert(movement::in_bounds(target_x, target_y), 'Target out of bounds');

            let mut room = store.get_room_state(player, game_id, run.room_id);
            assert(!bitmap::get_bit(room.blocked, target_x, target_y), 'Target blocked');

            let mut player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
            let from_x = player_actor.pos_x;
            let from_y = player_actor.pos_y;

            // No-op move (target == current position): skip silently.
            if target_x == from_x && target_y == from_y {
                store.set_actor_state(@player_actor);
                store.set_room_state(@room);
                store.set_run_state(@run);
                return true;
            }

            let dist = movement::manhattan_distance(from_x, from_y, target_x, target_y);
            let stamina_cost: u16 = dist.into() * player_actor.move_cost.into();
            assert(player_actor.stamina >= stamina_cost, 'Not enough stamina');
            // No bump: enemy-occupied tiles are hard blockers. Displacement
            // and "free" collision damage moved entirely into Shove/Slam.
            assert(!bitmap::get_bit(room.occupancy, target_x, target_y), 'Target occupied');

            player_actor.stamina -= stamina_cost;

            let move_to_x = target_x;
            let move_to_y = target_y;
            let did_move = true;

            if did_move {
                player_actor.pos_x = move_to_x;
                player_actor.pos_y = move_to_y;

                room.occupancy = bitmap::clear_bit(room.occupancy, from_x, from_y);
                room.occupancy = bitmap::set_bit(room.occupancy, move_to_x, move_to_y);

                run.last_player_direction = self.direction_from_delta(
                    from_x, from_y, move_to_x, move_to_y,
                );

                self.try_collect_orb_at(
                    ref store, player, game_id, ref room, ref player_actor,
                    move_to_x, move_to_y,
                );

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
                if self.maybe_finalize_room(ref store, player, game_id, ref run, ref room) {
                    return false;
                }
            };

            // Per-turn refill model: stamina reaching 0 is NOT a game-over.
            // The run ends only when player HP ≤ 0.
            true
        }

        /// Process a single ability action within a batched turn.
        /// Returns true to continue processing, false if turn should stop (player died, room cleared).
        fn process_ability(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            ability_id: u8,
            target_mode: u8,
            target_a: u8,
            target_b: u8,
        ) -> bool {
            let mut run = store.get_run_state(player, game_id);
            assert(run.phase == PHASE_PLAYER_TURN, 'Not player turn');

            let expected_mode = abilities::expected_target_mode(ability_id);
            assert(target_mode == expected_mode, 'Invalid target mode');

            let mut player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
            let mut room = store.get_room_state(player, game_id, run.room_id);

            let mut slot = store.get_ability_slot_state(
                player, game_id, PLAYER_ACTOR_ID, ability_id,
            );
            assert(slot.ability_id == ability_id, 'Unknown ability');
            assert(slot.cooldown_remaining == 0, 'Ability on cooldown');

            let stamina_cost = abilities::ability_cost(ability_id);
            assert(stamina_cost > 0, 'Invalid ability');
            assert(player_actor.stamina >= stamina_cost, 'Not enough stamina');

            player_actor.stamina -= stamina_cost;
            slot.cooldown_remaining = abilities::ability_cooldown(ability_id);

            // Save ref player to store BEFORE ability execution so that
            // apply_damage_to_actor reads the correct in-flight stamina
            // when applying kill bonuses.
            store.set_actor_state(@player_actor);

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
                    player_actor.pos_x,
                    player_actor.pos_y,
                    target_actor.pos_x,
                    target_actor.pos_y,
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
                    let (next_x, next_y, ok) = movement::step_in_direction(
                        cur_x, cur_y, direction,
                    );
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

                    // Drive-by orb pickup on each transit tile.
                    self
                        .try_collect_orb_at(
                            ref store, player, game_id, ref room, ref player_actor,
                            cur_x, cur_y,
                        );
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

                    // Persist position + any orb-derived stamina picked up during
                    // transit. (Ability branches normally don't re-save
                    // player_actor; Dash has to so the new position + stamina
                    // reach the store.)
                    store.set_actor_state(@player_actor);

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
                player_actor.hp = self.add_hp_capped(
                    player_actor.hp, player_actor.max_hp, HEAL_AMOUNT,
                );
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
                    player_actor.pos_x,
                    player_actor.pos_y,
                    target_actor.pos_x,
                    target_actor.pos_y,
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
                    if actor.alive
                        && actor.faction == FACTION_ENEMY
                        && actor.room_id == run.room_id
                    {
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

                            let actor_after_hit = store.get_actor_state(
                                player, game_id, actor_id,
                            );
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

            // player_actor already saved before ability execution; will re-read below.
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

            // Re-read player actor (may have been modified by damage helpers giving kill bonus)
            player_actor = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
            if !player_actor.alive || player_actor.hp == 0 {
                self.latch_game_over(ref store, player, game_id, ref run);
                return false;
            }

            if room.enemy_count == 0 {
                if self.maybe_finalize_room(ref store, player, game_id, ref run, ref room) {
                    return false;
                }
            };

            // Per-turn refill model: stamina reaching 0 is NOT a game-over.
            // The run ends only when player HP ≤ 0.
            let _ = target_b;
            true
        }

        /// Run the full enemy phase: resolve telegraphs, enemy AI, new telegraphs, turn transition.
        fn process_enemy_phase(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
        ) {
            let mut run = store.get_run_state(player, game_id);

            // End player phase
            run.phase = PHASE_ENEMY_TURN;
            store.set_run_state(@run);
            store.emit_turn_ended(player, game_id, run.room_id, run.turn_index);

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
                        ref store, player, game_id, room, run.room_id, tg,
                    );

                    tg.resolved = true;
                    store.set_telegraph_state(@tg);
                    store.emit_telegraph_resolved(player, game_id, telegraph_id, run.room_id);
                };

                telegraph_id += 1;
            };

            // Step 1b: resolve STAMINA_DRAIN telegraphs. Drain after PULL so
            // the player's post-pull tile is what matters. Killing the
            // Drainer before its telegraph resolves cancels the drain
            // automatically (the `tg.resolved` check skips it — no special
            // handling needed because we emit `tg` from a still-live source).
            telegraph_id = 0;
            while telegraph_id < telegraph_count {
                let mut tg = store.get_telegraph_state(player, game_id, telegraph_id);
                if !tg.resolved
                    && tg.room_id == run.room_id
                    && tg.resolves_turn == run.turn_index
                    && tg.telegraph_type == TELEGRAPH_TYPE_STAMINA_DRAIN
                {
                    let mut player_actor = store.get_actor_state(
                        player, game_id, PLAYER_ACTOR_ID,
                    );
                    if player_actor.alive && player_actor.room_id == run.room_id {
                        let in_zone = telegraph::tile_in_shape(
                            tg.shape_type,
                            tg.param_a,
                            tg.param_b,
                            tg.param_c,
                            player_actor.pos_x,
                            player_actor.pos_y,
                        );
                        if in_zone {
                            // Saturating subtract — stamina never goes below 0.
                            if player_actor.stamina > tg.damage {
                                player_actor.stamina -= tg.damage;
                            } else {
                                player_actor.stamina = 0;
                            };
                            store.set_actor_state(@player_actor);
                        };
                    };
                    tg.resolved = true;
                    store.set_telegraph_state(@tg);
                    store.emit_telegraph_resolved(player, game_id, telegraph_id, run.room_id);
                };

                telegraph_id += 1;
            };

            // Step 1c: resolve DAMAGE telegraphs.
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
                        store.set_room_state(@room);
                        self.latch_game_over(ref store, player, game_id, ref run);
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

            // Post-enemy safety checks: player death or room cleared.
            let player_after_enemies = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
            if !player_after_enemies.alive || player_after_enemies.hp == 0 {
                store.set_room_state(@room);
                self.latch_game_over(ref store, player, game_id, ref run);
                return;
            }
            if room.enemy_count == 0 {
                let _ = self.maybe_finalize_room(ref store, player, game_id, ref run, ref room);
                store.set_room_state(@room);
                return;
            }

            // Step 3: refill stamina to max at the start of the next player
            // turn. Per-turn-refill model: intra-turn bonuses (kill +10, orb
            // +20) evaporate here and the player starts fresh with their cap.
            // HP is preserved — only HP ≤ 0 ends the run.
            let mut player_refill = store.get_actor_state(player, game_id, PLAYER_ACTOR_ID);
            if player_refill.alive {
                player_refill.stamina = player_refill.max_stamina;
                store.set_actor_state(@player_refill);
            }

            // Step 4: phase transition.
            run.turn_index += 1;
            run.phase = PHASE_PLAYER_TURN;
            store.set_run_state(@run);

            let mut slot_index: u8 = 0;
            while slot_index < MAX_ABILITY_SLOTS {
                let mut slot = store.get_ability_slot_state(
                    player, game_id, PLAYER_ACTOR_ID, slot_index,
                );
                if slot.cooldown_remaining > 0 {
                    slot.cooldown_remaining -= 1;
                    store.set_ability_slot_state(@slot);
                };
                slot_index += 1;
            };

            // Orb aging rotation. Orbs live at most 2 player turns: they
            // spawn in `*_fresh`, migrate to `*_aged` at the end of this
            // enemy phase, and expire on the next rotation unless collected.
            // Stamina and HP orbs share the same lifetime — they differ only
            // in what they grant on pickup.
            room.orbs_aged = room.orbs_fresh;
            room.orbs_fresh = 0;
            room.hp_orbs_aged = room.hp_orbs_fresh;
            room.hp_orbs_fresh = 0;

            store.set_room_state(@room);
            store.emit_enemy_turn_computed(player, game_id, run.room_id, run.turn_index);
            store.emit_turn_ended(player, game_id, run.room_id, run.turn_index);
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

            // Ascend: no win condition. Every cleared room advances to the
            // next and awards bonus score = 100 × (new rooms_cleared).
            run.rooms_cleared += 1;
            run.score += 100_u32 * run.rooms_cleared.into();
            run.phase = PHASE_EXPLORE;
            store.set_run_state(@run);

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

                // Involuntary movement still collects orbs.
                self
                    .try_collect_orb_at(
                        ref store, player, game_id, ref room, ref player_actor,
                        cur_x, cur_y,
                    );
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

        /// Push `target_actor_id` up to `push_distance` tiles in `direction`.
        /// Used by the Shove and Slam abilities. On obstruction (wall, other
        /// actor) or when the target is immovable, the push silently stops —
        /// no collision damage. The ability's base damage already landed
        /// before push_actor_steps was called.
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
            let _ = source_actor_id;
            let mut target = store.get_actor_state(player, game_id, target_actor_id);
            if !target.alive || target.room_id != room_id {
                return (room, false);
            }

            if target.is_immovable {
                // Immovable (Heavy) just doesn't move. No bonus damage.
                return (room, false);
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
                    // Push blocked. Silent fail — no collision bonus damage.
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

        /// Latch game-over. Single source of truth for run termination on
        /// player HP=0. Sets ended_at (EGC game_over flips true), switches to
        /// PHASE_GAME_OVER (rejects further confirm_turn / enter_room), and
        /// emits RunEnded with leaderboard payload.
        fn latch_game_over(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            ref run: RunState,
        ) {
            let ended_at = starknet::get_block_timestamp();
            run.ended_at = ended_at;
            run.phase = PHASE_GAME_OVER;
            store.set_run_state(@run);
            store
                .emit_run_ended(
                    player, game_id, run.score, run.rooms_cleared, run.turn_index, ended_at,
                );
        }

        /// Collect any orb on (x, y). Called for every tile the player
        /// occupies — voluntary move destination, each Dash transit tile, and
        /// each step of a Pull displacement. Idempotent on empty tiles.
        ///
        /// Stamina orbs (Brute/Flanker/Drainer drops) top up stamina, capped
        /// at the per-turn max. HP orbs (Caster/Heavy/Puller drops) restore
        /// HP capped at max_hp. Stamina orbs have no carryover — refill at
        /// next player turn wipes any excess anyway.
        fn try_collect_orb_at(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
            ref room: RoomState,
            ref player_actor: ActorState,
            x: u8,
            y: u8,
        ) {
            let has_stamina_orb = bitmap::get_bit(room.orbs_fresh, x, y)
                || bitmap::get_bit(room.orbs_aged, x, y);
            if has_stamina_orb {
                let bonus: u16 = ORB_STAMINA_BONUS;
                let max_s = player_actor.max_stamina;
                if player_actor.stamina + bonus > max_s {
                    player_actor.stamina = max_s;
                } else {
                    player_actor.stamina += bonus;
                };
                room.orbs_fresh = bitmap::clear_bit(room.orbs_fresh, x, y);
                room.orbs_aged = bitmap::clear_bit(room.orbs_aged, x, y);
                store.emit_orb_collected(
                    player, game_id, room.room_id, x, y, player_actor.stamina, 0,
                );
            }

            let has_hp_orb = bitmap::get_bit(room.hp_orbs_fresh, x, y)
                || bitmap::get_bit(room.hp_orbs_aged, x, y);
            if has_hp_orb {
                player_actor.hp = self.add_hp_capped(
                    player_actor.hp, player_actor.max_hp, ORB_HP_BONUS,
                );
                room.hp_orbs_fresh = bitmap::clear_bit(room.hp_orbs_fresh, x, y);
                room.hp_orbs_aged = bitmap::clear_bit(room.hp_orbs_aged, x, y);
                store.emit_orb_collected(
                    player, game_id, room.room_id, x, y, player_actor.hp, 1,
                );
            }
        }

        /// Orb kind dropped by each enemy archetype on death.
        /// 0 = stamina, 1 = HP. Aggressive attackers drop stamina (reward
        /// for aggression); support/control enemies drop HP (reward for
        /// prioritizing threats).
        fn archetype_orb_kind(self: @ContractState, archetype: u8) -> u8 {
            if archetype == ARCHETYPE_BRUTE
                || archetype == ARCHETYPE_FLANKER
                || archetype == ARCHETYPE_DRAINER {
                0
            } else {
                // Caster, Heavy, Puller, and any future support archetype.
                1
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

                // Ascend: enemy death spawns an orb on its tile (kind depends
                // on archetype — see archetype_orb_kind) and awards score =
                // max_hp × 10 so scaled late-game enemies are worth more.
                if target.faction == FACTION_ENEMY {
                    let mut run = store.get_run_state(player, game_id);
                    let kill_score: u32 = target.max_hp.into() * 10;
                    run.score += kill_score;
                    store.set_run_state(@run);

                    let orb_kind = self.archetype_orb_kind(target.archetype);
                    if orb_kind == 0 {
                        room.orbs_fresh = bitmap::set_bit(
                            room.orbs_fresh, target.pos_x, target.pos_y,
                        );
                    } else {
                        room.hp_orbs_fresh = bitmap::set_bit(
                            room.hp_orbs_fresh, target.pos_x, target.pos_y,
                        );
                    };
                    store
                        .emit_orb_spawned(
                            player,
                            game_id,
                            room_id,
                            target.pos_x,
                            target.pos_y,
                            run.turn_index,
                            orb_kind,
                        );
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
            // speed desc + actor_id asc. Drainer (speed 6) interleaves with
            // Puller (also speed 6); actor_id asc resolves tie-break inside
            // process_enemies_of_archetype.
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
                ref store, player, game_id, ref run, ref room, ARCHETYPE_DRAINER,
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
            } else if enemy.archetype == ARCHETYPE_DRAINER {
                // Drainer mirrors Puller's spacing: retreat when too close
                // so the player has to chase through the drain telegraph.
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
            } else if enemy.archetype == ARCHETYPE_DRAINER {
                // 3×3 STAMINA_DRAIN zone centered on the player. The
                // `damage` u16 carries the drain amount (resolver reads it
                // as stamina when telegraph_type == TELEGRAPH_TYPE_STAMINA_DRAIN).
                self.create_telegraph(
                    ref store,
                    player,
                    game_id,
                    ref run,
                    enemy_actor_id,
                    TELEGRAPH_TYPE_STAMINA_DRAIN,
                    SHAPE_CIRCLE,
                    player_after_move.pos_x,
                    player_after_move.pos_y,
                    0,
                    STAMINA_DRAIN_AMOUNT,
                    0,
                    0,
                    0,
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

    }
}
