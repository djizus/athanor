#[inline]
pub fn NAME() -> ByteArray {
    "Play"
}

#[starknet::interface]
pub trait IPlay<T> {
    fn create(ref self: T, game_id: u64);
    fn clue(ref self: T, game_id: u64);
    fn craft(ref self: T, game_id: u64, ingredient_a: u8, ingredient_b: u8, quantity: u16);
    fn recruit(ref self: T, game_id: u64);
    fn buff(ref self: T, game_id: u64, character_id: u8, effect: u8, quantity: u16);
    fn explore(ref self: T, game_id: u64, character_id: u8);
    fn claim(ref self: T, game_id: u64, character_id: u8);
}

#[dojo::contract]
pub mod Play {
    use dojo::world::{WorldStorage, WorldStorageTrait};
    use game_components_minigame::interface::IMinigameTokenData;
    use game_components_minigame::libs::{assert_token_ownership, post_action, pre_action};
    use game_components_minigame::minigame::MinigameComponent;
    use game_components_token::core::interface::{
        IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
    };
    use game_components_token::libs::LifecycleTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{ContractAddress, get_block_timestamp};
    use crate::components::playable::PlayableComponent;
    use crate::constants::NAMESPACE;
    use crate::helpers::random::{RandomImpl, RandomTrait};
    use crate::models::config::Config;
    use crate::models::game::GameTrait;
    use crate::store::{StoreImpl, StoreTrait};
    use crate::systems::setup::NAME as SETUP;
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
        let mut world: WorldStorage = self.world(@NAMESPACE());
        let (config_address, _) = world.dns(@SETUP()).expect('Play: setup not found');
        self
            .minigame
            .initializer(
                creator_address: creator_address,
                name: "Athanor",
                description: "On-chain competitive grimoire race",
                developer: "djizus",
                publisher: "djizus",
                genre: "Strategy",
                image: "",
                color: Option::None,
                client_url: Option::None,
                renderer_address: Option::None,
                settings_address: Option::Some(config_address),
                objectives_address: Option::None,
                token_address: denshokan_address,
            );

        // Write centralized Config — all systems read from this
        let mut store = StoreImpl::new(world);
        store.set_config(@Config { key: 0, token_address: denshokan_address, vrf_address });
    }

    #[abi(embed_v0)]
    impl GameTokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: u64) -> u32 {
            let store = StoreImpl::new(self.world(@NAMESPACE()));
            let game = store.game(token_id);
            game.score()
        }

        fn game_over(self: @ContractState, token_id: u64) -> bool {
            let store = StoreImpl::new(self.world(@NAMESPACE()));
            let game = store.game(token_id);
            game.is_over()
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
            let random = RandomTrait::new(vrf_addr, game_id.into());
            // [Effect] Create game
            self.before(world, game_id);
            self.playable.create(world, game_id, random.seed);
            self.after(world, game_id);
        }

        fn clue(ref self: ContractState, game_id: u64) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Compute] Seed
            let store = StoreTrait::new(world);
            let vrf_addr = store.vrf_address();
            let random = RandomTrait::new(vrf_addr, game_id.into());
            // [Effect] Glean
            self.before(world, game_id);
            self.playable.clue(world, game_id, random.seed);
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
            // [Compute] Seed
            let store = StoreTrait::new(world);
            let vrf_addr = store.vrf_address();
            let random = RandomTrait::new(vrf_addr, game_id.into());
            // [Effect] Craft
            self.before(world, game_id);
            self
                .playable
                .craft(
                    world, game_id, ingredient_a.into(), ingredient_b.into(), quantity, random.seed,
                );
            self.after(world, game_id);
        }

        fn recruit(ref self: ContractState, game_id: u64) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Compute] Seed
            let store = StoreTrait::new(world);
            let vrf_addr = store.vrf_address();
            let random = RandomTrait::new(vrf_addr, game_id.into());
            // [Effect] Recruit
            self.before(world, game_id);
            self.playable.recruit(world, game_id, random.seed);
            self.after(world, game_id);
        }

        fn buff(
            ref self: ContractState, game_id: u64, character_id: u8, effect: u8, quantity: u16,
        ) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Effect] Buff
            self.before(world, game_id);
            self.playable.buff(world, game_id, character_id, effect.into(), quantity);
            self.after(world, game_id);
        }

        fn explore(ref self: ContractState, game_id: u64, character_id: u8) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Compute] Seed
            let store = StoreTrait::new(world);
            let vrf_addr = store.vrf_address();
            let random = RandomTrait::new(vrf_addr, game_id.into());
            // [Effect] Explore
            self.before(world, game_id);
            self.playable.explore(world, game_id, character_id, random.seed);
            self.after(world, game_id);
        }

        fn claim(ref self: ContractState, game_id: u64, character_id: u8) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Effect] Claim
            self.before(world, game_id);
            self.playable.claim(world, game_id, character_id);
            self.after(world, game_id);
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
