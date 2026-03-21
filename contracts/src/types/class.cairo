#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
pub enum ClassType {
    Warrior,
}

pub impl ClassTypeIntoU8 of Into<ClassType, u8> {
    fn into(self: ClassType) -> u8 {
        match self {
            ClassType::Warrior => 0,
        }
    }
}
