//! Backup round-trip tests.
//!
//! Drives a full `DataBackupCreateTask` → in-memory buffer → `DataBackupRestoreTask` cycle using minimal
//! in-memory provider implementations.
#![allow(clippy::arithmetic_side_effects, reason = "Test code with controlled inputs")]
#![allow(clippy::cast_possible_truncation, reason = "Test code with controlled inputs")]

use std::collections::{HashMap, HashSet};

use assert_matches::assert_matches;
use derive_builder::Builder;
use rstest::rstest;

use super::{minimal_contact, minimal_distribution_list, minimal_group};
use crate::{
    cli::provider::{InMemoryDb, InMemoryDbInit},
    common::{
        ChatServerGroup, ConversationId, DistributionListId, GroupIdentity, HashedNonce, MessageId,
        MessageOverrides, MessageOverridesDeliveryReceiptPolicy, ThreemaId,
        keys::{ClientKey, PublicKey},
    },
    data_backup::{
        DataBackupRestoreError,
        task::{
            create::{
                DataBackupCreateInit, DataBackupCreateLocalWriteInstruction, DataBackupCreateLoop,
                DataBackupCreateTask, DataBackupCreateWriteInstruction,
            },
            restore::{
                DataBackupRestoreLocalReadInstruction, DataBackupRestoreLoop,
                DataBackupRestoreReadInstruction, DataBackupRestoreReadResponse, DataBackupRestoreResponse,
                DataBackupRestoreStateUpdate, DataBackupRestoreTask,
            },
        },
    },
    model::{
        contact::Contact,
        distribution_list::DistributionList,
        group::GroupWithProfilePicture,
        message::{
            DeletedMessageState, EmojiReaction, IncomingMessageDirection, LocationMessageState,
            MessageDirection, MessageReaction, MessageStarMarker, MessageState, MessageStateBody,
            MessageStateBodyType, MessageText, MessageTextRevision, OutgoingMessageDirection, PollClose,
            PollOpen, TextMessageState,
        },
        poll::{Poll, PollChoice, PollChoiceId, PollId, PollVote, PollVotes, PollVotesSummary},
        profile::{ProfilePicture, ProfilePictureMediaType},
        settings::Settings,
        user_profile::{
            IdentityData, IdentityLinkEmailAddress, IdentityLinkPhoneNumber, ProfilePictureSharePolicy,
            UserProfile,
        },
    },
    protobuf::{self, d2d_sync::contact as protobuf_contact},
    utils::sync::MutexPoisonPanic as _,
};

// ── Deterministic test identities.
const USER_ID: ThreemaId = ThreemaId::predefined(*b"UUUUUUUU");
const CONTACT_ID_1: ThreemaId = ThreemaId::predefined(*b"AAAAAAAA");
const CONTACT_ID_2: ThreemaId = ThreemaId::predefined(*b"BBBBBBBB");
const CONTACT_ID_3: ThreemaId = ThreemaId::predefined(*b"CCCCCCCC");

// ── Create task driver.

fn drive_backup_create(init: DataBackupCreateInit) -> Vec<u8> {
    let (mut task, _) = DataBackupCreateTask::new(init);
    let mut buffer: Vec<u8> = Vec::new();
    while let DataBackupCreateLoop::Instruction(instruction) = task.poll().unwrap() {
        if let Some(instruction) = instruction.write_instruction {
            match instruction {
                DataBackupCreateWriteInstruction::Local(DataBackupCreateLocalWriteInstruction::Append(
                    data,
                )) => {
                    buffer.extend_from_slice(&data);
                },
                DataBackupCreateWriteInstruction::Local(DataBackupCreateLocalWriteInstruction::WriteAt {
                    offset,
                    data,
                }) => {
                    let offset = offset.0 as usize;
                    let end = offset + data.len();
                    if end > buffer.len() {
                        buffer.resize(end, 0);
                    }
                    buffer[offset..end].copy_from_slice(&data);
                },
            }
        }
    }
    buffer
}

// Build an in-memory database (from the CLI providers) seeded with the given data.
fn seed_database(init: &TestInit) -> InMemoryDb {
    InMemoryDb::from(InMemoryDbInit {
        user_identity: init.user,
        user_profile: init.user_profile.clone(),
        settings: init.settings.clone(),
        contacts: init.contacts.clone(),
        distribution_lists: init.distribution_lists.clone(),
        groups: init.groups.clone(),
        csp_nonces: init.csp_nonces.clone(),
        polls: init.polls.clone(),
        messages: init.messages.clone(),
    })
}

#[derive(Builder)]
#[builder(pattern = "owned")]
struct TestInit {
    #[builder(default = "USER_ID")]
    user: ThreemaId,

    #[builder(default = "\"test-pass\".to_owned()")]
    password: String,

    #[builder(default = "UserProfile::default()")]
    user_profile: UserProfile,

    #[builder(default = "Settings::default()")]
    settings: Settings,

    #[builder(default = "Vec::new()")]
    contacts: Vec<Contact>,

    #[builder(default = "Vec::new()")]
    groups: Vec<GroupWithProfilePicture>,

    #[builder(default = "Vec::new()")]
    distribution_lists: Vec<DistributionList>,

    #[builder(default = "Vec::new()")]
    csp_nonces: Vec<HashedNonce>,

    #[builder(default = "Vec::new()")]
    polls: Vec<Poll>,

    #[builder(default = "Vec::new()")]
    messages: Vec<MessageState>,
}
impl TestInitBuilder {
    fn with_contacts(self, contacts: Vec<Contact>) -> Self {
        self.contacts(contacts)
    }

    fn with_groups(self, groups: Vec<GroupWithProfilePicture>) -> Self {
        self.groups(groups)
    }

