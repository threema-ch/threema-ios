//! Binding version of [`user_profile`].
use std::sync::Arc;

use crate::{
    bindings::uniffi::{
        ConversionError,
        common::{ChatServerGroup, ThreemaId, keys::ClientKey},
    },
    common,
    model::{
        profile::ProfilePicture,
        user_profile::{self, IdentityLinkEmailAddress, IdentityLinkPhoneNumber},
    },
    provider::ProviderError,
    work::properties::WorkAvailabilityStatus,
};

/// Binding version of [`user_profile::IdentityData`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct IdentityData {
    pub user_identity: ThreemaId,
    pub client_key: ClientKey,
    pub csp_server_group: ChatServerGroup,
}
impl From<user_profile::IdentityData> for IdentityData {
    fn from(identity_data: user_profile::IdentityData) -> Self {
        Self {
            user_identity: identity_data.user_identity.into(),
            client_key: identity_data.client_key.into(),
            csp_server_group: identity_data.csp_server_group.into(),
        }
    }
}
impl TryFrom<IdentityData> for user_profile::IdentityData {
    type Error = ConversionError;

    fn try_from(identity_data: IdentityData) -> Result<Self, Self::Error> {
        Ok(Self {
            user_identity: identity_data.user_identity.try_into()?,
            client_key: identity_data.client_key.try_into()?,
            csp_server_group: identity_data.csp_server_group.try_into()?,
        })
    }
}

/// Binding version of [`user_profile::ProfilePictureSharePolicy`].
#[derive(uniffi::Enum)]
#[expect(missing_docs, reason = "Binding version")]
pub enum ProfilePictureSharePolicy {
    Nobody,
    Everyone,
    AllowList(Vec<ThreemaId>),
}
impl From<user_profile::ProfilePictureSharePolicy> for ProfilePictureSharePolicy {
    fn from(policy: user_profile::ProfilePictureSharePolicy) -> Self {
        match policy {
            user_profile::ProfilePictureSharePolicy::Nobody => Self::Nobody,
            user_profile::ProfilePictureSharePolicy::Everyone => Self::Everyone,
            user_profile::ProfilePictureSharePolicy::AllowList(threema_ids) => {
                Self::AllowList(threema_ids.into_iter().map(ThreemaId::from).collect())
            },
        }
    }
}
impl TryFrom<ProfilePictureSharePolicy> for user_profile::ProfilePictureSharePolicy {
    type Error = ConversionError;

    fn try_from(policy: ProfilePictureSharePolicy) -> Result<Self, Self::Error> {
        Ok(match policy {
            ProfilePictureSharePolicy::Nobody => Self::Nobody,
            ProfilePictureSharePolicy::Everyone => Self::Everyone,
            ProfilePictureSharePolicy::AllowList(threema_ids) => Self::AllowList(
                threema_ids
                    .into_iter()
                    .map(common::ThreemaId::try_from)
                    .collect::<Result<_, _>>()?,
            ),
        })
    }
}

/// Binding version of [`user_profile::UserProfile`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct UserProfile {
    pub nickname: String,
    pub profile_picture: Option<ProfilePicture>,
    pub profile_picture_share_policy: ProfilePictureSharePolicy,
    pub linked_phone_number: Option<IdentityLinkPhoneNumber>,
    pub linked_email_address: Option<IdentityLinkEmailAddress>,
    pub work_availability_status: Option<WorkAvailabilityStatus>,
}
impl From<user_profile::UserProfile> for UserProfile {
    fn from(user_profile: user_profile::UserProfile) -> Self {
        Self {
            nickname: user_profile.nickname,
            profile_picture: user_profile.profile_picture,
            profile_picture_share_policy: user_profile.profile_picture_share_policy.into(),
            linked_phone_number: user_profile.linked_phone_number,
            linked_email_address: user_profile.linked_email_address,
            work_availability_status: user_profile.work_availability_status,
        }
    }
}
impl TryFrom<UserProfile> for user_profile::UserProfile {
    type Error = ConversionError;

    fn try_from(user_profile: UserProfile) -> Result<Self, Self::Error> {
        Ok(Self {
            nickname: user_profile.nickname,
            profile_picture: user_profile.profile_picture,
            profile_picture_share_policy: user_profile::ProfilePictureSharePolicy::try_from(
                user_profile.profile_picture_share_policy,
            )?,
            linked_phone_number: user_profile.linked_phone_number,
            linked_email_address: user_profile.linked_email_address,
            work_availability_status: user_profile.work_availability_status,
        })
    }
}

/// Binding version of [`user_profile::UserProfileProvider`].
#[expect(missing_docs, clippy::missing_errors_doc, reason = "Binding version")]
#[uniffi::export(with_foreign)]
pub trait UserProfileProvider: Send + Sync {
    fn set(&self, user_profile: UserProfile) -> Result<(), ProviderError>;
    fn get(&self) -> Result<UserProfile, ProviderError>;
}
impl<T: UserProfileProvider + ?Sized> user_profile::UserProfileProvider for Arc<T> {
    fn set(&mut self, user_profile: user_profile::UserProfile) -> Result<(), ProviderError> {
        UserProfileProvider::set(self.as_ref(), user_profile.into())
    }

    fn get(&self) -> Result<user_profile::UserProfile, ProviderError> {
        Ok(UserProfileProvider::get(self.as_ref())?.try_into()?)
    }
}
