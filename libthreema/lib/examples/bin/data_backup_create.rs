//! Example for creating a data backup.
#![expect(unused_crate_dependencies, reason = "Example triggered false positive")]
mod utils;

use std::{
    fmt, fs,
    io::{self, Seek as _, Write as _},
    path,
    sync::{Arc, Mutex},
};

use anyhow::bail;
use clap::{Args, Parser};
use libthreema::{
    common::{ThreemaId, keys::DataBackupPassword},
    data_backup::task::create::{
        BackupCreateContextInit, BackupCreateLoop, BackupCreateTask, LocalWriteInstruction, WriteInstruction,
    },
    utils::logging::init_stderr_logging,
};
use tracing::{Level, debug, info};

use crate::provider::BackupDataProvider;

pub(crate) mod random_number_generator {
    use core::ops::Range;

    use libthreema_dependencies::rand::{
        self, Rng as _, RngCore as _, SeedableRng as _, distributions::uniform::SampleRange, rngs::StdRng,
        seq::SliceRandom as _,
    };

    pub(crate) struct RandomNumberGenerator(StdRng);
    impl RandomNumberGenerator {
        pub(crate) fn new() -> Self {
            Self(StdRng::from_seed([42; 32]))
        }

        pub(crate) fn generate<T>(&mut self) -> T
        where
            rand::distributions::Standard: rand::distributions::Distribution<T>,
        {
            self.0.r#gen()
        }

        pub(crate) fn random_string(&mut self, length: Range<usize>) -> String {
            self.0
                .clone()
                .sample_iter(rand::distributions::Alphanumeric)
                .take(self.0.gen_range(length))
                .map(char::from)
                .collect::<String>()
        }

        pub(crate) fn random_optional_u64(&mut self) -> Option<u64> {
            if self.generate() {
                Some(self.generate())
            } else {
                None
            }
        }

        pub(crate) fn random_bytes(&mut self, length: Range<usize>) -> Vec<u8> {
            let mut bytes = vec![0; self.0.gen_range(length)];
            self.0.fill_bytes(&mut bytes);
            bytes
        }

        pub(crate) fn random_fixed_length_bytes<const LENGTH: usize>(&mut self) -> [u8; LENGTH] {
            let mut bytes = [0; LENGTH];
            self.0.fill_bytes(&mut bytes);
            bytes
        }

        pub(crate) fn choose<'set, T>(&mut self, set: &'set [T]) -> Option<&'set T> {
            set.choose(&mut self.0)
        }

        pub(crate) fn choose_multiple<T: Copy>(&mut self, set: &[T], count: usize) -> Vec<T> {
            set.choose_multiple(&mut self.0, count).copied().collect()
        }

        pub(crate) fn random_in_range<R>(&mut self, range: R) -> usize
        where
            R: SampleRange<usize>,
        {
            self.0.gen_range(range)
        }
    }
}

