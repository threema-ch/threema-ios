//! Binding version of [`group`].
use std::{collections::HashSet, sync::Arc};

use libthreema_macros::uniffi_define_delta;

use crate::{
    bindings::uniffi::{
        ConversionError,
        common::{GroupIdentity, ThreemaId},
    },
    common,
    model::{
        group::{self, GroupMembershipFilter},
        profile::ProfilePicture,
    },
    protobuf,
    provider::ProviderError,
};

uniffi_define_delta!(
    group::GroupNotificationTriggerPolicyOverride,
    DeltaGroupNotificationTriggerPolicyOverride
);

/// Binding version of [`group::Group`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct Group {
    pub identity: GroupIdentity,
    pub name: String,
    pub created_at: u64,
    pub last_update_at: Option<u64>,
    pub user_state: protobuf::d2d_sync::group::UserState,
    pub members: HashSet<ThreemaId>,
    pub notification_trigger_policy_override: Option<group::GroupNotificationTriggerPolicyOverride>,
    pub conversation_category: protobuf::d2d_sync::ConversationCategory,
    pub conversation_visibility: protobuf::d2d_sync::ConversationVisibility,
}
impl TryFrom<Group> for group::Group {
    type Error = ConversionError;

    fn try_from(group: Group) -> Result<Self, Self::Error> {
        Ok(Self {
            identity: group.identity.try_into()?,
            name: group.name,
            created_at: group.created_at,
            last_update_at: group.last_update_at,
            user_state: group.user_state,
            members: group
                .members
                .into_iter()
                .map(common::ThreemaId::try_from)
                .collect::<Result<_, _>>()?,
            notification_trigger_policy_override: group.notification_trigger_policy_override,
            conversation_category: group.conversation_category,
            conversation_visibility: group.conversation_visibility,
        })
    }
}
impl From<group::Group> for Group {
    fn from(group: group::Group) -> Self {
        Self {
            identity: group.identity.into(),
            name: group.name,
            created_at: group.created_at,
            last_update_at: group.last_update_at,
            user_state: group.user_state,
            members: group.members.into_iter().map(ThreemaId::from).collect(),
            notification_trigger_policy_override: group.notification_trigger_policy_override,
            conversation_category: group.conversation_category,
            conversation_visibility: group.conversation_visibility,
        }
    }
}

/// Binding version of [`group::GroupUpdate`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct GroupUpdate {
    pub identity: GroupIdentity,
    pub name: Option<String>,
    pub user_state: Option<protobuf::d2d_sync::group::UserState>,
    pub members: Option<HashSet<ThreemaId>>,
    pub notification_trigger_policy_override: DeltaGroupNotificationTriggerPolicyOverride,
    pub conversation_category: Option<protobuf::d2d_sync::ConversationCategory>,
    pub conversation_visibility: Option<protobuf::d2d_sync::ConversationVisibility>,
}
impl From<group::GroupUpdate> for GroupUpdate {
    fn from(update: group::GroupUpdate) -> Self {
        Self {
            identity: update.identity.into(),
            name: update.name,
            user_state: update.user_state,
            members: update
                .members
                .map(|members| members.into_iter().map(ThreemaId::from).collect()),
            notification_trigger_policy_override: update.notification_trigger_policy_override.into(),
            conversation_category: update.conversation_category,
            conversation_visibility: update.conversation_visibility,
        }
    }
}

/// Binding version of [`group::GroupWithProfilePicture`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct GroupWithProfilePicture {
    pub group: Group,
    pub profile_picture: Option<ProfilePicture>,
}
impl TryFrom<GroupWithProfilePicture> for group::GroupWithProfilePicture {
    type Error = ConversionError;

    fn try_from(group: GroupWithProfilePicture) -> Result<Self, Self::Error> {
        Ok(Self {
            group: group.group.try_into()?,
            profile_picture: group.profile_picture,
        })
    }
}
impl From<group::GroupWithProfilePicture> for GroupWithProfilePicture {
    fn from(group: group::GroupWithProfilePicture) -> Self {
        Self {
            group: group.group.into(),
            profile_picture: group.profile_picture,
        }
    }
}

/// Binding version of [`group::GroupProvider`].
#[expect(missing_docs, clippy::missing_errors_doc, reason = "Binding version")]
#[uniffi::export(with_foreign)]
pub trait GroupProvider: Send + Sync {
    fn add_with_profile_picture(&self, groups: Vec<GroupWithProfilePicture>) -> Result<(), ProviderError>;

    fn set_profile_picture(
        &self,
        identity: GroupIdentity,
        profile_picture: Option<ProfilePicture>,
    ) -> Result<(), ProviderError>;

    fn update(&self, updates: Vec<GroupUpdate>) -> Result<(), ProviderError>;

    fn get(&self, identity: GroupIdentity) -> Result<Option<Group>, ProviderError>;

    fn get_identities(&self) -> Result<HashSet<GroupIdentity>, ProviderError>;

    fn get_with_profile_picture(
        &self,
        identity: GroupIdentity,
    ) -> Result<Option<GroupWithProfilePicture>, ProviderError>;

    fn has(&self, identity: GroupIdentity) -> Result<bool, ProviderError>;

    fn is_part_of_any_group(
        &self,
        identity: ThreemaId,
        filter: GroupMembershipFilter,
    ) -> Result<bool, ProviderError>;
}
impl<T: GroupProvider + ?Sized> group::GroupProvider for Arc<T> {
    fn add_with_profile_picture(
        &mut self,
        groups: Vec<group::GroupWithProfilePicture>,
    ) -> Result<(), ProviderError> {
        GroupProvider::add_with_profile_picture(
            self.as_ref(),
            groups.into_iter().map(GroupWithProfilePicture::from).collect(),
        )
    }

    fn set_profile_picture(
        &mut self,
        identity: common::GroupIdentity,
        profile_picture: Option<ProfilePicture>,
    ) -> Result<(), ProviderError> {
        GroupProvider::set_profile_picture(self.as_ref(), identity.into(), profile_picture)
    }

    fn update(&mut self, updates: Vec<group::GroupUpdate>) -> Result<(), ProviderError> {
        GroupProvider::update(
            self.as_ref(),
            updates.into_iter().map(GroupUpdate::from).collect(),
        )
    }

    fn get(&self, identity: common::GroupIdentity) -> Result<Option<group::Group>, ProviderError> {
        Ok(GroupProvider::get(self.as_ref(), identity.into())?
            .map(group::Group::try_from)
            .transpose()?)
    }

    fn get_identities(&self) -> Result<HashSet<common::GroupIdentity>, ProviderError> {
        Ok(GroupProvider::get_identities(self.as_ref())?
            .into_iter()
            .map(common::GroupIdentity::try_from)
            .collect::<Result<_, _>>()?)
    }

    fn get_with_profile_picture(
        &self,
        identity: common::GroupIdentity,
    ) -> Result<Option<group::GroupWithProfilePicture>, ProviderError> {
        Ok(
            GroupProvider::get_with_profile_picture(self.as_ref(), identity.into())?
                .map(group::GroupWithProfilePicture::try_from)
                .transpose()?,
        )
    }

    fn has(&self, identity: common::GroupIdentity) -> Result<bool, ProviderError> {
        GroupProvider::has(self.as_ref(), identity.into())
    }

    fn is_part_of_any_group(
        &self,
        identity: common::ThreemaId,
        filter: GroupMembershipFilter,
    ) -> Result<bool, ProviderError> {
        GroupProvider::is_part_of_any_group(self.as_ref(), identity.into(), filter)
    }
}
