//! In-memory providers for the CLI.

use core::cell::RefCell;
use std::{
    collections::{BTreeMap, BTreeSet, HashMap, HashSet},
    rc::Rc,
    sync::{Arc, Mutex},
};

use derive_builder::Builder;
use duplicate::duplicate_item;
use itertools::Itertools as _;
use tracing::warn;

use crate::{
    common::{
        ConversationId, ConversationType, DistributionListId, GroupIdentity, HashedNonce, MessageId,
        ThreemaId,
    },
    csp_e2e::CspE2eProtocolProviders,
    model::{
        contact::{Contact, ContactProvider, ContactUpdate, ContactWithProfilePictures},
        conversation::ConversationProvider,
        distribution_list::{DistributionList, DistributionListProvider},
        group::{Group, GroupMembershipFilter, GroupProvider, GroupWithProfilePicture},
        message::{MessageState, MessageStateMetadata, MessageStateUpdate, MessageStateUpdateApplyContext},
        poll::{Poll, PollId, PollProvider, PollVotes},
        profile::ProfilePicture,
        settings::{Settings, SettingsProvider, SettingsUpdate},
        user_profile::{UserProfile, UserProfileProvider},
    },
    protobuf,
    provider::{NonceProvider, ProviderError, ShortcutProvider},
    utils::{
        sync::MutexIgnorePoison as _,
        update::{Apply as _, TryApply as _},
    },
};

pub(crate) struct InMemoryDbStorage {
    pub(crate) user_identity: ThreemaId,
    #[expect(dead_code, reason = "TODO(LIB-94): Use for backups")]
    pub(crate) user_profile: UserProfile,
    pub(crate) csp_e2e_nonce_storage: BTreeSet<HashedNonce>,
    pub(crate) d2x_nonce_storage: BTreeSet<HashedNonce>,
    pub(crate) settings: Settings,
    pub(crate) contacts: InMemoryDbContacts,
    pub(crate) distribution_lists: InMemoryDbDistributionLists,
    pub(crate) groups: InMemoryDbGroups,
    pub(crate) conversations: InMemoryDbConversations,
    #[expect(dead_code, reason = "TODO(LIB-94): Use for backups")]
    pub(crate) polls: InMemoryDbPolls,
}

/// Default shortcut provider, applying reasonable shortcut defaults.
pub struct DefaultShortcutProvider;
impl ShortcutProvider for DefaultShortcutProvider {
    fn handle_web_session_resume_payload(&mut self, _payload: Vec<u8>) -> Result<(), ProviderError> {
        warn!("Discarding web-session-resume");
        Ok(())
    }
}

const NONCES_PER_BATCH: usize = (2_usize << 20).strict_div(HashedNonce::LENGTH); // 1 MiB per batch.

/// In-memory CSP E2EE nonce provider.
pub(crate) struct InMemoryDbCspE2eNonceProvider(Arc<Mutex<InMemoryDbStorage>>);

/// In-memory D2X provider.
pub struct InMemoryDbD2xNonceProvider(Arc<Mutex<InMemoryDbStorage>>);

#[duplicate_item(
    struct_name                       nonce_storage;
    [ InMemoryDbCspE2eNonceProvider ] [ csp_e2e_nonce_storage ];
    [ InMemoryDbD2xNonceProvider ]    [ d2x_nonce_storage ];
)]
impl NonceProvider for struct_name {
    fn add_many(&mut self, hashed_nonces: Vec<HashedNonce>) -> Result<(), ProviderError> {
        let mut storage = self.0.lock_ignore_poison();
        storage.nonce_storage.extend(hashed_nonces);
        Ok(())
    }

