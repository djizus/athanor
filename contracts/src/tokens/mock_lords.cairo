// Dev-only mock LORDS token.
//
// Standard ERC20 with an unrestricted `mint` entrypoint so playtesters can
// top up their balance without a faucet service. NOT for production — real
// LORDS on mainnet is the authority; this contract only exists for the
// Athanor:Ascend dev loop on Katana / slot.

#[starknet::interface]
pub trait IMockLords<T> {
    fn mint(ref self: T, recipient: starknet::ContractAddress, amount: u256);
}

#[starknet::contract]
pub mod mock_lords {
    use openzeppelin::token::erc20::{DefaultConfig, ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc20.initializer("Mock LORDS", "mLORDS");
    }

    #[abi(embed_v0)]
    impl MockLordsImpl of super::IMockLords<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.erc20.mint(recipient, amount);
        }
    }
}
