//! Group structs.
use std::collections::HashSet;

use libthreema_macros::Name;

use crate::{
    common::{GroupIdentity, ThreemaId},
    model::profile::ProfilePicture,
    protobuf,
    provider::ProviderError,
    utils::update::{Apply as _, ApplySome as _, Delta, TryApply},
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
#[cfg_attr(test, derive(PartialEq))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum GroupNotificationTriggerPolicyOverridePolicy {
    /// Only trigger a notification if the user is mentioned in a _conversation_ message.
    Mentioned,

    /// Never trigger a notification message.
    Never,
}

/// Notification trigger policy override for a group conversation.
#[derive(Clone, Debug, Name)]
#[cfg_attr(test, derive(PartialEq))]
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
#[cfg_attr(test, derive(PartialEq))]
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

/// All protocol relevant data associated to update a group with the following exclusions:
///
/// - `profile_picture`
pub struct GroupUpdate {
    /// Group identity.
    pub identity: GroupIdentity,

    /// Name of the group.
    pub name: Option<String>,

    /// The user's membership state within the group.
    pub user_state: Option<protobuf::d2d_sync::group::UserState>,

    /// Updated group member list (**NOT** including the creator or the user itself).
    pub members: Option<HashSet<ThreemaId>>,

    /// Notification trigger policy for the group.
    pub notification_trigger_policy_override: Delta<GroupNotificationTriggerPolicyOverride>,

    /// Conversation category of the group.
    pub conversation_category: Option<protobuf::d2d_sync::ConversationCategory>,

    /// Conversation visibility of the group.
    pub conversation_visibility: Option<protobuf::d2d_sync::ConversationVisibility>,
}
impl GroupUpdate {
    #[expect(dead_code, reason = "TODO(LIB-143): Will be used later.")]
    pub(crate) fn default(identity: GroupIdentity) -> Self {
        Self {
            identity,
            name: None,
            user_state: None,
            members: None,
            notification_trigger_policy_override: Delta::Unchanged,
            conversation_category: None,
            conversation_visibility: None,
        }
    }
}

#[cfg(any(test, feature = "cli"))]
impl TryApply<GroupUpdate> for Group {
    type Error = ProviderError;

    /// Try applying the group update to the group.
    ///
    /// # Errors
    ///
    /// Returns [`ProviderError::ContractViolation`] if the group identity mismatches.
    fn try_apply(&mut self, update: GroupUpdate) -> Result<(), Self::Error> {
        let GroupUpdate {
            identity,
            name,
            user_state,
            members,
            notification_trigger_policy_override,
            conversation_category,
            conversation_visibility,
        } = update;

        // Ensure the identity equals before updating.
        if identity != self.identity {
            return Err(ProviderError::ContractViolation(
                "Group update does not match group".to_owned(),
            ));
        }

        // Update all properties.
        self.name.apply_some(name);
        self.user_state.apply_some(user_state);
        self.members.apply_some(members);
        self.notification_trigger_policy_override
            .apply(notification_trigger_policy_override);
        self.conversation_category.apply_some(conversation_category);
        self.conversation_visibility.apply_some(conversation_visibility);

        // Done
        Ok(())
    }
}

/// All protocol relevant data associated to a group.
#[derive(Clone, Debug, Name)]
#[cfg_attr(test, derive(PartialEq))]
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
    ///       [`ProviderError::ContractViolation`].¹
    ///    2. If the `group.creator` is neither the user, nor a known contact², return
    ///       [`ProviderError::ContractViolation`].
    ///    3. For each `member` of `group.members`:
    ///       1. If `member` equals `group.identity.creator_identity`, return
    ///          [`ProviderError::ContractViolation`].
    ///       2. If `member` is the user's identity, return [`ProviderError::ContractViolation`].
    ///       3. If `member` is not a known contact², return [`ProviderError::ContractViolation`].
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

    // TODO(LIB-209): Evaluate whether this is necessary.
    /// 1. Look up the group associated to `identity` and let `group` be the result.¹
    /// 2. If `group` is not defined, return [`ProviderError::ContractViolation`].
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

    /// 1. For each `update` of `updates`:
    ///    1. If no group with the identity `update.identity` exists, return
    ///       [`ProviderError::ContractViolation`].¹
    ///    2. If update.members is set:
    ///       1. For each `member` of `update.members`:
    ///          1. If `member` equals `update.identity.creator_identity`, return
    ///             [`ProviderError::ContractViolation`].
    ///          2. If `member` is the user's identity, return [`ProviderError::ContractViolation`].
    ///          3. If `member` is not a known contact², return [`ProviderError::ContractViolation`].
    /// 2. For each `update` of `updates`:
    ///    1. Apply `update` to the group referred to by `update.identity`.
    ///
    /// ¹: This must include groups marked as _left_.
    ///
    /// ²: This must consider contacts with any acquaintance level, including _deleted_.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters or an invalid state. Otherwise, this function is
    /// considered infallible and should not return an error.
    fn update(&mut self, updates: Vec<GroupUpdate>) -> Result<(), ProviderError>;

    /// Return the group¹ stored for `identity`, if any.
    ///
    /// ¹: This must include groups marked as _left_.
    ///
    /// # Errors
    ///
    /// This function is considered infallible and should not return an error.
    fn get(&self, identity: GroupIdentity) -> Result<Option<Group>, ProviderError>;

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

    /// Return whether or not the group specified by `identity` exists¹.
    ///
    /// ¹: This must include groups marked as _left_.
    ///
    /// # Errors
    ///
    /// This function is considered infallible and should not return an error.
    fn has(&self, identity: GroupIdentity) -> Result<bool, ProviderError>;

    /// 1. If `identity` is the user's Threema ID, return [`ProviderError::ContractViolation`].
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
