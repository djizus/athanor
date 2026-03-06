#[starknet::interface]
pub trait IHeroSystem<T> {
    fn recruit_hero(ref self: T, game_id: u64);
    fn apply_potion(ref self: T, game_id: u64, potion_index: u16, hero_id: u8);
}

#[dojo::contract]
pub mod hero_system {
    use game_components_minigame::libs::{assert_token_ownership, post_action, pre_action};
    use game_components_token::core::interface::{
        IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
    };
    use game_components_token::libs::LifecycleTrait;
    use starknet::get_block_timestamp;

    use athanor::constants::{self, DEFAULT_NS};
    use athanor::models::game::GameSessionAssertTrait;
    use athanor::models::hero::{HeroTrait, HeroAssertTrait};
    use athanor::models::inventory::PotionItem;
    use athanor::store::{StoreImpl, StoreTrait};

    use super::IHeroSystem;

    // No Storage needed — token_address comes from Config via Store

    fn hero_cost(hero_id: u8) -> u32 {
        if hero_id == 0 {
            constants::HERO_COST_0
        } else if hero_id == 1 {
            constants::HERO_COST_1
        } else {
            constants::HERO_COST_2
        }
    }

    #[abi(embed_v0)]
    impl HeroSystemImpl of IHeroSystem<ContractState> {
        fn recruit_hero(ref self: ContractState, game_id: u64) {
            let mut store = StoreImpl::new(self.world(@DEFAULT_NS()));
            let token_address = store.token_address();
            let timestamp = get_block_timestamp();

            pre_action(token_address, game_id);

            let token_dispatcher = IMinigameTokenDispatcher {
                contract_address: token_address,
            };
            assert!(
                token_dispatcher.token_metadata(game_id).lifecycle.is_playable(timestamp),
                "Game not playable",
            );
            assert_token_ownership(token_address, game_id);

            let mut session = store.session(game_id);
            session.assert_not_over();
            assert!(session.hero_count < constants::MAX_HEROES, "Max heroes reached");

            let new_hero_id = session.hero_count;
            let cost = hero_cost(new_hero_id);
            assert!(session.gold >= cost, "Not enough gold");

            session.gold -= cost;
            session.hero_count += 1;
            store.set_session(@session);

            let hero = HeroTrait::new(game_id, new_hero_id);
            store.set_hero(@hero);

            store.emit_hero_recruited(game_id, new_hero_id, cost);

            post_action(token_address, game_id);
        }

        fn apply_potion(ref self: ContractState, game_id: u64, potion_index: u16, hero_id: u8) {
            let mut store = StoreImpl::new(self.world(@DEFAULT_NS()));
            let token_address = store.token_address();
            let timestamp = get_block_timestamp();

            pre_action(token_address, game_id);

            let token_dispatcher = IMinigameTokenDispatcher {
                contract_address: token_address,
            };
            assert!(
                token_dispatcher.token_metadata(game_id).lifecycle.is_playable(timestamp),
                "Game not playable",
            );
            assert_token_ownership(token_address, game_id);

            let session = store.session(game_id);
            session.assert_not_over();

            let potion = store.potion(game_id, potion_index);
            assert!(potion.effect_value > 0, "Potion already used or invalid");

            let mut hero = store.hero(game_id, hero_id);
            hero.assert_recruited(session.hero_count);
            hero.assert_idle();

            // Apply buff via model method
            hero.apply_buff(potion.effect_type, potion.effect_value);
            store.set_hero(@hero);

            // Consume potion (zero out effect_value to mark as used)
            store
                .set_potion(
                    @PotionItem {
                        game_id,
                        potion_index,
                        recipe_id: potion.recipe_id,
                        effect_type: potion.effect_type,
                        effect_value: 0,
                    },
                );

            store
                .emit_potion_applied(
                    game_id, hero_id, potion_index, potion.effect_type, potion.effect_value,
                );

            post_action(token_address, game_id);
        }
    }
}