    fn get_many(&self, batch_index: usize) -> Result<Vec<HashedNonce>, ProviderError> {
        let overflow_error = || ProviderError::InvalidParameter("'batch_index' exceeds maximum".to_owned());
        let range = batch_index
            .checked_mul(NONCES_PER_BATCH)
            .ok_or(overflow_error())?
            ..batch_index
                .checked_add(1)
                .ok_or(overflow_error())?
                .checked_mul(NONCES_PER_BATCH)
                .ok_or(overflow_error())?;
        let storage = self.0.lock_ignore_poison();
        Ok(storage.nonce_storage.iter().get(range).cloned().collect())
    }

    fn has(&self, hashed_nonce: &HashedNonce) -> Result<bool, ProviderError> {
        let storage = self.0.lock_ignore_poison();
        Ok(storage.nonce_storage.contains(hashed_nonce))
    }
}

/// In-memory settings provider.
pub(crate) struct InMemoryDbSettingsProvider(Arc<Mutex<InMemoryDbStorage>>);
impl SettingsProvider for InMemoryDbSettingsProvider {
    fn set(&mut self, settings: Settings) -> Result<(), ProviderError> {
        let mut storage = self.0.lock_ignore_poison();
        storage.settings = settings;
        Ok(())
    }

    fn update(&mut self, update: SettingsUpdate) -> Result<(), ProviderError> {
        let mut storage = self.0.lock_ignore_poison();
        storage.settings.apply(update);
        Ok(())
    }

    fn get(&self) -> Result<Settings, ProviderError> {
        let storage = self.0.lock_ignore_poison();
        Ok(storage.settings.clone())
    }
}

/// In-memory user profile provider.
#[expect(dead_code, reason = "TODO(LIB-94): Use for backups")]
#[derive(Clone)]
pub(crate) struct InMemoryDbUserProfileProvider(Arc<Mutex<InMemoryDbStorage>>);
impl UserProfileProvider for InMemoryDbUserProfileProvider {
    fn set(&mut self, user_profile: UserProfile) -> Result<(), ProviderError> {
        let mut storage = self.0.lock_ignore_poison();
        storage.user_profile = user_profile;
        Ok(())
    }

    fn get(&self) -> Result<UserProfile, ProviderError> {
        let storage = self.0.lock_ignore_poison();
        Ok(storage.user_profile.clone())
    }
}

type InMemoryDbContacts = HashMap<ThreemaId, ContactWithProfilePictures>;
type InMemoryDbGroups = BTreeMap<GroupIdentity, GroupWithProfilePicture>;
type InMemoryDbDistributionLists = BTreeMap<DistributionListId, DistributionList>;

/// In-memory contact provider.
pub(crate) struct InMemoryDbContactProvider(Arc<Mutex<InMemoryDbStorage>>);
impl InMemoryDbContactProvider {
    fn ensure_not_user_identity(
        storage: &InMemoryDbStorage,
        identity: ThreemaId,
    ) -> Result<(), ProviderError> {
        if identity == storage.user_identity {
            Err(ProviderError::InvalidState(
                "Unexpected encounter of user's identity in contact provider".to_owned(),
            ))
        } else {
            Ok(())
        }
    }

    fn with<TResult, TContactFn: FnOnce(Option<&mut ContactWithProfilePictures>) -> TResult>(
        storage: &mut InMemoryDbStorage,
        identity: ThreemaId,
        contact_fn: TContactFn,
    ) -> Result<TResult, ProviderError> {
        // Bail if identity is the user's identity.
        Self::ensure_not_user_identity(storage, identity)?;

        // Get a the contact (if it exists) and apply the closure.
        Ok(contact_fn(storage.contacts.get_mut(&identity)))
    }

    fn has(storage: &InMemoryDbStorage, identity: ThreemaId) -> Result<bool, ProviderError> {
        // Bail if identity is the user's identity.
        Self::ensure_not_user_identity(storage, identity)?;

        // Check if a contact for identity exists.
        Ok(storage.contacts.contains_key(&identity))
    }
}
impl ContactProvider for InMemoryDbContactProvider {
    fn add(&mut self, contacts: Vec<Contact>) -> Result<(), ProviderError> {
        self.add_with_profile_pictures(
            contacts
                .into_iter()
                .map(|contact| ContactWithProfilePictures {
                    contact,
                    contact_defined_profile_picture: None,
                    user_defined_profile_picture: None,
                })
                .collect(),
        )
    }

