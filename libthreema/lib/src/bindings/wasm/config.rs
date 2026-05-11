//! Bindings for the configuration.
use core::time::Duration;

use js_sys::Error;
use serde::Deserialize;
use serde_bytes::ByteBuf;
use tsify::Tsify;

use crate::common::{config, keys::PublicKey};

/// Binding version of [`config::BlobServerConfig`].
#[derive(Tsify, Deserialize)]
#[serde(rename_all = "camelCase")]
#[tsify(from_wasm_abi)]
#[expect(clippy::struct_field_names, reason = "All fields intentionally end with URL")]
pub struct BlobServerConfig {
    #[expect(missing_docs, reason = "Binding version")]
    pub upload_url: String,

    #[expect(missing_docs, reason = "Binding version")]
    pub download_url: String,

    #[expect(missing_docs, reason = "Binding version")]
    pub done_url: String,
}
impl TryFrom<BlobServerConfig> for config::BlobServerConfig {
    type Error = Error;

    fn try_from(config: BlobServerConfig) -> Result<Self, Self::Error> {
        Ok(Self {
            upload_url: config::BlobServerUploadUrl::try_from(config.upload_url)
                .map_err(|error| Error::new(&format!("Blob server 'upload_url' invalid: {error}")))?,

            download_url: config::BlobServerDownloadUrl::try_from(config.download_url)
                .map_err(|error| Error::new(&format!("Blob server 'download_url' invalid: {error}")))?,

            done_url: config::BlobServerDoneUrl::try_from(config.done_url)
                .map_err(|error| Error::new(&format!("Blob server 'done_url' invalid: {error}")))?,
        })
    }
}

/// Binding version of [`config::BlobMirrorServerConfig`].
#[derive(Tsify, Deserialize)]
#[serde(rename_all = "camelCase")]
#[tsify(from_wasm_abi)]
#[expect(clippy::struct_field_names, reason = "All fields intentionally end with URL")]
pub struct BlobMirrorServerConfig {
    #[expect(missing_docs, reason = "Binding version")]
    pub upload_url: String,

    #[expect(missing_docs, reason = "Binding version")]
    pub download_url: String,

    #[expect(missing_docs, reason = "Binding version")]
    pub done_url: String,
}
impl TryFrom<BlobMirrorServerConfig> for config::BlobMirrorServerConfig {
    type Error = Error;

    fn try_from(config: BlobMirrorServerConfig) -> Result<Self, Self::Error> {
        Ok(Self {
            upload_url: config::BlobMirrorServerUploadUrl::try_from(config.upload_url)
                .map_err(|error| Error::new(&format!("Blob mirror server 'upload_url' invalid: {error}")))?,

            download_url: config::BlobMirrorServerDownloadUrl::try_from(config.download_url).map_err(
                |error| Error::new(&format!("Blob mirror server 'download_url' invalid: {error}")),
            )?,

            done_url: config::BlobMirrorServerDoneUrl::try_from(config.done_url)
                .map_err(|error| Error::new(&format!("Blob mirror server 'done_url' invalid: {error}")))?,
        })
    }
}

/// Binding version of [`config::MultiDeviceConfig`].
#[derive(Tsify, Deserialize)]
#[serde(rename_all = "camelCase")]
#[tsify(from_wasm_abi)]
pub struct MultiDeviceConfig {
    #[expect(missing_docs, reason = "Binding version")]
    pub rendezvous_server_url: String,

    #[expect(missing_docs, reason = "Binding version")]
    pub mediator_server_url: String,

    #[expect(missing_docs, reason = "Binding version")]
    pub blob_mirror_server: BlobMirrorServerConfig,
}
impl TryFrom<MultiDeviceConfig> for config::MultiDeviceConfig {
    type Error = Error;

    fn try_from(config: MultiDeviceConfig) -> Result<Self, Self::Error> {
        Ok(Self {
            rendezvous_server_url: config::RendezvousServerBaseUrl::try_from(config.rendezvous_server_url)
                .map_err(|error| Error::new(&format!("'rendezvous_server_url' invalid: {error}")))?,

            mediator_server_url: config::MediatorServerBaseUrl::try_from(config.mediator_server_url)
                .map_err(|error| Error::new(&format!("'mediator_server_url' invalid: {error}")))?,

            blob_mirror_server: config.blob_mirror_server.try_into()?,
        })
    }
}

