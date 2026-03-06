import type { SchemaType as ISchemaType } from "@dojoengine/sdk";

import { CairoOption, CairoOptionVariant, BigNumberish } from 'starknet';

// Type definition for `athanor::models::config::Config` struct
export interface Config {
	key: BigNumberish;
	token_address: string;
	vrf_address: string;
}

// Type definition for `athanor::models::config::GameSettings` struct
export interface GameSettings {
	settings_id: BigNumberish;
	zone_count: BigNumberish;
	ingredients_per_zone: BigNumberish;
	recipes_to_discover: BigNumberish;
	max_heroes: BigNumberish;
	hero_base_hp: BigNumberish;
	hero_base_power: BigNumberish;
	hero_base_regen: BigNumberish;
	hint_base_cost: BigNumberish;
	hint_cost_multiplier: BigNumberish;
	soup_gold_value: BigNumberish;
	progressive_cap: BigNumberish;
}

// Type definition for `athanor::models::config::GameSettingsMetadata` struct
export interface GameSettingsMetadata {
	settings_id: BigNumberish;
	name: BigNumberish;
	created_by: string;
	created_at: BigNumberish;
	is_active: boolean;
}

// Type definition for `athanor::models::game::GameSeed` struct
export interface GameSeed {
	game_id: BigNumberish;
	seed: BigNumberish;
}

// Type definition for `athanor::models::game::GameSession` struct
export interface GameSession {
	game_id: BigNumberish;
	player: string;
	seed: BigNumberish;
	settings_id: BigNumberish;
	discovered_count: BigNumberish;
	failed_combo_count: BigNumberish;
	craft_attempts: BigNumberish;
	hints_used: BigNumberish;
	gold: BigNumberish;
	hero_count: BigNumberish;
	potion_count: BigNumberish;
	game_over: boolean;
	started_at: BigNumberish;
}

// Type definition for `athanor::models::index::Character` struct
export interface Character {
	game_id: BigNumberish;
	id: BigNumberish;
	role: BigNumberish;
	health: BigNumberish;
	max_health: BigNumberish;
	power: BigNumberish;
	regen: BigNumberish;
	gold: BigNumberish;
	available_at: BigNumberish;
	ingredients: BigNumberish;
}

// Type definition for `athanor::models::index::Discovery` struct
export interface Discovery {
	game_id: BigNumberish;
	ingredient_a: BigNumberish;
	ingredient_b: BigNumberish;
	effect: BigNumberish;
	discovered: boolean;
}

// Type definition for `athanor::models::index::Game` struct
export interface Game {
	id: BigNumberish;
	heroes: BigNumberish;
	started_at: BigNumberish;
	ended_at: BigNumberish;
	remaining_tries: BigNumberish;
	gold: BigNumberish;
	hint_price: BigNumberish;
	grimoire: BigNumberish;
	hints: BigNumberish;
	tries: BigNumberish;
	ingredients: BigNumberish;
	effects: BigNumberish;
	seed: BigNumberish;
}

// Type definition for `athanor::models::index::Hint` struct
export interface Hint {
	game_id: BigNumberish;
	ingredient: BigNumberish;
	recipes: BigNumberish;
}

// Type definition for `athanor::events::index::ExpeditionStarted` struct
export interface ExpeditionStarted {
	game_id: BigNumberish;
	hero_id: BigNumberish;
	death_depth: BigNumberish;
	return_at: BigNumberish;
}

// Type definition for `athanor::events::index::ExplorationEvent` struct
export interface ExplorationEvent {
	game_id: BigNumberish;
	event_index: BigNumberish;
	hero_id: BigNumberish;
	depth: BigNumberish;
	zone_id: BigNumberish;
	event_kind: BigNumberish;
	value: BigNumberish;
	hp_after: BigNumberish;
}

// Type definition for `athanor::events::index::GameCreated` struct
export interface GameCreated {
	game_id: BigNumberish;
	player: string;
	settings_id: BigNumberish;
	seed: BigNumberish;
}

// Type definition for `athanor::events::index::GrimoireCompleted` struct
export interface GrimoireCompleted {
	game_id: BigNumberish;
	player: string;
	completion_time: BigNumberish;
}

// Type definition for `athanor::events::index::HeroRecruited` struct
export interface HeroRecruited {
	game_id: BigNumberish;
	hero_id: BigNumberish;
	cost: BigNumberish;
}

// Type definition for `athanor::events::index::LootClaimed` struct
export interface LootClaimed {
	game_id: BigNumberish;
	hero_id: BigNumberish;
	gold: BigNumberish;
}

// Type definition for `athanor::events::index::PotionApplied` struct
export interface PotionApplied {
	game_id: BigNumberish;
	hero_id: BigNumberish;
	potion_index: BigNumberish;
	effect_type: BigNumberish;
	effect_value: BigNumberish;
}

// Type definition for `athanor::events::index::RecipeDiscovered` struct
export interface RecipeDiscovered {
	game_id: BigNumberish;
	recipe_id: BigNumberish;
	ingredient_a: BigNumberish;
	ingredient_b: BigNumberish;
	effect_type: BigNumberish;
	discovered_count: BigNumberish;
}

// Type definition for `game_components_metagame::extensions::context::structs::GameContext` struct
export interface GameContext {
	name: string;
	value: string;
}

// Type definition for `game_components_metagame::extensions::context::structs::GameContextDetails` struct
export interface GameContextDetails {
	name: string;
	description: string;
	id: CairoOption<BigNumberish>;
	context: Array<GameContext>;
}

// Type definition for `game_components_minigame::extensions::settings::structs::GameSetting` struct
export interface GameSetting {
	name: string;
	value: string;
}

