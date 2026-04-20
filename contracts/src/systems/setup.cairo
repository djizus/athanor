// Setup contract.
//
// Writes the default Ascend GameSettings + metadata at deploy time and
// registers them with Denshokan via the EGC SettingsComponent. Exposes
// IMinigameSettings + IMinigameSettingsDetails for external queries.

#[dojo::contract]
pub mod setup {
    use dojo::world::{WorldStorage, WorldStorageTrait};
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
    use starknet::get_block_timestamp;
    use athanor::models::config::{GameSettingsMetadata, GameSettingsTrait};
    use athanor::store::StoreTrait;

    component!(path: SettingsComponent, storage: settings, event: SettingsEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    impl SettingsInternalImpl = SettingsComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
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
        let world: WorldStorage = self.world(@"athanor_0_1");
        let timestamp = get_block_timestamp();
        let mut store = StoreTrait::new(world);

        self.settings.initializer();

        store.set_game_settings(@GameSettingsTrait::new_default());
        store.set_game_settings(@GameSettingsTrait::new_silver());
        store.set_game_settings(@GameSettingsTrait::new_gold());

        let creator_address = starknet::get_tx_info().unbox().account_contract_address;
        store
            .set_game_settings_metadata(
                @GameSettingsMetadata {
                    settings_id: 1,
                    name: 'Bronze',
                    created_by: creator_address,
                    created_at: timestamp,
                    is_active: true,
                },
            );
        store
            .set_game_settings_metadata(
                @GameSettingsMetadata {
                    settings_id: 2,
                    name: 'Silver',
                    created_by: creator_address,
                    created_at: timestamp,
                    is_active: true,
                },
            );
        store
            .set_game_settings_metadata(
                @GameSettingsMetadata {
                    settings_id: 3,
                    name: 'Gold',
                    created_by: creator_address,
                    created_at: timestamp,
                    is_active: true,
                },
            );

        let (actions_address, _) = world.dns(@"actions").expect('setup: actions not found');
        let minigame = IMinigameDispatcher { contract_address: actions_address };
        let token_address = minigame.token_address();

        // In local dev the actions contract never registered with Denshokan
        // (no token passed through dojo_init), so `token_address` comes back as
        // 0x0. The EGC settings component performs an ISRC5 check against
        // `minigame_token_address` inside `create_settings`, which reverts when
        // that contract isn't deployed. Skip the EGC-side registration in that
        // case — the on-chain GameSettings/Metadata rows above are what the
        // game actually reads, and Denshokan lookups are unused in dev.
        if token_address.into() == 0_felt252 {
            return;
        }

        self
            .settings
            .create_settings(
                game_address: actions_address,
                settings_id: 1,
                settings_details: GameSettingDetails {
                    name: "Ascend - Bronze",
                    description: "Ascend tactical roguelike. Bronze tier: 500 stamina budget.",
                    settings: array![
                        GameSetting { name: 'Tier', value: 'Bronze' },
                        GameSetting { name: 'Stamina', value: '500' },
                        GameSetting { name: 'Grid', value: '8x8' },
                        GameSetting { name: 'Class', value: 'Warrior' },
                        GameSetting { name: 'Lives', value: '1' },
                    ]
                        .span(),
                },
                minigame_token_address: token_address,
            );

        self
            .settings
            .create_settings(
                game_address: actions_address,
                settings_id: 2,
                settings_details: GameSettingDetails {
                    name: "Ascend - Silver",
                    description: "Ascend tactical roguelike. Silver tier: 1500 stamina budget.",
                    settings: array![
                        GameSetting { name: 'Tier', value: 'Silver' },
                        GameSetting { name: 'Stamina', value: '1500' },
                        GameSetting { name: 'Grid', value: '8x8' },
                        GameSetting { name: 'Class', value: 'Warrior' },
                        GameSetting { name: 'Lives', value: '1' },
                    ]
                        .span(),
                },
                minigame_token_address: token_address,
            );

        self
            .settings
            .create_settings(
                game_address: actions_address,
                settings_id: 3,
                settings_details: GameSettingDetails {
                    name: "Ascend - Gold",
                    description: "Ascend tactical roguelike. Gold tier: 4000 stamina budget.",
                    settings: array![
                        GameSetting { name: 'Tier', value: 'Gold' },
                        GameSetting { name: 'Stamina', value: '4000' },
                        GameSetting { name: 'Grid', value: '8x8' },
                        GameSetting { name: 'Class', value: 'Warrior' },
                        GameSetting { name: 'Lives', value: '1' },
                    ]
                        .span(),
                },
                minigame_token_address: token_address,
            );
    }

    #[abi(embed_v0)]
    impl GameSettingsImpl of IMinigameSettings<ContractState> {
        fn settings_exist(self: @ContractState, settings_id: u32) -> bool {
            let mut store = StoreTrait::new(self.world(@"athanor_0_1"));
            let s = store.get_game_settings(settings_id);
            s.exists()
        }

        fn settings_exist_batch(self: @ContractState, settings_ids: Span<u32>) -> Array<bool> {
            let mut results = array![];
            let mut i: u32 = 0;
            while i < settings_ids.len() {
                results.append(self.settings_exist(*settings_ids.at(i)));
                i += 1;
            }
            results
        }
    }

    #[abi(embed_v0)]
    impl MinigameSettingsDetailsImpl of IMinigameSettingsDetails<ContractState> {
        fn settings_count(self: @ContractState) -> u32 {
            3
        }

        fn settings_details(self: @ContractState, settings_id: u32) -> GameSettingDetails {
            let mut store = StoreTrait::new(self.world(@"athanor_0_1"));
            let metadata = store.get_game_settings_metadata(settings_id);
            GameSettingDetails {
                name: format!("{}", metadata.name),
                description: "Athanor:Ascend settings",
                settings: array![
                    GameSetting {
                        name: 'Active',
                        value: if metadata.is_active {
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
            let mut i: u32 = 0;
            while i < settings_ids.len() {
                results.append(self.settings_details(*settings_ids.at(i)));
                i += 1;
            }
            results
        }
    }
}
