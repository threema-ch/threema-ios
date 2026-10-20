//! Common items needed in many places.
use core::{
    array::TryFromSliceError,
    fmt,
    num::ParseIntError,
    str::{self, FromStr},
};
use std::env;

#[cfg(test)]
use anyhow;
use libthreema_dependencies::{
    crypto::{
        consts,
        digest::{FixedOutput as _, Mac as _},
        generic_array, sha2,
    },
    data_encoding::HEXLOWER_PERMISSIVE,
    rand::{self, Rng as _},
};
use libthreema_macros::{Name, UniffiNewType, VariantNames};
use serde::{Deserialize, Serialize};

use crate::{
    protobuf,
    utils::{debug::Name as _, protobuf::PaddedMessage as _, time::utc_now_ms, update::Apply},
};

pub mod config;
pub mod keys;
pub mod task;

/// Client info.
#[derive(Debug, Clone)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
#[cfg_attr(
    feature = "wasm",
    derive(tsify::Tsify, serde::Deserialize),
    serde(tag = "platform", rename_all = "kebab-case", rename_all_fields = "camelCase"),
    tsify(from_wasm_abi)
)]
pub enum ClientInfo {
    /// Android.
    Android {
        /// Version string.
        version: String,

        /// Locale, i.e. `<language>/<country-code>` where:
        ///
        /// - `<language>` is an ISO 639-1:2002-ish language code
        /// - `<country-code>` is an ISO 3166-1-ish country code
        locale: String,

        /// Device model.
        device_model: String,

        /// OS version.
        os_version: String,
    },

    /// iOS.
    Ios {
        /// Version string.
        version: String,

        /// Locale, i.e. `<language>/<country-code>` where:
        ///
        /// - `<language>` is an ISO 639-1:2002-ish language code
        /// - `<country-code>` is an ISO 3166-1-ish country code
        locale: String,

        /// Device model.
        device_model: String,

        /// OS version.
        os_version: String,
    },

    /// Desktop 2.x.
    Desktop {
        /// Version string.
        version: String,

        /// Locale, i.e. `<language>/<country-code>` where:
        ///
        /// - `<language>` is an ISO 639-1:2002-ish language code
        /// - `<country-code>` is an ISO 3166-1-ish country code
        locale: String,

        /// Renderer name (e.g. `electron`).
        renderer_name: String,

        /// Renderer version.
        renderer_version: String,

        /// OS name (e.g. `linux`).
        os_name: String,

        /// OS architecture (e.g. `x64`).
        os_architecture: String,
    },

    /// libthreema standalone (CLI, testing, ...)
    Libthreema,
}
impl ClientInfo {
    /// Encode to HTTPS user agent name.
    #[must_use]
    pub fn to_user_agent(&self) -> String {
        match self {
            Self::Android { version, .. } => format!("Threema Android/{version}"),
            Self::Ios { version, .. } => format!("Threema iOS/{version}"),
            Self::Desktop { version, .. } => format!("Threema Desktop/{version}"),
            Self::Libthreema => format!("libthreema/{version}", version = env!("CARGO_PKG_VERSION")),
        }
    }

    /// Encode to colon-separated as used by the CSP `client-info` (hopefully not for long).
    #[must_use]
    pub fn to_semicolon_separated(&self) -> String {
        match self {
            Self::Android {
                version,
                locale,
                device_model,
                os_version,
            } => {
                format!(
                    "{version};A;{locale};{device_model};{os_version}",
                    version = version.replace(';', "_"),
                    locale = locale.replace(';', "_"),
                    device_model = device_model.replace(';', "_"),
                    os_version = os_version.replace(';', "_")
                )
            },

            Self::Ios {
                version,
                locale,
                device_model,
                os_version,
            } => {
                format!(
                    "{version};I;{locale};{device_model};{os_version}",
                    version = version.replace(';', "_"),
                    locale = locale.replace(';', "_"),
                    device_model = device_model.replace(';', "_"),
                    os_version = os_version.replace(';', "_")
                )
            },

            Self::Desktop {
                version,
                locale,
                renderer_name,
                renderer_version,
                os_name,
                os_architecture,
            } => {
                format!(
                    "{version};Q;{locale};{renderer_name};{renderer_version};{os_name};{os_architecture}",
                    version = version.replace(';', "_"),
                    locale = locale.replace(';', "_"),
                    renderer_name = renderer_name.replace(';', "_"),
                    renderer_version = renderer_version.replace(';', "_"),
                    os_name = os_name.replace(';', "_"),
                    os_architecture = os_architecture.replace(';', "_")
                )
            },

            Self::Libthreema => {
                format!(
                    "{version};L;en/CH;{os_name};{os_architecture}",
                    version = env!("CARGO_PKG_VERSION"),
                    os_name = env::consts::OS,
                    os_architecture = env::consts::ARCH
                )
            },
        }
    }