    fn with_distribution_lists(self, lists: Vec<DistributionList>) -> Self {
        self.distribution_lists(lists)
    }

    fn with_nonces(self, nonces: Vec<HashedNonce>) -> Self {
        self.csp_nonces(nonces)
    }

    fn with_polls(self, polls: Vec<Poll>) -> Self {
        self.polls(polls)
    }

    fn with_messages(self, messages: Vec<MessageState>) -> Self {
        self.messages(messages)
    }

    // Build the create context and return the backing database so tests can compare its providers
    // against the restored ones.
    fn build_init(self) -> (DataBackupCreateInit, String, InMemoryDb) {
        let init = self.build().unwrap();
        let mut database = seed_database(&init);
        let context = DataBackupCreateInit {
            password: init.password.clone(),
            identity_data: IdentityData {
                user_identity: init.user,
                client_key: ClientKey::random(),
                csp_server_group: ChatServerGroup::try_from("csp").unwrap(),
            },
            providers: database.data_backup_providers(),
        };
        (context, init.password, database)
    }

    fn full_stack_data() -> Self {
        let poll_id = PollId(99);

        Self::default()
            .user(USER_ID)
            .user_profile(UserProfile {
                nickname: "Alice".to_owned(),
                profile_picture: Some(ProfilePicture {
                    media_type: ProfilePictureMediaType::Jpeg,
                    data: vec![0xff_u8; 16],
                }),
                profile_picture_share_policy: ProfilePictureSharePolicy::AllowList(
                    [CONTACT_ID_1].into_iter().collect(),
                ),
                linked_phone_number: Some(IdentityLinkPhoneNumber::PhoneNumber("41791234567".to_owned())),
                linked_email_address: Some(IdentityLinkEmailAddress::EmailAddress(
                    "user@example.com".to_owned(),
                )),
                work_availability_status: Some(crate::work::properties::WorkAvailabilityStatus::Busy(
                    "working".to_owned(),
                )),
            })
            .settings(Settings {
                blocked_identities: vec![CONTACT_ID_2],
                exclude_from_sync_identities: vec![CONTACT_ID_1],
                ..Settings::default()
            })
            .with_contacts(vec![
                Contact {
                    first_name: "Bob".to_owned(),
                    ..minimal_contact(
                        CONTACT_ID_1,
                        PublicKey::from_hex(
                            "0101010101010101010101010101010101010101010101010101010101010101",
                        )
                        .unwrap(),
                    )
                },
                Contact {
                    acquaintance_level: protobuf_contact::AcquaintanceLevel::GroupOrDeleted,
                    ..minimal_contact(
                        CONTACT_ID_2,
                        PublicKey::from_hex(
                            "0202020202020202020202020202020202020202020202020202020202020202",
                        )
                        .unwrap(),
                    )
                },
            ])
            .with_groups(vec![
                GroupWithProfilePicture {
                    group: minimal_group(USER_ID, 42, [CONTACT_ID_1].into_iter().collect()),
                    profile_picture: Some(ProfilePicture {
                        media_type: ProfilePictureMediaType::Jpeg,
                        data: vec![0xaa_u8; 32],
                    }),
                },
                GroupWithProfilePicture {
                    group: minimal_group(CONTACT_ID_2, 41, [CONTACT_ID_1].into_iter().collect()),
                    profile_picture: Some(ProfilePicture {
                        media_type: ProfilePictureMediaType::Jpeg,
                        data: vec![0xaa_u8; 32],
                    }),
                },
            ])
            .with_distribution_lists(vec![minimal_distribution_list(
                7,
                [CONTACT_ID_1, CONTACT_ID_2].into_iter().collect(),
            )])
            .with_nonces(vec![
                HashedNonce([0x01; HashedNonce::LENGTH]),
                HashedNonce([0x02; HashedNonce::LENGTH]),
            ])
            .with_polls(vec![Poll {
                id: poll_id,
                conversation: ConversationId::Group(GroupIdentity {
                    group_id: 42,
                    creator_identity: USER_ID,
                }),
                creator_identity: USER_ID,
                created_at: 1_000_000,
                state: protobuf::data_backup::poll::PollState::Open,
                description: "Full stack poll".to_owned(),
                answer_type: protobuf::data_backup::poll::PollAnswerType::MultipleChoice,
                announce_type: protobuf::data_backup::poll::PollAnnounceType::Everyone,
                display_mode: protobuf::data_backup::poll::PollDisplayMode::Summary,
                choices: vec![
                    PollChoice {
                        id: PollChoiceId(0),
                        description: "Yes".to_owned(),
                    },
                    PollChoice {
                        id: PollChoiceId(1),
                        description: "No".to_owned(),
                    },
                ],
                votes: PollVotes::Summary(PollVotesSummary {
                    summary: [(PollChoiceId(0), 3), (PollChoiceId(1), 1)].into_iter().collect(),
                    user_choices: HashSet::from([PollChoiceId(1)]),
                }),
            }])
            .with_messages(vec![
                MessageState {
                    conversation_id: ConversationId::Contact(CONTACT_ID_1),
                    creator_identity: USER_ID,
                    message_id: MessageId(1),
                    created_at: 2_000_000,
                    direction: MessageDirection::Outgoing(OutgoingMessageDirection {
                        sent_at: Some(2_000_001),
                        delivered_at: Some(2_000_002),
                    }),
                    read_at: Some(2_000_003),
                    star_marker: MessageStarMarker::Star,
                    reactions: vec![MessageReaction {
                        creator_identity: CONTACT_ID_1,
                        created_at: 2_000_004,
                        emoji: EmojiReaction {
                            codepoint: "\u{1f44d}".to_owned(),
                        },
                    }],
                    body: MessageStateBody::Text(TextMessageState {
                        original: MessageText {
                            text: "Hello".to_owned(),
                        },
                        revisions: vec![MessageTextRevision {
                            created_at: 2_000_005,
                            message: MessageText {
                                text: "Hello (edited)".to_owned(),
                            },
                        }],
                    }),
                },
                MessageState {
                    conversation_id: ConversationId::Contact(CONTACT_ID_1),
                    creator_identity: CONTACT_ID_1,
                    message_id: MessageId(2),
                    created_at: 2_000_010,
                    direction: MessageDirection::Incoming(IncomingMessageDirection {
                        received_at: 2_000_011,
                        overrides: MessageOverrides::default(),
                    }),
                    read_at: None,
                    star_marker: MessageStarMarker::None,
                    reactions: vec![],
                    body: MessageStateBody::Location(LocationMessageState {
                        latitude: 47.3769,
                        longitude: 8.5417,
                        accuracy_m: Some(10_f64),
                        name: "Zurich".to_owned(),
                        address: "Bahnhofstrasse 1".to_owned(),
                    }),
                },
                MessageState {
                    conversation_id: ConversationId::Contact(CONTACT_ID_1),
                    creator_identity: CONTACT_ID_1,
                    message_id: MessageId(3),
                    created_at: 2_000_015,
                    direction: MessageDirection::Incoming(IncomingMessageDirection {
                        received_at: 2_000_016,
                        overrides: MessageOverrides {
                            delivery_receipt_policy: MessageOverridesDeliveryReceiptPolicy::DontSend,
                        },
                    }),
                    read_at: None,
                    star_marker: MessageStarMarker::None,
                    reactions: vec![],
                    body: MessageStateBody::Text(TextMessageState {
                        original: MessageText {
                            text: "Don't send delivery receipts to gateway!".to_owned(),
                        },
                        revisions: vec![],
                    }),
                },
                MessageState {
                    conversation_id: ConversationId::Group(GroupIdentity {
                        group_id: 42,
                        creator_identity: USER_ID,
                    }),
                    creator_identity: USER_ID,
                    message_id: MessageId(4),
                    created_at: 2_000_020,
                    direction: MessageDirection::Outgoing(OutgoingMessageDirection {
                        sent_at: Some(2_000_021),
                        delivered_at: None,
                    }),
                    read_at: None,
                    star_marker: MessageStarMarker::None,
                    reactions: vec![],
                    body: MessageStateBody::PollOpen(PollOpen { id: poll_id }),
                },
                MessageState {
                    conversation_id: ConversationId::Group(GroupIdentity {
                        group_id: 42,
                        creator_identity: USER_ID,
                    }),
                    creator_identity: USER_ID,
                    message_id: MessageId(5),
                    created_at: 2_000_030,
                    direction: MessageDirection::Outgoing(OutgoingMessageDirection {
                        sent_at: Some(2_000_031),
                        delivered_at: None,
                    }),
                    read_at: None,
                    star_marker: MessageStarMarker::None,
                    reactions: vec![],
                    body: MessageStateBody::PollClose(PollClose { id: poll_id }),
                },
                MessageState {
                    conversation_id: ConversationId::DistributionList(DistributionListId(7)),
                    creator_identity: USER_ID,
                    message_id: MessageId(6),
                    created_at: 2_000_040,
                    direction: MessageDirection::Outgoing(OutgoingMessageDirection {
                        sent_at: Some(2_000_041),
                        delivered_at: None,
                    }),
                    read_at: None,
                    star_marker: MessageStarMarker::None,
                    reactions: vec![],
                    body: MessageStateBody::Deleted(DeletedMessageState {
                        previous_message_type: MessageStateBodyType::Text,
                        deleted_at: 2_000_042,
                    }),
                },
            ])
    }
}

