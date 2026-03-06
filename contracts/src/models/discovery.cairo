use crate::helpers::bitmap::Bitmap;
pub use crate::models::index::Discovery;
use crate::typess::effect::Effect;

pub mod Errors {
    pub const DISCOVERY_IS_DISCOVERED: felt252 = 'Discovery: already found';
}

#[generate_trait]
pub impl DiscoveryImpl of DiscoveryTrait {
    fn discover(ref self: Discovery, effect: Effect) {
        // [Check] Discovery is not already discovered
        self.assert_not_discovered();
        // [Effect] Update discovery
        self.effect = effect.into();
        self.discovered = true;
    }
}

#[generate_trait]
pub impl DiscoveryAssert of AssertTrait {
    fn assert_not_discovered(self: @Discovery) {
        assert(!*self.discovered, Errors::DISCOVERY_IS_DISCOVERED);
    }
}
