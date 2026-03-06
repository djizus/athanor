use core::num::traits::Zero;
use core::pedersen::pedersen;
use core::poseidon::poseidon_hash_span;
use starknet::{
    ContractAddress, get_block_timestamp, get_caller_address, get_contract_address, get_tx_info,
};
use athanor::interfaces::vrf::{IVrfProviderDispatcher, IVrfProviderDispatcherTrait, Source};

#[derive(Copy, Drop, Serde)]
pub struct Random {
    pub seed: felt252,
    pub nonce: usize,
}

#[generate_trait]
pub impl RandomImpl of RandomTrait {
    fn new_vrf(salt: felt252) -> Random {
        let vrf_address: ContractAddress = 0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f
            .try_into()
            .unwrap();
        let vrf_provider = IVrfProviderDispatcher { contract_address: vrf_address };
        let seed = vrf_provider.consume_random(Source::Salt(salt));
        Random { seed, nonce: 0 }
    }

    fn from_vrf_address(vrf_address: ContractAddress, salt: felt252) -> Random {
        if vrf_address.is_zero() {
            Self::new_pseudo_random()
        } else {
            let vrf_provider = IVrfProviderDispatcher { contract_address: vrf_address };
            let seed = vrf_provider.consume_random(Source::Salt(salt));
            Random { seed, nonce: 0 }
        }
    }

    fn new_pseudo_random() -> Random {
        let tx_info = get_tx_info().unbox();
        let caller = get_caller_address();
        let contract = get_contract_address();
        let timestamp: felt252 = get_block_timestamp().into();

        let seed = poseidon_hash_span(
            array![
                tx_info.transaction_hash, caller.into(), contract.into(), timestamp, tx_info.nonce,
            ]
                .span(),
        );

        Random { seed, nonce: 0 }
    }

    fn next_seed(ref self: Random) -> felt252 {
        self.nonce += 1;
        self.seed = pedersen(self.seed, self.nonce.into());
        self.seed
    }

    fn next_u128(ref self: Random) -> u128 {
        let seed256: u256 = self.next_seed().into();
        seed256.low
    }

    fn next_bounded(ref self: Random, bound: u32) -> u32 {
        if bound == 0 {
            return 0;
        }
        let val = self.next_u128();
        (val % bound.into()).try_into().unwrap()
    }
}
