//! Binding version of [`contact`].
use std::{collections::HashSet, sync::Arc};

use libthreema_macros::uniffi_define_delta;

use crate::{
    bindings::uniffi::{
        ConversionError,
        common::{ThreemaId, keys::PublicKey},
    },
    common::{self, FeatureMask},
    model::{contact, profile::ProfilePicture},
    protobuf::{self, d2d_sync::contact as protobuf_contact},
    provider::ProviderError,
    work::properties::WorkAvailabilityStatus,
};

uniffi_define_delta!(protobuf::d2d_sync::ReadReceiptPolicy, DeltaReadReceiptPolicy);
uniffi_define_delta!(
    protobuf::d2d_sync::TypingIndicatorPolicy,
    DeltaTypingIndicatorPolicy
);
uniffi_define_delta!(
    contact::ContactNotificationTriggerPolicyOverride,
    DeltaContactNotificationTriggerPolicyOverride
);

/// Binding version of [`contact::Contact`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct Contact {
    pub identity: ThreemaId,
    pub public_key: PublicKey,
    pub created_at: u64,
    pub last_update_at: Option<u64>,
    pub first_name: String,
    pub last_name: String,
    pub nickname: String,
    pub verification_level: protobuf_contact::VerificationLevel,
    pub work_verification_level: protobuf_contact::WorkVerificationLevel,
    pub identity_type: protobuf_contact::IdentityType,
    pub acquaintance_level: protobuf_contact::AcquaintanceLevel,
    pub activity_state: protobuf_contact::ActivityState,
    pub feature_mask: FeatureMask,
    pub sync_state: protobuf_contact::SyncState,
    pub work_last_full_sync_at: Option<u64>,
    pub work_availability_status: Option<WorkAvailabilityStatus>,
    pub read_receipt_policy_override: Option<protobuf::d2d_sync::ReadReceiptPolicy>,
    pub typing_indicator_policy_override: Option<protobuf::d2d_sync::TypingIndicatorPolicy>,
    pub notification_trigger_policy_override: Option<contact::ContactNotificationTriggerPolicyOverride>,
    pub conversation_category: protobuf::d2d_sync::ConversationCategory,
    pub conversation_visibility: protobuf::d2d_sync::ConversationVisibility,
}
impl From<contact::Contact> for Contact {
    fn from(contact: contact::Contact) -> Self {
        Self {
            identity: contact.identity.into(),
            public_key: contact.public_key.into(),
            created_at: contact.created_at,
            last_update_at: contact.last_update_at,
            first_name: contact.first_name,
            last_name: contact.last_name,
            nickname: contact.nickname,
            verification_level: contact.verification_level,
            work_verification_level: contact.work_verification_level,
            identity_type: contact.identity_type,
            acquaintance_level: contact.acquaintance_level,
            activity_state: contact.activity_state,
            feature_mask: contact.feature_mask,
            sync_state: contact.sync_state,
            work_last_full_sync_at: contact.work_last_full_sync_at,
            work_availability_status: contact.work_availability_status,
            read_receipt_policy_override: contact.read_receipt_policy_override,
            typing_indicator_policy_override: contact.typing_indicator_policy_override,
            notification_trigger_policy_override: contact.notification_trigger_policy_override,
            conversation_category: contact.conversation_category,
            conversation_visibility: contact.conversation_visibility,
        }
    }
}
impl TryFrom<Contact> for contact::Contact {
    type Error = ConversionError;

    fn try_from(contact: Contact) -> Result<Self, Self::Error> {
        Ok(Self {
            identity: contact.identity.try_into()?,
            public_key: contact.public_key.try_into()?,
            created_at: contact.created_at,
            last_update_at: contact.last_update_at,
            first_name: contact.first_name,
            last_name: contact.last_name,
            nickname: contact.nickname,
            verification_level: contact.verification_level,
            work_verification_level: contact.work_verification_level,
            identity_type: contact.identity_type,
            acquaintance_level: contact.acquaintance_level,
            activity_state: contact.activity_state,
            feature_mask: contact.feature_mask,
            sync_state: contact.sync_state,
            work_last_full_sync_at: contact.work_last_full_sync_at,
            work_availability_status: contact.work_availability_status,
            read_receipt_policy_override: contact.read_receipt_policy_override,
            typing_indicator_policy_override: contact.typing_indicator_policy_override,
            notification_trigger_policy_override: contact.notification_trigger_policy_override,
            conversation_category: contact.conversation_category,
            conversation_visibility: contact.conversation_visibility,
        })
    }
}

