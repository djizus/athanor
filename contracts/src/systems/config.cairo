use athanor::models::config::GameSettings;

#[starknet::interface]
pub trait IConfigSystem<T> {
    fn get_game_settings(self: @T, settings_id: u32) -> GameSettings;
}

#[dojo::contract]
pub mod config_system {
    use athanor::constants::DEFAULT_NS;
    use athanor::models::config::{GameSettings, GameSettingsMetadata, GameSettingsTrait};
    use athanor::store::{StoreImpl, StoreTrait};
    use dojo::world::{WorldStorage, WorldStorageTrait};
    use game_components_minigame::extensions::settings::interface::{
        IMinigameSettings, IMinigameSettingsDetails,
    };
    use game_components_minigame::extensions::settings::settings::SettingsComponent;
    use game_components_minigame::extensions::settings::structs::{GameSetting, GameSettingDetails};
    use game_components_minigame::interface::{IMinigameDispatcher, IMinigameDispatcherTrait};
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::{ContractAddress, get_block_timestamp};
    use super::IConfigSystem;

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

    fn dojo_init(ref self: ContractState, creator_address: ContractAddress) {
        let world: WorldStorage = self.world(@DEFAULT_NS());
        let timestamp = get_block_timestamp();
        let mut store = StoreImpl::new(world);

        self.settings.initializer();

        store.set_settings(@GameSettingsTrait::new_default());
        store
            .set_settings_meta(
                @GameSettingsMetadata {
                    settings_id: 0,
                    name: 'Default',
                    created_by: creator_address,
                    created_at: timestamp,
                    is_active: true,
                },
            );

        self.settings_counter.write(0);

        let (game_systems_address, _) = world.dns(@"game_system").unwrap();
        let minigame_dispatcher = IMinigameDispatcher { contract_address: game_systems_address };
        let minigame_token_address = minigame_dispatcher.token_address();

        self
            .settings
            .create_settings(
                game_systems_address,
                0,
                "Default",
                "Official Athanor settings. 3 zones, 9 ingredients, 10 recipes.",
                array![
                    GameSetting { name: "Zones", value: "3" },
                    GameSetting { name: "Recipes", value: "10" },
                ]
                    .span(),
                minigame_token_address,
            );
    }

    #[abi(embed_v0)]
    impl MinigameSettingsImpl of IMinigameSettings<ContractState> {
        fn settings_exist(self: @ContractState, settings_id: u32) -> bool {
            let store = StoreImpl::new(self.world(@DEFAULT_NS()));
            let settings = store.settings(settings_id);
            settings.exists()
        }
    }

    #[abi(embed_v0)]
    impl MinigameSettingsDetailsImpl of IMinigameSettingsDetails<ContractState> {
        fn settings_details(self: @ContractState, settings_id: u32) -> GameSettingDetails {
            let store = StoreImpl::new(self.world(@DEFAULT_NS()));
            let metadata = store.settings_meta(settings_id);

            GameSettingDetails {
                name: format!("{}", metadata.name),
                description: "Athanor game settings",
                settings: array![
                    GameSetting {
                        name: "Active", value: if metadata.is_active {
                            "Yes"
                        } else {
                            "No"
                        },
                    },
                ]
                    .span(),
            }
        }
    }

    #[abi(embed_v0)]
    impl ConfigSystemImpl of IConfigSystem<ContractState> {
        fn get_game_settings(self: @ContractState, settings_id: u32) -> GameSettings {
            let store = StoreImpl::new(self.world(@DEFAULT_NS()));
            store.settings(settings_id)
        }
    }
}
