//! Bindings for the Threema ID backup.
use crate::{
    bindings::uniffi::common::{ThreemaId, keys::ClientKey},
    id_backup::{self, IdentityBackupError},
};

/// Binding version of [`id_backup::IdentityBackupData`].
#[derive(uniffi::Record)]
pub struct IdentityBackupData {
    /// The user's identity.
    pub identity: ThreemaId,

    /// Client key (32 bytes).
    pub client_key: ClientKey,
}
impl From<id_backup::IdentityBackupData> for IdentityBackupData {
    fn from(backup_data: id_backup::IdentityBackupData) -> Self {
        Self {
            identity: backup_data.identity.into(),
            client_key: backup_data.client_key.into(),
        }
    }
}
impl TryFrom<IdentityBackupData> for id_backup::IdentityBackupData {
    type Error = IdentityBackupError;

    fn try_from(backup_data: IdentityBackupData) -> Result<Self, Self::Error> {
        Ok(Self {
            identity: backup_data.identity.try_into()?,
            client_key: backup_data.client_key.try_into()?,
        })
    }
}

/// Binding version of [`id_backup::encrypt_identity_backup`].
///
/// # Errors
///
/// Returns [`IdentityBackupError::InvalidParameter`] if `backup_data` is invalid.
#[uniffi::export]
pub fn encrypt_identity_backup(
    password: &str,
    backup_data: IdentityBackupData,
) -> Result<String, IdentityBackupError> {
    id_backup::encrypt_identity_backup(password, &id_backup::IdentityBackupData::try_from(backup_data)?)
}

/// Binding version of [`id_backup::decrypt_identity_backup`].
#[expect(clippy::missing_errors_doc, reason = "Binding version")]
#[uniffi::export]
pub fn decrypt_identity_backup(
    password: &str,
    encrypted_backup: &str,
) -> Result<IdentityBackupData, IdentityBackupError> {
    let (_, backup_data) = id_backup::decrypt_identity_backup(password, encrypted_backup)?;
    Ok(IdentityBackupData::from(backup_data))
}