    /// Construct a [`protobuf::d2d::DeviceInfo`] from a device label and the [`ClientInfo`].
    ///
    /// The device label (e.g. "PC at Work") is recommended to not exceed 64 grapheme clusters.
    pub(crate) fn to_device_info(&self, label: String) -> protobuf::d2d::DeviceInfo {
        let (platform, platform_details, app_version) = match self {
            Self::Android {
                version,
                device_model,
                ..
            } => (
                protobuf::d2d::device_info::Platform::Android,
                device_model.clone(),
                version.clone(),
            ),

            Self::Ios {
                version,
                device_model,
                ..
            } => (
                protobuf::d2d::device_info::Platform::Ios,
                device_model.clone(),
                version.clone(),
            ),

            Self::Desktop {
                version,
                renderer_name,
                renderer_version,
                os_name,
                ..
            } => (
                protobuf::d2d::device_info::Platform::Desktop,
                format!("{renderer_name} {renderer_version} ({os_name})"),
                version.clone(),
            ),

            Self::Libthreema => (
                protobuf::d2d::device_info::Platform::Unspecified,
                format!("libthreema ({os_name})", os_name = env::consts::OS),
                env!("CARGO_PKG_VERSION").to_owned(),
            ),
        };
        protobuf::d2d::DeviceInfo {
            #[expect(deprecated, reason = "Will be filled by encode_to_vec_padded")]
            padding: vec![],
            platform: platform as i32,
            platform_details,
            app_version,
            label,
        }
    }
}

/// Invalid [`ThreemaId`].
#[derive(Clone, Debug, thiserror::Error)]
pub enum ThreemaIdError {
    /// Invalid length (must be exactly 8 bytes).
    #[error("Threema ID must be exactly 8 bytes")]
    InvalidLength,

    /// Invalid symbols provided.
    #[error("Threema ID contains invalid symbols")]
    InvalidSymbols,
}
#[cfg(feature = "uniffi")]
impl From<ThreemaIdError> for crate::bindings::uniffi::ConversionError {
    fn from(error: ThreemaIdError) -> Self {
        Self::ContractViolation {
            name: ThreemaId::NAME.to_owned(),
            reason: error.to_string(),
        }
    }
}

/// A valid Threema ID.
#[expect(
    clippy::unsafe_derive_deserialize,
    reason = "False positive triggered by the unsafe block in as_str, \
    see https://github.com/rust-lang/rust-clippy/issues/10349"
)]
#[derive(Clone, Copy, Eq, Hash, PartialEq, PartialOrd, Ord, Serialize, Deserialize, Name)]
#[serde(try_from = "&str", into = "String")]
pub struct ThreemaId([u8; Self::LENGTH]);
impl ThreemaId {
    /// Byte length of a Threema ID.
    pub const LENGTH: usize = 8;

    /// Construct a predefined Threema ID.
    ///
    /// IMPORTANT: This skips the validation, so `identity` must be known to be valid!
    pub(crate) const fn predefined(identity: [u8; Self::LENGTH]) -> Self {
        Self(identity)
    }

    /// Byte representation of the Threema ID.
    #[inline]
    #[must_use]
    pub fn to_bytes(self) -> [u8; Self::LENGTH] {
        self.0
    }

    /// String representation of the Threema ID.
    #[inline]
    #[must_use]
    pub fn as_str(&self) -> &str {
        // SAFETY: This is safe because the creation of a `ThreemaId` requires that it is a valid
        // UTF-8 sequence.
        unsafe { str::from_utf8_unchecked(&self.0) }
    }

    /// Return whether this is a Gateway ID.
    #[inline]
    #[must_use]
    pub fn is_gateway_id(self) -> bool {
        self.0[0] == b'*'
    }
}
impl fmt::Display for ThreemaId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(self.as_str())
    }
}
impl fmt::Debug for ThreemaId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_tuple(Self::NAME)
            .field(&self.to_string())
            .finish()
    }
}
impl From<ThreemaId> for String {
    fn from(identity: ThreemaId) -> Self {
        identity.as_str().to_owned()
    }
}
impl TryFrom<&[u8]> for ThreemaId {
    type Error = ThreemaIdError;

