#[inline]
pub fn NAME() -> ByteArray {
    "Play"
}

#[starknet::interface]
pub trait IPlay<T> {
    fn create(ref self: T, game_id: u64);
    fn glean(ref self: T, game_id: u64);
    fn craft(ref self: T, game_id: u64, ingredient_a: u8, ingredient_b: u8, quantity: u16);
    fn surrender(ref self: T, game_id: u64);
}

#[dojo::contract]
pub mod Play {
    use athanor::constants::DEFAULT_NS;
    use athanor::helpers::random::RandomImpl;
    use athanor::helpers::recipes;
    use athanor::models::config::Config;
    use athanor::models::game::{GameSeed, GameSessionAssertTrait, GameSessionTrait};
    use athanor::models::hero::HeroTrait;
    use athanor::models::player::PlayerMeta;
    use athanor::store::{StoreImpl, StoreTrait};
    use core::num::traits::Zero;
    use dojo::world::{WorldStorage, WorldStorageTrait};
    use game_components_minigame::interface::IMinigameTokenData;
    use game_components_minigame::libs::{assert_token_ownership, post_action, pre_action};
    use game_components_token::core::interface::{
        IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
    };
    use game_components_token::libs::LifecycleTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use crate::components::playable::PlayableComponent;
    use crate::constants::NAMESPACE;
    use crate::helpers::random::RandomTrait;
    use super::*;

    // Components

    component!(path: MinigameComponent, storage: minigame, event: MinigameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: PlayableComponent, storage: playable, event: PlayableEvent);

    #[abi(embed_v0)]
    impl MinigameImpl = MinigameComponent::MinigameImpl<ContractState>;
    impl MinigameInternalImpl = MinigameComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    use game_components_minigame::minigame::MinigameComponent;
    impl PlayableInternalImpl = PlayableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        minigame: MinigameComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        playable: PlayableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MinigameEvent: MinigameComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        PlayableEvent: PlayableComponent::Event,
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
                if renderer.is_zero() {
                    Option::None
                } else {
                    Option::Some(renderer)
                },
                if config_address.is_zero() {
                    Option::None
                } else {
                    Option::Some(config_address)
                },
                Option::None,
                denshokan_address,
            );

        // Write centralized Config — all systems read from this
        let mut store = StoreImpl::new(world);
        store.set_config(@Config { key: 0, token_address: denshokan_address, vrf_address });
    }

    #[abi(embed_v0)]
    impl GameTokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: u64) -> u32 {
            let store = StoreImpl::new(self.world(@DEFAULT_NS()));
            let session = store.session(token_id);
            session.discovered_count.into()
        }

        fn game_over(self: @ContractState, token_id: u64) -> bool {
            let store = StoreImpl::new(self.world(@DEFAULT_NS()));
            let session = store.session(token_id);
            session.game_over
        }
    }

    #[abi(embed_v0)]
    impl GameSystemImpl of IPlay<ContractState> {
        fn create(ref self: ContractState, game_id: u64) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Compute] Seed
            let store = StoreTrait::new(world);
            let vrf_addr = store.vrf_address();
            let random = if vrf_addr.is_zero() {
                RandomTrait::new_pseudo_random()
            } else {
                RandomTrait::from_vrf_address(vrf_addr, game_id.into())
            };
            // [Effect] Create game
            self.before(world, game_id);
            self.playable.create(world, game_id, random.seed);

            // --- [LEGACY] ---

            // Create session + seed
            let player = get_caller_address();
            let timestamp = get_block_timestamp();
            let seed = random.seed;
            let session = GameSessionTrait::new(game_id, player, seed, timestamp);
            store.set_session(@session);
            let mut store = StoreTrait::new(world);
            store.set_game_seed(@GameSeed { game_id, seed });

            // Generate 10 recipes
            recipes::generate_recipes(ref store.world, game_id, seed);

            // Spawn hero #0
            let hero = HeroTrait::new(game_id, 0);
            store.set_hero(@hero);

            // Initialize or update player meta
            let mut player_meta = store.player(player);
            if player_meta.total_games == 0 && player_meta.best_time == 0 {
                player_meta =
                    PlayerMeta {
                        player, total_games: 1, best_time: 0, total_recipes_discovered: 0,
                    };
            } else {
                player_meta.total_games += 1;
            }
            store.set_player(@player_meta);

            store.emit_game_created(game_id, player, 0, seed);

            self.after(world, game_id);
        }

        fn glean(ref self: ContractState, game_id: u64) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Effect] Glean
            self.before(world, game_id);
            self.playable.glean(world, game_id);
            self.after(world, game_id);
        }

        fn craft(
            ref self: ContractState,
            game_id: u64,
            ingredient_a: u8,
            ingredient_b: u8,
            quantity: u16,
        ) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Effect] Craft
            self.before(world, game_id);
            self.playable.craft(world, game_id, ingredient_a.into(), ingredient_b.into(), quantity);
            self.after(world, game_id);
        }

        fn surrender(ref self: ContractState, game_id: u64) {
            let mut store = StoreImpl::new(self.world(@DEFAULT_NS()));
            let token_address = self.token_address();

            pre_action(token_address, game_id);

            let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
            let token_metadata = token_dispatcher.token_metadata(game_id);
            assert!(
                token_metadata.lifecycle.is_playable(get_block_timestamp()), "Game not playable",
            );
            assert_token_ownership(token_address, game_id);

            let mut session = store.session(game_id);
            session.assert_not_over();

            session.game_over = true;
            store.set_session(@session);

            post_action(token_address, game_id);
        }
    }

    #[generate_trait]
    pub impl PrivateImpl of PrivateTrait {
        fn before(ref self: ContractState, world: WorldStorage, game_id: u64) {
            // [Check] Game is playable
            let mut store = StoreTrait::new(world);
            let token_address = store.token_address();
            pre_action(token_address, game_id);
            let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
            let now = get_block_timestamp();
            assert!(
                token_dispatcher.token_metadata(game_id).lifecycle.is_playable(now),
                "Game not playable",
            );
            assert_token_ownership(token_address, game_id);
        }

        fn after(ref self: ContractState, world: WorldStorage, game_id: u64) {
            // [Effect] Post actions
            let store = StoreTrait::new(world);
            let token_address = store.token_address();
            post_action(token_address, game_id);
        }
    }
}