    fn add_with_profile_pictures(
        &mut self,
        contacts: Vec<ContactWithProfilePictures>,
    ) -> Result<(), ProviderError> {
        let mut storage = self.0.lock_ignore_poison();

        for contact in &contacts {
            // Bail if the contact's identity is the user's identity or the contact already exists.
            if Self::has(&storage, contact.contact.identity)? {
                return Err(ProviderError::InvalidState(format!(
                    "Contact {} to be added already exists",
                    contact.contact.identity
                )));
            }
        }

        // Add all contacts.
        storage.contacts.extend(
            contacts
                .into_iter()
                .map(|contact| (contact.contact.identity, contact)),
        );

        Ok(())
    }

    fn set_contact_defined_profile_picture(
        &self,
        identity: ThreemaId,
        profile_picture: Option<ProfilePicture>,
    ) -> Result<(), ProviderError> {
        let mut storage = self.0.lock_ignore_poison();

        // Bail if identity is the user's identity or the contact does not exist.
        Self::with(&mut storage, identity, |contact| {
            contact.map(|contact| {
                // Set the contact-defined profile picture.
                contact.contact_defined_profile_picture = profile_picture;
            })
        })?
        .ok_or_else(|| {
            ProviderError::InvalidState(format!(
                "Contact {identity} to set the contact-defined profile picture for does not exist"
            ))
        })
    }

    fn set_user_defined_profile_picture(
        &self,
        identity: ThreemaId,
        profile_picture: Option<ProfilePicture>,
    ) -> Result<(), ProviderError> {
        let mut storage = self.0.lock_ignore_poison();

        // Bail if identity is the user's identity or the contact does not exist.
        Self::with(&mut storage, identity, |contact| {
            contact.map(|contact| {
                // Set the user-defined profile picture.
                contact.user_defined_profile_picture = profile_picture;
            })
        })?
        .ok_or_else(|| {
            ProviderError::InvalidState(format!(
                "Contact {identity} to set the user-defined profile picture for does not exist"
            ))
        })
    }

    fn update(&mut self, updates: Vec<ContactUpdate>) -> Result<(), ProviderError> {
        let mut storage = self.0.lock_ignore_poison();

        for update in &updates {
            // Bail if the contact's identity is the user's identity or the contact does not exist.
            if !Self::has(&storage, update.identity)? {
                return Err(ProviderError::InvalidState(format!(
                    "Contact {} to be updated does not exist",
                    update.identity
                )));
            }
        }

        // Update all contacts.
        for update in updates {
            Self::with(&mut storage, update.identity, |contact| {
                contact
                    .expect("Contact existence has been ensured")
                    .contact
                    .try_apply(update)
            })??;
        }

        Ok(())
    }

    fn count_existing(&self, identities: &[ThreemaId]) -> Result<usize, ProviderError> {
        let storage = self.0.lock_ignore_poison();
        identities.iter().try_fold(0_usize, |n_identities, identity| {
            // Bail if identity is the user's identity and increase count if a contact for identity exists.
            if Self::has(&storage, *identity)? {
                Ok(n_identities.saturating_add(1))
            } else {
                Ok(n_identities)
            }
        })
    }

    fn get(&self, identity: ThreemaId) -> Result<Option<Contact>, ProviderError> {
        let mut storage = self.0.lock_ignore_poison();

        // Bail if identity is the user's identity and get a snapshot of the contact (if it exists).
        Self::with(&mut storage, identity, |contact| {
            contact.map(|contact| contact.contact.clone())
        })
    }

    fn get_identities(&self) -> Result<HashSet<ThreemaId>, ProviderError> {
        let storage = self.0.lock_ignore_poison();
        Ok(storage.contacts.keys().copied().collect())
    }

