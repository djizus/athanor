use athanor::types::direction::Direction;

#[starknet::interface]
trait IActions<T> {
    fn spawn(ref self: T, class_id: u8);
    fn choose(ref self: T, game_id: u32, direction: Direction);
    fn start(ref self: T, game_id: u32);
    fn cast(ref self: T, game_id: u32, mob_id: u8, skill_id: u8);
    fn finish(ref self: T, game_id: u32);
}

#[dojo::contract]
pub mod actions {
    use super::{IActions, Direction};
    use starknet::{ContractAddress, get_caller_address};

    use athanor::constants::{
        MAX_HEALTH, MAX_STAMINA, POWER, MOB_HEALTH, MOB_POWER, AA_COST,
        zone_mob_count, zone_children, is_fork, has_single_exit,
    };
    use athanor::models::index::{Character, Dungeon, Fight};
    use athanor::helpers::packing::{pack_mob_healths, get_mob_health, set_mob_health, count_alive_mobs};
    use athanor::store::{Store, StoreTrait};

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        /// Create a new character and dungeon.
        fn spawn(ref self: ContractState, class_id: u8) {
            let mut store = self.store();
            let player = get_caller_address();

            // Increment game counter
            let mut ps = store.get_player_state(player);
            ps.game_count += 1;
            let game_id = ps.game_count;
            store.set_player_state(@ps);

            // Create character
            let character = Character {
                player,
                game_id,
                class_id,
                health: MAX_HEALTH,
                max_health: MAX_HEALTH,
                power: POWER,
                stamina: MAX_STAMINA,
                max_stamina: MAX_STAMINA,
                current_zone: 0,
            };
            store.set_character(@character);

            // Create dungeon
            let dungeon = Dungeon {
                player,
                game_id,
                zones_cleared: 0,
                completed: false,
                failed: false,
            };
            store.set_dungeon(@dungeon);

            // Emit events
            store.emit_character_spawned(
                player, game_id, class_id, MAX_HEALTH, POWER, MAX_STAMINA,
            );
            store.emit_dungeon_created(player, game_id);
        }

        /// Choose a direction at a fork zone.
        fn choose(ref self: ContractState, game_id: u32, direction: Direction) {
            let mut store = self.store();
            let player = get_caller_address();

            let mut character = store.get_character(player, game_id);
            let dungeon = store.get_dungeon(player, game_id);

            // Validate dungeon state
            assert(!dungeon.completed, 'Dungeon already completed');
            assert(!dungeon.failed, 'Dungeon already failed');

            // Must be at a fork
            let zone = character.current_zone;
            assert(is_fork(zone), 'Not at a fork');

            // Zone must have no mobs or be cleared
            let mob_count = zone_mob_count(zone);
            if mob_count > 0 {
                let zone_bit = self.zone_bit(zone);
                assert(dungeon.zones_cleared & zone_bit != 0, 'Zone combat not resolved');
            }

            // Get target zone
            let (left, right) = zone_children(zone);
            let target = match direction {
                Direction::Left => left,
                Direction::Right => right,
            };
            assert(target != 0xFF, 'Invalid direction');

            // Move to target
            character.current_zone = target;
            store.set_character(@character);
            store.emit_zone_entered(player, game_id, target);

            // Auto-advance through single-exit zones (only if no mobs or mobs=0)
            self.auto_advance(ref store, player, game_id);
        }

        /// Begin combat in the current zone.
        fn start(ref self: ContractState, game_id: u32) {
            let mut store = self.store();
            let player = get_caller_address();

            let character = store.get_character(player, game_id);
            let dungeon = store.get_dungeon(player, game_id);
            let zone = character.current_zone;

            // Validations
            assert(!dungeon.completed, 'Dungeon already completed');
            assert(!dungeon.failed, 'Dungeon already failed');

            let mob_count = zone_mob_count(zone);
            assert(mob_count > 0, 'No mobs in this zone');

            // Zone must not already be cleared
            let zone_bit = self.zone_bit(zone);
            assert(dungeon.zones_cleared & zone_bit == 0, 'Zone already cleared');

            // No active fight
            let existing_fight = store.get_fight(player, game_id, zone);
            assert(!existing_fight.active, 'Fight already active');

            // Create fight with packed mob HPs
            let mob_healths = pack_mob_healths(mob_count, MOB_HEALTH);
            let fight = Fight {
                player,
                game_id,
                zone_id: zone,
                mob_count,
                mob_healths,
                mob_power: MOB_POWER,
                active: true,
            };
            store.set_fight(@fight);

            store.emit_fight_started(player, game_id, zone, mob_count);
        }

