//! Example for creating a data backup.
#![expect(unused_crate_dependencies, reason = "Example triggered false positive")]
mod utils;

use std::{
    fs,
    io::{self, Seek as _, Write as _},
    path,
    sync::{Arc, Mutex},
};

use clap::{Args, Parser};
use libthreema::{
    data_backup::task::{
        DataBackupProviders,
        create::{
            DataBackupCreateInit, DataBackupCreateLocalWriteInstruction, DataBackupCreateLoop,
            DataBackupCreateTask, DataBackupCreateWriteInstruction,
        },
    },
    utils::logging::init_stderr_logging,
};
use tracing::{Level, debug, info, trace};

use crate::provider::CreateDataProvider;

mod random_number_generator {
    use core::ops::Range;

    use libthreema_dependencies::rand::{
        self, Rng as _, RngCore as _, SeedableRng as _, distributions::uniform::SampleRange, rngs::StdRng,
        seq::SliceRandom as _,
    };

    pub(super) struct RandomNumberGenerator(StdRng);
    impl RandomNumberGenerator {
        pub(super) fn new() -> Self {
            Self(StdRng::from_seed([42; 32]))
        }

        pub(super) fn generate<T>(&mut self) -> T
        where
            rand::distributions::Standard: rand::distributions::Distribution<T>,
        {
            self.0.r#gen()
        }

        pub(super) fn random_string(&mut self, length: Range<usize>) -> String {
            self.0
                .clone()
                .sample_iter(rand::distributions::Alphanumeric)
                .take(self.0.gen_range(length))
                .map(char::from)
                .collect::<String>()
        }

        pub(super) fn random_optional_u64(&mut self) -> Option<u64> {
            if self.generate() {
                Some(self.generate())
            } else {
                None
            }
        }

        pub(super) fn random_bytes(&mut self, length: Range<usize>) -> Vec<u8> {
            let mut bytes = vec![0; self.0.gen_range(length)];
            self.0.fill_bytes(&mut bytes);
            bytes
        }

        pub(super) fn random_fixed_length_bytes<const LENGTH: usize>(&mut self) -> [u8; LENGTH] {
            let mut bytes = [0; LENGTH];
            self.0.fill_bytes(&mut bytes);
            bytes
        }

        pub(super) fn random_choice<'set, T>(&mut self, set: &'set [T]) -> Option<&'set T> {
            set.choose(&mut self.0)
        }

        pub(super) fn random_choice_multiple<T>(&mut self, set: &[T], count: usize) -> Vec<T>
        where
            T: Copy,
        {
            set.choose_multiple(&mut self.0, count).copied().collect()
        }

        pub(super) fn random_in_range<R>(&mut self, range: R) -> usize
        where
            R: SampleRange<usize>,
        {
            self.0.gen_range(range)
        }
    }
}

mod provider {
    #![expect(clippy::unimplemented, reason = "Unused methods for backup creation")]

    use core::{cmp::min, iter, ops::Range};
    use std::{
        collections::{BTreeMap, HashMap, HashSet},
        sync::{Arc, Mutex},
    };

    use libthreema::{
        common::{
            ChatServerGroup, ConversationId, ConversationType, DistributionListId, FeatureMask,
            GroupIdentity, HashedNonce, MessageId, MessageOverrides, MessageOverridesDeliveryReceiptPolicy,
            ThreemaId,
            keys::{ClientKey, PublicKey},
        },
        model::{
            contact::{Contact, ContactProvider, ContactWithProfilePictures},
            conversation::ConversationProvider,
            distribution_list::{DistributionList, DistributionListProvider},
            group::{Group, GroupMembershipFilter, GroupProvider, GroupUpdate, GroupWithProfilePicture},
            message::{
                EmojiReaction, IncomingMessageDirection, LocationMessageState, MessageDirection,
                MessageReaction, MessageStarMarker, MessageState, MessageStateBody, MessageStateMetadata,
                MessageStateUpdate, MessageText, MessageTextRevision, OutgoingMessageDirection, PollClose,
                PollOpen, TextMessageState,
            },
            poll::{
                Poll, PollChoice, PollChoiceId, PollId, PollProvider, PollVote, PollVotes, PollVotesSummary,
            },
            profile::{ProfilePicture, ProfilePictureMediaType},
            settings::{Settings, SettingsProvider, SettingsUpdate},
            user_profile::{IdentityData, UserProfile, UserProfileProvider},
        },
        protobuf,
        provider::{NonceProvider, ProviderError},
    };
    use libthreema_macros::concat_fixed_bytes;
    use tracing::warn;

    use crate::{
        BackupCreateParameters, random_number_generator::RandomNumberGenerator,
        utils::sync::MutexPoisonPanic as _,
    };

    const PROFILE_PICTURE_BYTE_LENGTH: Range<usize> = 1024..(2 * 1024);

    pub(super) struct CreateSettingsProvider;
    impl SettingsProvider for CreateSettingsProvider {
        fn set(&mut self, _settings: Settings) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn update(&mut self, _update: SettingsUpdate) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn get(&self) -> Result<Settings, ProviderError> {
            Ok(Settings::default())
        }
    }

    pub(super) struct CreateUserProfileProvider;
    impl UserProfileProvider for CreateUserProfileProvider {
        fn get(&self) -> Result<UserProfile, ProviderError> {
            Ok(UserProfile {
                nickname: "Moritz Mocker".to_owned(),
                profile_picture: Some(ProfilePicture {
                    media_type: ProfilePictureMediaType::Jpeg,
                    data: vec![0; PROFILE_PICTURE_BYTE_LENGTH.start],
                }),
                ..UserProfile::default()
            })
        }

