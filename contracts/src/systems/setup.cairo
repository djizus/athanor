// Setup contract (scaffold).
//
// Writes the default Ascend GameSettings + metadata at deploy time so Torii and
// clients can read the intended settings row immediately. EGC SettingsComponent
// wiring (registration with Denshokan) is added in a follow-up step alongside
// the MinigameComponent on Actions.

#[dojo::contract]
pub mod Setup {
    use dojo::world::WorldStorage;
    use starknet::get_block_timestamp;
    use athanor::models::config::{GameSettingsMetadata, GameSettingsTrait};
    use athanor::store::StoreTrait;

    fn dojo_init(ref self: ContractState) {
        let world: WorldStorage = self.world(@"athanor_0_1");
        let timestamp = get_block_timestamp();
        let mut store = StoreTrait::new(world);

        store.set_game_settings(@GameSettingsTrait::new_default());

        let creator_address = starknet::get_tx_info().unbox().account_contract_address;
        store
            .set_game_settings_metadata(
                @GameSettingsMetadata {
                    settings_id: 1,
                    name: 'Ascend',
                    created_by: creator_address,
                    created_at: timestamp,
                    is_active: true,
                },
            );
    }
}
