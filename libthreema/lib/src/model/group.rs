//! Group structs.
use std::collections::HashSet;

use libthreema_macros::Name;

use crate::{
    common::{GroupIdentity, ThreemaId},
    model::profile::ProfilePicture,
    protobuf,
    provider::ProviderError,
};

/// A filter for membership queries.
#[derive(Debug)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum GroupMembershipFilter {
    /// Only consider active groups, i.e., groups that are not marked as _left_.
    OnlyActive,

    /// Consider any groups (including groups that are marked as _left_).
    Any,
}

/// Policy for a [`GroupNotificationTriggerPolicyOverride`].
#[derive(Clone, Debug)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum GroupNotificationTriggerPolicyOverridePolicy {
    /// Only trigger a notification if the user is mentioned in a _conversation_ message.
    Mentioned,

    /// Never trigger a notification message.
    Never,
}

/// Notification trigger policy override for a group conversation.
#[derive(Clone, Debug, Name)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct GroupNotificationTriggerPolicyOverride {
    /// The notification policy to apply.
    pub policy: GroupNotificationTriggerPolicyOverridePolicy,

    /// Optional unix-ish timestamp in milliseconds when the policy should expire and fall back to the
    /// default.
    pub expires_at: Option<u64>,
}

/// All protocol relevant data associated to a group with the following exclusions:
///
/// - profile picture
#[derive(Clone, Debug)]
pub struct Group {
    /// Group identity.
    pub identity: GroupIdentity,

    /// Name of the group.
    ///
    /// Empty string means that the group has no provided name.
    pub name: String,

    /// Unix-ish timestamp in milliseconds when the group has been created locally.
    pub created_at: u64,

    /// Optional Unix-ish timestamp in milliseconds when the conversation with this group was last updated.
    pub last_update_at: Option<u64>,

    /// The user's membership state within the group.
    pub user_state: protobuf::d2d_sync::group::UserState,

    /// Group members (**NOT** including the creator or the user itself).
    pub members: HashSet<ThreemaId>,

    /// Notification trigger policy for the group.
    pub notification_trigger_policy_override: Option<GroupNotificationTriggerPolicyOverride>,

    /// Conversation category of the group.
    pub conversation_category: protobuf::d2d_sync::ConversationCategory,

    /// Conversation visibility of the group.
    pub conversation_visibility: protobuf::d2d_sync::ConversationVisibility,
}

/// All protocol relevant data associated to a group.
#[derive(Clone, Debug, Name)]
pub struct GroupWithProfilePicture {
    /// The group.
    pub group: Group,

    /// The group profile picture (if any).
    pub profile_picture: Option<ProfilePicture>,
}

/// Group storage provider.
pub trait GroupProvider {
    /// 1. For each `group` of `groups`:
    ///    1. If a group with group identity `group.identity` already exists, return
    ///       [`ProviderError::InvalidState`].¹
    ///    2. If the `group.creator` is neither the user, nor a known contact², return
    ///       [`ProviderError::InvalidState`].
    ///    3. For each `member` of `group.members`:
    ///       1. If `member` is the user's identity, return [`ProviderError::InvalidState`].
    ///       2. If `member` is not a known contact², return [`ProviderError::InvalidState`].
    /// 2. For each `group` of `groups`:
    ///    1. Add `group` to the application storage.
    ///
    /// ¹: This must include groups marked as _left_.
    ///
    /// ²: This must consider contacts with any acquaintance level, including _deleted_.
    ///
    /// ³: By adding groups, each associated member's and the creator's acquaintance level will be elevated to
    /// at least _group_. This does not require any change in storage for those contacts since acquaintance
    /// level _deleted_ and _group_ are numerically identical.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters or an invalid state. Otherwise, this function is
    /// considered infallible and should not return an error.
    fn add_with_profile_picture(&mut self, groups: Vec<GroupWithProfilePicture>)
    -> Result<(), ProviderError>;

    /// 1. Look up the group associated to `identity` and let `group` be the result.¹
    /// 2. If `group` is not defined, return [`ProviderError::InvalidState`].
    /// 3. Set the profile picture associated to `group` to `profile_picture`.²
    ///
    /// ¹: This must include groups marked as _left_.
    ///
    /// ²: [`None`] signals to remove the profile picture.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters or an invalid state. Otherwise, this function is
    /// considered infallible and should not return an error.
    fn set_profile_picture(
        &mut self,
        identity: GroupIdentity,
        profile_picture: Option<ProfilePicture>,
    ) -> Result<(), ProviderError>;

    /// Return all group identities of all¹ groups.
    ///
    /// ¹: This must include groups marked as _left_.
    ///
    /// # Errors
    ///
    /// This function is considered infallible and should not return an error.
    fn get_identities(&self) -> Result<HashSet<GroupIdentity>, ProviderError>;

    /// Return the group¹ stored for `identity` (with its associated profile pictures), if any.
    ///
    /// ¹: This must include groups marked as _left_.
    ///
    /// # Errors
    ///
    /// This function is considered infallible and should not return an error.
    fn get_with_profile_picture(
        &self,
        identity: GroupIdentity,
    ) -> Result<Option<GroupWithProfilePicture>, ProviderError>;

    /// 1. If `identity` is the user's Threema ID, return [`ProviderError::InvalidState`].
    /// 2. Return whether `identity` is part¹ of a group matching `filter`.
    ///
    /// ¹: Either as a regular group member or as the creator of the group.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters or an invalid state. Otherwise, this function is
    /// considered infallible and should not return an error.
    fn is_part_of_any_group(
        &self,
        identity: ThreemaId,
        filter: GroupMembershipFilter,
    ) -> Result<bool, ProviderError>;
}
