use dojo::event::EventStorage;
use dojo::model::ModelStorage;
use dojo::world::WorldStorage;
use game_components_token::core::interface::IMinigameTokenDispatcher;
use starknet::ContractAddress;
use crate::events::crafting::RecipeDiscoveredTrait;

// Event constructors
use crate::events::exploration::{ExpeditionStartedTrait, ExplorationEventTrait};
use crate::events::game::{GameCreatedTrait, GrimoireCompletedTrait};
use crate::events::hero::{HeroRecruitedTrait, PotionAppliedTrait};
use crate::events::loot::LootClaimedTrait;
use crate::interfaces::vrf::IVrfProviderDispatcher;
use crate::models::config::{Config, GameSettings, GameSettingsMetadata};
use crate::models::crafting::FailedCombo;
use crate::models::discovery::Discovery;
use crate::models::game::{GameSeed, GameSession};
use crate::models::hero::{Hero, HeroPendingIngredient};
use crate::models::hint::Hint;
use crate::models::index::Game;
use crate::models::inventory::{IngredientBalance, PotionItem};
use crate::models::player::PlayerMeta;
use crate::models::recipe::Recipe;

// ---------------------------------------------------------------------------
// Store — typed facade over WorldStorage
// ---------------------------------------------------------------------------

#[derive(Copy, Drop)]
pub struct Store {
    pub world: WorldStorage,
}

#[generate_trait]
pub impl StoreImpl of StoreTrait {
    #[inline]
    fn new(world: WorldStorage) -> Store {
        Store { world }
    }

    // -----------------------------------------------------------------------
    // Config (singleton, key = 0)
    // -----------------------------------------------------------------------

    fn config(self: @Store) -> Config {
        self.world.read_model(0)
    }

    fn set_config(mut self: Store, config: @Config) {
        self.world.write_model(config);
    }

    // -----------------------------------------------------------------------
    // Dispatchers (built from Config addresses)
    // -----------------------------------------------------------------------

    fn token_address(self: @Store) -> ContractAddress {
        self.config().token_address
    }

    fn token_disp(self: @Store) -> IMinigameTokenDispatcher {
        IMinigameTokenDispatcher { contract_address: self.config().token_address }
    }

    fn vrf_disp(self: @Store) -> IVrfProviderDispatcher {
        IVrfProviderDispatcher { contract_address: self.config().vrf_address }
    }

    fn vrf_address(self: @Store) -> ContractAddress {
        self.config().vrf_address
    }

    fn game(self: @Store, game_id: u64) -> Game {
        self.world.read_model(game_id)
    }

    fn set_game(mut self: Store, model: @Game) {
        self.world.write_model(model);
    }

    fn hint(self: @Store, game_id: u64, ingredient: u8) -> Hint {
        self.world.read_model((game_id, ingredient))
    }

    fn set_hint(mut self: Store, model: @Hint) {
        self.world.write_model(model);
    }

    fn discovery(self: @Store, game_id: u64, ingredient_a: u8, ingredient_b: u8) -> Discovery {
        self.world.read_model((game_id, ingredient_a, ingredient_b))
    }

    fn set_discovery(mut self: Store, model: @Discovery) {
        self.world.write_model(model);
    }

    // -----------------------------------------------------------------------
    // GameSession
    // -----------------------------------------------------------------------

    fn session(self: @Store, game_id: u64) -> GameSession {
        self.world.read_model(game_id)
    }

    fn set_session(mut self: Store, model: @GameSession) {
        self.world.write_model(model);
    }

    // -----------------------------------------------------------------------
    // GameSeed
    // -----------------------------------------------------------------------

    fn game_seed(self: @Store, game_id: u64) -> GameSeed {
        self.world.read_model(game_id)
    }

    fn set_game_seed(mut self: Store, model: @GameSeed) {
        self.world.write_model(model);
    }

    // -----------------------------------------------------------------------
    // Hero
    // -----------------------------------------------------------------------

    fn hero(self: @Store, game_id: u64, hero_id: u8) -> Hero {
        self.world.read_model((game_id, hero_id))
    }

    fn set_hero(mut self: Store, model: @Hero) {
        self.world.write_model(model);
    }

    // -----------------------------------------------------------------------
    // HeroPendingIngredient
    // -----------------------------------------------------------------------

    fn pending_ingredient(
        self: @Store, game_id: u64, hero_id: u8, ingredient_id: u8,
    ) -> HeroPendingIngredient {
        self.world.read_model((game_id, hero_id, ingredient_id))
    }

    fn set_pending_ingredient(mut self: Store, model: @HeroPendingIngredient) {
        self.world.write_model(model);
    }

    // -----------------------------------------------------------------------
    // Recipe
    // -----------------------------------------------------------------------

