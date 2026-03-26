#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
pub enum AbilityType {
    Strike,
    Dash,
    Heal,
    Shove,
    Slam,
}

#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
pub enum AbilityTargetMode {
    SingleActor,
    Tile,
    Area,
    SelfActor,
}
