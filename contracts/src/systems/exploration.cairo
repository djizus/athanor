#[starknet::interface]
pub trait IExplorationSystem<T> {
    fn send_expedition(ref self: T, game_id: u64, hero_id: u8);
    fn claim_loot(ref self: T, game_id: u64, hero_id: u8);
}

#[dojo::contract]
pub mod exploration_system {
    use core::poseidon::poseidon_hash_span;
    use game_components_minigame::libs::{assert_token_ownership, post_action, pre_action};
    use game_components_token::core::interface::{
        IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
    };
    use game_components_token::libs::LifecycleTrait;
    use starknet::get_block_timestamp;

    use athanor::constants::{self, DEFAULT_NS};
    use athanor::helpers::exploration;
    use athanor::helpers::random::RandomImpl;
    use athanor::models::game::GameSessionAssertTrait;
    use athanor::models::hero::{HeroPendingIngredient, HeroAssertTrait, HeroTrait};
    use athanor::store::{StoreImpl, StoreTrait};

    use super::IExplorationSystem;

    // No Storage needed — token_address and vrf_address come from Config via Store

    #[abi(embed_v0)]
    impl ExplorationSystemImpl of IExplorationSystem<ContractState> {
        fn send_expedition(ref self: ContractState, game_id: u64, hero_id: u8) {
            let mut store = StoreImpl::new(self.world(@DEFAULT_NS()));
            let token_address = store.token_address();
            let timestamp = get_block_timestamp();

            pre_action(token_address, game_id);

            let token_dispatcher = IMinigameTokenDispatcher {
                contract_address: token_address,
            };
            let token_metadata = token_dispatcher.token_metadata(game_id);
            assert!(token_metadata.lifecycle.is_playable(timestamp), "Game not playable");
            assert_token_ownership(token_address, game_id);

            let session = store.session(game_id);
            session.assert_not_over();

            let mut hero = store.hero(game_id, hero_id);
            hero.assert_recruited(session.hero_count);
            hero.assert_idle();
            hero.assert_alive();

            // VRF per expedition — unique salt from game_id + hero_id + timestamp
            let vrf_addr = store.vrf_address();
            let salt = poseidon_hash_span(
                array![game_id.into(), hero_id.into(), timestamp.into()].span(),
            );
            let random = RandomImpl::from_vrf_address(vrf_addr, salt);
            let seed = random.seed;

            let result = exploration::simulate_expedition(hero.hp, hero.max_hp, hero.power, seed);

            let death_depth_u64: u64 = result.death_depth.into();
            let return_at = timestamp + death_depth_u64 + (death_depth_u64 / 2);

            // Emit exploration events
            let events_len = result.events.len();
            let mut event_idx: u32 = 0;
            loop {
                if event_idx >= events_len {
                    break;
                }
                let tick = *result.events.at(event_idx);
                store
                    .emit_exploration_event(
                        game_id,
                        event_idx.try_into().unwrap(),
                        hero_id,
                        tick.depth,
                        tick.zone_id,
                        tick.event_kind,
                        tick.value,
                        tick.hp_after,
                    );
                event_idx += 1;
            };

            // Update hero with expedition results
            hero.status = athanor::types::HERO_STATUS_EXPLORING;
            hero.expedition_seed = seed;
            hero.expedition_start = timestamp;
            hero.return_at = return_at;
            hero.death_depth = result.death_depth;
            hero.pending_gold = result.gold;
            hero.hp = result.remaining_hp;
            store.set_hero(@hero);

            // Store pending ingredients
            let ing_len = result.ingredient_counts.len();
            let mut ing_idx: u32 = 0;
            loop {
                if ing_idx >= ing_len {
                    break;
                }
                let qty = *result.ingredient_counts.at(ing_idx);
                if qty > 0 {
                    store
                        .set_pending_ingredient(
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

            store.emit_expedition_started(game_id, hero_id, result.death_depth, return_at);

            post_action(token_address, game_id);
        }

        fn claim_loot(ref self: ContractState, game_id: u64, hero_id: u8) {
            let mut store = StoreImpl::new(self.world(@DEFAULT_NS()));
            let token_address = store.token_address();
            let timestamp = get_block_timestamp();

            pre_action(token_address, game_id);

            let token_dispatcher = IMinigameTokenDispatcher {
                contract_address: token_address,
            };
            let token_metadata = token_dispatcher.token_metadata(game_id);
            assert!(token_metadata.lifecycle.is_playable(timestamp), "Game not playable");
            assert_token_ownership(token_address, game_id);

            let mut session = store.session(game_id);
            // Note: claim_loot allowed even when game_over — loot was earned before surrender

            let mut hero = store.hero(game_id, hero_id);
            hero.assert_exploring();
            assert!(timestamp >= hero.return_at, "Hero hasn't returned yet");

            // Transfer gold
            let claimed_gold = hero.pending_gold;
            session.gold += claimed_gold;
            hero.pending_gold = 0;

            // Transfer ingredients
            let mut ing_id: u8 = 0;
            loop {
                if ing_id >= constants::TOTAL_INGREDIENTS {
                    break;
                }
                let pending = store.pending_ingredient(game_id, hero_id, ing_id);
                if pending.quantity > 0 {
                    let mut balance = store.ingredient(game_id, ing_id);
                    balance.quantity += pending.quantity;
                    store.set_ingredient(@balance);

                    store
                        .set_pending_ingredient(
                            @HeroPendingIngredient {
                                game_id, hero_id, ingredient_id: ing_id, quantity: 0,
                            },
                        );
                }
                ing_id += 1;
            };

            // Idle regen + reset expedition fields
            hero.idle_regen(timestamp);
            hero.complete_expedition();
            store.set_hero(@hero);

            store.set_session(@session);

            store.emit_loot_claimed(game_id, hero_id, claimed_gold);

            post_action(token_address, game_id);
        }
    }
}
