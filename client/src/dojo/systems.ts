import type { AccountInterface, BigNumberish } from 'starknet'

type ManifestContract = {
  tag: string
  address: string
}

type Manifest = {
  contracts: ManifestContract[]
}

function getContractAddress(manifest: Manifest, tag: string) {
  const contract = manifest.contracts.find((item) => item.tag === tag)

  if (!contract?.address) {
    throw new Error(`Missing contract address for ${tag}`)
  }

  return contract.address
}

export function createSystemCalls(manifest: Manifest) {
  const gameSystemAddress = getContractAddress(manifest, 'athanor-game_system')
  const explorationSystemAddress = getContractAddress(manifest, 'athanor-exploration_system')
  const craftingSystemAddress = getContractAddress(manifest, 'athanor-crafting_system')
  const heroSystemAddress = getContractAddress(manifest, 'athanor-hero_system')

  return {
    create: (account: AccountInterface, game_id: BigNumberish) =>
      account.execute({
        contractAddress: gameSystemAddress,
        entrypoint: 'create',
        calldata: [game_id],
      }),
    surrender: (account: AccountInterface, game_id: BigNumberish) =>
      account.execute({
        contractAddress: gameSystemAddress,
        entrypoint: 'surrender',
        calldata: [game_id],
      }),
    sendExpedition: (account: AccountInterface, game_id: BigNumberish, hero_id: BigNumberish) =>
      account.execute({
        contractAddress: explorationSystemAddress,
        entrypoint: 'send_expedition',
        calldata: [game_id, hero_id],
      }),
    claimLoot: (account: AccountInterface, game_id: BigNumberish, hero_id: BigNumberish) =>
      account.execute({
        contractAddress: explorationSystemAddress,
        entrypoint: 'claim_loot',
        calldata: [game_id, hero_id],
      }),
    craft: (
      account: AccountInterface,
      game_id: BigNumberish,
      ingredient_a: BigNumberish,
      ingredient_b: BigNumberish,
    ) =>
      account.execute({
        contractAddress: craftingSystemAddress,
        entrypoint: 'craft',
        calldata: [game_id, ingredient_a, ingredient_b],
      }),
    craftRecipe: (account: AccountInterface, game_id: BigNumberish, recipe_id: BigNumberish) =>
      account.execute({
        contractAddress: craftingSystemAddress,
        entrypoint: 'craft_recipe',
        calldata: [game_id, recipe_id],
      }),
    buyHint: (account: AccountInterface, game_id: BigNumberish) =>
      account.execute({
        contractAddress: craftingSystemAddress,
        entrypoint: 'buy_hint',
        calldata: [game_id],
      }),
    recruitHero: (account: AccountInterface, game_id: BigNumberish) =>
      account.execute({
        contractAddress: heroSystemAddress,
        entrypoint: 'recruit_hero',
        calldata: [game_id],
      }),
    applyPotion: (
      account: AccountInterface,
      game_id: BigNumberish,
      potion_index: BigNumberish,
      hero_id: BigNumberish,
    ) =>
      account.execute({
        contractAddress: heroSystemAddress,
        entrypoint: 'apply_potion',
        calldata: [game_id, potion_index, hero_id],
      }),
  }
}