    fn try_from(identity: &[u8]) -> Result<Self, Self::Error> {
        let identity = <[u8; Self::LENGTH]>::try_from(identity).map_err(|_| ThreemaIdError::InvalidLength)?;
        if ![b'*'..=b'*', b'0'..=b'9', b'A'..=b'Z']
            .iter()
            .any(|range| range.contains(identity.first().expect("identity must be exactly 8 bytes")))
        {
            return Err(ThreemaIdError::InvalidSymbols);
        }
        if !identity
            .get(1..8)
            .expect("identity must be exactly 8 bytes")
            .iter()
            .all(|byte| {
                [b'0'..=b'9', b'A'..=b'Z']
                    .iter()
                    .any(|range| range.contains(byte))
            })
        {
            return Err(ThreemaIdError::InvalidSymbols);
        }
        Ok(Self(identity))
    }
}
impl TryFrom<&str> for ThreemaId {
    type Error = ThreemaIdError;

    fn try_from(identity: &str) -> Result<Self, Self::Error> {
        Self::try_from(identity.as_bytes())
    }
}
impl FromStr for ThreemaId {
    type Err = ThreemaIdError;

    fn from_str(identity: &str) -> Result<Self, Self::Err> {
        Self::try_from(identity)
    }
}

#[cfg(test)]
mod threema_id_tests {
    use assert_matches::assert_matches;
    use rstest::rstest;

    use super::{ThreemaId, ThreemaIdError};

    #[rstest]
    #[case(&[0x45, 0x43, 0x48, 0x4f, 0x45, 0x43, 0x48, 0x4f])]
    #[case(&[0x2a, 0x52, 0x49, 0x43, 0x48, 0x54, 0x49, 0x47])]
    fn valid_bytes(#[case] identity: &[u8]) {
        assert!(ThreemaId::try_from(identity).is_ok());
    }

    #[rstest]
    #[case("ECHOECHO")]
    #[case("*RICHTIG")]
    fn valid_str(#[case] identity: &str) {
        assert!(ThreemaId::try_from(identity).is_ok());
    }

    #[rstest]
    #[case("")]
    #[case("ZUWENIG")]
    #[case("*NEINNEIN")]
    #[case("ECHÜECHÜ")]
    fn invalid_length(#[case] identity: &str) {
        assert_matches!(ThreemaId::try_from(identity), Err(ThreemaIdError::InvalidLength));
    }

    #[rstest]
    #[case(&[0x00, 0x9f, 0x92, 0x96, 0x00, 0x00, 0x00, 0x00])]
    #[case(&[0_u8; 8])]
    fn invalid_symbols_bytes(#[case] identity: &[u8]) {
        assert_matches!(ThreemaId::try_from(identity), Err(ThreemaIdError::InvalidSymbols));
    }

    #[rstest]
    #[case("ECH_ECH_")]
    #[case("********")]
    fn invalid_symbols_str(#[case] identity: &str) {
        assert_matches!(ThreemaId::try_from(identity), Err(ThreemaIdError::InvalidSymbols));
    }
}

/// A unique distribution list identity.
#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq, PartialOrd, Ord)]
#[cfg_attr(feature = "uniffi", derive(UniffiNewType))]
pub struct DistributionListId(pub u64);
impl fmt::Display for DistributionListId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&HEXLOWER_PERMISSIVE.encode(&self.0.to_le_bytes()))
    }
}

/// A unique group identity.
#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq, PartialOrd, Ord, Name)]
pub struct GroupIdentity {
    /// Group ID as chosen by the group's creator.
    pub group_id: u64,

    /// Threema ID of the group's creator.
    pub creator_identity: ThreemaId,
}
impl TryFrom<&protobuf::common::GroupIdentity> for GroupIdentity {
    type Error = ThreemaIdError;

    fn try_from(group_identity: &protobuf::common::GroupIdentity) -> Result<Self, Self::Error> {
        Ok(Self {
            group_id: group_identity.group_id,
            creator_identity: ThreemaId::try_from(group_identity.creator_identity.as_str())?,
        })
    }
}
impl From<&GroupIdentity> for protobuf::common::GroupIdentity {
    fn from(group_identity: &GroupIdentity) -> Self {
        Self {
            group_id: group_identity.group_id,
            creator_identity: group_identity.creator_identity.into(),
        }
    }
}
impl fmt::Display for GroupIdentity {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "{}.{}",
            self.creator_identity,
            HEXLOWER_PERMISSIVE.encode(&self.group_id.to_le_bytes()),
        )
    }
}

