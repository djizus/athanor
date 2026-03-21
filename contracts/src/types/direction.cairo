#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
pub enum Direction {
    Left,
    Right,
}
