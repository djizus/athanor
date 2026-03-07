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
  const playAddress = getContractAddress(manifest, 'ATHANOR-Play')

  return {
    mintGame: (account: AccountInterface, settingsId: number = 0) =>
      account.execute([
        {
          contractAddress: playAddress,
          entrypoint: 'mint_game',
          calldata: CallData.compile([
            new CairoOption(CairoOptionVariant.None),
            new CairoOption(CairoOptionVariant.Some, settingsId),
            new CairoOption(CairoOptionVariant.None),
            new CairoOption(CairoOptionVariant.None),
            new CairoOption(CairoOptionVariant.None),
            new CairoOption(CairoOptionVariant.None),
            new CairoOption(CairoOptionVariant.None),
            new CairoOption(CairoOptionVariant.None),
            account.address,
            true,
          ]),
        },
      ]),

    create: (account: AccountInterface, game_id: BigNumberish) =>
      account.execute([
        {
          contractAddress: playAddress,
          entrypoint: 'create',
          calldata: [game_id],
        },
      ]),

    clue: (account: AccountInterface, game_id: BigNumberish) =>
      account.execute([
        {
          contractAddress: playAddress,
          entrypoint: 'clue',
          calldata: [game_id],
        },
      ]),

    craft: (
      account: AccountInterface,
      game_id: BigNumberish,
      ingredient_a: BigNumberish,
      ingredient_b: BigNumberish,
      quantity: BigNumberish = 1,
    ) =>
      account.execute([
        {
          contractAddress: playAddress,
          entrypoint: 'craft',
          calldata: [game_id, Number(ingredient_a) + 1, Number(ingredient_b) + 1, quantity],
        },
      ]),

    recruit: (account: AccountInterface, game_id: BigNumberish) =>
      account.execute([
        {
          contractAddress: playAddress,
          entrypoint: 'recruit',
          calldata: [game_id],
        },
      ]),

    buff: (
      account: AccountInterface,
      game_id: BigNumberish,
      character_id: BigNumberish,
      effect: BigNumberish,
      quantity: BigNumberish = 1,
    ) =>
      account.execute([
        {
          contractAddress: playAddress,
          entrypoint: 'buff',
          calldata: [game_id, character_id, Number(effect) + 1, quantity],
        },
      ]),

    explore: (account: AccountInterface, game_id: BigNumberish, character_id: BigNumberish) =>
      account.execute([
        {
          contractAddress: playAddress,
          entrypoint: 'claim',
          calldata: [game_id, character_id],
        },
        {
          contractAddress: playAddress,
          entrypoint: 'explore',
          calldata: [game_id, character_id],
        },
      ]),

    claim: (account: AccountInterface, game_id: BigNumberish, character_id: BigNumberish) =>
      account.execute([
        {
          contractAddress: playAddress,
          entrypoint: 'claim',
          calldata: [game_id, character_id],
        },
      ]),
  }
}
