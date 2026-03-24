#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
pub enum Faction {
    Player,
    Enemy,
}