    fn get_with_profile_pictures(
        &self,
        identity: ThreemaId,
    ) -> Result<Option<ContactWithProfilePictures>, ProviderError> {
        let mut storage = self.0.lock_ignore_poison();

        // Bail if identity is the user's identity and get a snapshot of the contact with its user profile (if
        // it exists).
        #[expect(clippy::redundant_closure_for_method_calls, reason = "Ambiguous type")]
        Self::with(&mut storage, identity, |contact| contact.cloned())
    }

    fn has(&self, identity: ThreemaId) -> Result<bool, ProviderError> {
        let storage = self.0.lock_ignore_poison();
        Self::has(&storage, identity)
    }

    fn is_explicitly_blocked(&self, identity: ThreemaId) -> Result<bool, ProviderError> {
        let storage = self.0.lock_ignore_poison();

        // Bail if identity is the user's identity.
        Self::ensure_not_user_identity(&storage, identity)?;

        // Check if the identity is explicitly blocked.
        Ok(storage.settings.blocked_identities.contains(&identity))
    }
}

/// In-memory distribution list provider.
#[expect(dead_code, reason = "TODO(LIB-94): Use for backups")]
pub(crate) struct InMemoryDbDistributionListProvider(Arc<Mutex<InMemoryDbStorage>>);
impl DistributionListProvider for InMemoryDbDistributionListProvider {
    fn add(&mut self, distribution_lists: Vec<DistributionList>) -> Result<(), ProviderError> {
        let mut storage = self.0.lock_ignore_poison();

        for distribution_list in &distribution_lists {
            let distribution_list_id = distribution_list.identity;

            // Bail if distribution list already exists.
            if storage.distribution_lists.contains_key(&distribution_list_id) {
                return Err(ProviderError::InvalidState(format!(
                    "Distribution list {distribution_list_id} already exists"
                )));
            }

            // Bail if a member's identity is the user's identity or refers to an unknown contact.
            for member in &distribution_list.members {
                if *member == storage.user_identity {
                    return Err(ProviderError::InvalidState(format!(
                        "Distribution list {distribution_list_id} references user in members",
                    )));
                }
                if !storage.contacts.contains_key(member) {
                    return Err(ProviderError::InvalidState(format!(
                        "Distribution list {distribution_list_id} references unknown member {member}"
                    )));
                }
            }
        }

        // Add all distribution lists.
        storage.distribution_lists.extend(
            distribution_lists
                .into_iter()
                .map(|distribution_list| (distribution_list.identity, distribution_list)),
        );

        Ok(())
    }

    fn get(&self, id: DistributionListId) -> Result<Option<DistributionList>, ProviderError> {
        let storage = self.0.lock_ignore_poison();
        Ok(storage.distribution_lists.get(&id).cloned())
    }

    fn get_ids(&self) -> Result<HashSet<DistributionListId>, ProviderError> {
        let storage = self.0.lock_ignore_poison();
        Ok(storage.distribution_lists.keys().copied().collect())
    }
}

/// In-memory group provider.
pub(crate) struct InMemoryDbGroupProvider(Arc<Mutex<InMemoryDbStorage>>);
impl GroupProvider for InMemoryDbGroupProvider {
    fn add_with_profile_picture(
        &mut self,
        mut groups: Vec<GroupWithProfilePicture>,
    ) -> Result<(), ProviderError> {
        let mut storage = self.0.lock_ignore_poison();

        for group in &mut groups {
            // Bail if the group already exists.
            if storage.groups.contains_key(&group.group.identity) {
                return Err(ProviderError::InvalidState(format!(
                    "Group {} already exists",
                    group.group.identity
                )));
            }

            // Bail if creator is neither the user nor a known contact.
            if group.group.identity.creator_identity != storage.user_identity
                && !storage
                    .contacts
                    .contains_key(&group.group.identity.creator_identity)
            {
                return Err(ProviderError::InvalidState(format!(
                    "Group {} creator is unknown",
                    group.group.identity
                )));
            }

            // Bail if a member's identity is the user's identity or refers to an unknown contact.
            for member in &group.group.members {
                if *member == storage.user_identity {
                    return Err(ProviderError::InvalidState(format!(
                        "Group {} references user in members",
                        group.group.identity
                    )));
                }
                if !storage.contacts.contains_key(member) {
                    return Err(ProviderError::InvalidState(format!(
                        "Group {} references unknown member {member}",
                        group.group.identity
                    )));
                }
            }
        }

        // Add all groups.
        storage
            .groups
            .extend(groups.into_iter().map(|group| (group.group.identity, group)));

        Ok(())
    }

