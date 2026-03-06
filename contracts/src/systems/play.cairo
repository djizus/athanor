#[inline]
pub fn NAME() -> ByteArray {
    "Play"
}

#[starknet::interface]
pub trait IPlay<T> {
    fn create(ref self: T, game_id: u64);
    fn glean(ref self: T, game_id: u64);
    fn craft(ref self: T, game_id: u64, ingredient_a: u8, ingredient_b: u8, quantity: u16);
}

#[dojo::contract]
pub mod Play {
    use core::num::traits::Zero;
    use dojo::world::WorldStorage;
    use game_components_minigame::libs::{assert_token_ownership, post_action, pre_action};
    use game_components_token::core::interface::{
        IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
    };
    use game_components_token::libs::LifecycleTrait;
    use starknet::get_block_timestamp;
    use crate::components::playable::PlayableComponent;
    use crate::constants::NAMESPACE;
    use crate::helpers::random::RandomTrait;
    use crate::store::StoreTrait;
    use super::*;

    // Components

    component!(path: PlayableComponent, storage: playable, event: PlayableEvent);
    impl PlayableInternalImpl = PlayableComponent::InternalImpl<ContractState>;

    // Storage

    #[storage]
    struct Storage {
        #[substorage(v0)]
        playable: PlayableComponent::Storage,
    }

    // Events

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        PlayableEvent: PlayableComponent::Event,
    }

    #[abi(embed_v0)]
    impl PlayImpl of IPlay<ContractState> {
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

