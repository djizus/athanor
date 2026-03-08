use crate::constants::MAX_HEROES;
use crate::elements::roles;
use crate::models::character::Character;
pub const ROLE_COUNT: u8 = 3;

#[derive(Drop, Copy, Serde, PartialEq, Debug)]
pub enum Role {
    None,
    Mage,
    Rogue,
    Warrior,
}

#[generate_trait]
pub impl RoleImpl of RoleTrait {
    #[inline]
    fn index(self: Role) -> u8 {
        let id: u8 = self.into();
        id - 1
    }

    #[inline]
    fn from(index: u8) -> Role {
        (index + 1).into()
    }

    #[inline]
    fn spawn(self: Role, ref character: Character) {
        match self {
            Role::Mage => roles::mage::Mage::spawn(ref character),
            Role::Rogue => roles::rogue::Rogue::spawn(ref character),
            Role::Warrior => roles::warrior::Warrior::spawn(ref character),
            _ => (),
        }
    }


    #[inline]
    fn draw(mut bitmap: u8, rng: u128) -> Role {
        let mut eligibles: Array<Role> = array![];
        for index in 0..MAX_HEROES {
            if bitmap % 2 == 0 {
                let role: Role = Self::from(index);
                eligibles.append(role);
            }
            bitmap /= 2;
        }
        let len = eligibles.len();
        if len == 0 {
            return Role::None;
        }
        let index: u32 = (rng % len.into()).try_into().unwrap();
        *eligibles.at(index)
    }
}

pub impl RoleIntoU8 of Into<Role, u8> {
    fn into(self: Role) -> u8 {
        match self {
            Role::None => 0,
            Role::Mage => 1,
            Role::Rogue => 2,
            Role::Warrior => 3,
        }
    }
}

pub impl U8IntoRole of Into<u8, Role> {
    fn into(self: u8) -> Role {
        match self {
            0 => Role::None,
            1 => Role::Mage,
            2 => Role::Rogue,
            3 => Role::Warrior,
            _ => Role::None,
        }
    }
}