    fn set_profile_picture(
        &mut self,
        identity: GroupIdentity,
        profile_picture: Option<ProfilePicture>,
    ) -> Result<(), ProviderError> {
        let mut storage = self.0.lock_ignore_poison();

        // Ensure that the group exists.
        let Some(group) = storage.groups.get_mut(&identity) else {
            return Err(ProviderError::InvalidState(format!("Unknown group {identity}")));
        };

        // Set profile picture.
        group.profile_picture = profile_picture;

        Ok(())
    }

    fn get_identities(&self) -> Result<HashSet<GroupIdentity>, ProviderError> {
        let storage = self.0.lock_ignore_poison();
        Ok(storage.groups.keys().copied().collect())
    }

    fn get_with_profile_picture(
        &self,
        identity: GroupIdentity,
    ) -> Result<Option<GroupWithProfilePicture>, ProviderError> {
        let storage = self.0.lock_ignore_poison();
        Ok(storage.groups.get(&identity).cloned())
    }

    #[expect(unused_variables, reason = "TODO(LIB-16): Implement groups")]
    fn is_part_of_any_group(
        &self,
        identity: ThreemaId,
        filter: GroupMembershipFilter,
    ) -> Result<bool, ProviderError> {
        let storage = self.0.lock_ignore_poison();

        // Bail if identity is the user's identity.
        if identity == storage.user_identity {
            return Err(ProviderError::InvalidState(
                "Unexpected encounter of user's identity when checking for group membership".to_owned(),
            ));
        }

        // Check if the identity is a member of an active group.
        // TODO(LIB-16): Implement groups
        Ok(false)
    }
}

type InMemoryDbConversations = BTreeMap<ConversationId, BTreeMap<MessageId, MessageState>>;

/// In-memory message provider.
pub(crate) struct InMemoryDbConversationProvider(Arc<Mutex<InMemoryDbStorage>>);
impl InMemoryDbConversationProvider {
    const MESSAGES_PER_BATCH: usize = 512;