// Type definition for `game_components_minigame::extensions::settings::structs::GameSettingDetails` struct
export interface GameSettingDetails {
	name: string;
	description: string;
	settings: Array<GameSetting>;
}

export interface SchemaType extends ISchemaType {
	athanor: {
		Config: Config,
		GameSettings: GameSettings,
		GameSettingsMetadata: GameSettingsMetadata,
		GameSeed: GameSeed,
		GameSession: GameSession,
		Character: Character,
		Discovery: Discovery,
		Game: Game,
		Hint: Hint,
		ExpeditionStarted: ExpeditionStarted,
		ExplorationEvent: ExplorationEvent,
		GameCreated: GameCreated,
		GrimoireCompleted: GrimoireCompleted,
		HeroRecruited: HeroRecruited,
		LootClaimed: LootClaimed,
		PotionApplied: PotionApplied,
		RecipeDiscovered: RecipeDiscovered,
		GameContext: GameContext,
		GameContextDetails: GameContextDetails,
		GameSetting: GameSetting,
		GameSettingDetails: GameSettingDetails,
	},
}
export const schema: SchemaType = {
	athanor: {
		Config: {
			key: 0,
			token_address: "",
			vrf_address: "",
		},
		GameSettings: {
			settings_id: 0,
			zone_count: 0,
			ingredients_per_zone: 0,
			recipes_to_discover: 0,
			max_heroes: 0,
			hero_base_hp: 0,
			hero_base_power: 0,
			hero_base_regen: 0,
			hint_base_cost: 0,
			hint_cost_multiplier: 0,
			soup_gold_value: 0,
			progressive_cap: 0,
		},
		GameSettingsMetadata: {
			settings_id: 0,
			name: 0,
			created_by: "",
			created_at: 0,
			is_active: false,
		},
		GameSeed: {
			game_id: 0,
			seed: 0,
		},
		GameSession: {
			game_id: 0,
			player: "",
			seed: 0,
			settings_id: 0,
			discovered_count: 0,
			failed_combo_count: 0,
			craft_attempts: 0,
			hints_used: 0,
			gold: 0,
			hero_count: 0,
			potion_count: 0,
			game_over: false,
			started_at: 0,
		},
		Character: {
			game_id: 0,
			id: 0,
			role: 0,
			health: 0,
			max_health: 0,
			power: 0,
			regen: 0,
			gold: 0,
			available_at: 0,
			ingredients: 0,
		},
		Discovery: {
			game_id: 0,
			ingredient_a: 0,
			ingredient_b: 0,
			effect: 0,
			discovered: false,
		},
		Game: {
			id: 0,
			heroes: 0,
			started_at: 0,
			ended_at: 0,
			remaining_tries: 0,
			gold: 0,
			hint_price: 0,
			grimoire: 0,
			hints: 0,
			tries: 0,
			ingredients: 0,
			effects: 0,
			seed: 0,
		},
		Hint: {
			game_id: 0,
			ingredient: 0,
			recipes: 0,
		},
		ExpeditionStarted: {
			game_id: 0,
			hero_id: 0,
			death_depth: 0,
			return_at: 0,
		},
		ExplorationEvent: {
			game_id: 0,
			event_index: 0,
			hero_id: 0,
			depth: 0,
			zone_id: 0,
			event_kind: 0,
			value: 0,
			hp_after: 0,
		},
		GameCreated: {
			game_id: 0,
			player: "",
			settings_id: 0,
			seed: 0,
		},
		GrimoireCompleted: {
			game_id: 0,
			player: "",
			completion_time: 0,
		},
		HeroRecruited: {
			game_id: 0,
			hero_id: 0,
			cost: 0,
		},
		LootClaimed: {
			game_id: 0,
			hero_id: 0,
			gold: 0,
		},
		PotionApplied: {
			game_id: 0,
			hero_id: 0,
			potion_index: 0,
			effect_type: 0,
			effect_value: 0,
		},
		RecipeDiscovered: {
			game_id: 0,
			recipe_id: 0,
			ingredient_a: 0,
			ingredient_b: 0,
			effect_type: 0,
			discovered_count: 0,
		},
		GameContext: {
		name: "",
		value: "",
		},
		GameContextDetails: {
		name: "",
		description: "",
			id: new CairoOption(CairoOptionVariant.None),
			context: [{ name: "", value: "", }],
		},
		GameSetting: {
		name: "",
		value: "",
		},
		GameSettingDetails: {
		name: "",
		description: "",
			settings: [{ name: "", value: "", }],
		},
	},
};
export enum ModelsMapping {
	Config = 'athanor-Config',
	GameSettings = 'athanor-GameSettings',
	GameSettingsMetadata = 'athanor-GameSettingsMetadata',
	GameSeed = 'athanor-GameSeed',
	GameSession = 'athanor-GameSession',
	Character = 'athanor-Character',
	Discovery = 'athanor-Discovery',
	Game = 'athanor-Game',
	Hint = 'athanor-Hint',
	ExpeditionStarted = 'athanor-ExpeditionStarted',
	ExplorationEvent = 'athanor-ExplorationEvent',
	GameCreated = 'athanor-GameCreated',
	GrimoireCompleted = 'athanor-GrimoireCompleted',
	HeroRecruited = 'athanor-HeroRecruited',
	LootClaimed = 'athanor-LootClaimed',
	PotionApplied = 'athanor-PotionApplied',
	RecipeDiscovered = 'athanor-RecipeDiscovered',
	GameContext = 'game_components_metagame-GameContext',
	GameContextDetails = 'game_components_metagame-GameContextDetails',
	GameSetting = 'game_components_minigame-GameSetting',
	GameSettingDetails = 'game_components_minigame-GameSettingDetails',
}