use starknet::ContractAddress;
use crate::models::config::GameSettings;

#[inline]
pub fn NAME() -> ByteArray {
    "Setup"
}

#[starknet::interface]
pub trait ISetup<T> {
    fn get_game_settings(self: @T, settings_id: u32) -> GameSettings;
    fn set_vrf_address(self: @T, vrf_address: ContractAddress);
}

#[dojo::contract]
pub mod Setup {
    use dojo::world::{IWorldDispatcherTrait, WorldStorage, WorldStorageTrait};
    use game_components_embeddable_game_standard::minigame::extensions::settings::interface::{
        IMinigameSettings, IMinigameSettingsDetails,
    };
    use game_components_embeddable_game_standard::minigame::extensions::settings::settings::SettingsComponent;
    use game_components_embeddable_game_standard::minigame::extensions::settings::structs::{
        GameSetting, GameSettingDetails,
    };
    use game_components_embeddable_game_standard::minigame::interface::{
        IMinigameDispatcher, IMinigameDispatcherTrait,
    };
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::{ContractAddress, get_block_timestamp};
    use crate::constants::{NAMESPACE, WORLD_RESOURCE};
    use crate::models::config::{GameSettings, GameSettingsMetadata, GameSettingsTrait};
    use crate::store::{StoreImpl, StoreTrait};
    use crate::systems::play::NAME as PLAY;
    use super::ISetup;

    component!(path: SettingsComponent, storage: settings, event: SettingsEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    impl SettingsInternalImpl = SettingsComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        settings_counter: u32,
        #[substorage(v0)]
        settings: SettingsComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SettingsEvent: SettingsComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    fn dojo_init(ref self: ContractState) {
        let world: WorldStorage = self.world(@NAMESPACE());
        let timestamp = get_block_timestamp();
        let store = StoreImpl::new(world);

        self.settings.initializer();

        store.set_settings(@GameSettingsTrait::new_default());
        let creator_address = starknet::get_tx_info().unbox().account_contract_address;
        store
            .set_settings_meta(
                @GameSettingsMetadata {
                    settings_id: 1,
                    name: 'Default',
                    created_by: creator_address,
                    created_at: timestamp,
                    is_active: true,
                },
            );

        self.settings_counter.write(0);

        let (play_address, _) = world.dns(@PLAY()).expect('Setup: play not found');
        let minigame = IMinigameDispatcher { contract_address: play_address };
        let token_address = minigame.token_address();

        self
            .settings
            .create_settings(
                game_address: play_address,
                settings_id: 1,
                settings_details: GameSettingDetails {
                    name: "Default",
                    description: "Official Athanor settings. 3 zones, 9 ingredients, 10 recipes.",
                    settings: array![
                        GameSetting { name: 'Zones', value: '5' },
                        GameSetting { name: 'Ingredients', value: '25' },
                        GameSetting { name: 'Recipes', value: '30' },
                    ]
                        .span(),
                },
                minigame_token_address: token_address,
            );

        // [Event] Order torii to index the tokens
        let instance_name: felt252 = token_address.into();
        world
            .dispatcher
            .register_external_contract(
                namespace: NAMESPACE(),
                contract_name: "ERC721",
                instance_name: format!("{}", instance_name),
                contract_address: token_address,
                block_number: 1,
            );
    }

    #[abi(embed_v0)]
    impl GameSettingsImpl of IMinigameSettings<ContractState> {
        fn settings_exist(self: @ContractState, settings_id: u32) -> bool {
            let store = StoreImpl::new(self.world(@NAMESPACE()));
            let settings = store.settings(settings_id);
            settings.exists()
        }

        fn settings_exist_batch(self: @ContractState, settings_ids: Span<u32>) -> Array<bool> {
            let mut results = array![];
            let mut i = 0;
            while i < settings_ids.len() {
                results.append(self.settings_exist(*settings_ids.at(i)));
                i += 1;
            }
            results
        }
    }

    #[abi(embed_v0)]
    impl MinigameSettingsDetailsImpl of IMinigameSettingsDetails<ContractState> {
        // Batch operations
        fn settings_count(self: @ContractState) -> u32 {
            1
        }

        fn settings_details(self: @ContractState, settings_id: u32) -> GameSettingDetails {
            let store = StoreImpl::new(self.world(@NAMESPACE()));
            let metadata = store.settings_meta(settings_id);

            GameSettingDetails {
                name: format!("{}", metadata.name),
                description: "Athanor game settings",
                settings: array![
                    GameSetting {
                        name: 'Active', value: if metadata.is_active {
                            'Yes'
                        } else {
                            'No'
                        },
                    },
                ]
                    .span(),
            }
        }

        fn settings_details_batch(
            self: @ContractState, settings_ids: Span<u32>,
        ) -> Array<GameSettingDetails> {
            let mut results = array![];
            let mut i = 0;
            while i < settings_ids.len() {
                results.append(self.settings_details(*settings_ids.at(i)));
                i += 1;
            }
            results
        }
    }

    #[abi(embed_v0)]
    impl SetupImpl of ISetup<ContractState> {
        fn get_game_settings(self: @ContractState, settings_id: u32) -> GameSettings {
            let store = StoreImpl::new(self.world(@NAMESPACE()));
            store.settings(settings_id)
        }

        fn set_vrf_address(self: @ContractState, vrf_address: ContractAddress) {
            // [Setup] World and Store
            let mut world = self.world(@NAMESPACE());
            let mut store = StoreImpl::new(world);
            // [Check] Caller is allowed
            self.assert_only_owner(world);
            // [Effect] Update config
            let mut config = store.config();
            config.vrf_address = vrf_address;
            store.set_config(@config);
        }
    }

    #[generate_trait]
    pub impl PrivateImpl of PrivateTrait {
        fn assert_only_owner(self: @ContractState, world: WorldStorage) {
            let caller = starknet::get_caller_address();
            assert!(world.dispatcher.is_owner(WORLD_RESOURCE, caller), "Unauthorized caller");
        }
    }
}
