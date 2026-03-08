#[inline]
pub fn NAME() -> ByteArray {
    "Play"
}

#[starknet::interface]
pub trait IPlay<T> {
    fn create(ref self: T, game_id: felt252);
    fn clue(ref self: T, game_id: felt252);
    fn craft(ref self: T, game_id: felt252, ingredient_a: u8, ingredient_b: u8, quantity: u16);
    fn recruit(ref self: T, game_id: felt252);
    fn buff(ref self: T, game_id: felt252, character_id: u8, effect: u8, quantity: u16);
    fn explore(ref self: T, game_id: felt252, character_id: u8, zone_id: u8);
    fn claim(ref self: T, game_id: felt252, character_id: u8);
    fn surrender(ref self: T, game_id: felt252);
}

#[dojo::contract]
pub mod Play {
    use dojo::world::{WorldStorage, WorldStorageTrait};
    use game_components_embeddable_game_standard::minigame::interface::IMinigameTokenData;
    use game_components_embeddable_game_standard::minigame::minigame_component::MinigameComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::components::playable::PlayableComponent;
    use crate::constants::NAMESPACE;
    use crate::helpers::random::{RandomImpl, RandomTrait};
    use crate::metadata::image::IMAGE;
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
        denshokan_address: ContractAddress,
        renderer_address: Option<ContractAddress>,
        vrf_address: ContractAddress,
    ) {
        let mut world: WorldStorage = self.world(@NAMESPACE());
        let creator_address = starknet::get_tx_info().unbox().account_contract_address;
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
                image: IMAGE(),
                color: Option::None,
                client_url: Option::Some("https://athanor-psi.vercel.app/"),
                renderer_address: Option::None,
                settings_address: Option::Some(config_address),
                objectives_address: Option::None,
                token_address: denshokan_address,
                royalty_fraction: Option::None,
                skills_address: Option::None,
                version: 1,
            );

        // Write centralized Config — all systems read from this
        let mut store = StoreImpl::new(world);
        store.set_config(@Config { key: 0, token_address: denshokan_address, vrf_address });
    }

    #[abi(embed_v0)]
    impl TokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: felt252) -> u64 {
            let store = StoreImpl::new(self.world(@NAMESPACE()));
            let game = store.game(token_id);
            game.score().into()
        }

        fn game_over(self: @ContractState, token_id: felt252) -> bool {
            let store = StoreImpl::new(self.world(@NAMESPACE()));
            let game = store.game(token_id);
            game.is_over()
        }

        fn score_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<u64> {
            let mut results = array![];
            let mut i = 0;
            while i < token_ids.len() {
                results.append(self.score(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn game_over_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<bool> {
            let mut results = array![];
            let mut i = 0;
            while i < token_ids.len() {
                results.append(self.game_over(*token_ids.at(i)));
                i += 1;
            }
            results
        }
    }

    #[abi(embed_v0)]
    impl GameSystemImpl of IPlay<ContractState> {
        fn create(ref self: ContractState, game_id: felt252) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Compute] Seed
            let store = StoreTrait::new(world);
            let vrf_addr = store.vrf_address();
            let random = RandomTrait::new(vrf_addr, game_id);
            // [Effect] Create game
            self.before(world, game_id);
            self.playable.create(world, game_id, random.seed);
            self.after(world, game_id);
        }

        fn clue(ref self: ContractState, game_id: felt252) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Compute] Seed
            let store = StoreTrait::new(world);
            let vrf_addr = store.vrf_address();
            let random = RandomTrait::new(vrf_addr, game_id);
            // [Effect] Glean
            self.before(world, game_id);
            self.playable.clue(world, game_id, random.seed);
            self.after(world, game_id);
        }

        fn craft(
            ref self: ContractState,
            game_id: felt252,
            ingredient_a: u8,
            ingredient_b: u8,
            quantity: u16,
        ) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Compute] Seed
            let store = StoreTrait::new(world);
            let vrf_addr = store.vrf_address();
            let random = RandomTrait::new(vrf_addr, game_id);
            // [Effect] Craft
            self.before(world, game_id);
            self
                .playable
                .craft(
                    world, game_id, ingredient_a.into(), ingredient_b.into(), quantity, random.seed,
                );
            self.after(world, game_id);
        }

        fn recruit(ref self: ContractState, game_id: felt252) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Compute] Seed
            let store = StoreTrait::new(world);
            let vrf_addr = store.vrf_address();
            let random = RandomTrait::new(vrf_addr, game_id);
            // [Effect] Recruit
            self.before(world, game_id);
            self.playable.recruit(world, game_id, random.seed);
            self.after(world, game_id);
        }

        fn buff(
            ref self: ContractState, game_id: felt252, character_id: u8, effect: u8, quantity: u16,
        ) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Effect] Buff
            self.before(world, game_id);
            self.playable.buff(world, game_id, character_id, effect.into(), quantity);
            self.after(world, game_id);
        }

        fn explore(ref self: ContractState, game_id: felt252, character_id: u8, zone_id: u8) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Compute] Seed
            let store = StoreTrait::new(world);
            let vrf_addr = store.vrf_address();
            let random = RandomTrait::new(vrf_addr, game_id);
            // [Effect] Explore
            self.before(world, game_id);
            self.playable.explore(world, game_id, character_id, zone_id, random.seed);
            self.after(world, game_id);
        }

        fn claim(ref self: ContractState, game_id: felt252, character_id: u8) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Effect] Claim
            self.before(world, game_id);
            self.playable.claim(world, game_id, character_id);
            self.after(world, game_id);
        }

        fn surrender(ref self: ContractState, game_id: felt252) {
            // [Setup] World
            let world = self.world(@NAMESPACE());
            // [Effect] Surrender
            self.before(world, game_id);
            self.playable.surrender(world, game_id);
            self.after(world, game_id);
        }
    }

    #[generate_trait]
    pub impl PrivateImpl of PrivateTrait {
        fn before(ref self: ContractState, world: WorldStorage, game_id: felt252) {
            // [Check] Game is not over, otherwise return silently
            let mut store = StoreTrait::new(world);
            let game = store.game(game_id);
            if game.is_over() {
                return;
            }
            // [Check] Game is playable
            self.minigame.pre_action(game_id);
            self.minigame.assert_token_ownership(game_id);
        }

        fn after(ref self: ContractState, world: WorldStorage, game_id: felt252) {
            // [Effect] Post actions
            self.minigame.post_action(game_id);
        }
    }
}
