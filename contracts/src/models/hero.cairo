#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Hero {
    #[key]
    pub game_id: u64,
    #[key]
    pub hero_id: u8,
    pub hp: u16,
    pub max_hp: u16,
    pub power: u16,
    pub regen_per_sec: u16,
    pub status: u8,
    pub expedition_seed: felt252,
    pub expedition_start: u64,
    pub return_at: u64,
    pub death_depth: u16,
    pub pending_gold: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct HeroPendingIngredient {
    #[key]
    pub game_id: u64,
    #[key]
    pub hero_id: u8,
    #[key]
    pub ingredient_id: u8,
    pub quantity: u16,
}

// --- Logic ---

use athanor::constants;
use athanor::types;

#[generate_trait]
pub impl HeroImpl of HeroTrait {
    /// Create a new hero with base stats.
    fn new(game_id: u64, hero_id: u8) -> Hero {
        Hero {
            game_id,
            hero_id,
            hp: constants::HERO_BASE_HP,
            max_hp: constants::HERO_BASE_HP,
            power: constants::HERO_BASE_POWER,
            regen_per_sec: constants::HERO_BASE_REGEN,
            status: types::HERO_STATUS_IDLE,
            expedition_seed: 0,
            expedition_start: 0,
            return_at: 0,
            death_depth: 0,
            pending_gold: 0,
        }
    }

    /// Apply a potion buff to the hero (permanent stat increase).
    fn apply_buff(ref self: Hero, effect_type: u8, effect_value: u8) {
        if effect_type == types::EFFECT_MAX_HP {
            let buff: u16 = effect_value.into() * 100;
            self.max_hp += buff;
            self.hp += buff;
        } else if effect_type == types::EFFECT_POWER {
            self.power += effect_value.into() * 100;
        } else if effect_type == types::EFFECT_REGEN {
            self.regen_per_sec += effect_value.into() * 10;
        }
    }

    /// Apply idle regen: hero rests from return_at until `now`, HP capped at max.
    fn idle_regen(ref self: Hero, now: u64) {
        let rest_time: u64 = now - self.return_at;
        let regen_amount: u64 = rest_time * self.regen_per_sec.into();
        let total_hp: u64 = self.hp.into() + regen_amount;
        self.hp = if total_hp >= self.max_hp.into() {
            self.max_hp
        } else {
            total_hp.try_into().unwrap()
        };
    }

    /// Reset expedition fields after claiming loot.
    fn complete_expedition(ref self: Hero) {
        self.status = types::HERO_STATUS_IDLE;
        self.death_depth = 0;
        self.expedition_seed = 0;
        self.expedition_start = 0;
        self.return_at = 0;
    }
}

// --- Assertions ---

#[generate_trait]
pub impl HeroAssert of HeroAssertTrait {
    #[inline]
    fn assert_idle(self: @Hero) {
        assert!(*self.status == types::HERO_STATUS_IDLE, "Hero not idle");
    }

    #[inline]
    fn assert_exploring(self: @Hero) {
        assert!(*self.status == types::HERO_STATUS_EXPLORING, "Hero not on expedition");
    }

    #[inline]
    fn assert_alive(self: @Hero) {
        assert!(*self.hp > 0, "Hero has no HP");
    }

    #[inline]
    fn assert_recruited(self: @Hero, hero_count: u8) {
        assert!(*self.hero_id < hero_count, "Hero not recruited");
    }
}