        fn set(&mut self, _user_profile: UserProfile) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }
    }

    pub(super) struct CreateContactProvider {
        pub(super) user_identity: ThreemaId,
        pub(super) random_number_generator: Arc<Mutex<RandomNumberGenerator>>,
        pub(super) contacts: Arc<Mutex<BTreeMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,
    }
    impl CreateContactProvider {
        fn random_contact(
            random_number_generator: &Arc<Mutex<RandomNumberGenerator>>,
            contacts: &Arc<Mutex<BTreeMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,
        ) -> Option<ThreemaId> {
            let contacts: Vec<ThreemaId> = contacts
                .lock_unwrap()
                .iter()
                .filter_map(|(contact, acquaintance_level)| {
                    if acquaintance_level == &protobuf::d2d_sync::contact::AcquaintanceLevel::Direct {
                        Some(contact)
                    } else {
                        None
                    }
                })
                .copied()
                .collect();

            random_number_generator
                .lock_unwrap()
                .random_choice(&contacts)
                .copied()
        }
    }
    impl ContactProvider for CreateContactProvider {
        fn add(&mut self, _contacts: Vec<Contact>) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn add_with_profile_pictures(
            &mut self,
            _contacts: Vec<ContactWithProfilePictures>,
        ) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn set_contact_defined_profile_picture(
            &self,
            _identity: ThreemaId,
            _profile_picture: Option<ProfilePicture>,
        ) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn set_user_defined_profile_picture(
            &self,
            _identity: ThreemaId,
            _profile_picture: Option<ProfilePicture>,
        ) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn update(
            &mut self,
            _updates: Vec<libthreema::model::contact::ContactUpdate>,
        ) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn count_existing(&self, _identities: &[ThreemaId]) -> Result<usize, ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn get(&self, _identity: ThreemaId) -> Result<Option<Contact>, ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn get_identities(&self) -> Result<HashSet<ThreemaId>, ProviderError> {
            Ok(self.contacts.lock_unwrap().keys().copied().collect())
        }

        fn get_with_profile_pictures(
            &self,
            identity: ThreemaId,
        ) -> Result<Option<ContactWithProfilePictures>, ProviderError> {
            // Bail if identity is the user's identity.
            if identity == self.user_identity {
                return Err(ProviderError::ContractViolation(
                    "Unexpected encounter of user's identity in contact provider".to_owned(),
                ));
            }

            // Get a snapshot of the contact (if it exists).
            let contacts = self.contacts.lock_unwrap();
            let Some(acquaintance_level) = contacts.get(&identity) else {
                return Ok(None);
            };

            let mut random_number_generator = self.random_number_generator.lock_unwrap();
            Ok(Some(ContactWithProfilePictures {
                contact: Contact {
                    identity,
                    public_key: PublicKey::from(random_number_generator.random_fixed_length_bytes()),
                    created_at: random_number_generator.generate(),
                    last_update_at: random_number_generator.random_optional_u64(),
                    first_name: random_number_generator.random_string(0..20),
                    last_name: random_number_generator.random_string(0..20),
                    nickname: random_number_generator.random_string(0..20),
                    verification_level: protobuf::d2d_sync::contact::VerificationLevel::Unverified,
                    work_verification_level: protobuf::d2d_sync::contact::WorkVerificationLevel::None,
                    identity_type: protobuf::d2d_sync::contact::IdentityType::Work,
                    acquaintance_level: *acquaintance_level,
                    activity_state: protobuf::d2d_sync::contact::ActivityState::Active,
                    feature_mask: FeatureMask(0),
                    sync_state: protobuf::d2d_sync::contact::SyncState::Initial,
                    work_last_full_sync_at: random_number_generator.random_optional_u64(),
                    work_availability_status: None,
                    read_receipt_policy_override: None,
                    typing_indicator_policy_override: None,
                    notification_trigger_policy_override: None,
                    conversation_category: protobuf::d2d_sync::ConversationCategory::Default,
                    conversation_visibility: protobuf::d2d_sync::ConversationVisibility::Normal,
                },
                contact_defined_profile_picture: if random_number_generator.generate() {
                    Some(ProfilePicture {
                        media_type: ProfilePictureMediaType::Jpeg,
                        data: random_number_generator.random_bytes(PROFILE_PICTURE_BYTE_LENGTH),
                    })
                } else {
                    None
                },
                user_defined_profile_picture: if random_number_generator.generate() {
                    Some(ProfilePicture {
                        media_type: ProfilePictureMediaType::Jpeg,
                        data: random_number_generator.random_bytes(PROFILE_PICTURE_BYTE_LENGTH),
                    })
                } else {
                    None
                },
            }))
        }

        fn is_explicitly_blocked(&self, _identity: ThreemaId) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn has(&self, _identity: ThreemaId) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup create");
        }
    }

    pub(super) struct CreateDistributionListProvider {
        pub(super) random_number_generator: Arc<Mutex<RandomNumberGenerator>>,
        pub(super) distribution_lists: Arc<Mutex<BTreeMap<DistributionListId, HashSet<ThreemaId>>>>,
    }
    impl DistributionListProvider for CreateDistributionListProvider {
        fn add(&mut self, _distribution_lists: Vec<DistributionList>) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn get(&self, id: DistributionListId) -> Result<Option<DistributionList>, ProviderError> {
            let Some(members) = self.distribution_lists.lock_unwrap().get(&id).cloned() else {
                return Ok(None);
            };

            let mut random_number_generator = self.random_number_generator.lock_unwrap();
            Ok(Some(DistributionList {
                identity: id,
                name: random_number_generator.random_string(10..20),
                created_at: random_number_generator.generate(),
                last_update_at: random_number_generator.generate(),
                members,
                conversation_category: protobuf::d2d_sync::ConversationCategory::Default,
                conversation_visibility: protobuf::d2d_sync::ConversationVisibility::Normal,
            }))
        }

        fn get_ids(&self) -> Result<HashSet<DistributionListId>, ProviderError> {
            Ok(self.distribution_lists.lock_unwrap().keys().copied().collect())
        }
    }

    pub(super) struct CreateGroupProvider {
        pub(super) random_number_generator: Arc<Mutex<RandomNumberGenerator>>,
        pub(super) groups: Arc<Mutex<BTreeMap<GroupIdentity, HashSet<ThreemaId>>>>,
    }
    impl GroupProvider for CreateGroupProvider {
        fn add_with_profile_picture(
            &mut self,
            _groups: Vec<GroupWithProfilePicture>,
        ) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn set_profile_picture(
            &mut self,
            _identity: GroupIdentity,
            _profile_picture: Option<ProfilePicture>,
        ) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn update(&mut self, _updates: Vec<GroupUpdate>) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn get(&self, _identity: GroupIdentity) -> Result<Option<Group>, ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn get_identities(&self) -> Result<HashSet<GroupIdentity>, ProviderError> {
            Ok(self.groups.lock_unwrap().keys().copied().collect())
        }

        fn get_with_profile_picture(
            &self,
            identity: GroupIdentity,
        ) -> Result<Option<GroupWithProfilePicture>, ProviderError> {
            let Some(members) = self.groups.lock_unwrap().get(&identity).cloned() else {
                return Ok(None);
            };
            let mut random_number_generator = self.random_number_generator.lock_unwrap();
            Ok(Some(GroupWithProfilePicture {
                group: Group {
                    identity,
                    name: random_number_generator.random_string(10..20),
                    created_at: random_number_generator.generate(),
                    last_update_at: random_number_generator.random_optional_u64(),
                    user_state: protobuf::d2d_sync::group::UserState::Member,
                    members,
                    notification_trigger_policy_override: None,
                    conversation_category: protobuf::d2d_sync::ConversationCategory::Default,
                    conversation_visibility: protobuf::d2d_sync::ConversationVisibility::Normal,
                },
                profile_picture: if random_number_generator.generate() {
                    Some(ProfilePicture {
                        media_type: ProfilePictureMediaType::Jpeg,
                        data: random_number_generator.random_bytes(PROFILE_PICTURE_BYTE_LENGTH),
                    })
                } else {
                    None
                },
            }))
        }

        fn has(&self, _identity: GroupIdentity) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn is_part_of_any_group(
            &self,
            _identity: ThreemaId,
            _filter: GroupMembershipFilter,
        ) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup create");
        }
    }

    pub(super) struct CreateConversationProvider {
        pub(super) random_number_generator: Arc<Mutex<RandomNumberGenerator>>,
        pub(super) user_identity: ThreemaId,
        pub(super) contacts: Arc<Mutex<BTreeMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,
        pub(super) distribution_lists: Arc<Mutex<BTreeMap<DistributionListId, HashSet<ThreemaId>>>>,
        pub(super) groups: Arc<Mutex<BTreeMap<GroupIdentity, HashSet<ThreemaId>>>>,

        /// Pool of [`PollOpen`] messages, grouped by conversation.
        ///
        /// Originated from polls generated by [`BackupPollProvider`] and consumed by
        /// [`Self::take_poll_open`].
        pub(super) poll_open_pool: Arc<Mutex<HashMap<ConversationId, Vec<PollOpen>>>>,

        /// Pool of [`PollClose`] messages for polls that have been opened and are to be closed.
        ///
        /// Populated when [`PollOpen`] entries are consumed by [`Self::take_poll_open`],
        /// and consumed by [`Self::take_poll_close`].
        pub(super) poll_close_pool: Arc<Mutex<HashMap<ConversationId, Vec<PollClose>>>>,

        pub(super) total_number_of_contact_messages: usize,
        pub(super) total_number_of_distribution_list_messages: usize,
        pub(super) total_number_of_group_messages: usize,
    }
    impl CreateConversationProvider {
        const MESSAGES_PER_BATCH: usize = 128;

        fn random_text_message_state(&self) -> TextMessageState {
            let mut random_number_generator = self.random_number_generator.lock_unwrap();
            TextMessageState {
                original: MessageText {
                    text: random_number_generator.random_string(10..500),
                },
                revisions: vec![MessageTextRevision {
                    created_at: random_number_generator.generate(),
                    message: MessageText {
                        text: random_number_generator.random_string(10..500),
                    },
                }],
            }
        }

        fn random_location_message(&self) -> LocationMessageState {
            let mut random_number_generator = self.random_number_generator.lock_unwrap();
            LocationMessageState {
                latitude: random_number_generator.generate(),
                longitude: random_number_generator.generate(),
                accuracy_m: if random_number_generator.generate() {
                    Some(5.0)
                } else {
                    None
                },
                name: random_number_generator.random_string(0..20),
                address: random_number_generator.random_string(0..20),
            }
        }

        fn random_reactions(&self, creators: &[ThreemaId]) -> Vec<MessageReaction> {
            let mut random_number_generator = self.random_number_generator.lock_unwrap();
            let mut reactions = vec![];
            for creator_identity in creators {
                if random_number_generator.generate() {
                    reactions.push(MessageReaction {
                        created_at: random_number_generator.generate(),
                        creator_identity: *creator_identity,
                        emoji: EmojiReaction {
                            codepoint: "\u{1f68}".to_owned(),
                        },
                    });
                }
            }
            reactions
        }

        /// Consume a [`PollOpen`] from the pool for `conversation`.
        ///
        /// The consumed [`PollOpen`] is used to generate a [`PollClose`] which is added
        /// to the close pool so that a matching poll-close message can be generated later.
        fn take_poll_open(&self, conversation: ConversationId) -> Option<PollOpen> {
            let poll_open = self
                .poll_open_pool
                .lock_unwrap()
                .get_mut(&conversation)
                .and_then(Vec::pop)?;
            self.poll_close_pool
                .lock_unwrap()
                .entry(conversation)
                .or_default()
                .push(PollClose { id: poll_open.id });
            Some(poll_open)
        }

        /// Consume a [`PollClose`] from the close pool for `conversation`.
        ///
        /// Only polls that have already been opened (via [`Self::take_poll_open`])
        /// are available here, ensuring every poll-close has a matching poll-open.
        fn take_poll_close(&self, conversation: ConversationId) -> Option<PollClose> {
            self.poll_close_pool
                .lock_unwrap()
                .get_mut(&conversation)
                .and_then(Vec::pop)
        }

        fn random_message_body_state(&self, conversation_id: ConversationId) -> MessageStateBody {
            let message_type = self.random_number_generator.lock_unwrap().random_in_range(0..4);
            match message_type {
                0 => MessageStateBody::Text(self.random_text_message_state()),
                1 => MessageStateBody::Location(self.random_location_message()),
                2 => self.take_poll_open(conversation_id).map_or_else(
                    || MessageStateBody::Text(self.random_text_message_state()),
                    MessageStateBody::PollOpen,
                ),
                3 => self.take_poll_close(conversation_id).map_or_else(
                    || MessageStateBody::Text(self.random_text_message_state()),
                    MessageStateBody::PollClose,
                ),
                _ => unreachable!("All message types should have been covered"),
            }
        }

        fn random_contact(&self) -> Option<ThreemaId> {
            let contacts = self
                .contacts
                .lock_unwrap()
                .iter()
                .filter_map(|(contact, acquaintance_level)| {
                    if acquaintance_level == &protobuf::d2d_sync::contact::AcquaintanceLevel::Direct {
                        Some(contact)
                    } else {
                        None
                    }
                })
                .copied()
                .collect::<Vec<_>>();

            self.random_number_generator
                .lock_unwrap()
                .random_choice(&contacts)
                .copied()
        }

        fn random_group_identity(&self) -> Option<GroupIdentity> {
            self.random_number_generator
                .lock_unwrap()
                .random_choice(&self.groups.lock_unwrap().keys().collect::<Vec<_>>())
                .copied()
                .copied()
        }

        fn random_distribution_list_identity(&self) -> Option<DistributionListId> {
            self.random_number_generator
                .lock_unwrap()
                .random_choice(&self.distribution_lists.lock_unwrap().keys().collect::<Vec<_>>())
                .copied()
                .copied()
        }

        fn random_reaction_pool(
            &self,
            guaranteed: impl IntoIterator<Item = ThreemaId>,
            members: &HashSet<ThreemaId>,
        ) -> Vec<ThreemaId> {
            let mut pool: HashSet<ThreemaId> = guaranteed.into_iter().collect();
            pool.extend(self.random_members(members));
            pool.into_iter().collect()
        }

        fn random_incoming_message_state(&self, conversation_type: ConversationType) -> MessageState {
            let (conversation_id, creator_identity, reactions, body) = match conversation_type {
                ConversationType::Contact => {
                    let sender = self
                        .random_contact()
                        .expect("There must be at least one direct contact for 1:1 messages");
                    let body = self.random_message_body_state(ConversationId::Contact(sender));
                    let reactions = self.random_reactions(&[self.user_identity, sender]);
                    (ConversationId::Contact(sender), sender, reactions, body)
                },

                ConversationType::DistributionList => {
                    unreachable!("Cannot generate incoming distribution list message for outgoing message");
                },

                ConversationType::Group => {
                    let group_identity = self
                        .random_group_identity()
                        .expect("There must be at least one group for group messages");

                    let body = self.random_message_body_state(ConversationId::Group(group_identity));

                    // Get group members for sender selection and reaction pool.
                    let groups = self.groups.lock_unwrap();
                    let members = groups.get(&group_identity).expect("Group should have members");

                    // Choose sender from list of group members or direct contacts if group has no members.
                    // Note: A sender might have been a part of the group in the past but isn't anymore.
                    let sender = {
                        let mut random_number_generator = self.random_number_generator.lock_unwrap();
                        random_number_generator
                            .random_choice(&members.iter().copied().collect::<Vec<_>>())
                            .copied()
                    }
                    .or_else(|| self.random_contact())
                    .expect("Incoming message should have a sender");

                    // Build reaction pool with guaranteed participants.
                    let reactions = self.random_reactions(&self.random_reaction_pool(
                        [self.user_identity, group_identity.creator_identity, sender],
                        members,
                    ));
                    (ConversationId::Group(group_identity), sender, reactions, body)
                },
            };

            let mut random_number_generator = self.random_number_generator.lock_unwrap();
            MessageState {
                conversation_id,
                creator_identity,
                message_id: MessageId(random_number_generator.generate()),
                created_at: random_number_generator.generate(),
                direction: MessageDirection::Incoming(IncomingMessageDirection {
                    received_at: random_number_generator.generate(),
                    overrides: MessageOverrides {
                        delivery_receipt_policy: MessageOverridesDeliveryReceiptPolicy::Default,
                    },
                }),
                read_at: random_number_generator.generate(),
                star_marker: MessageStarMarker::None,
                reactions,
                body,
            }
        }

        fn random_outgoing_message_state(&self, conversation_type: ConversationType) -> MessageState {
            let (conversation_id, reactions, body) = match conversation_type {
                ConversationType::Contact => {
                    let receiver_identity = self
                        .random_contact()
                        .expect("There must be at least one contact for 1:1 messages");
                    let reactions = self.random_reactions(&[self.user_identity, receiver_identity]);
                    let body = self.random_message_body_state(ConversationId::Contact(receiver_identity));

                    (ConversationId::Contact(receiver_identity), reactions, body)
                },
                ConversationType::DistributionList => {
                    let distribution_list_id = self
                        .random_distribution_list_identity()
                        .expect("There must be at least one distribution list");

                    (
                        ConversationId::DistributionList(distribution_list_id),
                        vec![],
                        self.random_message_body_state(ConversationId::DistributionList(
                            distribution_list_id,
                        )),
                    )
                },
                ConversationType::Group => {
                    let group_identity = self
                        .random_group_identity()
                        .expect("There must be at least one group for group messages");

                    let body = self.random_message_body_state(ConversationId::Group(group_identity));

                    // Build reaction pool from group members.
                    let reactions = self.random_reactions(
                        &self.random_reaction_pool(
                            [self.user_identity],
                            self.groups
                                .lock_unwrap()
                                .get(&group_identity)
                                .expect("Group should have members"),
                        ),
                    );

                    (ConversationId::Group(group_identity), reactions, body)
                },
            };

            let mut random_number_generator = self.random_number_generator.lock_unwrap();
            MessageState {
                conversation_id,
                creator_identity: self.user_identity,
                message_id: MessageId(random_number_generator.generate()),
                created_at: random_number_generator.generate(),
                direction: MessageDirection::Outgoing(OutgoingMessageDirection {
                    sent_at: Some(random_number_generator.generate()),
                    delivered_at: Some(random_number_generator.generate()),
                }),
                read_at: random_number_generator.generate(),
                star_marker: MessageStarMarker::None,
                reactions,
                body,
            }
        }

        fn random_members(&self, members: &HashSet<ThreemaId>) -> Vec<ThreemaId> {
            if members.is_empty() {
                return Vec::new();
            }
            let mut random_number_generator = self.random_number_generator.lock_unwrap();
            let count = random_number_generator.random_in_range(1..=members.len());
            let members: Vec<_> = members.iter().copied().collect();
            random_number_generator.random_choice_multiple(&members, count)
        }

        fn random_message_state(&self, conversation_type: ConversationType) -> MessageState {
            // Generate random message states (Incoming/Outgoing) for conversation types other
            // than DistributionLists (always Outgoing) which only supports Outgoing.
            match conversation_type {
                ConversationType::Contact | ConversationType::Group => {
                    if self.random_number_generator.lock_unwrap().generate() {
                        self.random_outgoing_message_state(conversation_type)
                    } else {
                        self.random_incoming_message_state(conversation_type)
                    }
                },
                ConversationType::DistributionList => self.random_outgoing_message_state(conversation_type),
            }
        }
    }
    impl ConversationProvider for CreateConversationProvider {
        fn add_messages(&mut self, _message_states: Vec<MessageState>) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn set_typing_indicator(
            &mut self,
            _sender_identity: ThreemaId,
            _is_typing: bool,
        ) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn update_messages(&mut self, _updates: Vec<MessageStateUpdate>) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn get_many_messages(
            &self,
            conversation_type: ConversationType,
            batch_index: usize,
        ) -> Result<Vec<MessageState>, ProviderError> {
            let limit = match conversation_type {
                ConversationType::Contact => self.total_number_of_contact_messages,
                ConversationType::DistributionList => self.total_number_of_distribution_list_messages,
                ConversationType::Group => self.total_number_of_group_messages,
            };
            let mut messages = Vec::with_capacity(Self::MESSAGES_PER_BATCH);

            for _ in batch_index.saturating_mul(Self::MESSAGES_PER_BATCH)
                ..min(
                    batch_index
                        .saturating_add(1)
                        .saturating_mul(Self::MESSAGES_PER_BATCH),
                    limit,
                )
            {
                messages.push(self.random_message_state(conversation_type));
            }

            Ok(messages)
        }

        fn get_messages_metadata(
            &self,
            _conversation_id: ConversationId,
            _message_ids: &[MessageId],
        ) -> Result<Vec<MessageStateMetadata>, ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn is_message_marked_used(
            &self,
            _sender_identity: ThreemaId,
            _message_id: MessageId,
        ) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup create");
        }
    }

    pub(super) struct CreateCspNonceProvider {
        pub(super) total_number_of_nonces: usize,
    }
    impl CreateCspNonceProvider {
        const NONCES_PER_BATCH: usize = 1024;
    }
    impl NonceProvider for CreateCspNonceProvider {
        fn add_many(&mut self, _hashed_nonces: Vec<HashedNonce>) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn get_many(&self, batch_index: usize) -> Result<Vec<HashedNonce>, ProviderError> {
            let mut nonces = Vec::with_capacity(Self::NONCES_PER_BATCH);

            for nonce in batch_index.saturating_mul(Self::NONCES_PER_BATCH)
                ..min(
                    batch_index
                        .saturating_add(1)
                        .saturating_mul(Self::NONCES_PER_BATCH),
                    self.total_number_of_nonces,
                )
            {
                nonces.push(HashedNonce(concat_fixed_bytes!(nonce.to_le_bytes(), [0_u8; 24])));
            }

            Ok(nonces)
        }

        fn has(&self, _hashed_nonce: &HashedNonce) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup create");
        }
    }

    pub(super) struct CreatePollProvider {
        pub(super) random_number_generator: Arc<Mutex<RandomNumberGenerator>>,
        pub(super) user_identity: ThreemaId,
        pub(super) contacts: Arc<Mutex<BTreeMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,
        pub(super) groups: Arc<Mutex<BTreeMap<GroupIdentity, HashSet<ThreemaId>>>>,
        /// Registry of generated [`PollOpen`] messages, grouped by their conversation.
        ///
        /// Shared with [`BackupConversationProvider`] so that poll-open/poll-close messages can
        /// reference an actual poll in the same conversation.
        pub(super) polls: Arc<Mutex<HashMap<ConversationId, Vec<PollOpen>>>>,
        pub(super) number_of_polls: usize,
    }
    impl CreatePollProvider {
        const POLLS_PER_BATCH: usize = 64;

        /// Choose a random, non-empty set of voters for a poll in a group conversation.
        ///
        /// Selects a random subset of group members, then extends with a coin-flip
        /// - by a random number of non-group contacts to simulate former group members
        /// - by the user itself.
        fn random_group_voters(&self, group_identity: &GroupIdentity) -> Vec<ThreemaId> {
            let group_members: Vec<ThreemaId> = self
                .groups
                .lock_unwrap()
                .get(group_identity)
                .expect("Group must exist")
                .iter()
                .copied()
                .collect();

            let mut random_number_generator = self.random_number_generator.lock_unwrap();

            // Select a random subset of group members as voters.
            let voter_count = random_number_generator.random_in_range(0..=group_members.len());
            let mut voters = random_number_generator.random_choice_multiple(&group_members, voter_count);

            // Coin-flip: extend with random contacts that are not group members.
            if random_number_generator.generate() {
                let non_group_contacts: Vec<ThreemaId> = self
                    .contacts
                    .lock_unwrap()
                    .keys()
                    .copied()
                    .filter(|contact| !group_members.contains(contact))
                    .collect();

                if !non_group_contacts.is_empty() {
                    let extra_count = random_number_generator.random_in_range(1..=non_group_contacts.len());
                    voters.extend(
                        random_number_generator.random_choice_multiple(&non_group_contacts, extra_count),
                    );
                }
            }

            // Coin-flip: user will be part of the voters.
            if random_number_generator.generate() && !voters.contains(&self.user_identity) {
                voters.push(self.user_identity);
            }
            voters
        }

        /// Generate a random group or 1:1 `ConversationId`.
        ///
        /// Note: A group `ConversationId` is only generated if a group with at least one member exists.
        fn random_contact_or_group(&self) -> ConversationId {
            if self.random_number_generator.lock_unwrap().generate()
                && let Some(group_identity) = self
                    .random_number_generator
                    .lock_unwrap()
                    .random_choice(&self.groups.lock_unwrap().keys().collect::<Vec<_>>())
                    .copied()
                    .copied()
            {
                ConversationId::Group(group_identity)
            } else {
                let peer =
                    CreateContactProvider::random_contact(&self.random_number_generator, &self.contacts)
                        .expect("There must be at least one contact for polls");
                ConversationId::Contact(peer)
            }
        }

        /// Generate a random poll located either in a group or in a 1:1 conversation.
        ///
        /// A group poll is generated only if a group with at least one member exists and a 'coin flip'
        /// selects it, otherwise a 1:1 poll is generated.
        ///
        /// The voters depend on the conversation:
        /// - Group poll: a non-empty set of valid contacts.
        /// - 1:1 poll: the user and the contact the conversation is with.
        fn random_poll(&self) -> Poll {
            // Determine the conversation the poll is located in and its associated voters.
            let conversation = self.random_contact_or_group();
            let (creator_identity, voters) = match conversation {
                ConversationId::Group(group_identity) => (
                    if self.random_number_generator.lock_unwrap().generate() {
                        self.random_number_generator
                            .lock_unwrap()
                            .random_choice(&self.contacts.lock_unwrap().keys().copied().collect::<Vec<_>>())
                            .copied()
                            .expect("Contacts must not be empty")
                    } else {
                        self.user_identity
                    },
                    self.random_group_voters(&group_identity),
                ),
                ConversationId::Contact(contact) => (
                    self.random_number_generator
                        .lock_unwrap()
                        .random_choice(&[self.user_identity, contact])
                        .copied()
                        .expect("A valid user or contact"),
                    vec![self.user_identity, contact],
                ),
                ConversationId::DistributionList(_) => {
                    unreachable!("Unsupported conversation type for polls")
                },
            };

            let mut random_number_generator = self.random_number_generator.lock_unwrap();

            let answer_type = if random_number_generator.generate() {
                protobuf::data_backup::poll::PollAnswerType::SingleChoice
            } else {
                protobuf::data_backup::poll::PollAnswerType::MultipleChoice
            };
            let display_mode = if random_number_generator.generate() {
                protobuf::data_backup::poll::PollDisplayMode::List
            } else {
                protobuf::data_backup::poll::PollDisplayMode::Summary
            };

            let choices: Vec<PollChoice> = {
                let number_of_choices = random_number_generator.random_in_range(1..11);
                iter::repeat_with(|| PollChoice {
                    id: PollChoiceId(random_number_generator.generate()),
                    description: random_number_generator.random_string(1..20),
                })
                .take(number_of_choices)
                .collect()
            };

            let votes = {
                // Cast votes.
                let votes = voters
                    .iter()
                    .copied()
                    .map(|voter| {
                        (
                            voter,
                            PollVote {
                                choices: match answer_type {
                                    protobuf::data_backup::poll::PollAnswerType::SingleChoice => {
                                        HashSet::from([*random_number_generator
                                            .random_choice(
                                                &choices
                                                    .iter()
                                                    .map(|poll_choice| poll_choice.id)
                                                    .collect::<Vec<_>>(),
                                            )
                                            .expect("There should be at least one choice")])
                                    },

                                    protobuf::data_backup::poll::PollAnswerType::MultipleChoice => choices
                                        .iter()
                                        .filter_map(|poll_choice| {
                                            if random_number_generator.generate() {
                                                Some(poll_choice.id)
                                            } else {
                                                None
                                            }
                                        })
                                        .collect(),
                                }
                                .into_iter()
                                .collect(),
                                created_at: random_number_generator.generate(),
                                modified_at: random_number_generator.random_optional_u64(),
                            },
                        )
                    })
                    .collect();

                // Map votes to display mode.
                match display_mode {
                    protobuf::data_backup::poll::PollDisplayMode::List => PollVotes::Votes(votes),
                    protobuf::data_backup::poll::PollDisplayMode::Summary => {
                        let user_choices = if let Some(user_votes) = votes.get(&self.user_identity) {
                            user_votes.choices.iter().copied().collect()
                        } else {
                            HashSet::new()
                        };
                        PollVotes::Summary(PollVotesSummary {
                            summary: choices
                                .iter()
                                .map(|poll_choice| {
                                    (
                                        poll_choice.id,
                                        votes
                                            .iter()
                                            .filter(|(_, vote)| vote.choices.contains(&poll_choice.id))
                                            .count()
                                            .try_into()
                                            .expect("The number of votes should fit into u16"),
                                    )
                                })
                                .collect(),
                            user_choices,
                        })
                    },
                }
            };

            Poll {
                id: PollId(random_number_generator.generate()),
                conversation,
                creator_identity,
                created_at: random_number_generator.generate(),
                state: if random_number_generator.generate() {
                    protobuf::data_backup::poll::PollState::Open
                } else {
                    protobuf::data_backup::poll::PollState::Closed
                },
                description: random_number_generator.random_string(0..40),
                answer_type,
                announce_type: if random_number_generator.generate() {
                    protobuf::data_backup::poll::PollAnnounceType::CreatorOnly
                } else {
                    protobuf::data_backup::poll::PollAnnounceType::Everyone
                },
                display_mode,
                choices,
                votes,
            }
        }
    }
    impl PollProvider for CreatePollProvider {
        fn add(&mut self, _polls: Vec<Poll>) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn get_many(&self, batch_index: usize) -> Result<Vec<Poll>, ProviderError> {
            let mut polls = Vec::with_capacity(Self::POLLS_PER_BATCH);

            for _ in batch_index.saturating_mul(Self::POLLS_PER_BATCH)
                ..min(
                    batch_index
                        .saturating_add(1)
                        .saturating_mul(Self::POLLS_PER_BATCH),
                    self.number_of_polls,
                )
            {
                let poll = self.random_poll();

                // Register the poll so poll-open/poll-close messages can reference it later.
                self.polls
                    .lock_unwrap()
                    .entry(poll.conversation)
                    .or_default()
                    .push(PollOpen { id: poll.id });

                polls.push(poll);
            }

            Ok(polls)
        }
    }

    pub(super) struct CreateDataProvider {
        random_number_generator: Arc<Mutex<RandomNumberGenerator>>,

        user_identity: ThreemaId,

        contacts: Arc<Mutex<BTreeMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,

        distribution_lists: Arc<Mutex<BTreeMap<DistributionListId, HashSet<ThreemaId>>>>,

        groups: Arc<Mutex<BTreeMap<GroupIdentity, HashSet<ThreemaId>>>>,

        /// Shared registry of generated [`PollOpen`] messages, keyed by conversation.
        /// Filled by the poll provider and read by the conversation provider so poll
        /// messages reference real polls.
        poll_opens: Arc<Mutex<HashMap<ConversationId, Vec<PollOpen>>>>,

        parameters: BackupCreateParameters,
    }
    impl CreateDataProvider {
        pub(super) fn new(parameters: BackupCreateParameters) -> anyhow::Result<(Self, IdentityData)> {
            let user_identity = ThreemaId::try_from("BACKMEUP").expect("Should be a valid Threema ID");
            let mut random_number_generator = RandomNumberGenerator::new();
            let contacts = Self::generate_contacts(&mut random_number_generator, parameters.contacts)?;
            let distribution_lists = Self::generate_distribution_lists(
                &mut random_number_generator,
                &contacts.keys().copied().collect::<Vec<_>>(),
                parameters.distribution_lists,
            );
            let groups = Self::generate_groups(
                &mut random_number_generator,
                user_identity,
                &contacts.keys().copied().collect::<Vec<_>>(),
                parameters.groups,
            );
            let example_data_provider = Self {
                random_number_generator: Arc::new(Mutex::new(random_number_generator)),
                user_identity,
                contacts: Arc::new(Mutex::new(contacts)),
                groups: Arc::new(Mutex::new(groups)),
                distribution_lists: Arc::new(Mutex::new(distribution_lists)),
                poll_opens: Arc::new(Mutex::new(HashMap::new())),
                parameters,
            };
            let identity_data = IdentityData {
                user_identity: example_data_provider.user_identity,
                client_key: ClientKey::from([1; ClientKey::LENGTH]),
                csp_server_group: ChatServerGroup::try_from("a").expect("Chat Server Group should be valid"),
            };

            Ok((example_data_provider, identity_data))
        }

        fn generate_contacts(
            random_number_generator: &mut RandomNumberGenerator,
            number: usize,
        ) -> anyhow::Result<BTreeMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>> {
            (0..number)
                .map(|index| {
                    Ok((
                        ThreemaId::try_from(format!("{index:08X}").as_str())?,
                        *random_number_generator
                            .random_choice(&[
                                protobuf::d2d_sync::contact::AcquaintanceLevel::Direct,
                                protobuf::d2d_sync::contact::AcquaintanceLevel::GroupOrDeleted,
                            ])
                            .expect("Acquaintance level choice set non-empty"),
                    ))
                })
                .collect()
        }

        fn generate_distribution_lists(
            random_number_generator: &mut RandomNumberGenerator,
            contacts: &[ThreemaId],
            number: usize,
        ) -> BTreeMap<DistributionListId, HashSet<ThreemaId>> {
            if contacts.is_empty() {
                warn!("Cannot generate a distribution list without any contacts");
                return BTreeMap::new();
            }
            (0..number)
                .map(|index| {
                    let n_members = random_number_generator.random_in_range(1..=256);
                    let members = random_number_generator
                        .random_choice_multiple(contacts, n_members)
                        .into_iter()
                        .collect();
                    (DistributionListId(index as u64), members)
                })
                .collect()
        }

        fn generate_groups(
            random_number_generator: &mut RandomNumberGenerator,
            user_identity: ThreemaId,
            contacts: &[ThreemaId],
            number: usize,
        ) -> BTreeMap<GroupIdentity, HashSet<ThreemaId>> {
            (0..number)
                .map(|index| {
                    let creator = if index.is_multiple_of(2) {
                        user_identity
                    } else {
                        *random_number_generator
                            .random_choice(contacts)
                            .unwrap_or(&user_identity)
                    };
                    let n_members = random_number_generator.random_in_range(0..=256);
                    let members = random_number_generator
                        .random_choice_multiple(contacts, n_members)
                        .into_iter()
                        .filter(|contact| *contact != creator)
                        .collect();
                    (
                        GroupIdentity {
                            group_id: index as u64,
                            creator_identity: creator,
                        },
                        members,
                    )
                })
                .collect()
        }

        #[expect(clippy::unused_self, reason = "Follow pattern")]
        pub(super) fn user_profile_provider(&self) -> CreateUserProfileProvider {
            CreateUserProfileProvider
        }

        #[expect(clippy::unused_self, reason = "Follow pattern")]
        pub(super) fn settings_provider(&self) -> CreateSettingsProvider {
            CreateSettingsProvider
        }

        pub(super) fn contact_provider(&self) -> CreateContactProvider {
            CreateContactProvider {
                user_identity: self.user_identity,
                random_number_generator: Arc::clone(&self.random_number_generator),
                contacts: Arc::clone(&self.contacts),
            }
        }

        pub(super) fn group_provider(&self) -> CreateGroupProvider {
            CreateGroupProvider {
                random_number_generator: Arc::clone(&self.random_number_generator),
                groups: Arc::clone(&self.groups),
            }
        }

        pub(super) fn distribution_list_provider(&self) -> CreateDistributionListProvider {
            CreateDistributionListProvider {
                random_number_generator: Arc::clone(&self.random_number_generator),
                distribution_lists: Arc::clone(&self.distribution_lists),
            }
        }

        pub(super) fn csp_nonce_provider(&self) -> CreateCspNonceProvider {
            CreateCspNonceProvider {
                total_number_of_nonces: self.parameters.csp_nonces,
            }
        }

        pub(super) fn conversation_provider(&self) -> CreateConversationProvider {
            CreateConversationProvider {
                random_number_generator: Arc::clone(&self.random_number_generator),
                user_identity: self.user_identity,
                contacts: Arc::clone(&self.contacts),
                distribution_lists: Arc::clone(&self.distribution_lists),
                groups: Arc::clone(&self.groups),
                poll_open_pool: Arc::clone(&self.poll_opens),
                poll_close_pool: Arc::new(Mutex::new(HashMap::new())),
                total_number_of_contact_messages: self.parameters.contact_messages,
                total_number_of_distribution_list_messages: self.parameters.distribution_list_messages,
                total_number_of_group_messages: self.parameters.group_messages,
            }
        }

        pub(super) fn poll_provider(&self) -> CreatePollProvider {
            CreatePollProvider {
                random_number_generator: Arc::clone(&self.random_number_generator),
                user_identity: self.user_identity,
                contacts: Arc::clone(&self.contacts),
                groups: Arc::clone(&self.groups),
                polls: Arc::clone(&self.poll_opens),
                number_of_polls: self.parameters.polls,
            }
        }
    }
}

