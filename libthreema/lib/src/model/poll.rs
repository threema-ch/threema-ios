//! Poll (ballot) structs.
use core::fmt;
use std::collections::{HashMap, HashSet};

use libthreema_dependencies::data_encoding::HEXLOWER_PERMISSIVE;
use libthreema_macros::{Name, UniffiNewType};

use crate::{
    common::{ConversationId, ThreemaId},
    protobuf,
    provider::ProviderError,
};

/// An identifier of a poll.
///
/// Note: This is only unique if combined with **both** the creator's Threema ID and the conversation ID.
#[derive(Clone, Copy, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
#[cfg_attr(feature = "uniffi", derive(UniffiNewType))]
pub struct PollId(pub u64);
impl fmt::Display for PollId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&HEXLOWER_PERMISSIVE.encode(&self.0.to_le_bytes()))
    }
}

/// A per-poll unique ID of a choice.
#[derive(Copy, Clone, Debug, Name, PartialEq, Eq, Hash)]
#[cfg_attr(feature = "uniffi", derive(UniffiNewType))]
pub struct PollChoiceId(pub u32);

/// A poll choice.
#[derive(Clone, Debug, Name)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct PollChoice {
    /// The poll choice ID.
    pub id: PollChoiceId,

    /// The description.
    pub description: String,
}

/// A vote as part of [`PollVotes::Votes`].
#[derive(Clone, Debug, Name)]
pub struct PollVote {
    /// The list of the voter's current choices.
    pub choices: HashSet<PollChoiceId>,

    /// Unix-ish timestamp in milliseconds for when the choice has initially been created.
    pub created_at: u64,

    /// Unix-ish timestamp in milliseconds for when the choice has been modified.
    pub modified_at: Option<u64>,
}

/// The votes of a [`Poll`].
#[derive(Clone, Debug, Name)]
pub enum PollVotes {
    /// A map of participants to their chosen option(s).
    ///
    /// Used if at least one of the following condition holds:
    ///
    /// - the user is the creator of the poll, **or**
    /// - the display mode is _list_.
    Votes(HashMap<ThreemaId, PollVote>),

    /// A map of choice ids to the amount of participants that voted for it.
    ///
    /// Used if all the following conditions hold:
    ///
    /// - the user is not the creator of the poll, **and**
    /// - the display mode is _summary_.
    Summary(HashMap<PollChoiceId, u16>),
}

/// A poll including all possible choices and votes.
#[derive(Clone, Debug, Name)]
pub struct Poll {
    /// A unique (per creator within a conversation) identifier of the poll.
    pub id: PollId,

    /// The conversation in which the poll is located in.
    pub conversation: ConversationId,

    /// Creator of the poll.
    pub creator_identity: ThreemaId,

    /// Unix-ish timestamp in milliseconds for when the poll has been created.
    pub created_at: u64,

    /// The current state of the poll.
    pub state: protobuf::data_backup::poll::PollState,

    /// A short description/topic for the poll.
    pub description: String,

    /// Answer type.
    pub answer_type: protobuf::data_backup::poll::PollAnswerType,

    /// Announce type.
    pub announce_type: protobuf::data_backup::poll::PollAnnounceType,

    /// Display mode.
    pub display_mode: protobuf::data_backup::poll::PollDisplayMode,

    /// A map from the possible choice IDs to their descriptions.
    pub choices: Vec<PollChoice>,

    /// The votes.
    pub votes: PollVotes,
}
impl Poll {
    #[must_use]
    pub(crate) fn participants(&self) -> Option<Vec<ThreemaId>> {
        match &self.votes {
            PollVotes::Votes(votes) => Some(votes.keys().copied().collect()),
            PollVotes::Summary(_) => None,
        }
    }
}

/// Poll storage interface.
///
/// # Contract
///
/// The following modifications do not require an interaction with libthreema:
///
/// - Removing a poll.
pub trait PollProvider {
    /// 1. For each `poll` of `polls`:
    ///    1. If `poll` refers to a 1:1 contact conversation and the referred contact does not exist, return
    ///       [`ProviderError::InvalidState`].¹
    ///    2. If `poll` refers to a distribution list, return [`ProviderError::InvalidState`].
    ///    3. If `poll` refers to a group conversation and the referred group does not exist, return
    ///       [`ProviderError::InvalidState`].
    ///    4. If the `poll.creator` is neither the user, nor a known contact¹, return
    ///       [`ProviderError::InvalidState`].
    ///    5. If a poll with `poll.id` already exists in the referred conversation, return
    ///       [`ProviderError::InvalidState`].
    ///    6. If `poll.votes` is of type [`PollVotes::Votes`]:
    ///       1. For each `vote` of `poll.votes`, if the `vote`r is neither the user, nor a known contact¹,
    ///          return [`ProviderError::InvalidState`].
    /// 2. For each `poll` of `polls`:
    ///    1. Add `poll` to the application storage.
    ///
    /// ¹: This must consider contacts with any acquaintance level, including _deleted_.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters or an invalid state. Otherwise, this function is
    /// considered infallible and should not return an error.
    fn add(&mut self, polls: Vec<Poll>) -> Result<(), ProviderError>;

    /// 1. Look up all polls of all types of conversations and let `polls` be the result.
    /// 2. Deterministically partition `polls` into non-empty, incrementally zero-based numbered batches¹.
    /// 3. Return the batch with index `batch_index`.
    ///
    /// Note: The ordering does not matter.
    ///
    /// ¹: IMPORTANT: Batches must be non-overlapping between function calls! However, the surrounding
    /// protocol ensures that the batching mechanism is only used in a uninterruptible (_read-only_) state. A
    /// batch should contain about 100 polls. An empty batch signals that no further polls are available.
    ///
    /// # Errors
    ///
    /// This function is considered infallible and should not return an error.
    //-
    // TODO(LIB-168): Replace with iterator pattern.
    fn get_many(&self, batch_index: usize) -> Result<Vec<Poll>, ProviderError>;
}