// TODO(LIB-94): Reuse the implementations fropm cli/providers (and maybe even share code)
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
            GroupIdentity, HashedNonce, MessageId, ThreemaId,
            keys::{ClientKey, PublicKey},
        },
        model::{
            contact::{Contact, ContactProvider, ContactWithProfilePictures},
            conversation::ConversationProvider,
            distribution_list::{DistributionList, DistributionListProvider},
            group::{Group, GroupMembershipFilter, GroupProvider, GroupWithProfilePicture},
            message::{
                EmojiReaction, IncomingMessageDirection, LocationMessageState, MessageDirection,
                MessageReaction, MessageStarMarker, MessageState, MessageStateBody, MessageStateMetadata,
                MessageStateUpdate, MessageText, MessageTextRevision, OutgoingMessageDirection, PollClose,
                PollOpen, TextMessageState,
            },
            poll::{Poll, PollChoice, PollChoiceId, PollId, PollProvider, PollVote, PollVotes},
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
        utils::sync::MutexIgnorePoison as _,
    };

    const PROFILE_PICTURE_BYTES_SIZE: Range<usize> = 1024..2 * 1024;

    pub(crate) struct BackupSettingsProvider {
        pub(crate) blocked_identities: Vec<ThreemaId>,
        pub(crate) excluded_from_sync_identities: Vec<ThreemaId>,
    }
    impl SettingsProvider for BackupSettingsProvider {
        fn get(&self) -> Result<Settings, ProviderError> {
            Ok(Settings {
                blocked_identities: self.blocked_identities.clone(),
                exclude_from_sync_identities: self.excluded_from_sync_identities.clone(),
                ..Settings::default()
            })
        }

        fn update(&mut self, _update: SettingsUpdate) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn set(&mut self, _settings: Settings) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }
    }

    pub(crate) struct BackupUserProfileProvider;
    impl UserProfileProvider for BackupUserProfileProvider {
        fn get(&self) -> Result<UserProfile, ProviderError> {
            Ok(UserProfile {
                nickname: "Moritz Mocker".to_owned(),
                profile_picture: Some(ProfilePicture {
                    media_type: ProfilePictureMediaType::Jpeg,
                    data: vec![0; PROFILE_PICTURE_BYTES_SIZE.start],
                }),
                ..UserProfile::default()
            })
        }

        fn set(&mut self, _user_profile: UserProfile) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }
    }

    pub(crate) struct BackupContactProvider {
        pub(crate) user_identity: ThreemaId,
        pub(crate) random_number_generator: Arc<Mutex<RandomNumberGenerator>>,
        pub(crate) contacts: Arc<Mutex<BTreeMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,
    }
    impl BackupContactProvider {
        fn random_contact(
            random_number_generator: &Arc<Mutex<RandomNumberGenerator>>,
            contacts: &Arc<Mutex<BTreeMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,
        ) -> Option<ThreemaId> {
            let contacts: Vec<ThreemaId> = contacts
                .lock_ignore_poison()
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
                .lock_ignore_poison()
                .choose(&contacts)
                .copied()
        }
    }
    impl ContactProvider for BackupContactProvider {
        fn is_explicitly_blocked(&self, _identity: ThreemaId) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn has(&self, _identity: ThreemaId) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn count_existing(&self, _identities: &[ThreemaId]) -> Result<usize, ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn get_identities(&self) -> Result<HashSet<ThreemaId>, ProviderError> {
            Ok(self.contacts.lock_ignore_poison().keys().copied().collect())
        }

        fn get(&self, _identity: ThreemaId) -> Result<Option<Contact>, ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn add(&mut self, _contacts: Vec<Contact>) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn get_with_profile_pictures(
            &self,
            identity: ThreemaId,
        ) -> Result<Option<ContactWithProfilePictures>, ProviderError> {
            // Bail if identity is the user's identity
            if identity == self.user_identity {
                return Err(ProviderError::InvalidParameter(
                    "Unexpected encounter of user's identity in contact provider".to_owned(),
                ));
            }

            // Get a snapshot of the contact (if it exists)
            let contacts = self.contacts.lock_ignore_poison();
            let Some(acquaintance_level) = contacts.get(&identity) else {
                return Ok(None);
            };

            let mut random_number_generator = self.random_number_generator.lock_ignore_poison();
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
                        data: random_number_generator.random_bytes(PROFILE_PICTURE_BYTES_SIZE),
                    })
                } else {
                    None
                },
                user_defined_profile_picture: if random_number_generator.generate() {
                    Some(ProfilePicture {
                        media_type: ProfilePictureMediaType::Jpeg,
                        data: random_number_generator.random_bytes(PROFILE_PICTURE_BYTES_SIZE),
                    })
                } else {
                    None
                },
            }))
        }

        fn add_with_profile_pictures(
            &mut self,
            _contacts: Vec<ContactWithProfilePictures>,
        ) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn update(
            &mut self,
            _updates: Vec<libthreema::model::contact::ContactUpdate>,
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
    }

    pub(crate) struct BackupGroupProvider {
        pub(crate) random_number_generator: Arc<Mutex<RandomNumberGenerator>>,
        pub(crate) groups: Arc<Mutex<BTreeMap<GroupIdentity, HashSet<ThreemaId>>>>,
    }
    impl GroupProvider for BackupGroupProvider {
        fn is_part_of_any_group(
            &self,
            _identity: ThreemaId,
            _filter: GroupMembershipFilter,
        ) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn get_identities(&self) -> Result<HashSet<GroupIdentity>, ProviderError> {
            Ok(self.groups.lock_ignore_poison().keys().copied().collect())
        }

        fn get_with_profile_picture(
            &self,
            identity: GroupIdentity,
        ) -> Result<Option<GroupWithProfilePicture>, ProviderError> {
            let Some(members) = self.groups.lock_ignore_poison().get(&identity).cloned() else {
                return Ok(None);
            };
            let mut random_number_generator = self.random_number_generator.lock_ignore_poison();
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
                        data: random_number_generator.random_bytes(PROFILE_PICTURE_BYTES_SIZE),
                    })
                } else {
                    None
                },
            }))
        }

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
    }

    pub(crate) struct BackupDistributionListProvider {
        pub(crate) random_number_generator: Arc<Mutex<RandomNumberGenerator>>,
        pub(crate) distribution_lists: Arc<Mutex<BTreeMap<DistributionListId, HashSet<ThreemaId>>>>,
    }
    impl DistributionListProvider for BackupDistributionListProvider {
        fn get_ids(&self) -> Result<HashSet<DistributionListId>, ProviderError> {
            Ok(self
                .distribution_lists
                .lock_ignore_poison()
                .keys()
                .copied()
                .collect())
        }

        fn get(&self, id: DistributionListId) -> Result<Option<DistributionList>, ProviderError> {
            let Some(members) = self.distribution_lists.lock_ignore_poison().get(&id).cloned() else {
                return Ok(None);
            };

            let mut random_number_generator = self.random_number_generator.lock_ignore_poison();
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

        fn add(&mut self, _distribution_lists: Vec<DistributionList>) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }
    }

    pub(crate) struct BackupConversationProvider {
        pub(crate) random_number_generator: Arc<Mutex<RandomNumberGenerator>>,

        pub(crate) user_identity: ThreemaId,

        pub(crate) contacts: Arc<Mutex<BTreeMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,

        pub(crate) distribution_lists: Arc<Mutex<BTreeMap<DistributionListId, HashSet<ThreemaId>>>>,

        pub(crate) groups: Arc<Mutex<BTreeMap<GroupIdentity, HashSet<ThreemaId>>>>,

        pub(crate) total_number_of_contact_messages: usize,

        pub(crate) total_number_of_distribution_list_messages: usize,

        pub(crate) total_number_of_group_messages: usize,
    }
    impl BackupConversationProvider {
        const MESSAGES_PER_BATCH: usize = 128;

        fn random_text_message_state(&self) -> TextMessageState {
            let mut random_number_generator = self.random_number_generator.lock_ignore_poison();
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
            let mut random_number_generator = self.random_number_generator.lock_ignore_poison();
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
            let mut random_number_generator = self.random_number_generator.lock_ignore_poison();
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

        fn random_message_body_state(&self) -> MessageStateBody {
            let message_type = self
                .random_number_generator
                .lock_ignore_poison()
                .random_in_range(0..4);
            match message_type {
                0 => MessageStateBody::Text(self.random_text_message_state()),
                1 => MessageStateBody::Location(self.random_location_message()),
                2 => MessageStateBody::PollOpen(PollOpen {
                    id: PollId(self.random_number_generator.lock_ignore_poison().generate()),
                }),
                3 => MessageStateBody::PollClose(PollClose {
                    id: PollId(self.random_number_generator.lock_ignore_poison().generate()),
                }),
                _ => unreachable!("All message types should have been covered"),
            }
        }

        fn random_group_identity(&self) -> Option<GroupIdentity> {
            self.random_number_generator
                .lock_ignore_poison()
                .choose(&self.groups.lock_ignore_poison().keys().collect::<Vec<_>>())
                .copied()
                .copied()
        }

        fn random_distribution_list_identity(&self) -> Option<DistributionListId> {
            self.random_number_generator
                .lock_ignore_poison()
                .choose(
                    &self
                        .distribution_lists
                        .lock_ignore_poison()
                        .keys()
                        .collect::<Vec<_>>(),
                )
                .copied()
                .copied()
        }

        fn random_one_to_one_contact(&self) -> Option<ThreemaId> {
            let contacts: Vec<ThreemaId> = self
                .contacts
                .lock_ignore_poison()
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

            self.random_number_generator
                .lock_ignore_poison()
                .choose(&contacts)
                .copied()
        }

        fn random_incoming_message_state(&self, conversation_type: ConversationType) -> MessageState {
            let (conversation_id, creator_identity, reactions, body) = match conversation_type {
                ConversationType::Contact => {
                    let body = self.random_message_body_state();

                    let sender = self
                        .random_one_to_one_contact()
                        .expect("There must be at least one direct contact for 1:1 messages");

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

                    let body = self.random_message_body_state();

                    // Get group members for sender selection and reaction pool.
                    let groups = self.groups.lock_ignore_poison();
                    let members = groups.get(&group_identity).expect("Group should have members");

                    // Choose sender from list of group members or direct contacts if group has no members.
                    // Note: A sender might have been a part of the group in the past but isn't anymore.
                    let sender = {
                        let mut random_number_generator = self.random_number_generator.lock_ignore_poison();
                        random_number_generator
                            .choose(&members.iter().copied().collect::<Vec<_>>())
                            .copied()
                    }
                    .or_else(|| self.random_one_to_one_contact())
                    .expect("incoming message should have a sender");

                    // Build reaction pool with guaranteed participants.
                    let reactions = self.random_reactions(&self.random_reaction_pool(
                        [self.user_identity, group_identity.creator_identity, sender],
                        members,
                    ));
                    (ConversationId::Group(group_identity), sender, reactions, body)
                },
            };

            let mut random_number_generator = self.random_number_generator.lock_ignore_poison();
            MessageState {
                conversation_id,
                creator_identity,
                message_id: MessageId(random_number_generator.generate()),
                created_at: random_number_generator.generate(),
                direction: MessageDirection::Incoming(IncomingMessageDirection {
                    received_at: random_number_generator.generate(),
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
                        .random_one_to_one_contact()
                        .expect("There must be at least one contact for 1:1 messages");
                    let reactions = self.random_reactions(&[self.user_identity, receiver_identity]);
                    let body = self.random_message_body_state();

                    (ConversationId::Contact(receiver_identity), reactions, body)
                },
                ConversationType::DistributionList => {
                    let distribution_list_id = self
                        .random_distribution_list_identity()
                        .expect("There must be at least one distribution list");

                    let body = self.random_message_body_state();

                    // Build reaction pool from group members.
                    let reactions = self.random_reactions(
                        &self.random_reaction_pool(
                            [self.user_identity],
                            self.distribution_lists
                                .lock_ignore_poison()
                                .get(&distribution_list_id)
                                .expect("Group should have members"),
                        ),
                    );

                    (
                        ConversationId::DistributionList(distribution_list_id),
                        reactions,
                        body,
                    )
                },
                ConversationType::Group => {
                    let group_identity = self
                        .random_group_identity()
                        .expect("There must be at least one group for group messages");

                    let body = self.random_message_body_state();

                    // Build reaction pool from group members.
                    let reactions = self.random_reactions(
                        &self.random_reaction_pool(
                            [self.user_identity],
                            self.groups
                                .lock_ignore_poison()
                                .get(&group_identity)
                                .expect("Group should have members"),
                        ),
                    );

                    (ConversationId::Group(group_identity), reactions, body)
                },
            };

            let mut random_number_generator = self.random_number_generator.lock_ignore_poison();
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

        fn random_reaction_pool(
            &self,
            guaranteed: impl IntoIterator<Item = ThreemaId>,
            members: &HashSet<ThreemaId>,
        ) -> Vec<ThreemaId> {
            let mut pool: HashSet<ThreemaId> = guaranteed.into_iter().collect();
            pool.extend(self.random_members(members));
            pool.into_iter().collect()
        }

        fn random_members(&self, members: &HashSet<ThreemaId>) -> Vec<ThreemaId> {
            if members.is_empty() {
                return Vec::new();
            }
            let mut random_number_generator = self.random_number_generator.lock_ignore_poison();
            let count = random_number_generator.random_in_range(1..=members.len());
            let members: Vec<_> = members.iter().copied().collect();
            random_number_generator.choose_multiple(&members, count)
        }

        fn random_message_state(&self, conversation_type: ConversationType) -> MessageState {
            // Generate random message states (Incoming/Outgoing) for conversation types other
            // than DistributionLists (always Outgoing) which only supports Outgoing.
            match conversation_type {
                ConversationType::Contact | ConversationType::Group => {
                    if self.random_number_generator.lock_ignore_poison().generate() {
                        self.random_outgoing_message_state(conversation_type)
                    } else {
                        self.random_incoming_message_state(conversation_type)
                    }
                },
                ConversationType::DistributionList => self.random_outgoing_message_state(conversation_type),
            }
        }
    }
    impl ConversationProvider for BackupConversationProvider {
        fn add_messages(&mut self, _message_states: Vec<MessageState>) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn update_messages(&mut self, _updates: Vec<MessageStateUpdate>) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }

        fn set_typing_indicator(
            &mut self,
            _sender_identity: ThreemaId,
            _is_typing: bool,
        ) -> Result<(), ProviderError> {
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

    pub(crate) struct BackupCspNonceProvider {
        pub(crate) total_number_of_nonces: usize,
    }
    impl BackupCspNonceProvider {
        const NONCES_PER_BATCH: usize = 1024;
    }
    impl NonceProvider for BackupCspNonceProvider {
        fn has(&self, _hashed_nonce: &HashedNonce) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup create");
        }

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
    }

    pub(crate) struct BackupPollProvider {
        pub(crate) random_number_generator: Arc<Mutex<RandomNumberGenerator>>,
        pub(crate) user_identity: ThreemaId,
        pub(crate) contacts: Arc<Mutex<BTreeMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,
        #[expect(dead_code, reason = "TODO(LIB-117): Backup polls in group messages")]
        pub(crate) groups: Arc<Mutex<BTreeMap<GroupIdentity, HashSet<ThreemaId>>>>,
        pub(crate) number_of_polls: usize,
    }
    impl BackupPollProvider {
        const POLLS_PER_BATCH: usize = 64;

        fn random_one_to_one_poll(&self) -> Poll {
            let peer = BackupContactProvider::random_contact(&self.random_number_generator, &self.contacts)
                .expect("There must be at least one contact for one to one polls");
            let mut random_number_generator = self.random_number_generator.lock_ignore_poison();
            let is_outgoing: bool = random_number_generator.generate();
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
                let votes: HashMap<ThreemaId, PollVote> = [self.user_identity, peer]
                    .into_iter()
                    .map(|voter| {
                        (
                            voter,
                            PollVote {
                                choices: match answer_type {
                                    protobuf::data_backup::poll::PollAnswerType::SingleChoice => {
                                        HashSet::from([*random_number_generator
                                            .choose(
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
                    protobuf::data_backup::poll::PollDisplayMode::Summary => PollVotes::Summary(
                        choices
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
                    ),
                }
            };

            Poll {
                id: PollId(random_number_generator.generate()),
                conversation: ConversationId::Contact(peer),
                creator_identity: if is_outgoing { self.user_identity } else { peer },
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
    impl PollProvider for BackupPollProvider {
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
                // TODO(LIB-117): Generate random group polls
                polls.push(self.random_one_to_one_poll());
            }

            Ok(polls)
        }

        fn add(&mut self, _polls: Vec<Poll>) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup create");
        }
    }

    pub(crate) struct BackupDataProvider {
        random_number_generator: Arc<Mutex<RandomNumberGenerator>>,
        user_identity: ThreemaId,
        contacts: Arc<Mutex<BTreeMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,
        distribution_lists: Arc<Mutex<BTreeMap<DistributionListId, HashSet<ThreemaId>>>>,
        groups: Arc<Mutex<BTreeMap<GroupIdentity, HashSet<ThreemaId>>>>,
        parameters: BackupCreateParameters,
    }
    impl BackupDataProvider {
        pub(crate) fn new(parameters: BackupCreateParameters) -> anyhow::Result<(Self, IdentityData)> {
            let user_identity = ThreemaId::try_from("BACKMEUP").expect("Should be a valid Threema ID");
            let contacts = Self::generate_contacts(parameters.contacts)?;
            let groups = Self::generate_groups(
                user_identity,
                &contacts.keys().copied().collect::<Vec<_>>(),
                parameters.groups,
            );
            let distribution_list = Self::generate_distribution_lists(
                &contacts.keys().copied().collect::<Vec<_>>(),
                parameters.distribution_lists,
            );
            let example_data_provider = Self {
                random_number_generator: Arc::new(Mutex::new(RandomNumberGenerator::new())),
                user_identity,
                contacts: Arc::new(Mutex::new(contacts)),
                groups: Arc::new(Mutex::new(groups)),
                distribution_lists: Arc::new(Mutex::new(distribution_list)),
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
            number: usize,
        ) -> anyhow::Result<BTreeMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>> {
            let mut contacts = BTreeMap::new();

            for index in 0..number {
                let _ = contacts.insert(
                    ThreemaId::try_from(format!("{index:08X}").as_str())?,
                    if index.is_multiple_of(2) {
                        protobuf::d2d_sync::contact::AcquaintanceLevel::Direct
                    } else {
                        protobuf::d2d_sync::contact::AcquaintanceLevel::GroupOrDeleted
                    },
                );
            }

            Ok(contacts)
        }

        fn generate_groups(
            user_identity: ThreemaId,
            contacts: &[ThreemaId],
            number: usize,
        ) -> BTreeMap<GroupIdentity, HashSet<ThreemaId>> {
            let mut groups = BTreeMap::new();
            for index in 0..number {
                let creator = if contacts.is_empty() || index.is_multiple_of(2) {
                    user_identity
                } else {
                    *contacts
                        .get(
                            index
                                .checked_div_euclid(contacts.len())
                                .expect("contacts must not be empty here"),
                        )
                        .expect("index must be valid")
                };

                let members = contacts
                    .get(0..min(contacts.len().checked_div_euclid(index).unwrap_or(0), 256))
                    .unwrap_or_default()
                    .iter()
                    .copied()
                    .filter(|contact| *contact != creator)
                    .collect();

                let _ = groups.insert(
                    GroupIdentity {
                        group_id: index as u64,
                        creator_identity: creator,
                    },
                    members,
                );
            }

            groups
        }

        fn generate_distribution_lists(
            contacts: &[ThreemaId],
            number: usize,
        ) -> BTreeMap<DistributionListId, HashSet<ThreemaId>> {
            let mut distribution_lists = BTreeMap::new();
            if contacts.is_empty() {
                warn!("cannot generate a distribution list with empty contacts ");
                return distribution_lists;
            }

            for index in 0..number {
                let _ = distribution_lists.insert(
                    DistributionListId(index as u64),
                    contacts
                        .get(
                            0..contacts
                                .len()
                                .checked_div_euclid(index)
                                .unwrap_or(1)
                                .clamp(1, 256),
                        )
                        .expect("contacts must exist")
                        .iter()
                        .copied()
                        .collect(),
                );
            }

            distribution_lists
        }

        #[expect(clippy::unused_self, reason = "Follow pattern")]
        pub(crate) fn user_profile_provider(&self) -> BackupUserProfileProvider {
            BackupUserProfileProvider
        }

        #[expect(clippy::unused_self, reason = "Follow pattern")]
        pub(crate) fn settings_provider(&self) -> BackupSettingsProvider {
            BackupSettingsProvider {
                blocked_identities: vec![
                    ThreemaId::try_from("BLOCKYOU").expect("Should be a valid Threema ID"),
                ],
                excluded_from_sync_identities: vec![
                    ThreemaId::try_from("EXCLUDED").expect("Should be a valid Threema ID"),
                ],
            }
        }

        pub(crate) fn contact_provider(&self) -> BackupContactProvider {
            BackupContactProvider {
                user_identity: self.user_identity,
                random_number_generator: Arc::clone(&self.random_number_generator),
                contacts: Arc::clone(&self.contacts),
            }
        }

        pub(crate) fn group_provider(&self) -> BackupGroupProvider {
            BackupGroupProvider {
                random_number_generator: Arc::clone(&self.random_number_generator),
                groups: Arc::clone(&self.groups),
            }
        }

        pub(crate) fn distribution_list_provider(&self) -> BackupDistributionListProvider {
            BackupDistributionListProvider {
                random_number_generator: Arc::clone(&self.random_number_generator),
                distribution_lists: Arc::clone(&self.distribution_lists),
            }
        }

        pub(crate) fn csp_nonce_provider(&self) -> BackupCspNonceProvider {
            BackupCspNonceProvider {
                total_number_of_nonces: self.parameters.csp_nonces,
            }
        }

        pub(crate) fn conversation_provider(&self) -> BackupConversationProvider {
            BackupConversationProvider {
                random_number_generator: Arc::clone(&self.random_number_generator),
                user_identity: self.user_identity,
                contacts: Arc::clone(&self.contacts),
                distribution_lists: Arc::clone(&self.distribution_lists),
                groups: Arc::clone(&self.groups),
                total_number_of_contact_messages: self.parameters.contact_messages,
                total_number_of_distribution_list_messages: self.parameters.distribution_list_messages,
                total_number_of_group_messages: self.parameters.group_messages,
            }
        }

        pub(crate) fn poll_provider(&self) -> BackupPollProvider {
            BackupPollProvider {
                random_number_generator: Arc::clone(&self.random_number_generator),
                user_identity: self.user_identity,
                contacts: Arc::clone(&self.contacts),
                groups: Arc::clone(&self.groups),
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

    /// The path of to where the backup should be written at.
    #[arg(short, long)]
    path: path::PathBuf,

    /// Password used to secure the backup.
    #[arg(long)]
    password: Option<String>,

    /// Turn on debugging information.
    /// Use -v -vv to control log level.
    #[arg(short, action = clap::ArgAction::Count)]
    verbose: u8,
}

struct FileWriter {
    file: fs::File,
}
impl FileWriter {
    fn new(path: path::PathBuf) -> anyhow::Result<Self> {
        info!(?path, "Create file");
        Ok(Self {
            // note: don't use 'append' option as it would overrule the seek position.
            file: fs::OpenOptions::new().create_new(true).write(true).open(path)?,
        })
    }

    #[tracing::instrument(
        skip_all,
        fields(data_length = chunk.len())
       )]
    fn append(&mut self, chunk: &[u8]) -> anyhow::Result<()> {
        debug!("Append to file");
        let _ = self.file.seek(io::SeekFrom::End(0))?;
        self.file.write_all(chunk)?;
        Ok(())
    }

    #[tracing::instrument(skip_all, fields(offset, data_length=data.len()))]
    fn write_at(&mut self, offset: usize, data: &[u8]) -> anyhow::Result<()> {
        debug!("Write at specific position");
        let _ = self.file.seek(io::SeekFrom::Start(offset as u64))?;
        self.file.write_all(data)?;
        let _ = self.file.seek(io::SeekFrom::End(0))?;

        Ok(())
    }

    fn handle(&mut self, instruction: LocalWriteInstruction) -> anyhow::Result<()> {
        match instruction {
            LocalWriteInstruction::Append(data) => self.append(&data)?,
            LocalWriteInstruction::WriteAt { offset, data } => self.write_at(offset, &data)?,
        }

        Ok(())
    }

    fn file_size(&self) -> anyhow::Result<u64> {
        Ok(self.file.metadata()?.len())
    }
}

struct Backup {
    path: path::PathBuf,
    user_identity: ThreemaId,
    password: DataBackupPassword,
}
impl fmt::Debug for Backup {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("Backup")
            .field("path", &self.path)
            .field("user_identity", &self.user_identity)
            .field("password", &self.password.0)
            .finish()
    }
}

struct ExampleBackupCreator {
    password: DataBackupPassword,
    user_identity: ThreemaId,
    task: BackupCreateTask,
    file_writer: FileWriter,
    path: path::PathBuf,
}

impl ExampleBackupCreator {
    fn new(
        parameters: BackupCreateParameters,
        path: &path::Path,
        password: DataBackupPassword,
    ) -> anyhow::Result<Self> {
        let (database, identity_data) = BackupDataProvider::new(parameters)?;
        let user_identity = identity_data.user_identity;
        let (task, filename) = {
            let context = BackupCreateContextInit {
                password: password.clone(),
                identity_data,
                user_profile: Arc::new(Mutex::new(database.user_profile_provider())),
                contacts: Arc::new(Mutex::new(database.contact_provider())),
                groups: Arc::new(Mutex::new(database.group_provider())),
                distribution_lists: Arc::new(Mutex::new(database.distribution_list_provider())),
                conversations: Arc::new(Mutex::new(database.conversation_provider())),
                csp_nonces: Arc::new(Mutex::new(database.csp_nonce_provider())),
                settings: Arc::new(Mutex::new(database.settings_provider())),
                polls: Arc::new(Mutex::new(database.poll_provider())),
            };
            BackupCreateTask::new(context)?
        };

        let file_writer = FileWriter::new(path.join(filename.0))?;

        Ok(Self {
            password,
            user_identity,
            task,
            file_writer,
            path: path.to_path_buf(),
        })
    }

    fn run(mut self) -> anyhow::Result<Backup> {
        info!("Creating backup");
        loop {
            match self.task.poll()? {
                BackupCreateLoop::Instruction(instruction) => {
                    debug!(state_update=?instruction.state_update);
                    match instruction.write_instruction {
                        Some(WriteInstruction::Local(instruction)) => self.file_writer.handle(instruction)?,
                        Some(WriteInstruction::Remote) => {
                            bail!("Mock file reader can only handle local write instructions")
                        },
                        None => {},
                    }
                },

                BackupCreateLoop::Done(written_bytes) => {
                    if self.file_writer.file_size()? != written_bytes.0 as u64 {
                        bail!(
                            "Mismatch between expected {:?} and actual number {:?} of written bytes",
                            self.file_writer.file_size()?,
                            written_bytes.0
                        );
                    }

                    let backup = Backup {
                        path: self.path,
                        user_identity: self.user_identity,
                        password: self.password,
                    };
                    info!(?backup, "Successfully created backup");
                    return Ok(backup);
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

    let password = arguments
        .password
        .unwrap_or_else(|| DataBackupPassword::random().0);
    let _ =
        ExampleBackupCreator::new(arguments.config, &arguments.path, DataBackupPassword(password))?.run()?;
    Ok(())
}

#[test]
fn verify_cli() {
    use clap::CommandFactory;
    DataBackupCommand::command().debug_assert();
}
