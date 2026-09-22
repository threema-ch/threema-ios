//! Binding version of [`settings`].
use std::sync::Arc;

use crate::{
    bindings::uniffi::{ConversionError, common::ThreemaId},
    common,
    model::settings,
    protobuf::{self, d2d_sync::settings as protobuf_settings},
    provider::ProviderError,
};

/// Binding version of [`settings::SettingsUpdate`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct SettingsUpdate {
    pub contact_sync_policy: Option<protobuf_settings::ContactSyncPolicy>,
    pub unknown_contact_policy: Option<protobuf_settings::UnknownContactPolicy>,
    pub read_receipt_policy: Option<protobuf::d2d_sync::ReadReceiptPolicy>,
    pub typing_indicator_policy: Option<protobuf::d2d_sync::TypingIndicatorPolicy>,
    pub o2o_call_policy: Option<protobuf_settings::O2oCallPolicy>,
    pub o2o_call_connection_policy: Option<protobuf_settings::O2oCallConnectionPolicy>,
    pub o2o_call_video_policy: Option<protobuf_settings::O2oCallVideoPolicy>,
    pub group_call_policy: Option<protobuf_settings::GroupCallPolicy>,
    pub screenshot_policy: Option<protobuf_settings::ScreenshotPolicy>,
    pub blocked_identities: Option<Vec<ThreemaId>>,
    pub exclude_from_sync_identities: Option<Vec<ThreemaId>>,
}
impl From<settings::SettingsUpdate> for SettingsUpdate {
    fn from(update: settings::SettingsUpdate) -> Self {
        Self {
            contact_sync_policy: update.contact_sync_policy,
            unknown_contact_policy: update.unknown_contact_policy,
            read_receipt_policy: update.read_receipt_policy,
            typing_indicator_policy: update.typing_indicator_policy,
            o2o_call_policy: update.o2o_call_policy,
            o2o_call_connection_policy: update.o2o_call_connection_policy,
            o2o_call_video_policy: update.o2o_call_video_policy,
            group_call_policy: update.group_call_policy,
            screenshot_policy: update.screenshot_policy,
            blocked_identities: update
                .blocked_identities
                .map(|identities| identities.into_iter().map(ThreemaId::from).collect()),
            exclude_from_sync_identities: update
                .exclude_from_sync_identities
                .map(|identities| identities.into_iter().map(ThreemaId::from).collect()),
        }
    }
}

/// Binding version of [`settings::Settings`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct Settings {
    pub contact_sync_policy: protobuf_settings::ContactSyncPolicy,
    pub unknown_contact_policy: protobuf_settings::UnknownContactPolicy,
    pub read_receipt_policy: protobuf::d2d_sync::ReadReceiptPolicy,
    pub typing_indicator_policy: protobuf::d2d_sync::TypingIndicatorPolicy,
    pub o2o_call_policy: protobuf_settings::O2oCallPolicy,
    pub o2o_call_connection_policy: protobuf_settings::O2oCallConnectionPolicy,
    pub o2o_call_video_policy: protobuf_settings::O2oCallVideoPolicy,
    pub group_call_policy: protobuf_settings::GroupCallPolicy,
    pub screenshot_policy: protobuf_settings::ScreenshotPolicy,
    pub blocked_identities: Vec<ThreemaId>,
    pub exclude_from_sync_identities: Vec<ThreemaId>,
}
impl From<settings::Settings> for Settings {
    fn from(settings: settings::Settings) -> Self {
        Self {
            contact_sync_policy: settings.contact_sync_policy,
            unknown_contact_policy: settings.unknown_contact_policy,
            read_receipt_policy: settings.read_receipt_policy,
            typing_indicator_policy: settings.typing_indicator_policy,
            o2o_call_policy: settings.o2o_call_policy,
            o2o_call_connection_policy: settings.o2o_call_connection_policy,
            o2o_call_video_policy: settings.o2o_call_video_policy,
            group_call_policy: settings.group_call_policy,
            screenshot_policy: settings.screenshot_policy,
            blocked_identities: settings
                .blocked_identities
                .into_iter()
                .map(ThreemaId::from)
                .collect(),
            exclude_from_sync_identities: settings
                .exclude_from_sync_identities
                .into_iter()
                .map(ThreemaId::from)
                .collect(),
        }
    }
}
impl TryFrom<Settings> for settings::Settings {
    type Error = ConversionError;

    fn try_from(settings: Settings) -> Result<Self, Self::Error> {
        Ok(Self {
            contact_sync_policy: settings.contact_sync_policy,
            unknown_contact_policy: settings.unknown_contact_policy,
            read_receipt_policy: settings.read_receipt_policy,
            typing_indicator_policy: settings.typing_indicator_policy,
            o2o_call_policy: settings.o2o_call_policy,
            o2o_call_connection_policy: settings.o2o_call_connection_policy,
            o2o_call_video_policy: settings.o2o_call_video_policy,
            group_call_policy: settings.group_call_policy,
            screenshot_policy: settings.screenshot_policy,
            blocked_identities: settings
                .blocked_identities
                .into_iter()
                .map(common::ThreemaId::try_from)
                .collect::<Result<_, _>>()?,
            exclude_from_sync_identities: settings
                .exclude_from_sync_identities
                .into_iter()
                .map(common::ThreemaId::try_from)
                .collect::<Result<_, _>>()?,
        })
    }
}

/// Binding version of [`settings::SettingsProvider`].
#[expect(missing_docs, clippy::missing_errors_doc, reason = "Binding version")]
#[uniffi::export(with_foreign)]
pub trait SettingsProvider: Send + Sync {
    fn set(&self, settings: Settings) -> Result<(), ProviderError>;
    fn update(&self, update: SettingsUpdate) -> Result<(), ProviderError>;
    fn get(&self) -> Result<Settings, ProviderError>;
}
impl<T: SettingsProvider + ?Sized> settings::SettingsProvider for Arc<T> {
    fn set(&mut self, settings: settings::Settings) -> Result<(), ProviderError> {
        SettingsProvider::set(self.as_ref(), settings.into())
    }

    fn update(&mut self, update: settings::SettingsUpdate) -> Result<(), ProviderError> {
        SettingsProvider::update(self.as_ref(), update.into())
    }

    fn get(&self) -> Result<settings::Settings, ProviderError> {
        Ok(SettingsProvider::get(self.as_ref())?.try_into()?)
    }
}