    fn ensure_conversation_exists(
        storage: &InMemoryDbStorage,
        conversation_id: &ConversationId,
    ) -> Result<(), ProviderError> {
        match conversation_id {
            ConversationId::Contact(identity) => {
                if !storage.contacts.contains_key(identity) {
                    return Err(ProviderError::InvalidState(format!(
                        "Contact {identity} does not exist",
                    )));
                }
            },
            ConversationId::DistributionList(distribution_list_id) => {
                if !storage.distribution_lists.contains_key(distribution_list_id) {
                    return Err(ProviderError::InvalidState(format!(
                        "Distribution list {distribution_list_id} does not exist",
                    )));
                }
            },
            ConversationId::Group(group_identity) => {
                if !storage.groups.contains_key(group_identity) {
                    return Err(ProviderError::InvalidState(format!(
                        "Group {group_identity} does not exist",
                    )));
                }
            },
        }
        Ok(())
    }
}
impl ConversationProvider for InMemoryDbConversationProvider {
    fn add_messages(&mut self, messages: Vec<MessageState>) -> Result<(), ProviderError> {
        let mut storage = self.0.lock_ignore_poison();

        for message in &messages {
            // Check whether the referred contact/distribution list/group exists and is in the expected state.
            match &message.conversation_id {
                ConversationId::Contact(identity) => {
                    let Some(contact) = storage.contacts.get(identity) else {
                        return Err(ProviderError::InvalidState(format!(
                            "Contact {identity} does not exist",
                        )));
                    };
                    if contact.contact.acquaintance_level
                        != protobuf::d2d_sync::contact::AcquaintanceLevel::Direct
                    {
                        return Err(ProviderError::InvalidState(format!(
                            "Contact {identity} does not have acquaintance level direct",
                        )));
                    }
                },
                ConversationId::DistributionList(distribution_list_id) => {
                    if !storage.distribution_lists.contains_key(distribution_list_id) {
                        return Err(ProviderError::InvalidState(format!(
                            "Distribution list {distribution_list_id} does not exist",
                        )));
                    }
                },
                ConversationId::Group(group_identity) => {
                    if !storage.groups.contains_key(group_identity) {
                        return Err(ProviderError::InvalidState(format!(
                            "Group {group_identity} does not exist",
                        )));
                    }
                },
            }

            // Check if the message was already added to the conversation.
            if storage
                .conversations
                .get(&message.conversation_id)
                .is_some_and(|messages| messages.contains_key(&message.message_id))
            {
                return Err(ProviderError::InvalidState(format!(
                    "Message {} already exists in conversation {}",
                    message.message_id, message.conversation_id,
                )));
            }
        }

        // Add all message states to the corresponding conversation.
        for message in messages {
            let conversation = storage.conversations.entry(message.conversation_id).or_default();
            let _ = conversation.insert(message.message_id, message);
        }

        Ok(())
    }

    fn set_typing_indicator(
        &mut self,
        sender_identity: ThreemaId,
        _is_typing: bool,
    ) -> Result<(), ProviderError> {
        let storage = self.0.lock_ignore_poison();

        // Ensure the referred 1:1 conversation (i.e. the contact) exists.
        if !storage.contacts.contains_key(&sender_identity) {
            return Err(ProviderError::InvalidState(format!(
                "Contact {sender_identity} does not exist",
            )));
        }

        // Ignore
        Ok(())
    }

    fn update_messages(&mut self, updates: Vec<MessageStateUpdate>) -> Result<(), ProviderError> {
        let mut storage = self.0.lock_ignore_poison();

        for update in &updates {
            // Check whether the referred contact/distribution list/group exists.
            Self::ensure_conversation_exists(&storage, &update.conversation_id)?;

            // Check whether the original message exists.
            if !storage
                .conversations
                .get(&update.conversation_id)
                .is_some_and(|conversation| conversation.contains_key(&update.message_id))
            {
                return Err(ProviderError::InvalidState(format!(
                    "Discarding message update because message {} does not exist in conversation {}",
                    update.message_id, update.conversation_id
                )));
            }
        }

        // Try applying all message state updates.
        let user_identity = storage.user_identity;
        for update in updates {
            storage
                .conversations
                .get_mut(&update.conversation_id)
                .expect("Existence was ensured")
                .get_mut(&update.message_id)
                .expect("Existence was ensured")
                .try_apply(MessageStateUpdateApplyContext {
                    user_identity,
                    update,
                })?;
        }

        Ok(())
    }

    fn get_many_messages(
        &self,
        conversation_type: ConversationType,
        batch_index: usize,
    ) -> Result<Vec<MessageState>, ProviderError> {
        let overflow_error = || ProviderError::InvalidParameter("'batch_index' exceeds maximum".to_owned());

        // Compute range.
        let range = batch_index
            .checked_mul(Self::MESSAGES_PER_BATCH)
            .ok_or(overflow_error())?
            ..batch_index
                .checked_add(1)
                .ok_or(overflow_error())?
                .checked_mul(Self::MESSAGES_PER_BATCH)
                .ok_or(overflow_error())?;

        // Return all messages in range.
        let storage = self.0.lock_ignore_poison();
        Ok(storage
            .conversations
            .iter()
            .filter_map(|(conversation_id, conversation)| {
                if conversation_type == conversation_id.conversation_type() {
                    Some(conversation)
                } else {
                    None
                }
            })
            .flat_map(|conversation| conversation.values())
            .get(range)
            .cloned()
            .collect())
    }