/// A conversation type.
#[derive(Clone, Copy, Debug, PartialEq)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum ConversationType {
    /// A 1:1 conversation.
    Contact,

    /// A distribution list conversation.
    DistributionList,

    /// A group conversation.
    Group,
}

/// A specific conversation (aka _receiver_).
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Name, PartialOrd, Ord, VariantNames)]
pub enum ConversationId {
    /// A specific 1:1 contact.
    Contact(ThreemaId),

    /// A specific distribution list.
    DistributionList(DistributionListId),

    /// A specific group.
    Group(GroupIdentity),
}
impl ConversationId {
    #[inline]
    pub(crate) const fn conversation_type(&self) -> ConversationType {
        match self {
            Self::Contact(_) => ConversationType::Contact,
            Self::DistributionList(_) => ConversationType::DistributionList,
            Self::Group(_) => ConversationType::Group,
        }
    }
}
impl TryFrom<&protobuf::d2d::conversation_id::Id> for ConversationId {
    type Error = ThreemaIdError;

    fn try_from(conversation: &protobuf::d2d::conversation_id::Id) -> Result<Self, Self::Error> {
        Ok(match conversation {
            protobuf::d2d::conversation_id::Id::Contact(contact_identity) => {
                Self::Contact(ThreemaId::try_from(contact_identity.as_str())?)
            },
            protobuf::d2d::conversation_id::Id::DistributionList(distribution_list_id) => {
                Self::DistributionList(DistributionListId(*distribution_list_id))
            },
            protobuf::d2d::conversation_id::Id::Group(group_identity) => {
                Self::Group(GroupIdentity::try_from(group_identity)?)
            },
        })
    }
}
impl From<&ConversationId> for protobuf::d2d::ConversationId {
    fn from(conversation: &ConversationId) -> Self {
        let id = match conversation {
            ConversationId::Contact(contact_identity) => {
                protobuf::d2d::conversation_id::Id::Contact(contact_identity.as_str().to_owned())
            },
            ConversationId::DistributionList(distribution_list_id) => {
                protobuf::d2d::conversation_id::Id::DistributionList(distribution_list_id.0)
            },
            ConversationId::Group(group_identity) => {
                protobuf::d2d::conversation_id::Id::Group(group_identity.into())
            },
        };
        Self { id: Some(id) }
    }
}
impl fmt::Display for ConversationId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        let inner: &dyn fmt::Display = match self {
            Self::Contact(id) => id,
            Self::DistributionList(id) => id,
            Self::Group(id) => id,
        };
        write!(formatter, "{}({inner})", self.variant_name())
    }
}

/// Invalid [`ChatServerGroup`].
#[derive(Clone, Debug, thiserror::Error)]
pub enum ChatServerGroupError {
    /// Invalid length (must be at least one byte).
    #[error("Chat server group must be at least one byte")]
    InvalidLength,

    /// Invalid symbols provided.
    #[error("Chat server group contains invalid symbols")]
    InvalidSymbols,
}
#[cfg(feature = "uniffi")]
impl From<ChatServerGroupError> for crate::bindings::uniffi::ConversionError {
    fn from(error: ChatServerGroupError) -> Self {
        Self::ContractViolation {
            name: ChatServerGroup::NAME.to_owned(),
            reason: error.to_string(),
        }
    }
}

/// A valid CSP server group (i.e., matching matching `[a-zA-Z0-9\-]+`).
#[derive(Clone, Debug, Eq, Hash, PartialEq, Deserialize, Name)]
#[serde(try_from = "&str")]
pub struct ChatServerGroup(String);
impl ChatServerGroup {
    /// Extracts a string slice containing the entire Chat Server Group.
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}
impl TryFrom<&str> for ChatServerGroup {
    type Error = ChatServerGroupError;

    fn try_from(chat_server_group: &str) -> Result<Self, Self::Error> {
        if chat_server_group.is_empty() {
            return Err(ChatServerGroupError::InvalidLength);
        }
        if !chat_server_group
            .chars()
            .all(|symbol| symbol.is_ascii_alphanumeric() || symbol == '-')
        {
            return Err(ChatServerGroupError::InvalidSymbols);
        }
        Ok(Self(chat_server_group.to_owned()))
    }
}
impl FromStr for ChatServerGroup {
    type Err = ChatServerGroupError;

    fn from_str(chat_server_group: &str) -> Result<Self, Self::Err> {
        Self::try_from(chat_server_group)
    }
}
impl From<ChatServerGroup> for String {
    fn from(chat_server_group: ChatServerGroup) -> Self {
        chat_server_group.0
    }
}