        /// Cast a skill on a mob. Can be called multiple times per turn.
        fn cast(ref self: ContractState, game_id: u32, mob_id: u8, skill_id: u8) {
            let mut store = self.store();
            let player = get_caller_address();

            let mut character = store.get_character(player, game_id);
            let dungeon = store.get_dungeon(player, game_id);
            let zone = character.current_zone;

            // Validations
            assert(!dungeon.failed, 'Dungeon already failed');

            let mut fight = store.get_fight(player, game_id, zone);
            assert(fight.active, 'No active fight');
            assert(mob_id < fight.mob_count, 'Invalid mob id');

            // Check mob is alive
            let mob_hp = get_mob_health(fight.mob_healths, mob_id);
            assert(mob_hp > 0, 'Mob already dead');

            // Check stamina (only auto-attack for PoC)
            assert(skill_id == 0, 'Invalid skill'); // 0 = AutoAttack
            assert(character.stamina >= AA_COST, 'Not enough stamina');

            // Spend stamina
            character.stamina -= AA_COST;

            // Deal damage
            let damage = character.power;
            let new_hp = if damage >= mob_hp {
                0_u16
            } else {
                mob_hp - damage
            };

            fight.mob_healths = set_mob_health(fight.mob_healths, mob_id, new_hp);

            // Write state
            store.set_character(@character);
            store.set_fight(@fight);

            // Emit events
            store.emit_mob_damaged(player, game_id, zone, mob_id, damage, new_hp);

            if new_hp == 0 {
                store.emit_mob_died(player, game_id, zone, mob_id);
            }
        }

        /// End the player's turn. Mobs attack, stamina resets.
        fn finish(ref self: ContractState, game_id: u32) {
            let mut store = self.store();
            let player = get_caller_address();

            let mut character = store.get_character(player, game_id);
            let mut dungeon = store.get_dungeon(player, game_id);
            let zone = character.current_zone;

            // Validations
            assert(!dungeon.failed, 'Dungeon already failed');

            let mut fight = store.get_fight(player, game_id, zone);
            assert(fight.active, 'No active fight');

            // --- Mob attack phase ---
            let alive = count_alive_mobs(fight.mob_healths, fight.mob_count);
            let total_damage: u16 = alive.into() * fight.mob_power;

            if total_damage > 0 {
                if total_damage >= character.health {
                    character.health = 0;
                } else {
                    character.health -= total_damage;
                };

                store.emit_player_damaged(player, game_id, total_damage, character.health);
            }

            // --- Check player death ---
            if character.health == 0 {
                fight.active = false;
                dungeon.failed = true;

                store.set_fight(@fight);
                store.set_character(@character);
                store.set_dungeon(@dungeon);

                store.emit_dungeon_failed(player, game_id);
                return;
            }

            // --- Reset stamina ---
            character.stamina = character.max_stamina;

            // --- Check if all mobs dead ---
            if alive == 0 {
                fight.active = false;
                store.set_fight(@fight);

                // Mark zone cleared
                let zone_bit = self.zone_bit(zone);
                dungeon.zones_cleared = dungeon.zones_cleared | zone_bit;

                store.emit_fight_ended(player, game_id, zone);

                // Check dungeon completion (zone 4 = final)
                if zone == 4 {
                    dungeon.completed = true;
                    store.set_character(@character);
                    store.set_dungeon(@dungeon);
                    store.emit_dungeon_completed(player, game_id);
                    return;
                }

                // Auto-advance if single exit
                store.set_character(@character);
                store.set_dungeon(@dungeon);

                if has_single_exit(zone) {
                    let (next_zone, _) = zone_children(zone);
                    character.current_zone = next_zone;
                    store.set_character(@character);
                    store.emit_zone_entered(player, game_id, next_zone);
                }

                return;
            }

            // --- Mobs still alive, turn continues ---
            store.emit_turn_ended(player, game_id, zone);
            store.set_character(@character);
            store.set_fight(@fight);
        }
    }

    // --- Internal helpers ---

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn store(self: @ContractState) -> Store {
            StoreTrait::new(self.world(@"athanor"))
        }

        fn zone_bit(self: @ContractState, zone_id: u8) -> u8 {
            let mut bit: u8 = 1;
            let mut i: u8 = 0;
            while i < zone_id {
                bit = bit * 2;
                i += 1;
            };
            bit
        }

        fn auto_advance(
            self: @ContractState,
            ref store: Store,
            player: ContractAddress,
            game_id: u32,
        ) {
            let mut character = store.get_character(player, game_id);
            let zone = character.current_zone;

            // Only auto-advance if zone has 0 mobs and single exit
            if zone_mob_count(zone) == 0 && has_single_exit(zone) {
                let (next_zone, _) = zone_children(zone);
                character.current_zone = next_zone;
                store.set_character(@character);
                store.emit_zone_entered(player, game_id, next_zone);
            }
        }
    }
}