    fn get_messages_metadata(
        &self,
        conversation_id: ConversationId,
        message_ids: &[MessageId],
    ) -> Result<Vec<MessageStateMetadata>, ProviderError> {
        let storage = self.0.lock_ignore_poison();

        // Check whether the referred contact/distribution list/group exists.
        Self::ensure_conversation_exists(&storage, &conversation_id)?;
        let Some(conversation) = storage.conversations.get(&conversation_id) else {
            return Ok(vec![]);
        };

        // Gather message metadata for known messages.
        Ok(message_ids
            .iter()
            .filter_map(|message_id| conversation.get(message_id).map(MessageState::metadata))
            .collect())
    }

    fn is_message_marked_used(
        &self,
        sender_identity: ThreemaId,
        message_id: MessageId,
    ) -> Result<bool, ProviderError> {
        let storage = self.0.lock_ignore_poison();

        // TODO(LIB-16): This is pretty expensive. We'll have to figure this out.
        for conversation in storage.conversations.values() {
            if let Some(message) = conversation.get(&message_id) {
                return Ok(message.creator_identity == sender_identity);
            }
        }
        Ok(false)
    }
}

type InMemoryDbPolls = BTreeMap<(ConversationId, PollId), Poll>;

/// In-memory poll provider.
#[expect(dead_code, reason = "TODO(LIB-94): Use for backups")]
pub(crate) struct InMemoryDbPollProvider(Arc<Mutex<InMemoryDbStorage>>);
impl InMemoryDbPollProvider {
    #[expect(dead_code, reason = "TODO(LIB-94): Use for backups")]
    const POLLS_PER_BATCH: usize = 100;
}
impl PollProvider for InMemoryDbPollProvider {
    fn add(&mut self, polls: Vec<Poll>) -> Result<(), ProviderError> {
        let mut storage = self.0.lock_ignore_poison();

        for poll in &polls {
            // Check whether referred contact/group does not exists and bail if it's a distribution list.
            match poll.conversation {
                ConversationId::Contact(identity) => {
                    if !storage.contacts.contains_key(&identity) {
                        return Err(ProviderError::InvalidState(format!(
                            "Contact {identity} does not exist",
                        )));
                    }
                },

                ConversationId::DistributionList(_) => {
                    return Err(ProviderError::InvalidState(
                        "Distribution lists are not supported by polls".to_owned(),
                    ));
                },

                ConversationId::Group(group_identity) => {
                    if !storage.groups.contains_key(&group_identity) {
                        return Err(ProviderError::InvalidState(format!(
                            "Group {group_identity} does not exist",
                        )));
                    }
                },
            }

            // Bail if creator is neither the user nor a known contact.
            if poll.creator_identity != storage.user_identity
                && !storage.contacts.contains_key(&poll.creator_identity)
            {
                return Err(ProviderError::InvalidState(format!(
                    "Poll creator {} is unknown",
                    poll.creator_identity,
                )));
            }

            // Bail if the poll already exists.
            if storage.polls.contains_key(&(poll.conversation, poll.id)) {
                return Err(ProviderError::InvalidState(format!(
                    "Poll {} already exists",
                    poll.id
                )));
            }

            // Bail if a voter is neither the user nor a known contact.
            if let PollVotes::Votes(voters) = &poll.votes {
                for voter in voters.keys() {
                    if *voter != storage.user_identity && !storage.contacts.contains_key(voter) {
                        return Err(ProviderError::InvalidState(format!(
                            "Poll {} references unknown voter {voter}",
                            poll.id
                        )));
                    }
                }
            }
        }

        // Add all polls.
        storage
            .polls
            .extend(polls.into_iter().map(|poll| ((poll.conversation, poll.id), poll)));

        Ok(())
    }

