//! Binding version of [`keys`].
use libthreema_macros::{Name, UniffiNewType};

use crate::{bindings::uniffi::ConversionError, common::keys, utils::debug::Name as _};

/// Binding version of [`keys::ClientKey`].
///
/// # Contract
///
/// Must be exactly 32 bytes.
#[derive(UniffiNewType)]
pub struct ClientKey(pub Vec<u8>);
impl From<keys::ClientKey> for ClientKey {
    fn from(key: keys::ClientKey) -> Self {
        Self(key.as_bytes().to_vec())
    }
}
impl TryFrom<ClientKey> for keys::ClientKey {
    type Error = ConversionError;

    fn try_from(client_key: ClientKey) -> Result<Self, Self::Error> {
        client_key
            .0
            .as_slice()
            .try_into()
            .map_err(|_| ConversionError::ContractViolation {
                name: Self::NAME.to_owned(),
                reason: format!("Must be {} bytes", Self::LENGTH),
            })
    }
}

/// Binding version of [`keys::PublicKey`].
///
/// # Contract
///
/// Must be exactly 32 bytes.
#[derive(UniffiNewType)]
pub struct PublicKey(pub Vec<u8>);
impl From<keys::PublicKey> for PublicKey {
    fn from(public_key: keys::PublicKey) -> Self {
        Self(public_key.0.to_bytes().to_vec())
    }
}
impl TryFrom<PublicKey> for keys::PublicKey {
    type Error = ConversionError;

    fn try_from(public_key: PublicKey) -> Result<Self, Self::Error> {
        public_key
            .0
            .as_slice()
            .try_into()
            .map_err(|_| ConversionError::ContractViolation {
                name: Self::NAME.to_owned(),
                reason: format!("Must be {} bytes", Self::LENGTH),
            })
    }
}

/// Binding version of [`keys::RemoteSecret`].
///
/// # Contract
///
/// Must be exactly 32 bytes.
#[derive(Name, UniffiNewType)]
#[uniffi_new_type(fixed_size_bytes = keys::RemoteSecret)]
pub struct RemoteSecret(pub Vec<u8>);

/// Binding version of [`keys::RemoteSecretHash`].
///
/// # Contract
///
/// Must be exactly 32 bytes.
#[derive(Name, UniffiNewType)]
#[uniffi_new_type(fixed_size_bytes = keys::RemoteSecretHash)]
pub struct RemoteSecretHash(pub Vec<u8>);

/// Binding version of [`keys::RemoteSecretHashForIdentity`].
///
/// # Contract
///
/// Must be exactly 32 bytes.
#[derive(Name, UniffiNewType)]
#[uniffi_new_type(fixed_size_bytes = keys::RemoteSecretHashForIdentity)]
pub struct RemoteSecretHashForIdentity(pub Vec<u8>);

/// Binding version of [`keys::RemoteSecretAuthenticationToken`].
///
/// # Contract
///
/// Must be exactly 32 bytes.
#[derive(Name, UniffiNewType)]
#[uniffi_new_type(fixed_size_bytes = keys::RemoteSecretAuthenticationToken)]
pub struct RemoteSecretAuthenticationToken(pub Vec<u8>);
