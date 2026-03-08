#[derive(Copy, Drop)]
pub enum Category {
    None,
    Trap,
    Gold,
    Heal,
    BeastWin,
    BeastLose,
    Ingredient,
}

pub impl CategoryIntoU8 of Into<Category, u8> {
    fn into(self: Category) -> u8 {
        match self {
            Category::None => 0,
            Category::Trap => 1,
            Category::Gold => 2,
            Category::Heal => 3,
            Category::BeastWin => 4,
            Category::BeastLose => 5,
            Category::Ingredient => 6,
        }
    }
}

pub impl U8IntoCategory of Into<u8, Category> {
    fn into(self: u8) -> Category {
        match self {
            0 => Category::None,
            1 => Category::Trap,
            2 => Category::Gold,
            3 => Category::Heal,
            4 => Category::BeastWin,
            5 => Category::BeastLose,
            6 => Category::Ingredient,
            _ => Category::None,
        }
    }
}