    fn get_many(&self, batch_index: usize) -> Result<Vec<Poll>, ProviderError> {
        let overflow_error = || ProviderError::InvalidParameter("'batch_index' exceeds maximum".to_owned());

        // Compute range.
        let range = batch_index
            .checked_mul(Self::POLLS_PER_BATCH)
            .ok_or(overflow_error())?
            ..batch_index
                .checked_add(1)
                .ok_or(overflow_error())?
                .checked_mul(Self::POLLS_PER_BATCH)
                .ok_or(overflow_error())?;

        // Return all polls for range.
        let storage = self.0.lock_ignore_poison();
        Ok(storage.polls.values().get(range).cloned().collect())
    }
}

/// Initializer for an [`InMemoryDb`].
#[derive(Builder)]
pub struct InMemoryDbInit {
    /// The user's identity.
    pub user_identity: ThreemaId,

    /// User profile.
    pub user_profile: UserProfile,

    /// Initial settings.
    pub settings: Settings,

    /// Initial contacts.
    pub contacts: Vec<Contact>,

    /// Initial distribution lists.
    pub distribution_lists: Vec<DistributionList>,

    /// Initial groups.
    pub groups: Vec<Group>,
}

/// In-memory database.
pub struct InMemoryDb {
    pub(crate) storage: Arc<Mutex<InMemoryDbStorage>>,
}
impl From<InMemoryDbInit> for InMemoryDb {
    fn from(init: InMemoryDbInit) -> Self {
        Self {
            storage: Arc::new(Mutex::new(InMemoryDbStorage {
                user_identity: init.user_identity,

                user_profile: init.user_profile,

                csp_e2e_nonce_storage: BTreeSet::new(),

                d2x_nonce_storage: BTreeSet::new(),

                settings: init.settings,

                contacts: init
                    .contacts
                    .into_iter()
                    .map(|contact| {
                        (
                            contact.identity,
                            ContactWithProfilePictures {
                                contact,
                                contact_defined_profile_picture: None,
                                user_defined_profile_picture: None,
                            },
                        )
                    })
                    .collect(),

                distribution_lists: init
                    .distribution_lists
                    .into_iter()
                    .map(|distribution_list| (distribution_list.identity, distribution_list))
                    .collect(),

                groups: init
                    .groups
                    .into_iter()
                    .map(|group| {
                        (
                            group.identity,
                            GroupWithProfilePicture {
                                group,
                                profile_picture: None,
                            },
                        )
                    })
                    .collect(),

                conversations: BTreeMap::new(),

                polls: BTreeMap::new(),
            })),
        }
    }
}
impl InMemoryDb {
    /// CSP E2E protocol providers.
    #[must_use]
    pub fn csp_e2e_protocol_providers(&mut self) -> CspE2eProtocolProviders {
        CspE2eProtocolProviders {
            csp_e2e_nonce_provider: Rc::new(RefCell::new(InMemoryDbCspE2eNonceProvider(Arc::clone(
                &self.storage,
            )))),
            shortcut: Rc::new(RefCell::new(DefaultShortcutProvider)),
            settings: Rc::new(RefCell::new(InMemoryDbSettingsProvider(Arc::clone(
                &self.storage,
            )))),
            contacts: Rc::new(RefCell::new(InMemoryDbContactProvider(Arc::clone(&self.storage)))),
            groups: Rc::new(RefCell::new(InMemoryDbGroupProvider(Arc::clone(&self.storage)))),
            conversations: Rc::new(RefCell::new(InMemoryDbConversationProvider(Arc::clone(
                &self.storage,
            )))),
        }
    }

    /// D2D nonce provider.
    #[must_use]
    pub fn d2d_nonce_provider(&mut self) -> InMemoryDbD2xNonceProvider {
        InMemoryDbD2xNonceProvider(Arc::clone(&self.storage))
    }
}
