//! An account for backups that ensures sanity of the stored/restored data.

use std::collections::{HashMap, HashSet};

use tracing::{trace, warn};

use crate::{
    common::{ConversationId, DistributionListId, GroupIdentity, MessageId, ThreemaId, keys::PublicKey},
    model::{
        contact::Contact,
        distribution_list::DistributionList,
        group::GroupWithProfilePicture,
        message::{MessageState, MessageStateBody, PollClose, PollOpen},
        poll::{Poll, PollId},
        settings::Settings,
    },
    protobuf,
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

struct EncounteredPolls(HashMap<(ConversationId, PollId), EncounteredPoll>);
impl EncounteredPolls {
    fn new() -> Self {
        Self(HashMap::new())
    }

    fn check_and_add(&mut self, poll: &Poll) -> bool {
        // Bail if the poll has been encountered before.
        if self.0.contains_key(&(poll.conversation, poll.id)) {
            return false;
        }

        // Add the poll.
        let _ = self
            .0
            .insert((poll.conversation, poll.id), EncounteredPoll::default());
        true
    }

    #[must_use]
    fn check_open(&mut self, conversation: ConversationId, poll_open: &PollOpen) -> EncounteredPollCheck {
        // Bail if the referenced poll has not been encountered before.
        let Some(poll) = self.0.get_mut(&(conversation, poll_open.id)) else {
            return EncounteredPollCheck::Unknown;
        };

        // Bail if the poll was already opened before.
        if poll.encountered_open {
            return EncounteredPollCheck::ReferencedBefore;
        }

        // Mark the poll as opened and return Ok.
        poll.encountered_open = true;
        EncounteredPollCheck::Ok
    }

    #[must_use]
    fn check_close(&mut self, conversation: ConversationId, poll_close: &PollClose) -> EncounteredPollCheck {
        // Bail if the referenced poll has not been encountered before.
        let Some(poll) = self.0.get_mut(&(conversation, poll_close.id)) else {
            return EncounteredPollCheck::Unknown;
        };

        // Bail if the poll was already closed before.
        if poll.encountered_close {
            return EncounteredPollCheck::ReferencedBefore;
        }

        // Mark the poll as closed and return Ok.
        poll.encountered_close = true;
        EncounteredPollCheck::Ok
    }
}

/// Tracks data encountered during backup creation or restoration to enforce protocol invariance.
pub(super) struct BackupAccountant {
    user_identity: ThreemaId,

    /// A map of encountered contacts to their acquaintance level.
    ///
    /// Note: The public keys are stored separately for efficient lookup.
    contact_acquaintance_levels: HashMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>,

    /// A set of all the encountered contact public keys.
    ///
    /// Note: This is used to efficiently check whether we have encountered a contact's public key before.
    contact_public_keys: HashSet<PublicKey>,

    /// A list of all the user's distribution lists with its members (not including the user).
    distribution_lists: HashMap<DistributionListId, HashSet<ThreemaId>>,

    /// A list of all the user's groups with its members (not including the creator or the user).
    groups: HashMap<GroupIdentity, HashSet<ThreemaId>>,

    /// A set of poll events that have been encountered before.
    polls: EncounteredPolls,

    message_ids: HashSet<(ConversationId, MessageId)>,
}
impl BackupAccountant {
    pub(super) fn new(user_identity: ThreemaId) -> Self {
        Self {
            user_identity,
            contact_acquaintance_levels: HashMap::new(),
            contact_public_keys: HashSet::new(),
            distribution_lists: HashMap::new(),
            groups: HashMap::new(),
            polls: EncounteredPolls::new(),
            message_ids: HashSet::new(),
        }
    }

    /// Sanitize settings by removing any references to the user's own identity.
    pub(super) fn sanitize_settings(&self, mut settings: Settings) -> Settings {
        settings.blocked_identities.retain(|identity| {
            if *identity == self.user_identity {
                warn!("Dropping the user's identity from blocked identities");
                false
            } else {
                true
            }
        });
        settings.exclude_from_sync_identities.retain(|identity| {
            if *identity == self.user_identity {
                warn!("Dropping the user's identity from identities excluded from sync");
                false
            } else {
                true
            }
        });
        settings
    }

    /// Check if the identity should be added.
    pub(super) fn check_and_add_contact(&mut self, contact: &Contact) -> bool {
        let identity = contact.identity;

        // Bail if the contact has the user's identity.
        if identity == self.user_identity {
            warn!("Skipping contact with the user's identity");
            return false;
        }

        // Bail if the public key already exists.
        if self.contact_public_keys.contains(&contact.public_key) {
            warn!(
                ?identity,
                "Skipping contact with same public key as previous contact"
            );
            return false;
        }

        // Bail if the identity was encountered before.
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

    /// Sanitize a distribution list and check if it should be added.
    pub(super) fn sanitize_and_add_distribution_list(
        &mut self,
        mut distribution_list: DistributionList,
    ) -> Option<DistributionList> {
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

        // Bail if the member list is empty.
        if distribution_list.members.is_empty() {
            warn!(id = ?distribution_list.identity, "Skipping distribution list with empty member list");
            return None;
        }

        // Bail if the distribution list has been previously encountered.
        if self.distribution_lists.contains_key(&distribution_list.identity) {
            warn!(id = ?distribution_list.identity, "Skipping previously encountered distribution list");
            return None;
        }

        // All checks passed, add the distribution list.
        let _ = self
            .distribution_lists
            .insert(distribution_list.identity, distribution_list.members.clone());
        trace!(id = ?distribution_list.identity, "Distribution list passed all sanity checks");
        Some(distribution_list)
    }

    /// Sanitize the group and check if it should be added.
    ///
    /// Note: We explicitly allow groups with an empty members list (a.k.a. _notes group_).
    pub(super) fn sanitize_and_add_group(
        &mut self,
        mut group: GroupWithProfilePicture,
    ) -> Option<GroupWithProfilePicture> {
        let group_identity = group.group.identity;

        // Bail if the creator is not known.
        if !(group_identity.creator_identity == self.user_identity
            || self
                .contact_acquaintance_levels
                .contains_key(&group_identity.creator_identity))
        {
            warn!(?group_identity, "Skipping group with unknown creator");
            return None;
        }

        // Sanitize group members.
        group.group.members.retain(|member| {
            // Remove members equal to the creator.
            if member == &group.group.identity.creator_identity {
                warn!(?group_identity, "Removing creator from member list");
                return false;
            }

            // Remove members equal to the user.
            if member == &self.user_identity {
                warn!(?group_identity, "Removing user from member list");
                return false;
            }

            // Remove unknown members.
            if !self.contact_acquaintance_levels.contains_key(member) {
                warn!(?group_identity, ?member, "Removing unknown group member");
                return false;
            }

            true
        });

        // Bail if the group was encountered before.
        if self.groups.contains_key(&group_identity) {
            warn!(?group_identity, "Skipping previously encountered group");
            return None;
        }

        // All checks passed, add the group.
        let _ = self.groups.insert(group_identity, group.group.members.clone());
        trace!(?group_identity, "Group passed all sanity checks");
        Some(group)
    }

    /// Check if the poll should be added.
    pub(super) fn check_and_add_poll(&mut self, poll: &Poll) -> bool {
        let poll_id = poll.id;
        let conversation = poll.conversation;

        // Bail if the conversation is unknown.
        match conversation {
            ConversationId::Contact(contact) => {
                if !self.contact_acquaintance_levels.contains_key(&contact) {
                    warn!(
                        ?poll_id,
                        ?conversation,
                        "Skipping poll in unknown 1:1 conversation"
                    );
                    return false;
                }
            },
            ConversationId::DistributionList(_) => {
                warn!(
                    ?poll_id,
                    ?conversation,
                    "Skipping poll in distribution list (this is not supported)"
                );
                return false;
            },
            ConversationId::Group(group_identity) => {
                if !self.groups.contains_key(&group_identity) {
                    warn!(
                        ?poll_id,
                        ?conversation,
                        "Skipping poll in unknown group conversation"
                    );
                    return false;
                }
            },
        }

        // Bail if the creator is neither the user nor a known contact.
        if !(poll.creator_identity == self.user_identity
            || self
                .contact_acquaintance_levels
                .contains_key(&poll.creator_identity))
        {
            warn!(
                ?poll_id,
                ?conversation,
                creator = ?&poll.creator_identity,
                "Skipping poll with unknown creator"
            );
            return false;
        }

        // Bail if any participant is unknown.
        if let Some(participants) = poll.participants() {
            for participant in participants {
                if !(participant == self.user_identity
                    || self.contact_acquaintance_levels.contains_key(&participant))
                {
                    warn!(
                        ?poll_id,
                        ?conversation,
                        ?participant,
                        "Skipping poll with unknown participant"
                    );
                    return false;
                }
            }
        }

        // Bail if the poll has been encountered before.
        if !self.polls.check_and_add(poll) {
            warn!(?poll_id, ?conversation, "Skipping previously encountered poll");
            return false;
        }

        trace!(?poll_id, ?conversation, "Poll passed all sanity checks");
        true
    }

    /// Sanitize and check if the message should be added, validating its conversation and reactions.
    pub(super) fn sanitize_and_add_message(&mut self, mut message: MessageState) -> Option<MessageState> {
        let conversation_id = message.conversation_id;
        let message_id = message.message_id;

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
                    return None;
                }
            },
            ConversationId::DistributionList(distribution_list) => {
                if !self.distribution_lists.contains_key(&distribution_list) {
                    warn!(
                        ?message_id,
                        ?conversation_id,
                        "Skipping message in unknown distribution list"
                    );
                    return None;
                }
            },
            ConversationId::Group(group_identity) => {
                if !self.groups.contains_key(&group_identity) {
                    warn!(
                        ?message_id,
                        ?conversation_id,
                        "Skipping message in unknown group conversation"
                    );
                    return None;
                }
            },
        }

        // Sanitize reactions.
        message.reactions.retain(|reaction| {
            if reaction.creator_identity == self.user_identity
                || self
                    .contact_acquaintance_levels
                    .contains_key(&reaction.creator_identity)
            {
                true
            } else {
                warn!(
                    ?message_id,
                    ?conversation_id,
                    ?reaction,
                    "Removing reaction from unknown sender"
                );
                false
            }
        });

        // Run body-specific checks.
        match &message.body {
            MessageStateBody::PollOpen(poll_open) => {
                let poll_id = poll_open.id;
                match self.polls.check_open(conversation_id, poll_open) {
                    EncounteredPollCheck::Unknown => {
                        warn!(
                            ?message_id,
                            ?conversation_id,
                            ?poll_id,
                            "Skipping poll-open message for unknown poll state"
                        );
                        return None;
                    },
                    EncounteredPollCheck::ReferencedBefore => {
                        warn!(
                            ?message_id,
                            ?conversation_id,
                            ?poll_id,
                            "Skipping poll-open message for a poll state that was already marked as opened \
                             before"
                        );
                        return None;
                    },
                    EncounteredPollCheck::Ok => {
                        // All fine, continue.
                    },
                }
            },

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
                            ?message_id,
                            ?conversation_id,
                            ?poll_id,
                            "Skipping poll-close message for a poll state that was already marked as closed \
                             before"
                        );
                        return None;
                    },
                    EncounteredPollCheck::Ok => {
                        // All fine, continue.
                    },
                }
            },

            MessageStateBody::Deleted(_) => {
                if !message.reactions.is_empty() {
                    warn!(
                        ?message_id,
                        ?conversation_id,
                        "Removing all reactions from deleted message"
                    );
                    message.reactions.clear();
                }
            },

            MessageStateBody::Text(_) | MessageStateBody::Location(_) => {
                // No checks required.
            },
        }

        // Bail if the message ID was encountered before.
        if !self.message_ids.insert((conversation_id, message_id)) {
            warn!(
                ?message_id,
                ?conversation_id,
                "Skipping already encountered message"
            );
            return None;
        }

        // Everything passed, return true.
        trace!(
            ?message_id,
            ?conversation_id,
            "Sanitized message passed all checks"
        );
        Some(message)
    }
}
