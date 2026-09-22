//! An account for backups that ensures sanity of the stored/restored data.

use std::collections::{HashMap, HashSet};

use educe::Educe;
use tracing::{trace, warn};

use crate::{
    common::{ConversationId, DistributionListId, GroupIdentity, MessageId, ThreemaId, keys::PublicKey},
    model::{
        contact::Contact,
        distribution_list::DistributionList,
        group::Group,
        message::{MessageState, MessageStateBody, PollClose, PollOpen},
        poll::{Poll, PollId},
        settings::Settings,
    },
    protobuf,
    utils::debug::debug_collection_length,
};

#[derive(Default)]
struct EncounteredPoll {
    /// Whether we have already encountered the [`PollOpen`] message.
    encountered_open: bool,

    /// Whether we have already encountered the [`PollClose`] message.
    encountered_close: bool,
}

/// Result of checking whether a poll has been encountered before.
pub(super) enum EncounteredPollCheck {
    /// The poll was not encountered before.
    Unknown,

    /// The poll was already referenced by a previous message of the same type (i.e., a [`PollOpen`] or
    /// [`PollClose`]).
    ReferencedBefore,

    /// Everything is Ok, i.e., the poll was encountered before and has been referenced for the first time for
    /// this type.
    Ok,
}

#[derive(Educe)]
#[educe(Debug)]
struct EncounteredPolls(
    #[educe(Debug(method(debug_collection_length)))] HashMap<(ConversationId, PollId), EncounteredPoll>,
);
impl EncounteredPolls {
    fn new() -> Self {
        Self(HashMap::new())
    }

    /// Add the poll to the encountered polls and return whether it was newly inserted. That is:
    /// - If the poll was not previously encountered, return `true`.
    /// - If the poll was previously encountered, replace the previously associated data and return `false`.
    fn insert(&mut self, poll_state: &Poll) -> bool {
        self.0
            .insert(
                (poll_state.conversation, poll_state.id),
                EncounteredPoll::default(),
            )
            .is_none()
    }

    #[must_use]
    fn check_open(&mut self, conversation: ConversationId, poll_open: &PollOpen) -> EncounteredPollCheck {
        // Check whether we know the poll.
        let Some(poll) = self.0.get_mut(&(conversation, poll_open.id)) else {
            return EncounteredPollCheck::Unknown;
        };

        // Check whether we have encountered it before.
        if poll.encountered_open {
            return EncounteredPollCheck::ReferencedBefore;
        }

        poll.encountered_open = true;
        EncounteredPollCheck::Ok
    }

    #[must_use]
    fn check_close(&mut self, conversation: ConversationId, poll_close: &PollClose) -> EncounteredPollCheck {
        // Check whether we know the poll.
        let Some(poll) = self.0.get_mut(&(conversation, poll_close.id)) else {
            return EncounteredPollCheck::Unknown;
        };

        // Check whether we have encountered it before.
        if poll.encountered_close {
            return EncounteredPollCheck::ReferencedBefore;
        }

        poll.encountered_close = true;
        EncounteredPollCheck::Ok
    }
}

/// Tracks data encountered during backup creation or restoration to enforce protocol invariants.
#[derive(Educe)]
#[educe(Debug)]
pub(super) struct BackupAccountant {
    user_identity: ThreemaId,

    /// A map of encountered contacts to their acquaintance level.
    ///
    /// Note: The public keys are stored separately for efficient lookup.
    #[educe(Debug(method(debug_collection_length)))]
    contact_acquaintance_levels: HashMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>,

    /// A set of all the encountered contact public keys.
    ///
    /// Note: This is used to efficiently check whether we have encountered a contact's public key before.
    #[educe(Debug(method(debug_collection_length)))]
    contact_public_keys: HashSet<PublicKey>,

    /// A list of all the user's groups with its members (not including the creator or the user).
    #[educe(Debug(method(debug_collection_length)))]
    groups: HashMap<GroupIdentity, HashSet<ThreemaId>>,

    /// A list of all the user's distribution lists with its members (not including the user).
    #[educe(Debug(method(debug_collection_length)))]
    distribution_lists: HashMap<DistributionListId, HashSet<ThreemaId>>,

    polls: EncounteredPolls,

    #[educe(Debug(method(debug_collection_length)))]
    message_ids: HashSet<(ConversationId, MessageId)>,
}
impl BackupAccountant {
    /// Create a new accountant for the given user identity.
    pub(super) fn new(user_identity: ThreemaId) -> Self {
        Self {
            user_identity,
            contact_acquaintance_levels: HashMap::new(),
            contact_public_keys: HashSet::new(),
            groups: HashMap::new(),
            distribution_lists: HashMap::new(),
            polls: EncounteredPolls::new(),
            message_ids: HashSet::new(),
        }
    }

    /// Return the number of contacts that have been added.
    pub(super) fn number_of_contacts(&self) -> usize {
        self.contact_acquaintance_levels.len()
    }

    /// Return the number of groups that have been added.
    pub(super) fn number_of_groups(&self) -> usize {
        self.groups.len()
    }

