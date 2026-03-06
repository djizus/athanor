#[starknet::interface]
pub trait IHeroSystem<T> {
    fn recruit_hero(ref self: T, game_id: u64);
    fn apply_potion(ref self: T, game_id: u64, potion_index: u16, hero_id: u8);
}

#[dojo::contract]
pub mod hero_system {
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
    use athanor::events::{HeroRecruited, PotionApplied};
    use athanor::models::game::GameSession;
    use athanor::models::hero::Hero;
    use athanor::models::inventory::PotionItem;
    use athanor::types;

    use super::IHeroSystem;

    #[storage]
    struct Storage {
        token_address: ContractAddress,
    }

    fn dojo_init(ref self: ContractState, token_address: ContractAddress) {
        self.token_address.write(token_address);
    }

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
            let mut world: WorldStorage = self.world(@DEFAULT_NS());
            let token_address = self.token_address.read();

            pre_action(token_address, game_id);

            let token_dispatcher = IMinigameTokenDispatcher {
                contract_address: token_address,
            };
            let timestamp = get_block_timestamp();
            assert!(
                token_dispatcher.token_metadata(game_id).lifecycle.is_playable(timestamp),
                "Game not playable",
            );
            assert_token_ownership(token_address, game_id);

            let mut session: GameSession = world.read_model(game_id);
            assert!(!session.game_over, "Game is over");
            assert!(session.hero_count < constants::MAX_HEROES, "Max heroes reached");

            let new_hero_id = session.hero_count;
            let cost = hero_cost(new_hero_id);
            assert!(session.gold >= cost, "Not enough gold");

            session.gold -= cost;
            session.hero_count += 1;
            world.write_model(@session);

            let hero = Hero {
                game_id,
                hero_id: new_hero_id,
                hp: constants::HERO_BASE_HP,
                max_hp: constants::HERO_BASE_HP,
                power: constants::HERO_BASE_POWER,
                regen_per_sec: constants::HERO_BASE_REGEN,
                status: types::HERO_STATUS_IDLE,
                expedition_seed: 0,
                expedition_start: 0,
                return_at: 0,
                death_depth: 0,
                pending_gold: 0,
            };
            world.write_model(@hero);

            world.emit_event(@HeroRecruited { game_id, hero_id: new_hero_id, cost });

            post_action(token_address, game_id);
        }

        fn apply_potion(ref self: ContractState, game_id: u64, potion_index: u16, hero_id: u8) {
            let mut world: WorldStorage = self.world(@DEFAULT_NS());
            let token_address = self.token_address.read();

            pre_action(token_address, game_id);

            let token_dispatcher = IMinigameTokenDispatcher {
                contract_address: token_address,
            };
            let timestamp = get_block_timestamp();
            assert!(
                token_dispatcher.token_metadata(game_id).lifecycle.is_playable(timestamp),
                "Game not playable",
            );
            assert_token_ownership(token_address, game_id);

            let session: GameSession = world.read_model(game_id);
            assert!(!session.game_over, "Game is over");

            let potion: PotionItem = world.read_model((game_id, potion_index));
            assert!(potion.effect_value > 0, "Potion already used or invalid");

            let mut hero: Hero = world.read_model((game_id, hero_id));
            assert!(hero_id < session.hero_count, "Hero not recruited");
            assert!(hero.status == types::HERO_STATUS_IDLE, "Hero not idle");

            if potion.effect_type == types::EFFECT_MAX_HP {
                let buff: u16 = potion.effect_value.into() * 100;
                hero.max_hp += buff;
                hero.hp += buff;
            } else if potion.effect_type == types::EFFECT_POWER {
                hero.power += potion.effect_value.into() * 100;
            } else if potion.effect_type == types::EFFECT_REGEN {
                hero.regen_per_sec += potion.effect_value.into() * 10;
            }
            world.write_model(@hero);

            // Consume potion (zero out effect_value to mark as used)
            world
                .write_model(
                    @PotionItem {
                        game_id,
                        potion_index,
                        recipe_id: potion.recipe_id,
                        effect_type: potion.effect_type,
                        effect_value: 0,
                    },
                );

            world
                .emit_event(
                    @PotionApplied {
                        game_id,
                        hero_id,
                        potion_index,
                        effect_type: potion.effect_type,
                        effect_value: potion.effect_value,
                    },
                );

            post_action(token_address, game_id);
        }
    }
}