/// The parameters defining the amount of instances of each type.
#[derive(Debug, Args)]
pub struct BackupCreateParameters {
    /// Number of contacts.
    #[arg(long, default_value_t = 0)]
    contacts: usize,

    /// Number of distribution lists.
    #[arg(long, default_value_t = 0)]
    distribution_lists: usize,

    /// Number of groups.
    #[arg(long, default_value_t = 0)]
    groups: usize,

    /// Number of polls.
    #[arg(long, default_value_t = 0)]
    polls: usize,

    /// Number of 1:1 messages.
    #[arg(long, default_value_t = 0)]
    contact_messages: usize,

    /// Number of distribution list messages.
    #[arg(long, default_value_t = 0)]
    distribution_list_messages: usize,

    /// Number of group messages.
    #[arg(long, default_value_t = 0)]
    group_messages: usize,

    /// Number of CSP nonces.
    #[arg(long, default_value_t = 0)]
    csp_nonces: usize,

    /// Number of D2M nonces.
    #[arg(long, default_value_t = 0)]
    d2d_nonces: usize,
}

#[derive(Parser)]
#[command()]
struct DataBackupCommand {
    #[command(flatten)]
    config: BackupCreateParameters,

    /// The path where the backup should be written to.
    #[arg(short, long)]
    path: path::PathBuf,

