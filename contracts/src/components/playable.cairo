#[starknet::component]
pub mod PlayableComponent {
    // Imports

    use dojo::world::WorldStorage;
    use crate::models::discovery::DiscoveryTrait;
    use crate::models::game::{GameAssert, GameTrait};
    use crate::models::hint::HintTrait;
    use crate::store::StoreTrait;
    use crate::typess::ingredient::Ingredient;

    // Storage

    #[storage]
    pub struct Storage {}

    // Events

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initialize(ref self: ComponentState<TContractState>, world: WorldStorage) {}

        fn create(
            ref self: ComponentState<TContractState>,
            world: WorldStorage,
            game_id: u64,
            seed: felt252,
        ) {
            // [Setup] Store
            let mut store = StoreTrait::new(world);
            // [Check] Game does not exist
            let game = store.game(game_id);
            game.assert_not_exist();
            // [Effect] Create Game
            let game = GameTrait::new(game_id, seed);
            store.set_game(@game);
        }

        fn glean(ref self: ComponentState<TContractState>, world: WorldStorage, game_id: u64) {
            // [Setup] Store
            let mut store = StoreTrait::new(world);
            // [Check] Game exists
            let mut game = store.game(game_id);
            game.assert_does_exist();
            game.assert_not_over();
            // [Effect] Add Hint
            let (effect, ingredient) = game.glean(game.seed.into());
            let mut hint = store.hint(game_id, ingredient.into());
            hint.add(effect);
            store.set_hint(@hint);
        }

        fn craft(
            ref self: ComponentState<TContractState>,
            world: WorldStorage,
            game_id: u64,
            ingredient_a: Ingredient,
            ingredient_b: Ingredient,
            quantity: u16,
        ) {
            // [Setup] Store
            let mut store = StoreTrait::new(world);
            // [Check] Game exists
            let mut game = store.game(game_id);
            game.assert_does_exist();
            game.assert_not_over();
            // [Check] Discovery
            let mut discovery = store.discovery(game_id, ingredient_a.into(), ingredient_b.into());
            if !discovery.discovered {
                // [Effect] Discover
                let hint_a = store.hint(game_id, ingredient_a.into());
                let hint_b = store.hint(game_id, ingredient_b.into());
                let effect = game
                    .discover(
                        ingredient_a,
                        ingredient_b,
                        hint_a.recipes,
                        hint_b.recipes,
                        game.seed.into(),
                    );
                // [Effect] Update discovery
                discovery.discover(effect);
                store.set_discovery(@discovery);
            }
            // [Effect] Craft
            game.craft(ingredient_a, ingredient_b, quantity);
            game.add_effect(discovery.effect.into(), quantity);
            // [Effect] Update game
            game.assess();
            store.set_game(@game);
        }
    }
}
