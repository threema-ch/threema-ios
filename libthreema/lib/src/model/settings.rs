//! Settings related structs.
use libthreema_macros::Name;

use crate::{
    common::ThreemaId,
    protobuf::{self, d2d_sync::settings as protobuf_settings},
    provider::ProviderError,
    utils::update::{Apply, ApplySome as _},
};

/// The settings.
//-
// IMPORTANT: When touching these, always make sure to update [`SettingsUpdate`] and [`Settings::apply`]
// accordingly.
#[derive(Clone, Debug, Name)]
#[cfg_attr(test, derive(PartialEq))]
pub struct Settings {
    /// Unknown contacts policy.
    pub unknown_contact_policy: protobuf_settings::UnknownContactPolicy,

    /// Read receipt policy when a message has been read.
    pub read_receipt_policy: protobuf::d2d_sync::ReadReceiptPolicy,

    /// Typing indicator policy.
    pub typing_indicator_policy: protobuf::d2d_sync::TypingIndicatorPolicy,

    /// Threema 1:1 Call policy.
    pub o2o_call_policy: protobuf_settings::O2oCallPolicy,

    /// Threema 1:1 Call connection policy.
    pub o2o_call_connection_policy: protobuf_settings::O2oCallConnectionPolicy,

    /// Threema 1:1 Call video policy.
    pub o2o_call_video_policy: protobuf_settings::O2oCallVideoPolicy,

    /// Threema Group Call policy.
    pub group_call_policy: protobuf_settings::GroupCallPolicy,

    /// Screenshot policy.
    pub screenshot_policy: protobuf_settings::ScreenshotPolicy,

    /// Threema IDs whose messages are blocked.
    ///
    /// Note: The user's identity will be ignored (but not filtered).
    pub blocked_identities: Vec<ThreemaId>,

    /// Threema IDs to be excluded when syncing the contact list.
    ///
    /// Note: The user's identity will be ignored (but not filtered).
    pub exclude_from_sync_identities: Vec<ThreemaId>,
}
#[cfg(any(test, feature = "cli"))]
impl Default for Settings {
    fn default() -> Self {
        Self {
            unknown_contact_policy: protobuf_settings::UnknownContactPolicy::AllowUnknown,
            read_receipt_policy: protobuf::d2d_sync::ReadReceiptPolicy::SendReadReceipt,
            typing_indicator_policy: protobuf::d2d_sync::TypingIndicatorPolicy::SendTypingIndicator,
            o2o_call_policy: protobuf_settings::O2oCallPolicy::AllowO2oCall,
            o2o_call_connection_policy: protobuf_settings::O2oCallConnectionPolicy::AllowDirectConnection,
            o2o_call_video_policy: protobuf_settings::O2oCallVideoPolicy::AllowVideo,
            group_call_policy: protobuf_settings::GroupCallPolicy::AllowGroupCall,
            screenshot_policy: protobuf_settings::ScreenshotPolicy::AllowScreenshot,
            blocked_identities: vec![],
            exclude_from_sync_identities: vec![],
        }
    }
}

/// An update to the settings.
#[derive(Clone, Debug, Name)]
pub struct SettingsUpdate {
    /// Unknown contacts policy.
    pub unknown_contact_policy: Option<protobuf_settings::UnknownContactPolicy>,

    /// Read receipt policy when a message has been read.
    pub read_receipt_policy: Option<protobuf::d2d_sync::ReadReceiptPolicy>,

    /// Typing indicator policy.
    pub typing_indicator_policy: Option<protobuf::d2d_sync::TypingIndicatorPolicy>,

    /// Threema 1:1 Call policy.
    pub o2o_call_policy: Option<protobuf_settings::O2oCallPolicy>,

    /// Threema 1:1 Call connection policy.
    pub o2o_call_connection_policy: Option<protobuf_settings::O2oCallConnectionPolicy>,

    /// Threema 1:1 Call video policy.
    pub o2o_call_video_policy: Option<protobuf_settings::O2oCallVideoPolicy>,

    /// Threema Group Call policy.
    pub group_call_policy: Option<protobuf_settings::GroupCallPolicy>,

    /// Screenshot policy.
    pub screenshot_policy: Option<protobuf_settings::ScreenshotPolicy>,

    /// Threema IDs whose messages are blocked.
    ///
    /// Note: The user's identity will be ignored (but not filtered).
    pub blocked_identities: Option<Vec<ThreemaId>>,

    /// Threema IDs to be excluded when syncing the contact list.
    ///
    /// Note: The user's identity will be ignored (but not filtered).
    pub exclude_from_sync_identities: Option<Vec<ThreemaId>>,
}
#[cfg(any(test, feature = "cli"))]
impl Apply<SettingsUpdate> for Settings {
    fn apply(&mut self, update: SettingsUpdate) {
        let SettingsUpdate {
            unknown_contact_policy,
            read_receipt_policy,
            typing_indicator_policy,
            o2o_call_policy,
            o2o_call_connection_policy,
            o2o_call_video_policy,
            group_call_policy,
            screenshot_policy,
            blocked_identities,
            exclude_from_sync_identities,
        } = update;

        self.unknown_contact_policy.apply_some(unknown_contact_policy);
        self.read_receipt_policy.apply_some(read_receipt_policy);
        self.typing_indicator_policy.apply_some(typing_indicator_policy);
        self.o2o_call_policy.apply_some(o2o_call_policy);
        self.o2o_call_connection_policy
            .apply_some(o2o_call_connection_policy);
        self.o2o_call_video_policy.apply_some(o2o_call_video_policy);
        self.group_call_policy.apply_some(group_call_policy);
        self.screenshot_policy.apply_some(screenshot_policy);
        self.blocked_identities.apply_some(blocked_identities);
        self.exclude_from_sync_identities
            .apply_some(exclude_from_sync_identities);
    }
}

/// Settings storage interface.
///
/// IMPORTANT: This interface handles only _user_ settings, and not _effective_ settings.
pub trait SettingsProvider {
    /// Set all settings.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters. Otherwise, this function is considered infallible and
    /// should not return an error.
    fn set(&mut self, settings: Settings) -> Result<(), ProviderError>;

    /// Update all provided settings.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters. Otherwise, this function is considered infallible and
    /// should not return an error.
    fn update(&mut self, update: SettingsUpdate) -> Result<(), ProviderError>;

    /// Return all settings.
    ///
    /// # Errors
    ///
    /// This function is considered infallible and should not return an error.
    fn get(&self) -> Result<Settings, ProviderError>;
}
