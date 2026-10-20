//! Distribution list structs.
use std::collections::HashSet;

use libthreema_macros::Name;

use crate::{
    common::{DistributionListId, ThreemaId},
    protobuf,
    provider::ProviderError,
};

/// All protocol relevant data associated to a distribution list with the following exclusions:
///
/// - profile picture
#[derive(Clone, Debug, Name)]
#[cfg_attr(test, derive(PartialEq))]
pub struct DistributionList {
    /// Distribution list identity.
    pub identity: DistributionListId,

    /// Name of the distribution list.
    ///
    /// Empty string means that the distribution list has no provided name.
    pub name: String,

    /// Unix-ish timestamp in milliseconds when the distribution list has been created.
    pub created_at: u64,

    /// Unix-ish timestamp in milliseconds when the conversation with this distribution list was last
    /// updated.
    pub last_update_at: u64,

    /// Distribution list members (**NOT** including the user).
    pub members: HashSet<ThreemaId>,

    /// Conversation category of the distribution list.
    pub conversation_category: protobuf::d2d_sync::ConversationCategory,

    /// Conversation visibility of the distribution list.
    pub conversation_visibility: protobuf::d2d_sync::ConversationVisibility,
}

/// Distribution list storage provider.
pub trait DistributionListProvider {
    /// 1. For each `distribution_list` of `distribution_lists`:
    ///    1. If a distribution list with ID `distribution_list.identity` already exists, return
    ///       [`ProviderError::ContractViolation`].
    ///    2. For each `member` of `distribution_list.members`:
    ///       1. If `member` is the user's identity, return [`ProviderError::ContractViolation`].
    ///       2. If `member` is not a known contact¹, return [`ProviderError::ContractViolation`].
    /// 2. For each `distribution_list` of `distribution_lists`:
    ///    1. Add `distribution_list` to the application storage.
    ///
    /// ¹: This must consider contacts with any acquaintance level, including _deleted_.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters or an invalid state. Otherwise, this function is
    /// considered infallible and should not return an error.
    fn add(&mut self, distribution_lists: Vec<DistributionList>) -> Result<(), ProviderError>;

    /// Return the distribution list stored for `id`, if any.
    ///
    /// # Errors
    ///
    /// This function is considered infallible and should not return an error.
    fn get(&self, id: DistributionListId) -> Result<Option<DistributionList>, ProviderError>;

    /// Return all IDs of all distribution lists.
    ///
    /// # Errors
    ///
    /// This function is considered infallible and should not return an error.
    fn get_ids(&self) -> Result<HashSet<DistributionListId>, ProviderError>;
}
