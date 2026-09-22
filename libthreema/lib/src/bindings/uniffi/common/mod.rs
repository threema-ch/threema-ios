//! Binding version of [`crate::common`].
use libthreema_macros::{Name, UniffiNewType};

use crate::{bindings::uniffi::ConversionError, common};

pub mod config;
pub mod keys;

/// Binding version of [`common::ThreemaId`].
///
/// # Contract
///
/// Must be a valid Threema ID, i.e., matching `[\*A-Z0-9]{1}[A-Z0-9]{7}`.
#[derive(PartialEq, Eq, Hash, UniffiNewType)]
pub struct ThreemaId(pub String);
impl From<common::ThreemaId> for ThreemaId {
    fn from(identity: common::ThreemaId) -> Self {
        Self(identity.as_str().to_owned())
    }
}
impl TryFrom<ThreemaId> for common::ThreemaId {
    type Error = ConversionError;

    fn try_from(identity: ThreemaId) -> Result<Self, Self::Error> {
        Ok(identity.0.as_str().try_into()?)
    }
}

/// Binding version of [`common::GroupIdentity`].
#[expect(missing_docs, reason = "Binding version")]
#[derive(uniffi::Record)]
pub struct GroupIdentity {
    pub group_id: u64,
    pub creator_identity: ThreemaId,
}
impl From<common::GroupIdentity> for GroupIdentity {
    fn from(group_identity: common::GroupIdentity) -> Self {
        Self {
            group_id: group_identity.group_id,
            creator_identity: group_identity.creator_identity.into(),
        }
    }
}
impl TryFrom<GroupIdentity> for common::GroupIdentity {
    type Error = ConversionError;

    fn try_from(group_identity: GroupIdentity) -> Result<Self, Self::Error> {
        Ok(Self {
            group_id: group_identity.group_id,
            creator_identity: group_identity.creator_identity.try_into()?,
        })
    }
}

/// Binding version of [`common::ConversationId`].
#[expect(missing_docs, reason = "Binding version")]
#[derive(uniffi::Enum)]
pub enum ConversationId {
    Contact(ThreemaId),
    DistributionList(common::DistributionListId),
    Group(GroupIdentity),
}
impl From<common::ConversationId> for ConversationId {
    fn from(conversation_id: common::ConversationId) -> Self {
        match conversation_id {
            common::ConversationId::Contact(threema_id) => Self::Contact(threema_id.into()),
            common::ConversationId::DistributionList(distribution_list_id) => {
                Self::DistributionList(distribution_list_id)
            },
            common::ConversationId::Group(group_identity) => Self::Group(group_identity.into()),
        }
    }
}
impl TryFrom<ConversationId> for common::ConversationId {
    type Error = ConversionError;

    fn try_from(conversation_id: ConversationId) -> Result<Self, Self::Error> {
        Ok(match conversation_id {
            ConversationId::Contact(threema_id) => Self::Contact(threema_id.try_into()?),
            ConversationId::DistributionList(distribution_list_id) => {
                Self::DistributionList(distribution_list_id)
            },
            ConversationId::Group(group_identity) => Self::Group(group_identity.try_into()?),
        })
    }
}

/// Binding version of [`common::ChatServerGroup`].
///
/// # Contract
///
/// Must be a valid Chat Server Group, i.e., matching `[a-zA-Z0-9\-]+`.
#[derive(UniffiNewType)]
pub struct ChatServerGroup(pub String);
impl From<common::ChatServerGroup> for ChatServerGroup {
    fn from(chat_server_group: common::ChatServerGroup) -> Self {
        Self(chat_server_group.into())
    }
}
impl TryFrom<ChatServerGroup> for common::ChatServerGroup {
    type Error = ConversionError;

    fn try_from(chat_server_group: ChatServerGroup) -> Result<Self, Self::Error> {
        Ok(chat_server_group.0.as_str().try_into()?)
    }
}

/// Binding version of [`common::DeviceCookie`].
///
/// # Contract
///
/// Must be exactly 16 bytes.
#[derive(Name, UniffiNewType)]
#[uniffi_new_type(fixed_size_bytes = common::DeviceCookie)]
pub struct DeviceCookie(pub Vec<u8>);

/// Binding version of [`common::HashedNonce`].
///
/// # Contract
///
/// Must be exactly 32 bytes.
#[derive(Name, UniffiNewType)]
#[uniffi_new_type(fixed_size_bytes = common::HashedNonce)]
pub struct HashedNonce(pub Vec<u8>);
