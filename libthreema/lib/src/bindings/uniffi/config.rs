//! Bindings for the configuration.
use core::time::Duration;

use crate::common::{config, keys::PublicKey};

/// Configuration error.
#[derive(Debug, thiserror::Error, uniffi::Error)]
#[uniffi(flat_error)]
pub enum ConfigError {
    /// Invalid parameter provided by foreign code.
    #[error("Invalid parameter in {location}: {reason}")]
    InvalidParameter {
        /// Parameter location in the configuration.
        location: &'static str,
        /// Reason why the parameter is invalid.
        reason: &'static str,
    },

    /// URL error.
    #[error("URL error in {location}: {error}")]
    UrlError {
        /// URL location in the configuration.
        location: &'static str,
        /// Underlying URL error.
        error: config::UrlError,
    },
}

/// Binding version of [`config::BlobServerConfig`].
#[derive(uniffi::Record)]
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
    type Error = ConfigError;

    fn try_from(config: BlobServerConfig) -> Result<Self, Self::Error> {
        Ok(Self {
            upload_url: config::BlobServerUploadUrl::try_from(config.upload_url).map_err(|error| {
                ConfigError::UrlError {
                    location: "Blob server 'upload_url'",
                    error,
                }
            })?,

            download_url: config::BlobServerDownloadUrl::try_from(config.download_url).map_err(|error| {
                ConfigError::UrlError {
                    location: "Blob server 'download_url'",
                    error,
                }
            })?,

            done_url: config::BlobServerDoneUrl::try_from(config.done_url).map_err(|error| {
                ConfigError::UrlError {
                    location: "Blob server 'done_url'",
                    error,
                }
            })?,
        })
    }
}

/// Binding version of [`config::BlobMirrorServerConfig`].
#[derive(uniffi::Record)]
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
    type Error = ConfigError;

    fn try_from(config: BlobMirrorServerConfig) -> Result<Self, Self::Error> {
        Ok(Self {
            upload_url: config::BlobMirrorServerUploadUrl::try_from(config.upload_url).map_err(|error| {
                ConfigError::UrlError {
                    location: "Blob mirror server 'upload_url'",
                    error,
                }
            })?,

            download_url: config::BlobMirrorServerDownloadUrl::try_from(config.download_url).map_err(
                |error| ConfigError::UrlError {
                    location: "Blob mirror server 'download_url'",
                    error,
                },
            )?,

            done_url: config::BlobMirrorServerDoneUrl::try_from(config.done_url).map_err(|error| {
                ConfigError::UrlError {
                    location: "Blob mirror server 'done_url'",
                    error,
                }
            })?,
        })
    }
}

/// Binding version of [`config::MultiDeviceConfig`].
#[derive(uniffi::Record)]
pub struct MultiDeviceConfig {
    #[expect(missing_docs, reason = "Binding version")]
    pub rendezvous_server_url: String,

    #[expect(missing_docs, reason = "Binding version")]
    pub mediator_server_url: String,

    #[expect(missing_docs, reason = "Binding version")]
    pub blob_mirror_server: BlobMirrorServerConfig,
}
impl TryFrom<MultiDeviceConfig> for config::MultiDeviceConfig {
    type Error = ConfigError;

    fn try_from(config: MultiDeviceConfig) -> Result<Self, Self::Error> {
        Ok(Self {
            rendezvous_server_url: config::RendezvousServerBaseUrl::try_from(config.rendezvous_server_url)
                .map_err(|error| ConfigError::UrlError {
                    location: "'rendezvous_server_url'",
                    error,
                })?,

            mediator_server_url: config::MediatorServerBaseUrl::try_from(config.mediator_server_url)
                .map_err(|error| ConfigError::UrlError {
                    location: "'mediator_server_url'",
                    error,
                })?,

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
    pub chat_server_public_keys: Vec<Vec<u8>>,

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
    type Error = ConfigError;

    fn try_from(config: OnPremConfig) -> Result<Self, Self::Error> {
        let chat_server_public_keys = config
            .chat_server_public_keys
            .into_iter()
            .map(|public_key| {
                PublicKey::try_from(public_key.as_slice()).map_err(|_| ConfigError::InvalidParameter {
                    location: "Public key in 'chat_server_public_keys'",
                    reason: "Must be 32 bytes",
                })
            })
            .collect::<Result<Vec<PublicKey>, ConfigError>>()?;

        Ok(config::OnPremConfig {
            version: config.version,

            refresh_interval: Duration::from_secs(config.refresh_interval_s),

            chat_server_address: config.chat_server_address,

            chat_server_public_keys,

            directory_server_url: config::DirectoryServerBaseUrl::try_from(config.directory_server_url)
                .map_err(|error| ConfigError::UrlError {
                    location: "'directory_server_url'",
                    error,
                })?,

            blob_server: config.blob_server.try_into()?,

            work_server_url: config::WorkServerBaseUrl::try_from(config.work_server_url).map_err(
                |error| ConfigError::UrlError {
                    location: "'work_server_url'",
                    error,
                },
            )?,

            gateway_avatar_server_url: config::GatewayAvatarBaseServerUrl::try_from(
                config.gateway_avatar_server_url,
            )
            .map_err(|error| ConfigError::UrlError {
                location: "'gateway_avatar_server_url'",
                error,
            })?,

            safe_server_url: config::SafeServerBaseUrl::try_from(config.safe_server_url).map_err(
                |error| ConfigError::UrlError {
                    location: "'safe_server_url'",
                    error,
                },
            )?,

            multi_device: config.multi_device.map(MultiDeviceConfig::try_into).transpose()?,
        })
    }
}

/// Binding version of [`config::ConfigEnvironment`].
#[derive(uniffi::Enum)]
#[expect(clippy::large_enum_variant, reason = "Uniffi does not support box")]
pub enum ConfigEnvironment {
    #[expect(missing_docs, reason = "Binding version")]
    Sandbox,

    #[expect(missing_docs, reason = "Binding version")]
    Production,

    #[expect(missing_docs, reason = "Binding version")]
    OnPrem(OnPremConfig),
}
impl TryFrom<ConfigEnvironment> for config::ConfigEnvironment {
    type Error = ConfigError;

    fn try_from(environment: ConfigEnvironment) -> Result<Self, Self::Error> {
        match environment {
            ConfigEnvironment::Sandbox => Ok(config::ConfigEnvironment::Sandbox),
            ConfigEnvironment::Production => Ok(config::ConfigEnvironment::Production),
            ConfigEnvironment::OnPrem(config) => Ok(config::ConfigEnvironment::OnPrem(Box::new(
                config::OnPremConfig::try_from(config)?,
            ))),
        }
    }
}