#[cfg(test)]
mod chat_server_group_tests {
    use assert_matches::assert_matches;
    use rstest::rstest;

    use super::{ChatServerGroup, ChatServerGroupError};

    #[rstest]
    #[case("a")]
    #[case("0")]
    #[case("-")]
    #[case("ds")]
    #[case("aAzZ09")]
    #[case("some-group-42")]
    fn valid(#[case] chat_server_group: &str) {
        assert!(ChatServerGroup::try_from(chat_server_group).is_ok());
    }

    #[test]
    fn invalid_length() {
        assert_matches!(
            ChatServerGroup::try_from(""),
            Err(ChatServerGroupError::InvalidLength)
        );
    }

    #[rstest]
    #[case("group with spaces")]
    #[case("under_score")]
    #[case("café")]
    #[case("dot.dot")]
    fn invalid_symbols(#[case] chat_server_group: &str) {
        assert_matches!(
            ChatServerGroup::try_from(chat_server_group),
            Err(ChatServerGroupError::InvalidSymbols)
        );
    }
}

/// A CSP device cookie.
#[derive(Clone, Copy, Eq, Hash, PartialEq, Name)]
pub struct DeviceCookie(pub [u8; Self::LENGTH]);
impl DeviceCookie {
    /// Byte length of a CSP device cookie.
    pub(crate) const LENGTH: usize = 16;

    #[cfg(any(test, feature = "cli"))]
    pub(crate) fn from_hex(string: &str) -> anyhow::Result<Self> {
        let bytes = HEXLOWER_PERMISSIVE.decode(string.as_bytes())?;
        let bytes: [u8; Self::LENGTH] = bytes.as_slice().try_into()?;
        Ok(Self(bytes))
    }
}
#[cfg(any(test, feature = "cli"))]
impl FromStr for DeviceCookie {
    type Err = anyhow::Error;

    fn from_str(device_cookie: &str) -> Result<Self, Self::Err> {
        Self::from_hex(device_cookie)
    }
}
impl TryFrom<&[u8]> for DeviceCookie {
    type Error = TryFromSliceError;

    fn try_from(device_cookie: &[u8]) -> Result<Self, Self::Error> {
        Ok(Self(<[u8; Self::LENGTH]>::try_from(device_cookie)?))
    }
}
impl fmt::Display for DeviceCookie {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&HEXLOWER_PERMISSIVE.encode(&self.0))
    }
}
impl fmt::Debug for DeviceCookie {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_tuple(Self::NAME)
            .field(&self.to_string())
            .finish()
    }
}

/// A D2X device ID.
#[derive(Clone, Copy, Eq, Hash, PartialEq, Name)]
pub struct D2xDeviceId(pub u64);
#[cfg(any(test, feature = "cli"))]
impl TryFrom<&str> for D2xDeviceId {
    type Error = ParseIntError;

    fn try_from(id: &str) -> Result<Self, Self::Error> {
        Ok(Self(u64::from_str_radix(id, 16)?.to_be()))
    }
}
#[cfg(any(test, feature = "cli"))]
impl FromStr for D2xDeviceId {
    type Err = ParseIntError;

    fn from_str(id: &str) -> Result<Self, Self::Err> {
        Self::try_from(id)
    }
}
impl fmt::Display for D2xDeviceId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{:02x}", self.0)
    }
}
impl fmt::Debug for D2xDeviceId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}({:016x})", Self::NAME, self.0.to_be())
    }
}

/// A CSP device ID.
///
/// WARNING: This should never be equal to the [`D2xDeviceId`].
#[derive(Clone, Copy, Eq, Hash, PartialEq, Name)]
pub struct CspDeviceId(pub u64);
impl CspDeviceId {
    /// Byte length of a CSP device ID.
    pub(crate) const LENGTH: usize = 8;
}
#[cfg(any(test, feature = "cli"))]
impl TryFrom<&str> for CspDeviceId {
    type Error = ParseIntError;

    fn try_from(id: &str) -> Result<Self, Self::Error> {
        Ok(Self(u64::from_str_radix(id, 16)?.to_be()))
    }
}
#[cfg(any(test, feature = "cli"))]
impl FromStr for CspDeviceId {
    type Err = ParseIntError;

    fn from_str(id: &str) -> Result<Self, Self::Err> {
        Self::try_from(id)
    }
}
impl fmt::Display for CspDeviceId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{:02x}", self.0)
    }
}
impl fmt::Debug for CspDeviceId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}({:016x})", Self::NAME, self.0.to_be())
    }
}

