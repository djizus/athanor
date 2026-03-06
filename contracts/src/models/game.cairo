use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GameSession {
    #[key]
    pub game_id: u64,
    pub player: ContractAddress,
    pub seed: felt252,
    pub settings_id: u32,
    pub discovered_count: u8,
    pub craft_attempts: u16,
    pub hints_used: u8,
    pub gold: u32,
    pub hero_count: u8,
    pub potion_count: u16,
    pub game_over: bool,
    pub started_at: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GameSeed {
    #[key]
    pub game_id: u64,
    pub seed: felt252,
}

// --- Logic ---

#[generate_trait]
pub impl GameSessionImpl of GameSessionTrait {
    fn new(
        game_id: u64, player: ContractAddress, seed: felt252, timestamp: u64,
    ) -> GameSession {
        GameSession {
            game_id,
            player,
            seed,
            settings_id: 0,
            discovered_count: 0,
            craft_attempts: 0,
            hints_used: 0,
            gold: 0,
            hero_count: 1,
            potion_count: 0,
            game_over: false,
            started_at: timestamp,
        }
    }
}

// --- Assertions ---

#[generate_trait]
pub impl GameSessionAssert of GameSessionAssertTrait {
    #[inline]
    fn assert_not_over(self: @GameSession) {
        assert!(!*self.game_over, "Game is over");
    }

    #[inline]
    fn assert_exists(self: @GameSession) {
        assert!(*self.started_at > 0, "Game does not exist");
    }
}