// ── Restore task driver.

fn drive_backup_restore(buffer: &[u8], password: String) -> Result<InMemoryDb, DataBackupRestoreError> {
    // Restore into a single in-memory database. Providers are created lazily when the task
    // signals via `identity_data`, matching the example's approach.
    let mut database = None;
    let mut task = DataBackupRestoreTask::new(password);
    loop {
        match task.poll()? {
            DataBackupRestoreLoop::Done(()) => break,
            DataBackupRestoreLoop::Instruction(instruction) => {
                // Handle any identity data.
                let providers = instruction.identity_data.map(|identity_data| {
                    let mut initialized_database = InMemoryDb::new(identity_data.user_identity);
                    let providers = initialized_database.data_backup_providers();
                    assert!(database.replace(initialized_database).is_none());
                    providers
                });

                // Handle any read instruction.
                let read_response = match instruction.read_instruction {
                    Some(DataBackupRestoreReadInstruction::Local(
                        DataBackupRestoreLocalReadInstruction { offset, length },
                    )) => {
                        let start = offset.0 as usize;
                        let end = start + length as usize;
                        let chunk = buffer[start..end].to_vec();
                        Some(DataBackupRestoreReadResponse { offset, chunk })
                    },
                    None => None,
                };

                // Provide response.
                task.response(DataBackupRestoreResponse {
                    providers,
                    read_response,
                })?;
            },
        }
    }

    Ok(database.unwrap())
}

#[rstest]
#[case::empty(TestInitBuilder::default().user(USER_ID))]
#[case::full_stack(TestInitBuilder::full_stack_data())]
fn roundtrip(#[case] init_builder: TestInitBuilder) {
    let (init, password, create_database) = init_builder.build_init();

    let buffer = drive_backup_create(init);
    assert!(!buffer.is_empty(), "backup buffer must not be empty");

    let restore_database = drive_backup_restore(&buffer, password).unwrap();
    create_database.assert_eq(&restore_database);
}

