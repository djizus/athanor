#[starknet::interface]
pub trait IGameSystem<T> {
    fn create(ref self: T, game_id: u64);
    fn surrender(ref self: T, game_id: u64);
}

#[dojo::contract]
pub mod game_system {
    use core::num::traits::Zero;
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo::world::{WorldStorage, WorldStorageTrait};
    use game_components_minigame::interface::IMinigameTokenData;
    use game_components_minigame::libs::{assert_token_ownership, post_action, pre_action};
    use game_components_minigame::minigame::MinigameComponent;
    use game_components_token::core::interface::{
        IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
    };
    use game_components_token::libs::LifecycleTrait;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    use athanor::constants::{self, DEFAULT_NS};
    use athanor::events::GameCreated;
    use athanor::helpers::random::RandomImpl;
    use athanor::helpers::recipes;
    use athanor::models::game::{GameSession, GameSeed};
    use athanor::models::hero::Hero;
    use athanor::models::player::PlayerMeta;
    use athanor::types;

    use super::IGameSystem;

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
        vrf_address: ContractAddress,
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
        creator_address: ContractAddress,
        denshokan_address: ContractAddress,
        renderer_address: Option<ContractAddress>,
        vrf_address: ContractAddress,
    ) {
        let mut world: WorldStorage = self.world(@DEFAULT_NS());

        let config_address = match world.dns(@"config_system") {
            Option::Some((addr, _)) => addr,
            Option::None => Zero::zero(),
        };

        let renderer = match renderer_address {
            Option::Some(addr) => addr,
            Option::None => {
                match world.dns(@"renderer_systems") {
                    Option::Some((addr, _)) => addr,
                    Option::None => Zero::zero(),
                }
            },
        };

        self
            .minigame
            .initializer(
                creator_address,
                "Athanor",
                "On-chain competitive grimoire race",
                "djizus",
                "djizus",
                "Strategy",
                "",
                Option::None,
                Option::None,
                if renderer.is_zero() { Option::None } else { Option::Some(renderer) },
                if config_address.is_zero() {
                    Option::None
                } else {
                    Option::Some(config_address)
                },
                Option::None,
                denshokan_address,
            );

        self.vrf_address.write(vrf_address);
    }

    #[abi(embed_v0)]
    impl GameTokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: u64) -> u32 {
            let world: WorldStorage = self.world(@DEFAULT_NS());
            let session: GameSession = world.read_model(token_id);
            session.discovered_count.into()
        }

        fn game_over(self: @ContractState, token_id: u64) -> bool {
            let world: WorldStorage = self.world(@DEFAULT_NS());
            let session: GameSession = world.read_model(token_id);
            session.game_over
        }
    }

    #[abi(embed_v0)]
    impl GameSystemImpl of IGameSystem<ContractState> {
        fn create(ref self: ContractState, game_id: u64) {
            let mut world: WorldStorage = self.world(@DEFAULT_NS());
            let token_address = self.token_address();

            pre_action(token_address, game_id);

            let token_dispatcher = IMinigameTokenDispatcher {
                contract_address: token_address,
            };
            let token_metadata = token_dispatcher.token_metadata(game_id);
            assert!(
                token_metadata.lifecycle.is_playable(get_block_timestamp()), "Game not playable",
            );
            assert_token_ownership(token_address, game_id);

            // Generate seed
            let vrf_addr = self.vrf_address.read();
            let random = if vrf_addr.is_zero() {
                RandomImpl::new_pseudo_random()
            } else {
                RandomImpl::from_vrf_address(vrf_addr, game_id.into())
            };
            let seed = random.seed;

            let player = get_caller_address();
            let timestamp = get_block_timestamp();

            let session = GameSession {
                game_id,
                player,
                seed,
                settings_id: 0,
                discovered_count: 0,
                craft_attempts: 0,
                hints_used: 0,
                gold: 0,
                hero_count: 1,
                potion_count: 0,
                game_over: false,
                started_at: timestamp,
            };
            world.write_model(@session);
            world.write_model(@GameSeed { game_id, seed });

            recipes::generate_recipes(ref world, game_id, seed);

            let hero = Hero {
                game_id,
                hero_id: 0,
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

            // Initialize or update player meta
            let mut player_meta: PlayerMeta = world.read_model(player);
            if player_meta.total_games == 0 && player_meta.best_time == 0 {
                player_meta =
                    PlayerMeta {
                        player, total_games: 1, best_time: 0, total_recipes_discovered: 0,
                    };
            } else {
                player_meta.total_games += 1;
            }
            world.write_model(@player_meta);

            world.emit_event(@GameCreated { game_id, player, settings_id: 0, seed });

            post_action(token_address, game_id);
        }

        fn surrender(ref self: ContractState, game_id: u64) {
            let mut world: WorldStorage = self.world(@DEFAULT_NS());
            let token_address = self.token_address();

            pre_action(token_address, game_id);

            let token_dispatcher = IMinigameTokenDispatcher {
                contract_address: token_address,
            };
            let token_metadata = token_dispatcher.token_metadata(game_id);
            assert!(
                token_metadata.lifecycle.is_playable(get_block_timestamp()), "Game not playable",
            );
            assert_token_ownership(token_address, game_id);

            let mut session: GameSession = world.read_model(game_id);
            assert!(!session.game_over, "Game already over");

            session.game_over = true;
            world.write_model(@session);

            post_action(token_address, game_id);
        }
    }
}