/// Binding version of [`contact::ContactUpdate`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct ContactUpdate {
    pub identity: ThreemaId,
    pub first_name: Option<String>,
    pub last_name: Option<String>,
    pub nickname: Option<String>,
    pub verification_level: Option<protobuf_contact::VerificationLevel>,
    pub work_verification_level: Option<protobuf_contact::WorkVerificationLevel>,
    pub identity_type: Option<protobuf_contact::IdentityType>,
    pub acquaintance_level: Option<protobuf_contact::AcquaintanceLevel>,
    pub activity_state: Option<protobuf_contact::ActivityState>,
    pub feature_mask: Option<FeatureMask>,
    pub sync_state: Option<protobuf_contact::SyncState>,
    pub read_receipt_policy_override: DeltaReadReceiptPolicy,
    pub typing_indicator_policy_override: DeltaTypingIndicatorPolicy,
    pub notification_trigger_policy_override: DeltaContactNotificationTriggerPolicyOverride,
    pub conversation_category: Option<protobuf::d2d_sync::ConversationCategory>,
    pub conversation_visibility: Option<protobuf::d2d_sync::ConversationVisibility>,
}
impl From<contact::ContactUpdate> for ContactUpdate {
    fn from(update: contact::ContactUpdate) -> Self {
        Self {
            identity: update.identity.into(),
            first_name: update.first_name,
            last_name: update.last_name,
            nickname: update.nickname,
            verification_level: update.verification_level,
            work_verification_level: update.work_verification_level,
            identity_type: update.identity_type,
            acquaintance_level: update.acquaintance_level,
            activity_state: update.activity_state,
            feature_mask: update.feature_mask,
            sync_state: update.sync_state,
            read_receipt_policy_override: update.read_receipt_policy_override.into(),
            typing_indicator_policy_override: update.typing_indicator_policy_override.into(),
            notification_trigger_policy_override: update.notification_trigger_policy_override.into(),
            conversation_category: update.conversation_category,
            conversation_visibility: update.conversation_visibility,
        }
    }
}

/// Binding version of [`contact::ContactWithProfilePictures`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct ContactWithProfilePictures {
    pub contact: Contact,
    pub contact_defined_profile_picture: Option<ProfilePicture>,
    pub user_defined_profile_picture: Option<ProfilePicture>,
}
impl From<contact::ContactWithProfilePictures> for ContactWithProfilePictures {
    fn from(contact: contact::ContactWithProfilePictures) -> Self {
        Self {
            contact: contact.contact.into(),
            contact_defined_profile_picture: contact.contact_defined_profile_picture,
            user_defined_profile_picture: contact.user_defined_profile_picture,
        }
    }
}
impl TryFrom<ContactWithProfilePictures> for contact::ContactWithProfilePictures {
    type Error = ConversionError;

    fn try_from(contact: ContactWithProfilePictures) -> Result<Self, Self::Error> {
        Ok(Self {
            contact: contact.contact.try_into()?,
            contact_defined_profile_picture: contact.contact_defined_profile_picture,
            user_defined_profile_picture: contact.user_defined_profile_picture,
        })
    }
}

/// Binding version of [`contact::ContactProvider`].
#[expect(missing_docs, clippy::missing_errors_doc, reason = "Binding version")]
#[uniffi::export(with_foreign)]
pub trait ContactProvider: Send + Sync {
    fn add(&self, contacts: Vec<Contact>) -> Result<(), ProviderError>;

    fn add_with_profile_pictures(
        &self,
        contacts: Vec<ContactWithProfilePictures>,
    ) -> Result<(), ProviderError>;