#[test]
fn duplicate_public_key_contacts_are_filtered() {
    let shared_key =
        PublicKey::from_hex("2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a").unwrap();
    let (init, password, create_database) = TestInitBuilder::default()
        .with_contacts(vec![
            minimal_contact(CONTACT_ID_1, shared_key),
            minimal_contact(CONTACT_ID_2, shared_key),
            minimal_contact(
                CONTACT_ID_3,
                PublicKey::from_hex("6363636363636363636363636363636363636363636363636363636363636363")
                    .unwrap(),
            ),
        ])
        .build_init();

    let buffer = drive_backup_create(init);
    let restore_database = drive_backup_restore(&buffer, password).unwrap();

    let create_contacts = create_database.storage.lock_unwrap().contacts.len();
    let restore_contacts = restore_database.storage.lock_unwrap().contacts.len();

    // Create side stores all 3 contacts, restore side should have 2 (one duplicate filtered).
    assert_eq!(create_contacts, 3);
    assert_eq!(restore_contacts, 2);

    // CONTACT_ID_3 has a unique key and must always be present.
    let restored_keys: HashSet<ThreemaId> = restore_database
        .storage
        .lock_unwrap()
        .contacts
        .keys()
        .copied()
        .collect();
    assert!(
        restored_keys.contains(&CONTACT_ID_3),
        "CONTACT_ID_3 with unique key must be present"
    );

    // Exactly one of CONTACT_ID_1 or CONTACT_ID_2 is kept (whichever the HashMap iterator
    // yields first). Both share the same public key, so the accountant drops the second one.
    let duplicate_kept = restored_keys.contains(&CONTACT_ID_1) ^ restored_keys.contains(&CONTACT_ID_2);
    assert!(
        duplicate_kept,
        "exactly one of the duplicate-key contacts should be kept"
    );
}

// ── Accountant filtering tests ──

#[test]
fn group_with_unknown_creator_is_skipped() {
    let unknown_creator = ThreemaId::predefined(*b"ZZZZZZZZ");
    let group = minimal_group(unknown_creator, 1, HashSet::new());
    let (init, password, create_database) = TestInitBuilder::default()
        .with_groups(vec![GroupWithProfilePicture {
            group,
            profile_picture: None,
        }])
        .build_init();

    let buffer = drive_backup_create(init);
    let restore_database = drive_backup_restore(&buffer, password).unwrap();

    let create_groups = create_database.storage.lock_unwrap().groups.len();
    let restore_groups = restore_database.storage.lock_unwrap().groups.len();

    assert_eq!(create_groups, 1);
    assert_eq!(restore_groups, 0);
}

#[test]
fn group_with_unknown_members_has_members_removed() {
    let known_contact = CONTACT_ID_1;
    let unknown_member = ThreemaId::predefined(*b"ZZZZZZZZ");
    let members = [known_contact, unknown_member].into_iter().collect();
    let group = minimal_group(USER_ID, 1, members);
    let (init, password, create_database) = TestInitBuilder::default()
        .with_contacts(vec![minimal_contact(
            known_contact,
            PublicKey::from_hex("0101010101010101010101010101010101010101010101010101010101010101").unwrap(),
        )])
        .with_groups(vec![GroupWithProfilePicture {
            group,
            profile_picture: None,
        }])
        .build_init();

    let buffer = drive_backup_create(init);
    let restore_database = drive_backup_restore(&buffer, password).unwrap();

    let create_groups = create_database.storage.lock_unwrap().groups.len();
    let restore_groups = restore_database.storage.lock_unwrap().groups.len();

    assert_eq!(create_groups, 1);
    assert_eq!(restore_groups, 1);

    let storage = restore_database.storage.lock_unwrap();
    let restored_group = storage.groups.values().next().unwrap();
    assert!(restored_group.group.members.contains(&known_contact));
    assert!(!restored_group.group.members.contains(&unknown_member));
}

#[test]
fn distribution_list_with_unknown_members_has_members_removed() {
    let known_contact = CONTACT_ID_1;
    let unknown_member = ThreemaId::predefined(*b"ZZZZZZZZ");
    let members = [known_contact, unknown_member].into_iter().collect();
    let distribution_list = minimal_distribution_list(1, members);
    let (init, password, create_database) = TestInitBuilder::default()
        .with_contacts(vec![minimal_contact(
            known_contact,
            PublicKey::from_hex("0101010101010101010101010101010101010101010101010101010101010101").unwrap(),
        )])
        .with_distribution_lists(vec![distribution_list])
        .build_init();

    let buffer = drive_backup_create(init);
    let restore_database = drive_backup_restore(&buffer, password).unwrap();

    let create_distribution_lists = create_database.storage.lock_unwrap().distribution_lists.len();
    let restore_distribution_lists = restore_database.storage.lock_unwrap().distribution_lists.len();

    assert_eq!(create_distribution_lists, 1);
    assert_eq!(restore_distribution_lists, 1);

    let storage = restore_database.storage.lock_unwrap();
    let restored_distribution_list = storage.distribution_lists.values().next().unwrap();
    assert!(restored_distribution_list.members.contains(&known_contact));
    assert!(!restored_distribution_list.members.contains(&unknown_member));
}

#[derive(Clone, Copy)]
enum MessageScenario {
    Outgoing,
    OutgoingWithDelivery,
    Incoming,
    Starred,
    WithReactions,
    WithRevisions,
    Read,
}

struct ConversationSetup {
    conversation_id: ConversationId,
    other_identity: ThreemaId,
    contacts: Vec<Contact>,
    groups: Vec<GroupWithProfilePicture>,
    distribution_lists: Vec<DistributionList>,
}