    fn recipe(self: @Store, game_id: u64, recipe_id: u8) -> Recipe {
        self.world.read_model((game_id, recipe_id))
    }

    fn set_recipe(mut self: Store, model: @Recipe) {
        self.world.write_model(model);
    }

    // -----------------------------------------------------------------------
    // IngredientBalance
    // -----------------------------------------------------------------------

    fn ingredient(self: @Store, game_id: u64, ingredient_id: u8) -> IngredientBalance {
        self.world.read_model((game_id, ingredient_id))
    }

    fn set_ingredient(mut self: Store, model: @IngredientBalance) {
        self.world.write_model(model);
    }

    // -----------------------------------------------------------------------
    // PotionItem
    // -----------------------------------------------------------------------

    fn potion(self: @Store, game_id: u64, potion_index: u16) -> PotionItem {
        self.world.read_model((game_id, potion_index))
    }

    fn set_potion(mut self: Store, model: @PotionItem) {
        self.world.write_model(model);
    }

    // -----------------------------------------------------------------------
    // FailedCombo
    // -----------------------------------------------------------------------

    fn failed_combo(self: @Store, game_id: u64, combo_key: u16) -> FailedCombo {
        self.world.read_model((game_id, combo_key))
    }

    fn set_failed_combo(mut self: Store, model: @FailedCombo) {
        self.world.write_model(model);
    }

    // -----------------------------------------------------------------------
    // PlayerMeta
    // -----------------------------------------------------------------------

    fn player(self: @Store, addr: ContractAddress) -> PlayerMeta {
        self.world.read_model(addr)
    }

    fn set_player(mut self: Store, model: @PlayerMeta) {
        self.world.write_model(model);
    }

    // -----------------------------------------------------------------------
    // GameSettings
    // -----------------------------------------------------------------------

    fn settings(self: @Store, settings_id: u32) -> GameSettings {
        self.world.read_model(settings_id)
    }

    fn set_settings(mut self: Store, model: @GameSettings) {
        self.world.write_model(model);
    }

    fn settings_meta(self: @Store, settings_id: u32) -> GameSettingsMetadata {
        self.world.read_model(settings_id)
    }

    fn set_settings_meta(mut self: Store, model: @GameSettingsMetadata) {
        self.world.write_model(model);
    }

    // -----------------------------------------------------------------------
    // Event emitters
    // -----------------------------------------------------------------------

    fn emit_game_created(
        mut self: Store, game_id: u64, player: ContractAddress, settings_id: u32, seed: felt252,
    ) {
        self.world.emit_event(@GameCreatedTrait::new(game_id, player, settings_id, seed));
    }

    fn emit_exploration_event(
        mut self: Store,
        game_id: u64,
        event_index: u16,
        hero_id: u8,
        depth: u16,
        zone_id: u8,
        event_kind: u8,
        value: u16,
        hp_after: u16,
    ) {
        self
            .world
            .emit_event(
                @ExplorationEventTrait::new(
                    game_id, event_index, hero_id, depth, zone_id, event_kind, value, hp_after,
                ),
            );
    }

    fn emit_expedition_started(
        mut self: Store, game_id: u64, hero_id: u8, death_depth: u16, return_at: u64,
    ) {
        self
            .world
            .emit_event(@ExpeditionStartedTrait::new(game_id, hero_id, death_depth, return_at));
    }

    fn emit_loot_claimed(mut self: Store, game_id: u64, hero_id: u8, gold: u32) {
        self.world.emit_event(@LootClaimedTrait::new(game_id, hero_id, gold));
    }

    fn emit_recipe_discovered(
        mut self: Store,
        game_id: u64,
        recipe_id: u8,
        ingredient_a: u8,
        ingredient_b: u8,
        effect_type: u8,
        discovered_count: u8,
    ) {
        self
            .world
            .emit_event(
                @RecipeDiscoveredTrait::new(
                    game_id, recipe_id, ingredient_a, ingredient_b, effect_type, discovered_count,
                ),
            );
    }

    fn emit_potion_applied(
        mut self: Store,
        game_id: u64,
        hero_id: u8,
        potion_index: u16,
        effect_type: u8,
        effect_value: u8,
    ) {
        self
            .world
            .emit_event(
                @PotionAppliedTrait::new(game_id, hero_id, potion_index, effect_type, effect_value),
            );
    }

    fn emit_hero_recruited(mut self: Store, game_id: u64, hero_id: u8, cost: u32) {
        self.world.emit_event(@HeroRecruitedTrait::new(game_id, hero_id, cost));
    }

    fn emit_grimoire_completed(
        mut self: Store, game_id: u64, player: ContractAddress, completion_time: u64,
    ) {
        self.world.emit_event(@GrimoireCompletedTrait::new(game_id, player, completion_time));
    }
}
