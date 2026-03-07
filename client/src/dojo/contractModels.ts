import { defineComponent, Type as RecsType } from '@dojoengine/recs'
import type { World } from '@dojoengine/recs'

export type ContractComponents = ReturnType<typeof defineContractComponents>

const { VITE_PUBLIC_NAMESPACE } = import.meta.env
const namespace = VITE_PUBLIC_NAMESPACE || 'ATHANOR'

export function defineContractComponents(world: World) {
  return {
    Game: (() => {
      return defineComponent(
        world,
        {
          id: RecsType.Number,
          heroes: RecsType.Number,
          started_at: RecsType.Number,
          ended_at: RecsType.Number,
          remaining_tries: RecsType.Number,
          gold: RecsType.Number,
          hint_price: RecsType.Number,
          grimoire: RecsType.Number,
          hints: RecsType.Number,
          tries: RecsType.BigInt,
          ingredients: RecsType.BigInt,
          effects: RecsType.BigInt,
          seed: RecsType.BigInt,
        },
        {
          metadata: {
            namespace,
            name: 'Game',
            types: [
              'u64',      // id (key)
              'u8',       // heroes
              'u64',      // started_at
              'u64',      // ended_at
              'u16',      // remaining_tries
              'u32',      // gold
              'u32',      // hint_price
              'u32',      // grimoire
              'u32',      // hints
              'u128',     // tries
              'felt252',  // ingredients
              'felt252',  // effects
              'felt252',  // seed
            ],
            customTypes: [],
          },
        },
      )
    })(),

    Character: (() => {
      return defineComponent(
        world,
        {
          game_id: RecsType.Number,
          id: RecsType.Number,
          role: RecsType.Number,
          health: RecsType.Number,
          max_health: RecsType.Number,
          power: RecsType.Number,
          regen: RecsType.Number,
          gold: RecsType.Number,
          available_at: RecsType.Number,
          ingredients: RecsType.BigInt,
        },
        {
          metadata: {
            namespace,
            name: 'Character',
            types: [
              'u64',      // game_id (key)
              'u8',       // id (key)
              'u8',       // role
              'u16',      // health
              'u16',      // max_health
              'u16',      // power
              'u16',      // regen
              'u32',      // gold
              'u64',      // available_at
              'felt252',  // ingredients
            ],
            customTypes: [],
          },
        },
      )
    })(),

    Discovery: (() => {
      return defineComponent(
        world,
        {
          game_id: RecsType.Number,
          ingredient_a: RecsType.Number,
          ingredient_b: RecsType.Number,
          effect: RecsType.Number,
          discovered: RecsType.Boolean,
        },
        {
          metadata: {
            namespace,
            name: 'Discovery',
            types: [
              'u64',  // game_id (key)
              'u8',   // ingredient_a (key)
              'u8',   // ingredient_b (key)
              'u8',   // effect
              'bool', // discovered
            ],
            customTypes: [],
          },
        },
      )
    })(),

    Hint: (() => {
      return defineComponent(
        world,
        {
          game_id: RecsType.Number,
          ingredient: RecsType.Number,
          recipes: RecsType.Number,
        },
        {
          metadata: {
            namespace,
            name: 'Hint',
            types: [
              'u64', // game_id (key)
              'u8',  // ingredient (key)
              'u32', // recipes
            ],
            customTypes: [],
          },
        },
      )
    })(),

    GameSession: (() => {
      return defineComponent(
        world,
        {
          game_id: RecsType.Number,
          player: RecsType.BigInt,
          seed: RecsType.BigInt,
          settings_id: RecsType.Number,
          discovered_count: RecsType.Number,
          failed_combo_count: RecsType.Number,
          craft_attempts: RecsType.Number,
          hints_used: RecsType.Number,
          gold: RecsType.Number,
          hero_count: RecsType.Number,
          potion_count: RecsType.Number,
          game_over: RecsType.Boolean,
          started_at: RecsType.Number,
        },
        {
          metadata: {
            namespace,
            name: 'GameSession',
            types: [
              'u64',             // game_id (key)
              'ContractAddress', // player
              'felt252',         // seed
              'u32',             // settings_id
              'u8',              // discovered_count
              'u16',             // failed_combo_count
              'u16',             // craft_attempts
              'u8',              // hints_used
              'u32',             // gold
              'u8',              // hero_count
              'u16',             // potion_count
              'bool',            // game_over
              'u64',             // started_at
            ],
            customTypes: [],
          },
        },
      )
    })(),

    GameSeed: (() => {
      return defineComponent(
        world,
        {
          game_id: RecsType.Number,
          seed: RecsType.BigInt,
        },
        {
          metadata: {
            namespace,
            name: 'GameSeed',
            types: [
              'u64',     // game_id (key)
              'felt252', // seed
            ],
            customTypes: [],
          },
        },
      )
    })(),

    GameSettings: (() => {
      return defineComponent(
        world,
        {
          settings_id: RecsType.Number,
          zone_count: RecsType.Number,
          ingredients_per_zone: RecsType.Number,
          recipes_to_discover: RecsType.Number,
          max_heroes: RecsType.Number,
          hero_base_hp: RecsType.Number,
          hero_base_power: RecsType.Number,
          hero_base_regen: RecsType.Number,
          hint_base_cost: RecsType.Number,
          hint_cost_multiplier: RecsType.Number,
          soup_gold_value: RecsType.Number,
          progressive_cap: RecsType.Number,
        },
        {
          metadata: {
            namespace,
            name: 'GameSettings',
            types: [
              'u32', // settings_id (key)
              'u8',  // zone_count
              'u8',  // ingredients_per_zone
              'u8',  // recipes_to_discover
              'u8',  // max_heroes
              'u16', // hero_base_hp
              'u16', // hero_base_power
              'u16', // hero_base_regen
              'u16', // hint_base_cost
              'u8',  // hint_cost_multiplier
              'u8',  // soup_gold_value
              'u16', // progressive_cap
            ],
            customTypes: [],
          },
        },
      )
    })(),

    GameSettingsMetadata: (() => {
      return defineComponent(
        world,
        {
          settings_id: RecsType.Number,
          name: RecsType.BigInt,
          created_by: RecsType.BigInt,
          created_at: RecsType.Number,
          is_active: RecsType.Boolean,
        },
        {
          metadata: {
            namespace,
            name: 'GameSettingsMetadata',
            types: [
              'u32',             // settings_id (key)
              'felt252',         // name
              'ContractAddress', // created_by
              'u64',             // created_at
              'bool',            // is_active
            ],
            customTypes: [],
          },
        },
      )
    })(),

    Config: (() => {
      return defineComponent(
        world,
        {
          key: RecsType.BigInt,
          token_address: RecsType.BigInt,
          vrf_address: RecsType.BigInt,
        },
        {
          metadata: {
            namespace,
            name: 'Config',
            types: [
              'felt252',         // key (key)
              'ContractAddress', // token_address
              'ContractAddress', // vrf_address
            ],
            customTypes: [],
          },
        },
      )
    })(),
  }
}