fn contact_conversation_setup() -> ConversationSetup {
    let contact = CONTACT_ID_1;
    ConversationSetup {
        conversation_id: ConversationId::Contact(contact),
        other_identity: contact,
        contacts: vec![minimal_contact(
            contact,
            PublicKey::from_hex("0101010101010101010101010101010101010101010101010101010101010101").unwrap(),
        )],
        groups: vec![],
        distribution_lists: vec![],
    }
}

fn own_group_conversation_setup() -> ConversationSetup {
    let contact = CONTACT_ID_1;
    let group = minimal_group(USER_ID, 1, [contact].into_iter().collect());
    ConversationSetup {
        conversation_id: ConversationId::Group(group.identity),
        other_identity: contact,
        contacts: vec![minimal_contact(
            contact,
            PublicKey::from_hex("0101010101010101010101010101010101010101010101010101010101010101").unwrap(),
        )],
        groups: vec![GroupWithProfilePicture {
            group,
            profile_picture: None,
        }],
        distribution_lists: vec![],
    }
}

fn foreign_group_conversation_setup() -> ConversationSetup {
    let creator = CONTACT_ID_1;
    let member = CONTACT_ID_2;
    let group = minimal_group(creator, 1, [member].into_iter().collect());
    ConversationSetup {
        conversation_id: ConversationId::Group(group.identity),
        other_identity: creator,
        contacts: vec![
            minimal_contact(
                creator,
                PublicKey::from_hex("0101010101010101010101010101010101010101010101010101010101010101")
                    .unwrap(),
            ),
            minimal_contact(
                member,
                PublicKey::from_hex("0202020202020202020202020202020202020202020202020202020202020202")
                    .unwrap(),
            ),
        ],
        groups: vec![GroupWithProfilePicture {
            group,
            profile_picture: None,
        }],
        distribution_lists: vec![],
    }
}

fn distribution_list_conversation_setup() -> ConversationSetup {
    let contact = CONTACT_ID_1;
    let distribution_list = minimal_distribution_list(1, [contact].into_iter().collect());
    ConversationSetup {
        conversation_id: ConversationId::DistributionList(distribution_list.identity),
        other_identity: contact,
        contacts: vec![minimal_contact(
            contact,
            PublicKey::from_hex("0101010101010101010101010101010101010101010101010101010101010101").unwrap(),
        )],
        groups: vec![],
        distribution_lists: vec![distribution_list],
    }
}

fn build_message_for_scenario(
    user: ThreemaId,
    conversation_id: ConversationId,
    other_identity: ThreemaId,
    scenario: MessageScenario,
) -> MessageState {
    let base = MessageState {
        conversation_id,
        creator_identity: user,
        message_id: MessageId(42),
        created_at: 2_000_000,
        direction: MessageDirection::Outgoing(OutgoingMessageDirection {
            sent_at: Some(2_000_001),
            delivered_at: None,
        }),
        read_at: None,
        star_marker: MessageStarMarker::None,
        reactions: vec![],
        body: MessageStateBody::Text(TextMessageState {
            original: MessageText {
                text: "Hello".to_owned(),
            },
            revisions: vec![],
        }),
    };

    match scenario {
        MessageScenario::Outgoing => base,
        MessageScenario::OutgoingWithDelivery => MessageState {
            direction: MessageDirection::Outgoing(OutgoingMessageDirection {
                sent_at: Some(2_000_001),
                delivered_at: Some(2_000_002),
            }),
            ..base
        },
        MessageScenario::Incoming => MessageState {
            creator_identity: other_identity,
            direction: MessageDirection::Incoming(IncomingMessageDirection {
                received_at: 2_000_001,
                overrides: MessageOverrides::default(),
            }),
            ..base
        },
        MessageScenario::Starred => MessageState {
            star_marker: MessageStarMarker::Star,
            ..base
        },
        MessageScenario::WithReactions => MessageState {
            reactions: vec![MessageReaction {
                creator_identity: other_identity,
                created_at: 2_000_003,
                emoji: EmojiReaction {
                    codepoint: "\u{1f44d}".to_owned(),
                },
            }],
            ..base
        },
        MessageScenario::WithRevisions => MessageState {
            body: MessageStateBody::Text(TextMessageState {
                original: MessageText {
                    text: "Hello".to_owned(),
                },
                revisions: vec![MessageTextRevision {
                    created_at: 2_000_004,
                    message: MessageText {
                        text: "Hello (edited)".to_owned(),
                    },
                }],
            }),
            ..base
        },
        MessageScenario::Read => MessageState {
            read_at: Some(2_000_005),
            ..base
        },
    }
}

#[rstest]
fn roundtrip_messages(
    #[values(
        MessageScenario::Outgoing,
        MessageScenario::OutgoingWithDelivery,
        MessageScenario::Incoming,
        MessageScenario::Starred,
        MessageScenario::WithReactions,
        MessageScenario::WithRevisions,
        MessageScenario::Read
    )]
    scenario: MessageScenario,

    #[values(
        contact_conversation_setup,
        own_group_conversation_setup,
        foreign_group_conversation_setup,
        distribution_list_conversation_setup
    )]
    make_setup: fn() -> ConversationSetup,
) {
    let setup = make_setup();
    let message = build_message_for_scenario(USER_ID, setup.conversation_id, setup.other_identity, scenario);

    let (init, password, create_database) = TestInitBuilder::default()
        .with_contacts(setup.contacts)
        .with_groups(setup.groups)
        .with_distribution_lists(setup.distribution_lists)
        .with_messages(vec![message])
        .build_init();

    let buffer = drive_backup_create(init);
    let restore_database = drive_backup_restore(&buffer, password).unwrap();

    create_database.assert_eq(&restore_database);
}

