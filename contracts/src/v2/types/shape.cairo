#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
pub enum ShapeType {
    SingleTile,
    Line,
    Cone,
    Circle,
}
