import { DojoProvider, DojoCall } from "@dojoengine/core";
import { Account, AccountInterface, BigNumberish, CairoOption, CairoCustomEnum } from "starknet";
import * as models from "./models.gen";

export function setupWorld(provider: DojoProvider) {

	const build_Play_buff_calldata = (gameId: BigNumberish, characterId: BigNumberish, effect: BigNumberish, quantity: BigNumberish): DojoCall => {
		return {
			contractName: "Play",
			entrypoint: "buff",
			calldata: [gameId, characterId, effect, quantity],
		};
	};

	const Play_buff = async (snAccount: Account | AccountInterface, gameId: BigNumberish, characterId: BigNumberish, effect: BigNumberish, quantity: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_Play_buff_calldata(gameId, characterId, effect, quantity),
				"ATHANOR",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Play_claim_calldata = (gameId: BigNumberish, characterId: BigNumberish): DojoCall => {
		return {
			contractName: "Play",
			entrypoint: "claim",
			calldata: [gameId, characterId],
		};
	};

	const Play_claim = async (snAccount: Account | AccountInterface, gameId: BigNumberish, characterId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_Play_claim_calldata(gameId, characterId),
				"ATHANOR",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Play_clue_calldata = (gameId: BigNumberish): DojoCall => {
		return {
			contractName: "Play",
			entrypoint: "clue",
			calldata: [gameId],
		};
	};

	const Play_clue = async (snAccount: Account | AccountInterface, gameId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_Play_clue_calldata(gameId),
				"ATHANOR",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Play_craft_calldata = (gameId: BigNumberish, ingredientA: BigNumberish, ingredientB: BigNumberish, quantity: BigNumberish): DojoCall => {
		return {
			contractName: "Play",
			entrypoint: "craft",
			calldata: [gameId, ingredientA, ingredientB, quantity],
		};
	};

	const Play_craft = async (snAccount: Account | AccountInterface, gameId: BigNumberish, ingredientA: BigNumberish, ingredientB: BigNumberish, quantity: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_Play_craft_calldata(gameId, ingredientA, ingredientB, quantity),
				"ATHANOR",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Play_create_calldata = (gameId: BigNumberish): DojoCall => {
		return {
			contractName: "Play",
			entrypoint: "create",
			calldata: [gameId],
		};
	};

	const Play_create = async (snAccount: Account | AccountInterface, gameId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_Play_create_calldata(gameId),
				"ATHANOR",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Play_explore_calldata = (gameId: BigNumberish, characterId: BigNumberish): DojoCall => {
		return {
			contractName: "Play",
			entrypoint: "explore",
			calldata: [gameId, characterId],
		};
	};

	const Play_explore = async (snAccount: Account | AccountInterface, gameId: BigNumberish, characterId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_Play_explore_calldata(gameId, characterId),
				"ATHANOR",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Play_gameOver_calldata = (tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "Play",
			entrypoint: "game_over",
			calldata: [tokenId],
		};
	};

	const Play_gameOver = async (tokenId: BigNumberish) => {
		try {
			return await provider.call("ATHANOR", build_Play_gameOver_calldata(tokenId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Play_mintGame_calldata = (playerName: CairoOption<BigNumberish>, settingsId: CairoOption<BigNumberish>, start: CairoOption<BigNumberish>, end: CairoOption<BigNumberish>, objectiveIds: CairoOption<Array<BigNumberish>>, context: CairoOption<GameContextDetails>, clientUrl: CairoOption<string>, rendererAddress: CairoOption<string>, to: string, soulbound: boolean): DojoCall => {
		return {
			contractName: "Play",
			entrypoint: "mint_game",
			calldata: [playerName, settingsId, start, end, objectiveIds, context, clientUrl, rendererAddress, to, soulbound],
		};
	};

	const Play_mintGame = async (playerName: CairoOption<BigNumberish>, settingsId: CairoOption<BigNumberish>, start: CairoOption<BigNumberish>, end: CairoOption<BigNumberish>, objectiveIds: CairoOption<Array<BigNumberish>>, context: CairoOption<GameContextDetails>, clientUrl: CairoOption<string>, rendererAddress: CairoOption<string>, to: string, soulbound: boolean) => {
		try {
			return await provider.call("ATHANOR", build_Play_mintGame_calldata(playerName, settingsId, start, end, objectiveIds, context, clientUrl, rendererAddress, to, soulbound));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Play_objectivesAddress_calldata = (): DojoCall => {
		return {
			contractName: "Play",
			entrypoint: "objectives_address",
			calldata: [],
		};
	};

	const Play_objectivesAddress = async () => {
		try {
			return await provider.call("ATHANOR", build_Play_objectivesAddress_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Play_recruit_calldata = (gameId: BigNumberish): DojoCall => {
		return {
			contractName: "Play",
			entrypoint: "recruit",
			calldata: [gameId],
		};
	};

	const Play_recruit = async (snAccount: Account | AccountInterface, gameId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_Play_recruit_calldata(gameId),
				"ATHANOR",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Play_score_calldata = (tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "Play",
			entrypoint: "score",
			calldata: [tokenId],
		};
	};

	const Play_score = async (tokenId: BigNumberish) => {
		try {
			return await provider.call("ATHANOR", build_Play_score_calldata(tokenId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Play_settingsAddress_calldata = (): DojoCall => {
		return {
			contractName: "Play",
			entrypoint: "settings_address",
			calldata: [],
		};
	};

	const Play_settingsAddress = async () => {
		try {
			return await provider.call("ATHANOR", build_Play_settingsAddress_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Play_supportsInterface_calldata = (interfaceId: BigNumberish): DojoCall => {
		return {
			contractName: "Play",
			entrypoint: "supports_interface",
			calldata: [interfaceId],
		};
	};

	const Play_supportsInterface = async (interfaceId: BigNumberish) => {
		try {
			return await provider.call("ATHANOR", build_Play_supportsInterface_calldata(interfaceId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Play_tokenAddress_calldata = (): DojoCall => {
		return {
			contractName: "Play",
			entrypoint: "token_address",
			calldata: [],
		};
	};

	const Play_tokenAddress = async () => {
		try {
			return await provider.call("ATHANOR", build_Play_tokenAddress_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Setup_getGameSettings_calldata = (settingsId: BigNumberish): DojoCall => {
		return {
			contractName: "Setup",
			entrypoint: "get_game_settings",
			calldata: [settingsId],
		};
	};

	const Setup_getGameSettings = async (settingsId: BigNumberish) => {
		try {
			return await provider.call("ATHANOR", build_Setup_getGameSettings_calldata(settingsId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Setup_settingsDetails_calldata = (settingsId: BigNumberish): DojoCall => {
		return {
			contractName: "Setup",
			entrypoint: "settings_details",
			calldata: [settingsId],
		};
	};

	const Setup_settingsDetails = async (settingsId: BigNumberish) => {
		try {
			return await provider.call("ATHANOR", build_Setup_settingsDetails_calldata(settingsId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Setup_settingsExist_calldata = (settingsId: BigNumberish): DojoCall => {
		return {
			contractName: "Setup",
			entrypoint: "settings_exist",
			calldata: [settingsId],
		};
	};

	const Setup_settingsExist = async (settingsId: BigNumberish) => {
		try {
			return await provider.call("ATHANOR", build_Setup_settingsExist_calldata(settingsId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_Setup_supportsInterface_calldata = (interfaceId: BigNumberish): DojoCall => {
		return {
			contractName: "Setup",
			entrypoint: "supports_interface",
			calldata: [interfaceId],
		};
	};

	const Setup_supportsInterface = async (interfaceId: BigNumberish) => {
		try {
			return await provider.call("ATHANOR", build_Setup_supportsInterface_calldata(interfaceId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};



	return {
		Play: {
			buff: Play_buff,
			buildBuffCalldata: build_Play_buff_calldata,
			claim: Play_claim,
			buildClaimCalldata: build_Play_claim_calldata,
			clue: Play_clue,
			buildClueCalldata: build_Play_clue_calldata,
			craft: Play_craft,
			buildCraftCalldata: build_Play_craft_calldata,
			create: Play_create,
			buildCreateCalldata: build_Play_create_calldata,
			explore: Play_explore,
			buildExploreCalldata: build_Play_explore_calldata,
			gameOver: Play_gameOver,
			buildGameOverCalldata: build_Play_gameOver_calldata,
			mintGame: Play_mintGame,
			buildMintGameCalldata: build_Play_mintGame_calldata,
			objectivesAddress: Play_objectivesAddress,
			buildObjectivesAddressCalldata: build_Play_objectivesAddress_calldata,
			recruit: Play_recruit,
			buildRecruitCalldata: build_Play_recruit_calldata,
			score: Play_score,
			buildScoreCalldata: build_Play_score_calldata,
			settingsAddress: Play_settingsAddress,
			buildSettingsAddressCalldata: build_Play_settingsAddress_calldata,
			supportsInterface: Play_supportsInterface,
			buildSupportsInterfaceCalldata: build_Play_supportsInterface_calldata,
			tokenAddress: Play_tokenAddress,
			buildTokenAddressCalldata: build_Play_tokenAddress_calldata,
		},
		Setup: {
			getGameSettings: Setup_getGameSettings,
			buildGetGameSettingsCalldata: build_Setup_getGameSettings_calldata,
			settingsDetails: Setup_settingsDetails,
			buildSettingsDetailsCalldata: build_Setup_settingsDetails_calldata,
			settingsExist: Setup_settingsExist,
			buildSettingsExistCalldata: build_Setup_settingsExist_calldata,
			supportsInterface: Setup_supportsInterface,
			buildSupportsInterfaceCalldata: build_Setup_supportsInterface_calldata,
		},
	};
}