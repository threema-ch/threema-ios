//! Tasks for beginning and committing (or aborting) a transaction.
pub mod begin;
pub mod commit;
pub(crate) mod manager;

#[cfg(test)]
mod tests {
    use core::cell::RefCell;

    use crate::{
        cli::provider::{InMemoryDb, InMemoryDbInit},
        common::{D2xDeviceId, ThreemaId, keys::DeviceGroupKey},
        csp_e2e::{D2xContext, D2xContextInit},
        model::{settings::Settings, user_profile::UserProfile},
    };

    pub(super) fn d2x_context() -> D2xContext {
        let mut database = InMemoryDb::from(InMemoryDbInit {
            user_identity: ThreemaId::try_from("FCKWEIDL").unwrap(),
            user_profile: UserProfile::default(),
            settings: Settings::default(),
            contacts: vec![],
            distribution_lists: vec![],
            groups: vec![],
            csp_nonces: vec![],
            polls: vec![],
            messages: vec![],
        });

        D2xContextInit {
            device_id: D2xDeviceId(0x01),
            device_group_key: DeviceGroupKey::from([0xab_u8; DeviceGroupKey::LENGTH]),
            nonce_provider: Box::new(RefCell::new(database.d2d_nonce_provider())),
        }
        .into()
    }
}
