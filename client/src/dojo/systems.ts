import {
  type AccountInterface,
  type BigNumberish,
  CallData,
  CairoOption,
  CairoOptionVariant,
} from 'starknet'

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

export function extractGameId(receipt: { events?: { keys?: string[]; data?: string[] }[] }): number {
  const events = receipt.events ?? []
  const transferEvent = events.find(
    (event) => event.keys != null && event.keys.length === 5 && (!event.data || event.data.length === 0),
  )

  if (transferEvent?.keys) {
    const tokenIdLow = BigInt(transferEvent.keys[3] ?? '0')
    const tokenIdHigh = BigInt(transferEvent.keys[4] ?? '0')
    return Number(tokenIdLow + (tokenIdHigh << 128n))
  }

  return 0
}

export function createSystemCalls(manifest: Manifest) {
  const gameSystemAddress = getContractAddress(manifest, 'athanor-game_system')
  const explorationSystemAddress = getContractAddress(manifest, 'athanor-exploration_system')
  const craftingSystemAddress = getContractAddress(manifest, 'athanor-crafting_system')
  const heroSystemAddress = getContractAddress(manifest, 'athanor-hero_system')

  return {
    mintGame: (account: AccountInterface, settingsId: number = 0) =>
      account.execute([
        {
          contractAddress: gameSystemAddress,
          entrypoint: 'mint_game',
          calldata: CallData.compile([
            new CairoOption(CairoOptionVariant.None),
            new CairoOption(CairoOptionVariant.Some, settingsId),
            1,
            1,
            1,
            1,
            1,
            1,
            account.address,
            true,
          ]),
        },
      ]),

    create: (account: AccountInterface, game_id: BigNumberish) =>
      account.execute([
        {
          contractAddress: gameSystemAddress,
          entrypoint: 'create',
          calldata: [game_id],
        },
      ]),

    glean: (account: AccountInterface, game_id: BigNumberish) =>
      account.execute([
        {
          contractAddress: gameSystemAddress,
          entrypoint: 'glean',
          calldata: [game_id],
        },
      ]),

    surrender: (account: AccountInterface, game_id: BigNumberish) =>
      account.execute([
        {
          contractAddress: gameSystemAddress,
          entrypoint: 'surrender',
          calldata: [game_id],
        },
      ]),

    sendExpedition: (account: AccountInterface, game_id: BigNumberish, hero_id: BigNumberish) =>
      account.execute([
        {
          contractAddress: explorationSystemAddress,
          entrypoint: 'send_expedition',
          calldata: [game_id, hero_id],
        },
      ]),

    claimLoot: (account: AccountInterface, game_id: BigNumberish, hero_id: BigNumberish) =>
      account.execute([
        {
          contractAddress: explorationSystemAddress,
          entrypoint: 'claim_loot',
          calldata: [game_id, hero_id],
        },
      ]),

    craft: (
      account: AccountInterface,
      game_id: BigNumberish,
      ingredient_a: BigNumberish,
      ingredient_b: BigNumberish,
    ) =>
      account.execute([
        {
          contractAddress: craftingSystemAddress,
          entrypoint: 'craft',
          calldata: [game_id, ingredient_a, ingredient_b],
        },
      ]),

    gameCraft: (
      account: AccountInterface,
      game_id: BigNumberish,
      ingredient_a: BigNumberish,
      ingredient_b: BigNumberish,
      quantity: BigNumberish = 1,
    ) =>
      account.execute([
        {
          contractAddress: gameSystemAddress,
          entrypoint: 'craft',
          calldata: [game_id, ingredient_a, ingredient_b, quantity],
        },
      ]),

    craftRecipe: (account: AccountInterface, game_id: BigNumberish, recipe_id: BigNumberish) =>
      account.execute([
        {
          contractAddress: craftingSystemAddress,
          entrypoint: 'craft_recipe',
          calldata: [game_id, recipe_id],
        },
      ]),

    buyHint: (account: AccountInterface, game_id: BigNumberish) =>
      account.execute([
        {
          contractAddress: craftingSystemAddress,
          entrypoint: 'buy_hint',
          calldata: [game_id],
        },
      ]),

    recruitHero: (account: AccountInterface, game_id: BigNumberish) =>
      account.execute([
        {
          contractAddress: heroSystemAddress,
          entrypoint: 'recruit_hero',
          calldata: [game_id],
        },
      ]),

    applyPotion: (
      account: AccountInterface,
      game_id: BigNumberish,
      potion_index: BigNumberish,
      hero_id: BigNumberish,
    ) =>
      account.execute([
        {
          contractAddress: heroSystemAddress,
          entrypoint: 'apply_potion',
          calldata: [game_id, potion_index, hero_id],
        },
      ]),
  }
}