    /// Return the number of distribution lists that have been added.
    pub(super) fn number_of_distribution_lists(&self) -> usize {
        self.distribution_lists.len()
    }

    /// Return the number of polls that have been added.
    pub(super) fn number_of_polls(&self) -> usize {
        self.polls.0.len()
    }

    /// Return the number of messages that have been added.
    pub(super) fn number_of_messages(&self) -> usize {
        self.message_ids.len()
    }

    /// Sanitize settings by removing any references to the user's own identity.
    pub(super) fn sanitize_settings(&self, settings: &mut Settings) {
        settings.blocked_identities.retain(|identity| {
            if *identity == self.user_identity {
                warn!("Skipping blocked identity with the user's identity");
                false
            } else {
                true
            }
        });
        settings.exclude_from_sync_identities.retain(|identity| {
            if *identity == self.user_identity {
                warn!("Skipping excluded from sync identity with the user's identity");
                false
            } else {
                true
            }
        });
    }

    /// Check if the identity should be added.
    pub(super) fn check_and_add_contact(&mut self, contact: &Contact) -> bool {
        let identity = contact.identity;
        if identity == self.user_identity {
            warn!("Skipping contact with the user's identity");
            return false;
        }

        // Check that the public key is unique.
        if self.contact_public_keys.contains(&contact.public_key) {
            warn!(
                ?identity,
                "Skipping contact with same public key as previous contact"
            );
            return false;
        }

        // Check if identity was not encountered before.
        if self.contact_acquaintance_levels.contains_key(&identity) {
            warn!(?identity, "Skipping previously encountered contact");
            return false;
        }

        // Store contact acquaintance level and public key.
        let _ = self
            .contact_acquaintance_levels
            .insert(identity, contact.acquaintance_level);
        let _ = self.contact_public_keys.insert(contact.public_key);
        trace!(?identity, "Contact passed all sanity checks");
        true
    }

    /// Sanitize the group and check if it should be added.
    pub(super) fn sanitize_and_add_group(&mut self, group: &mut Group) -> bool {
        let group_identity = group.identity;
        // Check if creator is known.
        if !(group_identity.creator_identity == self.user_identity
            || self
                .contact_acquaintance_levels
                .contains_key(&group_identity.creator_identity))
        {
            warn!(?group_identity, "Skipping group with unknown creator");
            return false;
        }

        // Check that the members do neither contain the user nor the creator.
        if group
            .members
            .iter()
            .any(|member| member == &self.user_identity || member == &group_identity.creator_identity)
        {
            warn!(?group_identity, members = ?group.members, "Skipping group with creator or user in members");
            return false;
        }

        // Remove unknown members.
        group.members.retain(|member| {
            if self.contact_acquaintance_levels.contains_key(member) {
                true
            } else {
                warn!(?group_identity, ?member, "Removing unknown group member");
                false
            }
        });

        // Store group and return if identity was not encountered before.
        if self.groups.contains_key(&group_identity) {
            warn!(?group_identity, "Skipping previously encountered group");
            return false;
        }

        // All checks passed.
        let _ = self.groups.insert(group_identity, group.members.clone());
        trace!(?group_identity, "Group passed all sanity checks");
        true
    }

    /// Sanitize and check if the distribution list should be added.
    pub(super) fn sanitize_and_add_distribution_list(
        &mut self,
        distribution_list: &mut DistributionList,
    ) -> bool {
        distribution_list.members.retain(|member| {
            // Remove user from members.
            if member == &self.user_identity {
                warn!(
                    id = ?distribution_list.identity,
                    "Removing user from distribution list members"
                );
                return false;
            }

            // Remove unknown members.
            if self.contact_acquaintance_levels.contains_key(member) {
                true
            } else {
                warn!(
                    id = ?distribution_list.identity,
                    ?member,
                    "Removing unknown member from distribution list"
                );
                false
            }
        });

        // Don't add distribution lists with empty member list.
        if distribution_list.members.is_empty() {
            warn!(id = ?distribution_list.identity, "Skipping distribution list with empty member list");
            return false;
        }

        // Store distribution list and return if identity was not encountered before.
        if self.distribution_lists.contains_key(&distribution_list.identity) {
            warn!(id = ?distribution_list.identity, "Skipping previously encountered distribution list");
            return false;
        }

        // All checks passed.
        let _ = self
            .distribution_lists
            .insert(distribution_list.identity, distribution_list.members.clone());
        trace!(id = ?distribution_list.identity, "Distribution list passed all sanity checks");
        true
    }