#[rstest]
#[case::minimal_profile(
    UserProfile {
        nickname: "Alice".to_owned(),
        ..UserProfile::default()
    },
    vec![],
)]
#[case::full_profile(
    UserProfile {
        nickname: "Alice".to_owned(),
        profile_picture: Some(ProfilePicture {
            media_type: ProfilePictureMediaType::Jpeg,
            data: vec![0xff_u8; 16],
        }),
        profile_picture_share_policy: ProfilePictureSharePolicy::AllowList(
            [CONTACT_ID_1].into_iter().collect(),
        ),
        linked_phone_number: Some(IdentityLinkPhoneNumber::PhoneNumber("41791234567".to_owned())),
        linked_email_address: Some(IdentityLinkEmailAddress::EmailAddress(
            "user@example.com".to_owned(),
        )),
        work_availability_status: Some(crate::work::properties::WorkAvailabilityStatus::Busy(
            "working".to_owned(),
        )),
    },
    vec![minimal_contact(
        CONTACT_ID_1,
        PublicKey::from_hex("0101010101010101010101010101010101010101010101010101010101010101").unwrap(),
    )],
)]
#[case::non_existing_contact(
    UserProfile {
        nickname: "Alice".to_owned(),
        profile_picture: Some(ProfilePicture {
            media_type: ProfilePictureMediaType::Jpeg,
            data: vec![0xff_u8; 16],
        }),
        profile_picture_share_policy: ProfilePictureSharePolicy::AllowList(
            [CONTACT_ID_1].into_iter().collect(),
        ),
        linked_phone_number: Some(IdentityLinkPhoneNumber::PhoneNumber("41791234567".to_owned())),
        linked_email_address: Some(IdentityLinkEmailAddress::EmailAddress(
            "user@example.com".to_owned(),
        )),
        work_availability_status: Some(crate::work::properties::WorkAvailabilityStatus::Busy(
            "working".to_owned(),
        )),
    },
    vec![],
)]
fn roundtrip_user_profile(#[case] profile: UserProfile, #[case] contacts: Vec<Contact>) {
    let (init, password, create_database) = TestInitBuilder::default()
        .user_profile(profile)
        .with_contacts(contacts)
        .build_init();

    let buffer = drive_backup_create(init);
    let restore_database = drive_backup_restore(&buffer, password).unwrap();

    create_database.assert_eq(&restore_database);
}

#[rstest]
#[case::no_blocked_identities(Settings {
    blocked_identities: vec![],
    ..Settings::default()
})]
#[case::with_blocked_identities(Settings {
    blocked_identities: vec![CONTACT_ID_1, CONTACT_ID_2],
    ..Settings::default()
})]
#[case::no_sync_exclusion(Settings {
    exclude_from_sync_identities: vec![],
    ..Settings::default()
})]
#[case::with_sync_exclusion(Settings {
    exclude_from_sync_identities: vec![CONTACT_ID_1, CONTACT_ID_2],
    ..Settings::default()
})]
fn roundtrip_settings(#[case] settings: Settings) {
    let (init, password, create_database) = TestInitBuilder::default().settings(settings).build_init();

    let buffer = drive_backup_create(init);
    let restore_database = drive_backup_restore(&buffer, password).unwrap();

    create_database.assert_eq(&restore_database);
}

// Produce a distinct nonce for the given index (used to generate large, unique nonce sets).
fn indexed_nonce(index: u32) -> HashedNonce {
    let index = index.to_le_bytes();
    let mut bytes = [0_u8; HashedNonce::LENGTH];
    bytes[..index.len()].copy_from_slice(&index);
    HashedNonce(bytes)
}

#[rstest]
#[case::single(vec![HashedNonce([0x01; HashedNonce::LENGTH])])]
#[case::multiple(
    vec![
        HashedNonce([0x01; HashedNonce::LENGTH]),
        HashedNonce([0x02; HashedNonce::LENGTH]),
        HashedNonce([0x03; HashedNonce::LENGTH]),
    ]
)]
// Exceed the CLI provider's `NONCES_PER_BATCH` (65536) to exercise the multi-batch loop.
#[case::multi_batch((0..70_000_u32).map(indexed_nonce).collect())]
fn roundtrip_csp_nonces(#[case] nonces: Vec<HashedNonce>) {
    let (init, password, create_database) = TestInitBuilder::default().with_nonces(nonces).build_init();

    let buffer = drive_backup_create(init);
    let restore_database = drive_backup_restore(&buffer, password).unwrap();

    create_database.assert_eq(&restore_database);
}

fn test_poll(id: u64) -> Poll {
    Poll {
        id: PollId(id),
        conversation: ConversationId::Contact(CONTACT_ID_1),
        creator_identity: CONTACT_ID_1,
        created_at: 1_000_000,
        state: protobuf::data_backup::poll::PollState::Open,
        description: format!("Poll {id}"),
        answer_type: protobuf::data_backup::poll::PollAnswerType::SingleChoice,
        announce_type: protobuf::data_backup::poll::PollAnnounceType::CreatorOnly,
        display_mode: protobuf::data_backup::poll::PollDisplayMode::List,
        choices: vec![],
        votes: PollVotes::Votes(HashMap::new()),
    }
}

#[rstest]
#[case::single(vec![test_poll(1)])]
#[case::multiple(vec![test_poll(1), test_poll(2), test_poll(3)])]
// Exceed the CLI provider's `POLLS_PER_BATCH` (100) to exercise the multi-batch loop.
#[case::multi_batch((1_u64..=150).map(test_poll).collect())]
fn roundtrip_polls_batch(#[case] polls: Vec<Poll>) {
    let (init, password, create_database) = TestInitBuilder::default()
        .with_contacts(vec![minimal_contact(
            CONTACT_ID_1,
            PublicKey::from_hex("0101010101010101010101010101010101010101010101010101010101010101").unwrap(),
        )])
        .with_polls(polls)
        .build_init();

    let buffer = drive_backup_create(init);
    let restore_database = drive_backup_restore(&buffer, password).unwrap();

    create_database.assert_eq(&restore_database);
}

