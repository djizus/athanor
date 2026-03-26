#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
pub enum Archetype {
    Hero,
    Brute,
    Caster,
    Flanker,
    Heavy,
    Puller,
}
