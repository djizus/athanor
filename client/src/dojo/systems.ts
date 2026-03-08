import {
  type AccountInterface,
  type BigNumberish,
  type Call,
  CallData,
  CairoOption,
  CairoOptionVariant,
  shortString,
  uint256,
  type Uint256,
} from 'starknet'

type ManifestContract = {
  tag: string
  address: string
}

type Manifest = {
  contracts: ManifestContract[]
}

const SN_SEPOLIA_VRF = "0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f";

export const getVrfAddress = (chainId?: bigint) => {
  if (!chainId) {
    return SN_SEPOLIA_VRF;
  }
  const decodedChainId = shortString.decodeShortString(
    `0x${chainId.toString(16)}`,
  );
  const fromEnv = import.meta.env[`VITE_${decodedChainId}_VRF`];
  if (fromEnv && BigInt(fromEnv) !== 0n) return fromEnv;
  return SN_SEPOLIA_VRF;
};

function getContractAddress(manifest: Manifest, tag: string) {
  const contract = manifest.contracts.find((item) => item.tag === tag)

  if (!contract?.address) {
    throw new Error(`Missing contract address for ${tag}`)
  }

  return contract.address
}

export function extractGameId(receipt: { events?: { keys?: string[]; data?: string[] }[] }): bigint {
  const events = receipt.events ?? []
  const transferEvent = events.find(
    (event) => event.keys != null && event.keys.length === 5 && (!event.data || event.data.length === 0),
  )

  if (transferEvent?.keys) {
    const tokenIdLow = BigInt(transferEvent.keys[3] ?? '0')
    const tokenIdHigh = BigInt(transferEvent.keys[4] ?? '0')
    const uint256Value: Uint256 = {low: tokenIdLow, high: tokenIdHigh};
    return uint256.uint256ToBN(uint256Value);
  }

  return 0n
}

export function createSystemCalls(manifest: Manifest) {
  const playAddress = getContractAddress(manifest, 'ATHANOR-Play')

  const vrfCalls = (): Call[] => [{
    contractAddress: getVrfAddress(),
    entrypoint: "request_random",
    calldata: CallData.compile({
      caller: playAddress,
      source: { type: 0, address: playAddress },
    }),
  }]

  return {
    // --- Direct-execute (used in HomePage, need receipt / account.address) ---

    mintGame: (account: AccountInterface, username: string, settingsId: number = 0) =>
      account.execute([
        {
          contractAddress: playAddress,
          entrypoint: 'mint_game',
          calldata: CallData.compile({
            player_name: new CairoOption(CairoOptionVariant.Some, shortString.encodeShortString(username)),
            settings_id: new CairoOption(CairoOptionVariant.Some, settingsId),
            start: new CairoOption(CairoOptionVariant.None),
            end: new CairoOption(CairoOptionVariant.None),
            objective_id: new CairoOption(CairoOptionVariant.None),
            context: new CairoOption(CairoOptionVariant.None),
            client_url: new CairoOption(CairoOptionVariant.None),
            renderer_address: new CairoOption(CairoOptionVariant.None),
            skills_address: new CairoOption(CairoOptionVariant.None),
            to: account.address,
            soulbound: false,
            paymaster: true,
            salt: 0,
            metadata: 0,
          }),
        },
      ]),

    create: (account: AccountInterface, game_id: BigNumberish) =>
      account.execute([
        ...vrfCalls(),
        {
          contractAddress: playAddress,
          entrypoint: 'create',
          calldata: [game_id],
        },
      ]),

    // --- Call builders (return Call[] for tx batcher) ---

    clue: (game_id: BigNumberish): Call[] => [
      ...vrfCalls(),
      { contractAddress: playAddress, entrypoint: 'clue', calldata: [game_id] },
    ],

    craft: (
      game_id: BigNumberish,
      ingredient_a: BigNumberish,
      ingredient_b: BigNumberish,
      quantity: BigNumberish = 1,
    ): Call[] => [
      ...vrfCalls(),
      {
        contractAddress: playAddress,
        entrypoint: 'craft',
        calldata: [game_id, Number(ingredient_a) + 1, Number(ingredient_b) + 1, quantity],
      },
    ],

    crafts: (game_id: BigNumberish, pairs: [number, number][]): Call[] => {
      const ingredients = pairs.flatMap(([a, b]) => [a + 1, b + 1])
      return [
        ...vrfCalls(),
        {
          contractAddress: playAddress,
          entrypoint: 'crafts',
          calldata: CallData.compile({ game_id, ingredients }),
        },
      ]
    },

    recruit: (game_id: BigNumberish): Call[] => [
      ...vrfCalls(),
      { contractAddress: playAddress, entrypoint: 'recruit', calldata: [game_id] },
    ],

    buff: (
      game_id: BigNumberish,
      character_id: BigNumberish,
      effect: BigNumberish,
      quantity: BigNumberish = 1,
    ): Call[] => [
      {
        contractAddress: playAddress,
        entrypoint: 'buff',
        calldata: [game_id, character_id, Number(effect) + 1, quantity],
      },
    ],

    buffs: (
      game_id: BigNumberish,
      character_id: BigNumberish,
      effects: number[],
    ): Call[] => {
      const effectIds = effects.map(e => e + 1)
      return [
        {
          contractAddress: playAddress,
          entrypoint: 'buffs',
          calldata: CallData.compile({ game_id, character_id, effects: effectIds }),
        },
      ]
    },

    explore: (game_id: BigNumberish, character_id: BigNumberish, zone_id: BigNumberish): Call[] => [
      ...vrfCalls(),
      { contractAddress: playAddress, entrypoint: 'claim', calldata: [game_id, character_id] },
      { contractAddress: playAddress, entrypoint: 'explore', calldata: [game_id, character_id, zone_id] },
    ],

    claim: (game_id: BigNumberish, character_id: BigNumberish): Call[] => [
      { contractAddress: playAddress, entrypoint: 'claim', calldata: [game_id, character_id] },
    ],

    surrender: (game_id: BigNumberish): Call[] => [
      { contractAddress: playAddress, entrypoint: 'surrender', calldata: [game_id] },
    ],
  }
}
