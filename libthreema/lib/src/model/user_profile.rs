//! User profile related structs.
use std::collections::HashSet;

use libthreema_macros::Name;

use crate::{
    common::{ChatServerGroup, ThreemaId, keys::ClientKey},
    model::profile::ProfilePicture,
    provider::ProviderError,
    work::properties::WorkAvailabilityStatus,
};

/// The user's identity data.
#[derive(Debug, Name)]
pub struct IdentityData {
    /// The user's identity.
    pub user_identity: ThreemaId,

    /// The user's client key.
    pub client_key: ClientKey,

    /// CSP server group.
    pub csp_server_group: ChatServerGroup,
}

/// Profile picture sharing policy.
#[derive(Clone, Debug, Default, Name)]
pub enum ProfilePictureSharePolicy {
    /// Do not share the profile picture with anyone.
    Nobody,

    /// Share the profile picture with everyone.
    #[default]
    Everyone,

    /// Share the profile picture only with explicitly listed contacts.
    ///
    /// Note: An empty set is valid and has the same effect as [`ProfilePictureSharePolicy::Nobody`].
    AllowList(HashSet<ThreemaId>),
}

/// A phone number identity link.
#[derive(Clone, Debug)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum IdentityLinkPhoneNumber {
    /// Linked with a verified telephone number in E.164 format without leading `+`.
    PhoneNumber(String),

    /// A phone number is linked, but the actual number is unknown.
    Unknown,
}

/// An email address identity link.
#[derive(Clone, Debug)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum IdentityLinkEmailAddress {
    /// Linked with a verified email address.
    EmailAddress(String),

    /// An email address is linked, but the actual email address is unknown.
    Unknown,
}

/// The user's profile.
#[derive(Clone, Debug, Default, Name)]
pub struct UserProfile {
    /// The nickname of the user.
    ///
    /// Empty string means that the user has no provided nickname.
    pub nickname: String,

    /// The user's profile picture.
    pub profile_picture: Option<ProfilePicture>,

    /// Profile picture share policy.
    pub profile_picture_share_policy: ProfilePictureSharePolicy,

    /// A phone number linked with the user's identity.
    pub linked_phone_number: Option<IdentityLinkPhoneNumber>,

    /// An email address linked with the user's identity.
    pub linked_email_address: Option<IdentityLinkEmailAddress>,

    /// The user's work availability status.
    pub work_availability_status: Option<WorkAvailabilityStatus>,
}

/// User profile storage interface.
pub trait UserProfileProvider {
    /// Set the user's profile.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters. Otherwise, this function is considered infallible and
    /// should not return an error.
    fn set(&mut self, user_profile: UserProfile) -> Result<(), ProviderError>;

    /// Return the user's profile.
    ///
    /// # Errors
    ///
    /// This function is considered infallible and should not return an error.
    fn get(&self) -> Result<UserProfile, ProviderError>;
}