#[rstest]
#[case::contact((vec![test_poll(1)], vec![]))]
#[case::group({
        let group = minimal_group(USER_ID, 1, [CONTACT_ID_1, CONTACT_ID_2].into_iter().collect());
        (
            vec![Poll {
                conversation: ConversationId::Group(group.identity),
                ..test_poll(1)
            }],
            vec![GroupWithProfilePicture {
                group,
                profile_picture: None,
            }],
        )}
    )]
fn roundtrip_polls_conversation_types(#[case] (polls, groups): (Vec<Poll>, Vec<GroupWithProfilePicture>)) {
    let (init, password, create_database) = TestInitBuilder::default()
        .with_contacts(vec![
            minimal_contact(
                CONTACT_ID_1,
                PublicKey::from_hex("0101010101010101010101010101010101010101010101010101010101010101")
                    .unwrap(),
            ),
            minimal_contact(
                CONTACT_ID_2,
                PublicKey::from_hex("0202020202020202020202020202020202020202020202020202020202020202")
                    .unwrap(),
            ),
        ])
        .with_groups(groups)
        .with_polls(polls)
        .build_init();

    let buffer = drive_backup_create(init);
    let restore_database = drive_backup_restore(&buffer, password).unwrap();

    create_database.assert_eq(&restore_database);
}

#[rstest]
#[case::votes_single_voter(Poll {
        choices: vec![
            PollChoice { id: PollChoiceId(0), description: "Yes".to_owned() },
            PollChoice { id: PollChoiceId(1), description: "No".to_owned() },
        ],
        votes: PollVotes::Votes(
            [(CONTACT_ID_1, PollVote {
                choices: [PollChoiceId(0)].into_iter().collect(),
                created_at: 2_000_000,
                modified_at: None,
            })].into_iter().collect(),
        ),
        ..test_poll(1)
    })]
#[case::votes_multiple_voters(Poll {
        choices: vec![
            PollChoice { id: PollChoiceId(0), description: "Option A".to_owned() },
            PollChoice { id: PollChoiceId(1), description: "Option B".to_owned() },
            PollChoice { id: PollChoiceId(2), description: "Option C".to_owned() },
        ],
        votes: PollVotes::Votes(
            [
                (CONTACT_ID_1, PollVote {
                    choices: [PollChoiceId(0)].into_iter().collect(),
                    created_at: 2_000_000,
                    modified_at: None,
                }),
                (CONTACT_ID_2, PollVote {
                    choices: [PollChoiceId(1), PollChoiceId(2)].into_iter().collect(),
                    created_at: 2_000_001,
                    modified_at: Some(2_000_002),
                }),
            ].into_iter().collect(),
        ),
        answer_type: protobuf::data_backup::poll::PollAnswerType::MultipleChoice,
        ..test_poll(1)
    })]
#[case::summary(Poll {
        choices: vec![
            PollChoice { id: PollChoiceId(0), description: "Yes".to_owned() },
            PollChoice { id: PollChoiceId(1), description: "No".to_owned() },
            PollChoice { id: PollChoiceId(2), description: "Maybe".to_owned() },
        ],
        votes: PollVotes::Summary(
            PollVotesSummary {
                summary: [
                    (PollChoiceId(0), 5),
                    (PollChoiceId(1), 2),
                    (PollChoiceId(2), 1)]
                    .into_iter().collect(),
                user_choices: HashSet::from([PollChoiceId(0), PollChoiceId(2)])
            },
        ),
        display_mode: protobuf::data_backup::poll::PollDisplayMode::Summary,
        state: protobuf::data_backup::poll::PollState::Closed,
        ..test_poll(1)
    })]
fn roundtrip_poll_votes(#[case] poll: Poll) {
    let (init, password, create_database) = TestInitBuilder::default()
        .with_contacts(vec![
            minimal_contact(
                CONTACT_ID_1,
                PublicKey::from_hex("0101010101010101010101010101010101010101010101010101010101010101")
                    .unwrap(),
            ),
            minimal_contact(
                CONTACT_ID_2,
                PublicKey::from_hex("0202020202020202020202020202020202020202020202020202020202020202")
                    .unwrap(),
            ),
        ])
        .with_polls(vec![poll])
        .build_init();

    let buffer = drive_backup_create(init);
    let restore_database = drive_backup_restore(&buffer, password).unwrap();

    create_database.assert_eq(&restore_database);
}

fn generate_public_key(index: u32) -> PublicKey {
    // Generate a unique public key by spreading the index across all 32 bytes.
    let mut bytes = [0_u8; PublicKey::LENGTH];
    bytes[..4].copy_from_slice(&index.to_le_bytes());
    bytes[4..8].copy_from_slice(&(index.wrapping_mul(1664525)).to_le_bytes());
    bytes[8..12].copy_from_slice(&(index.wrapping_mul(2147483647)).to_le_bytes());
    for (byte_index, byte) in bytes.iter_mut().enumerate() {
        *byte = byte.wrapping_add(byte_index as u8).wrapping_mul(31);
    }
    PublicKey::from(bytes)
}

