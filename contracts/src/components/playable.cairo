#[starknet::component]
pub mod PlayableComponent {
    // Imports

    use dojo::world::WorldStorage;
    use crate::models::character::{CharacterAssert, CharacterTrait};
    use crate::models::discovery::DiscoveryTrait;
    use crate::models::game::{GameAssert, GameTrait};
    use crate::models::hint::HintTrait;
    use crate::store::StoreTrait;
    use crate::typess::effect::Effect;
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
            game.assert_not_started();
            // [Effect] Create Game
            let mut game = GameTrait::new(game_id, seed);
            game.start();
            store.set_game(@game);
        }

        fn clue(
            ref self: ComponentState<TContractState>,
            world: WorldStorage,
            game_id: u64,
            seed: felt252,
        ) {
            // [Setup] Store
            let mut store = StoreTrait::new(world);
            // [Check] Game exists
            let mut game = store.game(game_id);
            game.assert_is_started();
            game.assert_not_over();
            // [Effect] Add Hint
            let (effect, ingredient) = game.clue(seed.into());
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
            seed: felt252,
        ) {
            // [Setup] Store
            let mut store = StoreTrait::new(world);
            // [Check] Game exists
            let mut game = store.game(game_id);
            game.assert_is_started();
            game.assert_not_over();
            // [Check] Discovery
            let mut discovery = store.discovery(game_id, ingredient_a.into(), ingredient_b.into());
            if !discovery.discovered {
                // [Effect] Discover
                let hint_a = store.hint(game_id, ingredient_a.into());
                let hint_b = store.hint(game_id, ingredient_b.into());
                let effect = game
                    .discover(
                        ingredient_a, ingredient_b, hint_a.recipes, hint_b.recipes, seed.into(),
                    );
                // [Effect] Update discovery
                discovery.discover(effect);
                store.set_discovery(@discovery);
            }
            // [Effect] Craft
            game.craft(ingredient_a, ingredient_b, quantity);
            game.store(discovery.effect.into(), quantity);
            // [Effect] Update game
            game.assess();
            store.set_game(@game);
        }

        fn recruit(
            ref self: ComponentState<TContractState>,
            world: WorldStorage,
            game_id: u64,
            seed: felt252,
        ) {
            // [Setup] Store
            let mut store = StoreTrait::new(world);
            // [Check] Game exists
            let mut game = store.game(game_id);
            game.assert_is_started();
            game.assert_not_over();
            // [Effect] Recruit hero
            let (character_id, role) = game.recruit(seed.into());
            let character = CharacterTrait::new(game_id, character_id, role);
            store.set_character(@character);
            store.set_game(@game);
        }

        fn buff(
            ref self: ComponentState<TContractState>,
            world: WorldStorage,
            game_id: u64,
            character_id: u8,
            effect: Effect,
            quantity: u16,
        ) {
            // [Setup] Store
            let mut store = StoreTrait::new(world);
            // [Check] Game exists
            let mut game = store.game(game_id);
            game.assert_is_started();
            game.assert_not_over();
            // [Check] Character exists
            let mut character = store.character(game_id, character_id);
            character.assert_has_spawned();
            // [Effect] Use effect
            game.consume(effect, quantity);
            // [Effect] Buff character
            character.buff(effect, quantity);
            store.set_character(@character);
            store.set_game(@game);
        }

        fn explore(
            ref self: ComponentState<TContractState>,
            world: WorldStorage,
            game_id: u64,
            character_id: u8,
            seed: felt252,
        ) {
            // [Setup] Store
            let mut store = StoreTrait::new(world);
            // [Check] Game exists
            let mut game = store.game(game_id);
            game.assert_is_started();
            game.assert_not_over();
            // [Check] Character exists
            let mut character = store.character(game_id, character_id);
            character.assert_has_spawned();
            // [Effect] Explore
            let mut logs = character.explore(seed);
            store.set_character(@character);
            // [Event] Emit logs
            let mut index: u16 = 0;
            while let Some(log) = logs.pop_front() {
                store
                    .emit_exploration_event(
                        game_id: game_id,
                        event_index: index,
                        hero_id: character_id,
                        depth: log.depth,
                        zone_id: log.zone_id,
                        event_kind: log.event_kind,
                        value: log.value,
                        hp_after: log.hp_after,
                    );
                index += 1;
            }
        }

        fn claim(
            ref self: ComponentState<TContractState>,
            world: WorldStorage,
            game_id: u64,
            character_id: u8,
        ) {
            // [Setup] Store
            let mut store = StoreTrait::new(world);
            // [Check] Game exists
            let mut game = store.game(game_id);
            game.assert_is_started();
            game.assert_not_over();
            // [Check] Character exists
            let mut character = store.character(game_id, character_id);
            character.assert_has_spawned();
            // [Effect] Claim loot
            let (ingredients, gold) = character.claim();
            store.set_character(@character);
            // [Effect] Update game
            game.earn(gold);
            game.merge(ingredients.into());
            store.set_game(@game);
        }
    }
}
