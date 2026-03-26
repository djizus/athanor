#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
pub enum Phase {
    Explore,
    PlayerTurn,
    EnemyTurn,
    Complete,
    Failed,
}