    /// Password used to secure the backup.
    #[arg(long)]
    password: String,

    /// Turn on debugging information.
    /// Use -v -vv to control log level.
    #[arg(short, action = clap::ArgAction::Count)]
    verbose: u8,
}

struct FileWriter {
    path: path::PathBuf,
    file: fs::File,
}
impl FileWriter {
    fn new(path: path::PathBuf) -> anyhow::Result<Self> {
        info!(?path, "Create file");
        Ok(Self {
            path: path.clone(),

            // Note: Don't use the 'append' option as it would overrule the seek position.
            file: fs::OpenOptions::new().create_new(true).write(true).open(path)?,
        })
    }

    #[tracing::instrument(skip_all, fields(length = chunk.len()))]
    fn append(&mut self, chunk: &[u8]) -> anyhow::Result<()> {
        trace!("Append to file");
        let _ = self.file.seek(io::SeekFrom::End(0))?;
        self.file.write_all(chunk)?;
        Ok(())
    }

    #[tracing::instrument(skip_all, fields(offset = offset, length = chunk.len()))]
    fn write_at(&mut self, offset: u64, chunk: &[u8]) -> anyhow::Result<()> {
        trace!("Write at specific position");
        let _ = self.file.seek(io::SeekFrom::Start(offset))?;
        self.file.write_all(chunk)?;
        let _ = self.file.seek(io::SeekFrom::End(0))?;

        Ok(())
    }

