use athanor::interfaces::vrf::{IVrfProviderDispatcher, IVrfProviderDispatcherTrait, Source};
use core::num::traits::Zero;
use core::poseidon::poseidon_hash_span;
use starknet::{ContractAddress, get_tx_info};

#[derive(Copy, Drop, Serde)]
pub struct Random {
    pub seed: felt252,
    pub nonce: usize,
}

#[generate_trait]
pub impl RandomImpl of RandomTrait {
    #[inline]
    fn new(vrf_address: ContractAddress, salt: felt252) -> Random {
        if vrf_address.is_zero() {
            Self::gen()
        } else {
            let vrf_provider = IVrfProviderDispatcher { contract_address: vrf_address };
            let seed = vrf_provider.consume_random(Source::Salt(salt));
            Random { seed, nonce: 0 }
        }
    }

    #[inline]
    fn gen() -> Random {
        Random { seed: get_tx_info().transaction_hash, nonce: 0 }
    }

    fn next_seed(ref self: Random) -> felt252 {
        self.nonce += 1;
        self.seed = poseidon_hash_span(array![self.seed, self.nonce.into()].span());
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