/// A blob ID.
#[derive(Clone, Copy, Eq, PartialEq, Name)]
pub struct BlobId(pub [u8; Self::LENGTH]);
impl BlobId {
    /// Byte length of a blob ID.
    pub const LENGTH: usize = 16;
}
impl fmt::Debug for BlobId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_tuple(Self::NAME)
            .field(&self.to_string())
            .finish()
    }
}
impl fmt::Display for BlobId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&HEXLOWER_PERMISSIVE.encode(&self.0))
    }
}

/// CSP features supported by a device or available for a contact.
///
/// IMPORTANT: The flags determine what a device/contact is capable of, not
/// whether the settings allow for it. For example, group calls may be supported
/// but ignored if disabled in the settings.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[cfg_attr(feature = "uniffi", derive(UniffiNewType))]
pub struct FeatureMask(pub u64);
#[rustfmt::skip]
impl FeatureMask {
    /// No features available.
    pub const NONE: u64 =                     0b_0000_0000_0000_0000;

    /// Supports voice messages.
    pub const VOICE_MESSAGE_SUPPORT: u64 =    0b_0000_0000_0000_0001;

    /// Supports groups.
    pub const GROUP_SUPPORT: u64 =            0b_0000_0000_0000_0010;

    /// Supports polls.
    pub const POLL_SUPPORT: u64 =             0b_0000_0000_0000_0100;

    /// Supports file messages.
    pub const FILE_MESSAGE_SUPPORT: u64 =     0b_0000_0000_0000_1000;

    /// Supports 1:1 audio calls.
    pub const O2O_AUDIO_CALL_SUPPORT: u64 =   0b_0000_0000_0001_0000;

    /// Supports 1:1 video calls.
    pub const O2O_VIDEO_CALL_SUPPORT: u64 =   0b_0000_0000_0010_0000;

    /// Supports forward security.
    pub const FORWARD_SECURITY_SUPPORT: u64 = 0b_0000_0000_0100_0000;

    /// Supports group calls.
    pub const GROUP_CALL_SUPPORT: u64 =       0b_0000_0000_1000_0000;

    /// Supports editing messages.
    pub const EDIT_MESSAGE_SUPPORT: u64 =     0b_0000_0001_0000_0000;

    /// Supports deleting messages.
    pub const DELETE_MESSAGE_SUPPORT: u64 =   0b_0000_0010_0000_0000;
}

/// A 24-byte nonce for use with XSalsa20Poly1305 or XChaCha20Poly1305.
#[derive(Clone, Eq, PartialEq, Hash, Name)]
pub struct Nonce(pub [u8; Self::LENGTH]);
impl Nonce {
    /// Byte length of a nonce.
    pub const LENGTH: usize = 24;

    /// Generate a random nonce.
    #[must_use]
    pub fn random() -> Self {
        let mut nonce = Self([0_u8; Self::LENGTH]);
        rand::thread_rng().fill(&mut nonce.0);
        nonce
    }

    #[cfg(test)]
    pub(crate) fn from_hex(string: &str) -> anyhow::Result<Self> {
        let bytes = HEXLOWER_PERMISSIVE.decode(string.as_bytes())?;
        let bytes: [u8; Self::LENGTH] = bytes.as_slice().try_into()?;
        Ok(Self(bytes))
    }

    /// Hash the Nonce with HMAC-SHA256 using the user's identity as key.
    #[must_use]
    pub(crate) fn hash_with(&self, user_identity: ThreemaId) -> HashedNonce {
        HashedNonce(
            sha2::HmacSha256::new_from_slice(&user_identity.to_bytes())
                .expect("HMAC can take Threema Id as key input")
                .chain_update(self.0)
                .finalize_fixed()
                .into(),
        )
    }
}
impl From<[u8; Self::LENGTH]> for Nonce {
    fn from(nonce: [u8; Self::LENGTH]) -> Self {
        Self(nonce)
    }
}
impl<'array, 'nonce: 'array> From<&'nonce Nonce> for &'array generic_array::GenericArray<u8, consts::U24> {
    fn from(nonce: &'nonce Nonce) -> Self {
        Self::from(&nonce.0)
    }
}
impl From<generic_array::GenericArray<u8, consts::U24>> for Nonce {
    fn from(nonce: generic_array::GenericArray<u8, consts::U24>) -> Self {
        Self(nonce.into())
    }
}
impl TryFrom<&[u8]> for Nonce {
    type Error = TryFromSliceError;

