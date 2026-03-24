#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
pub enum AbilityType {
    Strike,
    Dash,
    Cleave,
    Fireball,
    Guard,
}

#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
pub enum AbilityTargetMode {
    SingleActor,
    Tile,
    Area,
    SelfActor,
}