#[rstest]
#[case::messages({
    let messages: Vec<MessageState> = (0_u64..10_000)
        .map(|index| MessageState {
            conversation_id: ConversationId::Contact(CONTACT_ID_1),
            creator_identity: USER_ID,
            message_id: MessageId(index),
            created_at: 2_000_000 + index,
            direction: MessageDirection::Outgoing(OutgoingMessageDirection {
                sent_at: Some(2_000_001 + index),
                delivered_at: None,
            }),
            read_at: None,
            star_marker: MessageStarMarker::None,
            reactions: vec![],
            body: MessageStateBody::Text(TextMessageState {
                original: MessageText {
                    text: format!("Message number {index} with some padding text to increase size"),
                },
                revisions: vec![],
            }),
        })
        .collect();
    TestInitBuilder::default()
        .with_contacts(vec![minimal_contact(
            CONTACT_ID_1,
            PublicKey::from_hex("0101010101010101010101010101010101010101010101010101010101010101")
                .unwrap(),
        )])
        .with_messages(messages)
})]
#[case::nonces(
    TestInitBuilder::default()
    .with_nonces((0..70_000_u32).map(indexed_nonce).collect())
)]
#[case::contacts(
    TestInitBuilder::default()
        .with_contacts((0..1_000_u32)
            .map(|index|
                minimal_contact(
                    ThreemaId::try_from(format!("{index:08X}").as_str()).unwrap(),
                    generate_public_key(index)))
            .collect())
)]
#[case::groups({
    let contacts: Vec<ThreemaId> = (0..10_u32)
        .map(|index| ThreemaId::try_from(format!("{index:08X}").as_str()).unwrap())
        .collect();
    TestInitBuilder::default()
        .with_contacts(contacts.iter().copied().enumerate().map(|(contact_index, id)| {
            minimal_contact(id, generate_public_key(contact_index as u32))
        }).collect())
        .with_groups((0..500_u64)
            .map(|group_id| GroupWithProfilePicture {
                group: minimal_group(
                    USER_ID,
                    group_id,
                    contacts.iter().copied().take((group_id.rem_euclid(5)) as usize + 1).collect(),
                ),
                profile_picture: None,
            })
            .collect())
})]
#[case::distribution_lists({
    let contacts: Vec<ThreemaId> = (0..10_u32)
        .map(|index| ThreemaId::try_from(format!("{index:08X}").as_str()).unwrap())
        .collect();
    TestInitBuilder::default()
        .with_contacts(contacts.iter().copied().enumerate()
            .map(|(contact_index, id)| minimal_contact(
                id,
                generate_public_key(contact_index as u32))).collect())
        .with_distribution_lists((0..500_u64)
            .map(|id| minimal_distribution_list(
                id,
                contacts.iter().copied().take((id.rem_euclid(5)) as usize + 1).collect(),
            ))
            .collect())
})]
fn roundtrip_large(#[case] test_builder: TestInitBuilder) {
    let (init, password, create_database) = test_builder.build_init();

    let buffer = drive_backup_create(init);
    let restore_database = drive_backup_restore(&buffer, password).unwrap();

    create_database.assert_eq(&restore_database);
}

#[test]
fn restore_state_update_order() {
    let (init, password, _create_database) = TestInitBuilder::default()
        .with_contacts(vec![minimal_contact(
            CONTACT_ID_1,
            PublicKey::from_hex("0101010101010101010101010101010101010101010101010101010101010101").unwrap(),
        )])
        .with_groups(vec![GroupWithProfilePicture {
            group: minimal_group(USER_ID, 1, [CONTACT_ID_1].into_iter().collect()),
            profile_picture: None,
        }])
        .with_distribution_lists(vec![minimal_distribution_list(
            1,
            [CONTACT_ID_1].into_iter().collect(),
        )])
        .with_nonces(vec![HashedNonce([0x01; HashedNonce::LENGTH])])
        .with_polls(vec![test_poll(1)])
        .with_messages(vec![build_message_for_scenario(
            USER_ID,
            ConversationId::Contact(CONTACT_ID_1),
            CONTACT_ID_1,
            MessageScenario::Outgoing,
        )])
        .build_init();

    let buffer = drive_backup_create(init);

    let expected_order = [
        DataBackupRestoreStateUpdate::UserData,
        DataBackupRestoreStateUpdate::Contacts,
        DataBackupRestoreStateUpdate::DistributionLists,
        DataBackupRestoreStateUpdate::Groups,
        DataBackupRestoreStateUpdate::CspNonces,
        DataBackupRestoreStateUpdate::Polls,
        DataBackupRestoreStateUpdate::Messages,
    ];

    let mut task = DataBackupRestoreTask::new(password);
    let mut observed_updates: Vec<DataBackupRestoreStateUpdate> = Vec::new();

    while let DataBackupRestoreLoop::Instruction(instruction) = task.poll().unwrap() {
        // Handle any identity data.
        let providers = instruction.identity_data.map(|identity_data| {
            let mut database = InMemoryDb::new(identity_data.user_identity);
            database.data_backup_providers()
        });

        // Handle any state update.
        if let Some(state_update) = instruction.state_update {
            observed_updates.push(state_update);
        }

        // Handle any read instruction.
        let read_response = match instruction.read_instruction {
            Some(DataBackupRestoreReadInstruction::Local(DataBackupRestoreLocalReadInstruction {
                offset,
                length,
            })) => {
                let start = offset.0 as usize;
                let end = start + length as usize;
                let chunk = buffer[start..end].to_vec();
                Some(DataBackupRestoreReadResponse { offset, chunk })
            },
            None => None,
        };

        // Provide response.
        task.response(DataBackupRestoreResponse {
            providers,
            read_response,
        })
        .unwrap();
    }

    assert_eq!(
        observed_updates,
        expected_order.to_vec(),
        "state updates should arrive in the expected order"
    );
}

#[test]
fn wrong_password_returns_error() {
    let (init, _, _create_database) = TestInitBuilder::default()
        .password("correct-password".to_owned())
        .build_init();

    let buffer = drive_backup_create(init);

    assert_matches!(
        drive_backup_restore(&buffer, "wrong-password".to_owned()),
        Err(DataBackupRestoreError::DecryptionFailed { .. })
    );
}