    fn try_from(nonce: &[u8]) -> Result<Self, Self::Error> {
        Ok(Self::from(<[u8; Self::LENGTH]>::try_from(nonce)?))
    }
}
impl fmt::Display for Nonce {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&HEXLOWER_PERMISSIVE.encode(&self.0))
    }
}
impl fmt::Debug for Nonce {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_tuple(Self::NAME)
            .field(&self.to_string())
            .finish()
    }
}

/// A nonce hashed with HMAC-SHA256 using the identity as key.
#[derive(Clone, PartialEq, Eq, PartialOrd, Ord, Name)]
#[cfg_attr(test, derive(Debug))]
pub struct HashedNonce(pub [u8; Self::LENGTH]);
impl HashedNonce {
    /// Byte length of a hashed nonce.
    pub const LENGTH: usize = 32;
}
impl From<[u8; Self::LENGTH]> for HashedNonce {
    fn from(hashed_nonce: [u8; Self::LENGTH]) -> Self {
        Self(hashed_nonce)
    }
}
impl TryFrom<&[u8]> for HashedNonce {
    type Error = TryFromSliceError;

    fn try_from(nonce: &[u8]) -> Result<Self, Self::Error> {
        Ok(Self::from(<[u8; Self::LENGTH]>::try_from(nonce)?))
    }
}

/// A message ID.
///
/// May or may not be unique, depending on the context it is used for.
#[derive(Clone, Copy, Eq, Hash, PartialEq, PartialOrd, Ord, Name)]
#[cfg_attr(feature = "uniffi", derive(UniffiNewType))]
pub struct MessageId(pub u64);
impl MessageId {
    /// Byte length of a message ID.
    pub const LENGTH: usize = 8;

    /// Generate a random message ID.
    #[must_use]
    pub fn random() -> Self {
        Self(rand::thread_rng().r#gen())
    }

    #[cfg(test)]
    pub(crate) fn from_hex(string: &str) -> Result<Self, ParseIntError> {
        Ok(Self(u64::from_str_radix(string, 16)?.to_be()))
    }

    /// Byte representation of the Message ID.
    #[inline]
    #[must_use]
    pub fn to_bytes(self) -> [u8; Self::LENGTH] {
        u64::to_le_bytes(self.0)
    }
}
impl fmt::Display for MessageId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{:016x}", self.0.to_be())
    }
}
impl fmt::Debug for MessageId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_tuple(Self::NAME)
            .field(&self.to_string())
            .finish()
    }
}
impl From<[u8; Self::LENGTH]> for MessageId {
    fn from(message_id: [u8; Self::LENGTH]) -> Self {
        Self(u64::from_le_bytes(message_id))
    }
}

/// Whether delivery receipts should be sent.
#[derive(Clone, Copy, Debug, Name)]
#[cfg_attr(test, derive(PartialEq, Default))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum MessageOverridesDeliveryReceiptPolicy {
    /// Apply the default behaviour as defined by the message's properties.
    #[cfg_attr(test, default)]
    Default,

    /// Don't send delivery receipts in response to the referred message.
    ///
    /// This overrides the default behaviour as defined by the message's properties.
    DontSend,
}

/// Message behaviour overrides that need to be stored.
#[derive(Clone, Copy, Name)]
#[cfg_attr(test, derive(PartialEq, Default))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct MessageOverrides {
    /// Delivery receipt override policy.
    pub delivery_receipt_policy: MessageOverridesDeliveryReceiptPolicy,
}
impl Apply<MessageOverrides> for MessageFlags {
    fn apply(&mut self, overrides: MessageOverrides) {
        if matches!(
            overrides.delivery_receipt_policy,
            MessageOverridesDeliveryReceiptPolicy::DontSend
        ) {
            self.0 |= Self::NO_DELIVERY_RECEIPTS;
        }
    }
}
impl fmt::Debug for MessageOverrides {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        // Keep this format in sync with `MessageFlags`!
        write!(
            formatter,
            "{}({})",
            Self::NAME,
            itertools::join(
                [matches!(
                    self.delivery_receipt_policy,
                    MessageOverridesDeliveryReceiptPolicy::DontSend
                )
                .then_some("no-receipts"),]
                .into_iter()
                .flatten(),
                ", ",
            ),
        )
    }
}
impl From<MessageFlags> for MessageOverrides {
    fn from(flags: MessageFlags) -> Self {
        Self {
            delivery_receipt_policy: if flags.0 & MessageFlags::NO_DELIVERY_RECEIPTS != 0 {
                MessageOverridesDeliveryReceiptPolicy::DontSend
            } else {
                MessageOverridesDeliveryReceiptPolicy::Default
            },
        }
    }
}

