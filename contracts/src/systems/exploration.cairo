#[starknet::interface]
pub trait IExplorationSystem<T> {
    fn send_expedition(ref self: T, game_id: u64, hero_id: u8);
    fn claim_loot(ref self: T, game_id: u64, hero_id: u8);
}

#[dojo::contract]
pub mod exploration_system {
    use core::poseidon::poseidon_hash_span;
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo::world::WorldStorage;
    use game_components_minigame::libs::{assert_token_ownership, post_action, pre_action};
    use game_components_token::core::interface::{
        IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
    };
    use game_components_token::libs::LifecycleTrait;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_block_timestamp};

    use athanor::constants::{self, DEFAULT_NS};
    use athanor::events::{ExplorationEvent, ExpeditionStarted, LootClaimed};
    use athanor::helpers::exploration::{self, TickEvent};
    use athanor::helpers::random::RandomImpl;
    use athanor::models::game::GameSession;
    use athanor::models::hero::{Hero, HeroPendingIngredient};
    use athanor::models::inventory::IngredientBalance;
    use athanor::types;

    use super::IExplorationSystem;

    #[storage]
    struct Storage {
        token_address: ContractAddress,
        vrf_address: ContractAddress,
    }

    fn dojo_init(
        ref self: ContractState,
        token_address: ContractAddress,
        vrf_address: ContractAddress,
    ) {
        self.token_address.write(token_address);
        self.vrf_address.write(vrf_address);
    }

    #[abi(embed_v0)]
    impl ExplorationSystemImpl of IExplorationSystem<ContractState> {
        fn send_expedition(ref self: ContractState, game_id: u64, hero_id: u8) {
            let mut world: WorldStorage = self.world(@DEFAULT_NS());
            let token_address = self.token_address.read();

            pre_action(token_address, game_id);

            let token_dispatcher = IMinigameTokenDispatcher {
                contract_address: token_address,
            };
            let token_metadata = token_dispatcher.token_metadata(game_id);
            let timestamp = get_block_timestamp();
            assert!(token_metadata.lifecycle.is_playable(timestamp), "Game not playable");
            assert_token_ownership(token_address, game_id);

            let session: GameSession = world.read_model(game_id);
            assert!(!session.game_over, "Game is over");

            let mut hero: Hero = world.read_model((game_id, hero_id));
            assert!(hero_id < session.hero_count, "Hero not recruited");
            assert!(hero.status == types::HERO_STATUS_IDLE, "Hero not idle");
            assert!(hero.hp > 0, "Hero has no HP");

            // VRF per expedition — unique salt from game_id + hero_id + timestamp
            let vrf_addr = self.vrf_address.read();
            let salt = poseidon_hash_span(
                array![game_id.into(), hero_id.into(), timestamp.into()].span(),
            );
            let random = RandomImpl::from_vrf_address(vrf_addr, salt);
            let seed = random.seed;

            let result = exploration::simulate_expedition(hero.hp, hero.max_hp, hero.power, seed);

            let death_depth_u64: u64 = result.death_depth.into();
            let return_at = timestamp + death_depth_u64 + (death_depth_u64 / 2);

            let events_len = result.events.len();
            let mut event_idx: u32 = 0;
            loop {
                if event_idx >= events_len {
                    break;
                }
                let tick: TickEvent = *result.events.at(event_idx);
                world
                    .emit_event(
                        @ExplorationEvent {
                            game_id,
                            event_index: event_idx.try_into().unwrap(),
                            hero_id,
                            depth: tick.depth,
                            zone_id: tick.zone_id,
                            event_kind: tick.event_kind,
                            value: tick.value,
                            hp_after: tick.hp_after,
                        },
                    );
                event_idx += 1;
            };

            hero.status = types::HERO_STATUS_EXPLORING;
            hero.expedition_seed = seed;
            hero.expedition_start = timestamp;
            hero.return_at = return_at;
            hero.death_depth = result.death_depth;
            hero.pending_gold = result.gold;
            hero.hp = result.remaining_hp;
            world.write_model(@hero);

            let ing_len = result.ingredient_counts.len();
            let mut ing_idx: u32 = 0;
            loop {
                if ing_idx >= ing_len {
                    break;
                }
                let qty = *result.ingredient_counts.at(ing_idx);
                if qty > 0 {
                    world
                        .write_model(
                            @HeroPendingIngredient {
                                game_id,
                                hero_id,
                                ingredient_id: ing_idx.try_into().unwrap(),
                                quantity: qty,
                            },
                        );
                }
                ing_idx += 1;
            };

            world
                .emit_event(
                    @ExpeditionStarted {
                        game_id, hero_id, death_depth: result.death_depth, return_at,
                    },
                );

            post_action(token_address, game_id);
        }

        fn claim_loot(ref self: ContractState, game_id: u64, hero_id: u8) {
            let mut world: WorldStorage = self.world(@DEFAULT_NS());
            let token_address = self.token_address.read();

            pre_action(token_address, game_id);

            let token_dispatcher = IMinigameTokenDispatcher {
                contract_address: token_address,
            };
            let token_metadata = token_dispatcher.token_metadata(game_id);
            let timestamp = get_block_timestamp();
            assert!(token_metadata.lifecycle.is_playable(timestamp), "Game not playable");
            assert_token_ownership(token_address, game_id);

            let mut session: GameSession = world.read_model(game_id);
            // Note: claim_loot allowed even when game_over — loot was earned before surrender

            let mut hero: Hero = world.read_model((game_id, hero_id));
            assert!(hero.status == types::HERO_STATUS_EXPLORING, "Hero not on expedition");
            assert!(timestamp >= hero.return_at, "Hero hasn't returned yet");

            let claimed_gold = hero.pending_gold;
            session.gold += claimed_gold;
            hero.pending_gold = 0;

            let mut ing_id: u8 = 0;
            loop {
                if ing_id >= constants::TOTAL_INGREDIENTS {
                    break;
                }
                let pending: HeroPendingIngredient = world
                    .read_model((game_id, hero_id, ing_id));
                if pending.quantity > 0 {
                    let mut balance: IngredientBalance = world
                        .read_model((game_id, ing_id));
                    balance.quantity += pending.quantity;
                    world.write_model(@balance);

                    world
                        .write_model(
                            @HeroPendingIngredient {
                                game_id, hero_id, ingredient_id: ing_id, quantity: 0,
                            },
                        );
                }
                ing_id += 1;
            };

            // Idle regen: hero rests from return_at until now (adds to any surviving HP)
            let rest_time: u64 = timestamp - hero.return_at;
            let regen_amount: u64 = rest_time * hero.regen_per_sec.into();
            let total_hp: u64 = hero.hp.into() + regen_amount;
            let capped_hp: u16 = if total_hp >= hero.max_hp.into() {
                hero.max_hp
            } else {
                total_hp.try_into().unwrap()
            };

            hero.status = types::HERO_STATUS_IDLE;
            hero.hp = capped_hp;
            hero.death_depth = 0;
            hero.expedition_seed = 0;
            hero.expedition_start = 0;
            hero.return_at = 0;
            world.write_model(@hero);

            world.write_model(@session);

            world.emit_event(@LootClaimed { game_id, hero_id, gold: claimed_gold });

            post_action(token_address, game_id);
        }
    }
}