    /// Check if the poll should be added.
    #[tracing::instrument(skip_all, fields(?poll.id))]
    pub(super) fn check_and_add_poll(&mut self, poll: &Poll) -> bool {
        // Check if we know the conversation.
        match poll.conversation {
            ConversationId::Contact(identity) => {
                if !self.contact_acquaintance_levels.contains_key(&identity) {
                    warn!(?identity, "Skipping poll in unknown 1:1 conversation");
                    return false;
                }
            },
            ConversationId::DistributionList(distribution_list_id) => {
                warn!("Skipping poll in distribution list {distribution_list_id} (this is not supported)");
                return false;
            },
            ConversationId::Group(group_identity) => {
                if !self.groups.contains_key(&group_identity) {
                    warn!(?group_identity, "Skipping poll in unknown group conversation");
                    return false;
                }
            },
        }

        // Check if we know the creator.
        if !(poll.creator_identity == self.user_identity
            || self
                .contact_acquaintance_levels
                .contains_key(&poll.creator_identity))
        {
            warn!(creator = ?&poll.creator_identity, "Skipping poll with unknown creator");
            return false;
        }

        // Check if we know all participants.
        if let Some(participants) = poll.participants() {
            for participant in participants {
                if !(participant == self.user_identity
                    || self.contact_acquaintance_levels.contains_key(&participant))
                {
                    warn!(?participant, "Skipping poll with unknown participant");
                    return false;
                }
            }
        }

        // Check if we have previously encountered the poll.
        if !self.polls.insert(poll) {
            warn!("Skipping previously encountered poll");
            return false;
        }

        trace!("Poll passed all sanity checks");
        true
    }

    /// Sanitize and check if the message should be added, validating its conversation and reactions.
    pub(super) fn sanitize_and_add_message(&mut self, message_state: &mut MessageState) -> bool {
        let conversation_id = message_state.conversation_id;
        let message_id = message_state.message_id;

        // Check if the conversation is valid.
        match conversation_id {
            ConversationId::Contact(contact) => {
                if self
                    .contact_acquaintance_levels
                    .get(&contact)
                    .is_none_or(|acquaintance_level| {
                        *acquaintance_level != protobuf::d2d_sync::contact::AcquaintanceLevel::Direct
                    })
                {
                    warn!(
                        ?message_id,
                        ?conversation_id,
                        "Skipping message in unknown 1:1 conversation"
                    );
                    return false;
                }
            },
            ConversationId::DistributionList(distribution_list) => {
                if !self.distribution_lists.contains_key(&distribution_list) {
                    warn!(
                        ?message_id,
                        ?conversation_id,
                        "Skipping message in unknown distribution list"
                    );
                    return false;
                }
            },
            ConversationId::Group(group_identity) => {
                if !self.groups.contains_key(&group_identity) {
                    warn!(
                        ?message_id,
                        ?conversation_id,
                        "Skipping message in unknown group conversation"
                    );
                    return false;
                }
            },
        }

        // Sanitize reactions.
        message_state.reactions.retain(|reaction| {
            if reaction.creator_identity == self.user_identity
                || self
                    .contact_acquaintance_levels
                    .contains_key(&reaction.creator_identity)
            {
                true
            } else {
                warn!(?message_id, ?reaction, "Removing reaction from unknown sender");
                false
            }
        });

        // Check body specific stuff.
        // TODO(LIB-117): Return group polls as well.
        match &message_state.body {
            // `PollOpen` messages.
            MessageStateBody::PollOpen(poll_open) => {
                let poll_id = poll_open.id;
                match self.polls.check_open(conversation_id, poll_open) {
                    EncounteredPollCheck::Unknown => {
                        warn!(
                            ?conversation_id,
                            ?poll_id,
                            "Skipping poll-open message for unknown poll state"
                        );
                        return false;
                    },
                    EncounteredPollCheck::ReferencedBefore => {
                        warn!(
                            ?conversation_id,
                            ?poll_id,
                            "Skipping poll-open message for a poll state that was already marked as opened \
                             before"
                        );
                        return false;
                    },
                    EncounteredPollCheck::Ok => {
                        // All fine, continue.
                    },
                }
            },

            // `PollClose` messages.
            MessageStateBody::PollClose(poll_close) => {
                let poll_id = poll_close.id;

                #[expect(clippy::match_same_arms, reason = "Different comments")]
                match self.polls.check_close(conversation_id, poll_close) {
                    EncounteredPollCheck::Unknown => {
                        // This is fine, we might not have been in conversation when receiving the poll-open
                        // message.
                    },
                    EncounteredPollCheck::ReferencedBefore => {
                        warn!(
                            ?conversation_id,
                            ?poll_id,
                            "Skipping poll-close message for a poll state that was already marked as closed \
                             before"
                        );
                        return false;
                    },
                    EncounteredPollCheck::Ok => {
                        // TODO(LIB-97): @lgr: We could check that the corresponding [`Poll`] is closed.
                        // But, this is quite some effort: We would need to keep track of all poll states, and
                        // differentiate whether we are in creation or restoration phase.
                        // (It makes only sense to close during restoration). Hence, I'm not sure whether it
                        // is really worth the effort.
                        //
                        // All fine, continue.
                    },
                }
            },
            MessageStateBody::Text(_) | MessageStateBody::Location(_) | MessageStateBody::Deleted(_) => {
                // No checks for other message bodies.
            },
        }

        // Check if the message ID was not encountered before.
        if !self.message_ids.insert((conversation_id, message_id)) {
            warn!(?message_id, "Skipping already encountered message.");
            return false;
        }

        // Everything passed, return true.
        true
    }
}
