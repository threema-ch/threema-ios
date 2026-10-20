//! Bindings for the configuration.
use core::time::Duration;

use duplicate::duplicate_item;
use libthreema_macros::{Name, UniffiNewType};

use crate::{
    bindings::uniffi::{ConversionError, common::keys::PublicKey},
    common::config,
};

#[duplicate_item(
    https_base_url_type;
    [ DirectoryServerBaseUrl ];
    [ WorkServerLegacyBaseUrl ];
    [ WorkServerBaseUrl ];
    [ GatewayAvatarBaseServerUrl ];
    [ SafeServerBaseUrl ];
)]
/// Binding version of the URL defined in [`config`].
///
/// # Contract
///
/// Must have the following syntax: `https://<host>/<path>/`.
///
/// The trailing slash is required!
#[derive(Name, UniffiNewType)]
#[uniffi_new_type(string = config::https_base_url_type)]
pub struct https_base_url_type(pub String);

#[duplicate_item(
    wss_base_url_type;
    [ RendezvousServerBaseUrl ];
    [ MediatorServerBaseUrl ];
)]
/// Binding version of the URL defined in [`config`].
///
/// # Contract
///
/// Must have the following syntax: `wss://<host>/<path>/`.
///
/// The trailing slash is required!
#[derive(Name, UniffiNewType)]
#[uniffi_new_type(string = config::wss_base_url_type)]
pub struct wss_base_url_type(pub String);

#[duplicate_item(
    url_type;
    [ OnPremConfigUrl ];
    [ BlobServerUploadUrl ];
    [ BlobServerDownloadUrl ];
    [ BlobServerDoneUrl ];
    [ BlobMirrorServerUploadUrl ];
    [ BlobMirrorServerDownloadUrl ];
    [ BlobMirrorServerDoneUrl ];
)]
/// Binding version of the URL defined in [`config`].
///
/// # Contract
///
/// Must have the following syntax: `https://<host>/<path>`.
#[derive(Name, UniffiNewType)]
#[uniffi_new_type(string = config::url_type)]
pub struct url_type(pub String);

/// Binding version of [`config::BlobServerConfig`].
#[derive(uniffi::Record)]
#[expect(clippy::struct_field_names, reason = "All fields intentionally end with URL")]
#[expect(missing_docs, reason = "Binding version")]
pub struct BlobServerConfig {
    pub upload_url: BlobServerUploadUrl,
    pub download_url: BlobServerDownloadUrl,
    pub done_url: BlobServerDoneUrl,
}
impl TryFrom<BlobServerConfig> for config::BlobServerConfig {
    type Error = ConversionError;

    fn try_from(config: BlobServerConfig) -> Result<Self, Self::Error> {
        Ok(Self {
            upload_url: config.upload_url.try_into()?,
            download_url: config.download_url.try_into()?,
            done_url: config.done_url.try_into()?,
        })
    }
}

/// Binding version of [`config::BlobMirrorServerConfig`].
#[derive(uniffi::Record)]
#[expect(clippy::struct_field_names, reason = "All fields intentionally end with URL")]
#[expect(missing_docs, reason = "Binding version")]
pub struct BlobMirrorServerConfig {
    pub upload_url: BlobMirrorServerUploadUrl,
    pub download_url: BlobMirrorServerDownloadUrl,
    pub done_url: BlobMirrorServerDoneUrl,
}
impl TryFrom<BlobMirrorServerConfig> for config::BlobMirrorServerConfig {
    type Error = ConversionError;

    fn try_from(config: BlobMirrorServerConfig) -> Result<Self, Self::Error> {
        Ok(Self {
            upload_url: config.upload_url.try_into()?,
            download_url: config.download_url.try_into()?,
            done_url: config.done_url.try_into()?,
        })
    }
}

/// Binding version of [`config::MultiDeviceConfig`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct MultiDeviceConfig {
    pub rendezvous_server_url: RendezvousServerBaseUrl,
    pub mediator_server_url: MediatorServerBaseUrl,
    pub blob_mirror_server: BlobMirrorServerConfig,
}
impl TryFrom<MultiDeviceConfig> for config::MultiDeviceConfig {
    type Error = ConversionError;

    fn try_from(config: MultiDeviceConfig) -> Result<Self, Self::Error> {
        Ok(Self {
            rendezvous_server_url: config.rendezvous_server_url.try_into()?,
            mediator_server_url: config.mediator_server_url.try_into()?,
            blob_mirror_server: config.blob_mirror_server.try_into()?,
        })
    }
}

/// Binding version of [`config::OnPremConfig`].
#[derive(uniffi::Record)]
pub struct OnPremConfig {
    #[expect(missing_docs, reason = "Binding version")]
    pub version: config::OnPremConfigVersion,

    /// Configuration refresh interval in seconds.
    pub refresh_interval_s: u64,

    #[expect(missing_docs, reason = "Binding version")]
    pub chat_server_address: config::ChatServerAddress,

    #[expect(missing_docs, reason = "Binding version")]
    pub chat_server_public_keys: Vec<PublicKey>,

    #[expect(missing_docs, reason = "Binding version")]
    pub directory_server_url: DirectoryServerBaseUrl,

    #[expect(missing_docs, reason = "Binding version")]
    pub blob_server: BlobServerConfig,

    #[expect(missing_docs, reason = "Binding version")]
    pub work_server_url: WorkServerBaseUrl,

    #[expect(missing_docs, reason = "Binding version")]
    pub gateway_avatar_server_url: GatewayAvatarBaseServerUrl,

    #[expect(missing_docs, reason = "Binding version")]
    pub safe_server_url: SafeServerBaseUrl,

    #[expect(missing_docs, reason = "Binding version")]
    pub multi_device: Option<MultiDeviceConfig>,
}

impl TryFrom<OnPremConfig> for config::OnPremConfig {
    type Error = ConversionError;

    fn try_from(config: OnPremConfig) -> Result<Self, Self::Error> {
        Ok(Self {
            version: config.version,
            refresh_interval: Duration::from_secs(config.refresh_interval_s),
            chat_server_address: config.chat_server_address,
            chat_server_public_keys: config
                .chat_server_public_keys
                .into_iter()
                .map(PublicKey::try_into)
                .collect::<Result<_, _>>()?,
            directory_server_url: config.directory_server_url.try_into()?,
            blob_server: config.blob_server.try_into()?,
            work_server_url: config.work_server_url.try_into()?,
            gateway_avatar_server_url: config.gateway_avatar_server_url.try_into()?,
            safe_server_url: config.safe_server_url.try_into()?,
            multi_device: config.multi_device.map(MultiDeviceConfig::try_into).transpose()?,
        })
    }
}

/// Binding version of [`config::ConfigEnvironment`].
#[derive(uniffi::Enum)]
#[expect(clippy::large_enum_variant, reason = "Uniffi does not support box")]
#[expect(missing_docs, reason = "Binding version")]
pub enum ConfigEnvironment {
    Sandbox,
    Production,
    OnPrem(OnPremConfig),
}
impl TryFrom<ConfigEnvironment> for config::ConfigEnvironment {
    type Error = ConversionError;

    fn try_from(environment: ConfigEnvironment) -> Result<Self, Self::Error> {
        match environment {
            ConfigEnvironment::Sandbox => Ok(Self::Sandbox),
            ConfigEnvironment::Production => Ok(Self::Production),
            ConfigEnvironment::OnPrem(config) => {
                Ok(Self::OnPrem(Box::new(config::OnPremConfig::try_from(config)?)))
            },
        }
    }
}
