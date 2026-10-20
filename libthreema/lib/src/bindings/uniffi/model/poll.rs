//! Binding version of [`poll`].
use std::{collections::HashMap, sync::Arc};

use crate::{
    bindings::uniffi::{
        ConversionError,
        common::{ConversationId, ThreemaId},
    },
    common,
    model::poll::{self, PollId},
    protobuf,
    provider::ProviderError,
};

/// Binding version of [`poll::PollVotes`].
#[derive(uniffi::Enum)]
#[expect(missing_docs, reason = "Binding version")]
pub enum PollVotes {
    Votes(HashMap<ThreemaId, poll::PollVote>),
    Summary(poll::PollVotesSummary),
}
impl From<poll::PollVotes> for PollVotes {
    fn from(votes: poll::PollVotes) -> Self {
        match votes {
            poll::PollVotes::Votes(votes) => Self::Votes(
                votes
                    .into_iter()
                    .map(|(voter, vote)| (ThreemaId::from(voter), vote))
                    .collect(),
            ),
            poll::PollVotes::Summary(votes_summary) => Self::Summary(votes_summary),
        }
    }
}
impl TryFrom<PollVotes> for poll::PollVotes {
    type Error = ConversionError;

    fn try_from(votes: PollVotes) -> Result<Self, Self::Error> {
        Ok(match votes {
            PollVotes::Votes(votes) => Self::Votes(
                votes
                    .into_iter()
                    .map(|(voter, vote)| Ok::<_, Self::Error>((common::ThreemaId::try_from(voter)?, vote)))
                    .collect::<Result<_, _>>()?,
            ),
            PollVotes::Summary(vote_counts) => Self::Summary(vote_counts),
        })
    }
}

/// Binding version of [`poll::Poll`].
#[expect(missing_docs, reason = "Binding version")]
#[derive(uniffi::Record)]
pub struct Poll {
    pub id: PollId,
    pub conversation: ConversationId,
    pub creator_identity: ThreemaId,
    pub created_at: u64,
    pub state: protobuf::data_backup::poll::PollState,
    pub description: String,
    pub answer_type: protobuf::data_backup::poll::PollAnswerType,
    pub announce_type: protobuf::data_backup::poll::PollAnnounceType,
    pub display_mode: protobuf::data_backup::poll::PollDisplayMode,
    pub choices: Vec<poll::PollChoice>,
    pub votes: PollVotes,
}
impl From<poll::Poll> for Poll {
    fn from(poll: poll::Poll) -> Self {
        Self {
            id: poll.id,
            conversation: poll.conversation.into(),
            creator_identity: poll.creator_identity.into(),
            created_at: poll.created_at,
            state: poll.state,
            description: poll.description,
            answer_type: poll.answer_type,
            announce_type: poll.announce_type,
            display_mode: poll.display_mode,
            choices: poll.choices,
            votes: poll.votes.into(),
        }
    }
}
impl TryFrom<Poll> for poll::Poll {
    type Error = ConversionError;

    fn try_from(poll: Poll) -> Result<Self, Self::Error> {
        Ok(Self {
            id: poll.id,
            conversation: poll.conversation.try_into()?,
            creator_identity: poll.creator_identity.try_into()?,
            created_at: poll.created_at,
            state: poll.state,
            description: poll.description,
            answer_type: poll.answer_type,
            announce_type: poll.announce_type,
            display_mode: poll.display_mode,
            choices: poll.choices,
            votes: poll.votes.try_into()?,
        })
    }
}

/// Binding version of [`poll::PollProvider`].
#[expect(missing_docs, clippy::missing_errors_doc, reason = "Binding version")]
#[uniffi::export(with_foreign)]
pub trait PollProvider: Send + Sync {
    fn add(&self, polls: Vec<Poll>) -> Result<(), ProviderError>;
    fn get_many(&self, batch_index: u64) -> Result<Vec<Poll>, ProviderError>;
}
impl<T: PollProvider + ?Sized> poll::PollProvider for Arc<T> {
    fn add(&mut self, polls: Vec<poll::Poll>) -> Result<(), ProviderError> {
        PollProvider::add(self.as_ref(), polls.into_iter().map(Poll::from).collect())
    }

    fn get_many(&self, batch_index: usize) -> Result<Vec<poll::Poll>, ProviderError> {
        PollProvider::get_many(self.as_ref(), batch_index as u64)?
            .into_iter()
            .map(|poll| Ok(poll::Poll::try_from(poll)?))
            .collect()
    }
}
