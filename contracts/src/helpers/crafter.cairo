use crate::helpers::bitmap::Bitmap;
use crate::typess::effect::Effect;

const TOTAL_PROBABILITY: u32 = 100;
const MULTIPLIER: u32 = 10_000;

#[generate_trait]
pub impl Crafter of CrafterTrait {
    /// Returns a random effect from the remaining recipes.
    fn craft(total: u16, mut recipes: u32, seed: u128) -> Effect {
        // [Check] Total cannot be null
        assert(total > 0, 'Crafter: total cannot be null');
        // [Check] No recipes left
        let count = Bitmap::popcount(recipes);
        if count == 0 {
            return Effect::None;
        }
        // [Compute] Calculate probability
        let probability: u32 = count.into() * MULTIPLIER / total.into();
        let random: u32 = (seed % MULTIPLIER.into()).try_into().unwrap();
        if random >= probability {
            return Effect::None;
        }
        // [Compute] Select a random recipe from the recipes
        let mut eligibles: Array<Effect> = array![];
        let mut index: u8 = 0;
        while recipes > 0 {
            index += 1;
            if recipes % 2 == 1 {
                let effect: Effect = index.into();
                eligibles.append(effect);
            }
            recipes /= 2;
        }
        return *eligibles.at((seed % eligibles.len().into()).try_into().unwrap());
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SEED: u128 = 'SEED';

    #[test]
    fn test_crafter_craft_nothing_left() {
        let effect = CrafterTrait::craft(1, 0, SEED);
        assert_eq!(effect, Effect::None, "Must return None when no recipes left");
    }

    #[test]
    fn test_crafter_craft_one_left() {
        let effect = CrafterTrait::craft(1, 1, SEED);
        assert_eq!(effect, Effect::Blue, "Must return Blue when one recipe left");
    }
}