/// Message flags which were/are transmitted to the server.
#[derive(Clone, Copy, Default, Name, PartialEq, Eq)]
pub struct MessageFlags(pub u8);
#[rustfmt::skip]
impl MessageFlags {
    pub(crate) const LENGTH: usize = 1;

    /// Whether a push should be sent by the chat server. Only meaningful for an outgoing message.
    pub const SEND_PUSH_NOTIFICATION:u8 =          0b_0000_0001;

    /// Whether the chat server should discard the message in case the receiver is not currently connected to
    /// the chat server. Only meaningful for an outgoing message.
    pub const NO_SERVER_QUEUING: u8 =              0b_0000_0010;

    /// Whether the message should not be acknowledged by the chat server (outgoing) or by the client
    /// (incoming).
    pub const NO_SERVER_ACKNOWLEDGEMENT: u8 =      0b_0000_0100;

    // Reserved:                                   0b_0000_1000
    // Reserved (formerly _group message marker_): 0b_0001_0000

    /// Instructs the chat server to only queue the message for a short period of time (currently 60 seconds).
    /// Only meaningful for an outgoing message.
    pub const SHORT_LIVED_SERVER_QUEUING: u8 =     0b_0010_0000;

    // Reserved:                                   0b_0100_0000

    /// If present, overrides behaviour of messages that would normally trigger a delivery receipt of type
    /// _received_ or _read_.
    pub const NO_DELIVERY_RECEIPTS: u8 =           0b_1000_0000;
}
impl fmt::Debug for MessageFlags {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        let check_flag = |flag: u8, name: &'static str| -> Option<&'static str> {
            if self.0 & flag != 0 { Some(name) } else { None }
        };

        // Keep this format in sync with `MessageOverrides`!
        write!(
            formatter,
            "{}({})",
            Self::NAME,
            itertools::join(
                [
                    check_flag(Self::SEND_PUSH_NOTIFICATION, "push"),
                    check_flag(Self::NO_SERVER_QUEUING, "no-queue"),
                    check_flag(Self::NO_SERVER_ACKNOWLEDGEMENT, "no-ack"),
                    check_flag(Self::SHORT_LIVED_SERVER_QUEUING, "short-lived"),
                    check_flag(Self::NO_DELIVERY_RECEIPTS, "no-receipts"),
                ]
                .into_iter()
                .flatten(),
                ", ",
            ),
        )
    }
}

/// Metadata associated to a message.
#[derive(Debug, Clone)]
pub struct MessageMetadata {
    /// Unique message ID. Must match the message ID of the outer struct.
    pub message_id: MessageId,

    /// Unix-ish timestamp in milliseconds for when the message has been created.
    pub created_at: u64,

    /// Nickname of the sender at the time the message had been created.
    ///
    /// Note: If not present, this indicates that the nickname **did not change**.
    pub nickname: Option<String>,
}
impl MessageMetadata {
    /// Create for a new outgoing message.
    #[must_use]
    pub fn new_outgoing(message_id: MessageId, nickname: Option<String>) -> Self {
        Self {
            message_id,
            created_at: utc_now_ms(),
            nickname,
        }
    }
}
impl From<protobuf::csp_e2e::MessageMetadata> for MessageMetadata {
    fn from(metadata: protobuf::csp_e2e::MessageMetadata) -> Self {
        Self {
            message_id: MessageId(metadata.message_id),
            created_at: metadata.created_at,
            nickname: metadata.nickname.map(|nickname| nickname.trim().to_owned()),
        }
    }
}
impl From<MessageMetadata> for Vec<u8> {
    fn from(metadata: MessageMetadata) -> Self {
        let metadata = protobuf::csp_e2e::MessageMetadata {
            #[expect(deprecated, reason = "Will be filled by encode_to_vec_padded")]
            padding: vec![],
            message_id: metadata.message_id.0,
            created_at: metadata.created_at,
            nickname: metadata.nickname,
        };
        metadata.encode_to_vec_padded()
    }
}

/// An offset within a stream.
///
/// Note: The offset is relative to the *beginning* of the stream including any metadata, i.e. offset `0`
/// marks the first byte of the stream.
#[derive(Copy, Clone, Debug, Eq, Hash, Name, PartialEq, PartialOrd)]
#[cfg_attr(feature = "uniffi", derive(UniffiNewType))]
pub struct StreamOffset(pub u64);
impl fmt::Display for StreamOffset {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}
