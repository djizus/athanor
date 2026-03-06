#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct FailedCombo {
    #[key]
    pub game_id: u64,
    #[key]
    pub combo_key: u16,
    pub attempted: bool,
}
