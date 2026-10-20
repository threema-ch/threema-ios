//! Tasks of the data backup.
use std::sync::{Arc, Mutex};

use crate::{
    model::{
        contact::ContactProvider, conversation::ConversationProvider,
        distribution_list::DistributionListProvider, group::GroupProvider, poll::PollProvider,
        settings::SettingsProvider, user_profile::UserProfileProvider,
    },
    provider::NonceProvider,
};

pub mod create;
pub mod restore;

/// Common providers for data backup creation/restore.
pub struct DataBackupProviders {
    /// See [`UserProfileProvider`].
    pub user_profile: Arc<Mutex<dyn UserProfileProvider + Send + Sync>>,

    /// See [`SettingsProvider`].
    pub settings: Arc<Mutex<dyn SettingsProvider + Send + Sync>>,

    /// See [`ContactProvider`].
    pub contacts: Arc<Mutex<dyn ContactProvider + Send + Sync>>,

    /// See [`DistributionListProvider`].
    pub distribution_lists: Arc<Mutex<dyn DistributionListProvider + Send + Sync>>,

    /// See [`GroupProvider`].
    pub groups: Arc<Mutex<dyn GroupProvider + Send + Sync>>,

    /// See [`NonceProvider`].
    pub csp_nonces: Arc<Mutex<dyn NonceProvider + Send + Sync>>,

    /// See [`PollProvider`].
    pub polls: Arc<Mutex<dyn PollProvider + Send + Sync>>,

    /// See [`ConversationProvider`].
    pub conversations: Arc<Mutex<dyn ConversationProvider + Send + Sync>>,
}

#[cfg(feature = "slow_tests")]
#[cfg(test)]
mod tests;
