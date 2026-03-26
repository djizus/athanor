#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
pub enum Direction {
    North,
    East,
    South,
    West,
}
