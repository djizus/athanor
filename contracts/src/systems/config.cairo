use athanor::models::config::GameSettings;

#[starknet::interface]
pub trait IConfigSystem<T> {
    fn get_game_settings(self: @T, settings_id: u32) -> GameSettings;
    fn settings_exists(self: @T, settings_id: u32) -> bool;
}

#[dojo::contract]
pub mod config_system {
    use dojo::model::ModelStorage;
    use dojo::world::WorldStorage;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::{ContractAddress, get_block_timestamp};
    use athanor::constants::DEFAULT_NS;
    use athanor::models::config::{
        GameSettings, GameSettingsMetadata, GameSettingsTrait,
    };
    use super::IConfigSystem;

    #[storage]
    struct Storage {
        settings_counter: u32,
    }

    fn dojo_init(ref self: ContractState, creator_address: ContractAddress) {
        let mut world: WorldStorage = self.world(@DEFAULT_NS());
        let timestamp = get_block_timestamp();

        world.write_model(@GameSettingsTrait::new_default());
        world
            .write_model(
                @GameSettingsMetadata {
                    settings_id: 0,
                    name: 'Default',
                    created_by: creator_address,
                    created_at: timestamp,
                    is_active: true,
                },
            );

        self.settings_counter.write(0);
    }

    #[abi(embed_v0)]
    impl ConfigSystemImpl of IConfigSystem<ContractState> {
        fn get_game_settings(self: @ContractState, settings_id: u32) -> GameSettings {
            let world: WorldStorage = self.world(@DEFAULT_NS());
            world.read_model(settings_id)
        }

        fn settings_exists(self: @ContractState, settings_id: u32) -> bool {
            let world: WorldStorage = self.world(@DEFAULT_NS());
            let settings: GameSettings = world.read_model(settings_id);
            settings.exists()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@DEFAULT_NS())
        }
    }
}