    fn handle(&mut self, instruction: DataBackupCreateLocalWriteInstruction) -> anyhow::Result<()> {
        match instruction {
            DataBackupCreateLocalWriteInstruction::Append(chunk) => self.append(&chunk)?,
            DataBackupCreateLocalWriteInstruction::WriteAt { offset, data } => {
                self.write_at(offset.0, &data)?;
            },
        }

        Ok(())
    }
}

struct ExampleBackupCreator {
    task: DataBackupCreateTask,
    file_writer: FileWriter,
}

impl ExampleBackupCreator {
    fn new(parameters: BackupCreateParameters, path: &path::Path, password: String) -> anyhow::Result<Self> {
        let (database, identity_data) = CreateDataProvider::new(parameters)?;
        let (task, filename) = {
            let context = DataBackupCreateInit {
                password,
                identity_data,
                providers: DataBackupProviders {
                    user_profile: Arc::new(Mutex::new(database.user_profile_provider())),
                    contacts: Arc::new(Mutex::new(database.contact_provider())),
                    groups: Arc::new(Mutex::new(database.group_provider())),
                    distribution_lists: Arc::new(Mutex::new(database.distribution_list_provider())),
                    conversations: Arc::new(Mutex::new(database.conversation_provider())),
                    csp_nonces: Arc::new(Mutex::new(database.csp_nonce_provider())),
                    settings: Arc::new(Mutex::new(database.settings_provider())),
                    polls: Arc::new(Mutex::new(database.poll_provider())),
                },
            };
            DataBackupCreateTask::new(context)
        };
        let file_writer = FileWriter::new(path.join(filename))?;
        Ok(Self { task, file_writer })
    }

    fn run(mut self) -> anyhow::Result<()> {
        info!("Creating backup");
        loop {
            match self.task.poll()? {
                DataBackupCreateLoop::Instruction(instruction) => {
                    debug!(state_update = ?instruction.state_update);
                    match instruction.write_instruction {
                        Some(DataBackupCreateWriteInstruction::Local(instruction)) => {
                            self.file_writer.handle(instruction)?;
                        },
                        None => {},
                    }
                },

                DataBackupCreateLoop::Done(()) => {
                    info!(path = ?self.file_writer.path, "Backup created successfully");
                    return Ok(());
                },
            }
        }
    }
}

fn main() -> anyhow::Result<()> {
    let arguments = DataBackupCommand::parse();
    // Configure logging.
    let log_level = match arguments.verbose {
        1 => Level::DEBUG,
        2 => Level::TRACE,
        _ => Level::INFO,
    };
    init_stderr_logging(log_level);

    ExampleBackupCreator::new(arguments.config, &arguments.path, arguments.password)?.run()
}

#[test]
fn verify_cli() {
    use clap::CommandFactory;
    DataBackupCommand::command().debug_assert();
}