    fn set_contact_defined_profile_picture(
        &self,
        identity: ThreemaId,
        profile_picture: Option<ProfilePicture>,
    ) -> Result<(), ProviderError>;

    fn set_user_defined_profile_picture(
        &self,
        identity: ThreemaId,
        profile_picture: Option<ProfilePicture>,
    ) -> Result<(), ProviderError>;

    fn update(&self, updates: Vec<ContactUpdate>) -> Result<(), ProviderError>;

    fn count_existing(&self, identities: Vec<ThreemaId>) -> Result<u32, ProviderError>;

    fn get(&self, identity: ThreemaId) -> Result<Option<Contact>, ProviderError>;

    fn get_identities(&self) -> Result<HashSet<ThreemaId>, ProviderError>;

    fn get_with_profile_pictures(
        &self,
        identity: ThreemaId,
    ) -> Result<Option<ContactWithProfilePictures>, ProviderError>;

    fn has(&self, identity: ThreemaId) -> Result<bool, ProviderError>;

    fn is_explicitly_blocked(&self, identity: ThreemaId) -> Result<bool, ProviderError>;
}
impl<T: ContactProvider + ?Sized> contact::ContactProvider for Arc<T> {
    fn add(&mut self, contacts: Vec<contact::Contact>) -> Result<(), ProviderError> {
        ContactProvider::add(self.as_ref(), contacts.into_iter().map(Contact::from).collect())
    }

    fn add_with_profile_pictures(
        &mut self,
        contacts: Vec<contact::ContactWithProfilePictures>,
    ) -> Result<(), ProviderError> {
        ContactProvider::add_with_profile_pictures(
            self.as_ref(),
            contacts
                .into_iter()
                .map(ContactWithProfilePictures::from)
                .collect(),
        )
    }

    fn set_contact_defined_profile_picture(
        &self,
        identity: common::ThreemaId,
        profile_picture: Option<ProfilePicture>,
    ) -> Result<(), ProviderError> {
        ContactProvider::set_contact_defined_profile_picture(self.as_ref(), identity.into(), profile_picture)
    }

    fn set_user_defined_profile_picture(
        &self,
        identity: common::ThreemaId,
        profile_picture: Option<ProfilePicture>,
    ) -> Result<(), ProviderError> {
        ContactProvider::set_user_defined_profile_picture(self.as_ref(), identity.into(), profile_picture)
    }

    fn update(&mut self, updates: Vec<contact::ContactUpdate>) -> Result<(), ProviderError> {
        ContactProvider::update(
            self.as_ref(),
            updates.into_iter().map(ContactUpdate::from).collect(),
        )
    }

    fn count_existing(&self, identities: &[common::ThreemaId]) -> Result<usize, ProviderError> {
        ContactProvider::count_existing(
            self.as_ref(),
            identities.iter().copied().map(ThreemaId::from).collect(),
        )
        .map(|amount| amount as usize)
    }

    fn get(&self, identity: common::ThreemaId) -> Result<Option<contact::Contact>, ProviderError> {
        Ok(ContactProvider::get(self.as_ref(), identity.into())?
            .map(contact::Contact::try_from)
            .transpose()?)
    }

    fn get_identities(&self) -> Result<HashSet<common::ThreemaId>, ProviderError> {
        Ok(ContactProvider::get_identities(self.as_ref())?
            .into_iter()
            .map(common::ThreemaId::try_from)
            .collect::<Result<_, _>>()?)
    }

    fn get_with_profile_pictures(
        &self,
        identity: common::ThreemaId,
    ) -> Result<Option<contact::ContactWithProfilePictures>, ProviderError> {
        Ok(
            ContactProvider::get_with_profile_pictures(self.as_ref(), identity.into())?
                .map(contact::ContactWithProfilePictures::try_from)
                .transpose()?,
        )
    }

    fn has(&self, identity: common::ThreemaId) -> Result<bool, ProviderError> {
        ContactProvider::has(self.as_ref(), identity.into())
    }

    fn is_explicitly_blocked(&self, identity: common::ThreemaId) -> Result<bool, ProviderError> {
        ContactProvider::is_explicitly_blocked(self.as_ref(), identity.into())
    }
}
