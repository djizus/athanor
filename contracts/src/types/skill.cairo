use athanor::constants::AA_COST;

#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
pub enum SkillType {
    AutoAttack,
}

#[generate_trait]
pub impl SkillImpl of SkillTrait {
    fn cost(self: SkillType) -> u16 {
        match self {
            SkillType::AutoAttack => AA_COST,
        }
    }
}