/// Binding version of [`config::OnPremConfig`].
#[derive(Tsify, Deserialize)]
#[serde(rename_all = "camelCase")]
#[tsify(from_wasm_abi)]
pub struct OnPremConfig {
    #[expect(missing_docs, reason = "Binding version")]
    pub version: config::OnPremConfigVersion,

    /// Configuration refresh interval in seconds.
    pub refresh_interval_s: u64,

    #[expect(missing_docs, reason = "Binding version")]
    pub chat_server_address: config::ChatServerAddress,

    #[expect(missing_docs, reason = "Binding version")]
    pub chat_server_public_keys: Vec<ByteBuf>,

    #[expect(missing_docs, reason = "Binding version")]
    pub directory_server_url: String,

    #[expect(missing_docs, reason = "Binding version")]
    pub blob_server: BlobServerConfig,

    #[expect(missing_docs, reason = "Binding version")]
    pub work_server_url: String,

    #[expect(missing_docs, reason = "Binding version")]
    pub gateway_avatar_server_url: String,

    #[expect(missing_docs, reason = "Binding version")]
    pub safe_server_url: String,

    #[expect(missing_docs, reason = "Binding version")]
    pub multi_device: Option<MultiDeviceConfig>,
}
impl TryFrom<OnPremConfig> for config::OnPremConfig {
    type Error = Error;

    fn try_from(config: OnPremConfig) -> Result<Self, Self::Error> {
        let chat_server_public_keys = config
            .chat_server_public_keys
            .into_iter()
            .map(|public_key| {
                PublicKey::try_from(public_key.as_slice())
                    .map_err(|_| Error::new("Public key in 'chat_server_public_keys' must be 32 bytes"))
            })
            .collect::<Result<Vec<PublicKey>, Error>>()?;

        Ok(config::OnPremConfig {
            version: config.version,

            refresh_interval: Duration::from_secs(config.refresh_interval_s),

            chat_server_address: config.chat_server_address,

            chat_server_public_keys,

            directory_server_url: config::DirectoryServerBaseUrl::try_from(config.directory_server_url)
                .map_err(|error| Error::new(&format!("'directory_server_url' invalid: {error}")))?,

            blob_server: config.blob_server.try_into()?,

            work_server_url: config::WorkServerBaseUrl::try_from(config.work_server_url)
                .map_err(|error| Error::new(&format!("'work_server_url' invalid: {error}")))?,

            gateway_avatar_server_url: config::GatewayAvatarBaseServerUrl::try_from(
                config.gateway_avatar_server_url,
            )
            .map_err(|error| Error::new(&format!("'gateway_avatar_server_url' invalid: {error}")))?,

            safe_server_url: config::SafeServerBaseUrl::try_from(config.safe_server_url)
                .map_err(|error| Error::new(&format!("'safe_server_url' invalid: {error}")))?,

            multi_device: config.multi_device.map(MultiDeviceConfig::try_into).transpose()?,
        })
    }
}

/// Binding version of [`config::ConfigEnvironment`].
#[derive(Tsify, Deserialize)]
#[serde(
    tag = "type",
    content = "value",
    rename_all = "kebab-case",
    rename_all_fields = "camelCase"
)]
#[tsify(from_wasm_abi)]
pub enum ConfigEnvironment {
    #[expect(missing_docs, reason = "Binding version")]
    Sandbox,

    #[expect(missing_docs, reason = "Binding version")]
    Production,

    #[expect(missing_docs, reason = "Binding version")]
    OnPrem(Box<OnPremConfig>),
}
impl TryFrom<ConfigEnvironment> for config::ConfigEnvironment {
    type Error = Error;

    fn try_from(environment: ConfigEnvironment) -> Result<Self, Self::Error> {
        match environment {
            ConfigEnvironment::Sandbox => Ok(config::ConfigEnvironment::Sandbox),
            ConfigEnvironment::Production => Ok(config::ConfigEnvironment::Production),
            ConfigEnvironment::OnPrem(config) => Ok(config::ConfigEnvironment::OnPrem(Box::new(
                config::OnPremConfig::try_from(*config)?,
            ))),
        }
    }
}
