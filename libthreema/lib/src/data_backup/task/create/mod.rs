//! Backup Creation Task.
use core::{fmt, mem, ops::RangeFrom};
use std::sync::{Arc, Mutex, PoisonError};

use educe::Educe;
use libthreema_dependencies::crypto::argon2;
use libthreema_macros::Name;
use tracing::{debug, warn};

use crate::{
    common::{
        ConversationType, DistributionListId, GroupIdentity, ThreemaId,
        keys::{DataBackupPassword, DataBackupRootKey, DataBackupSalt},
        task::TaskLoop,
    },
    data_backup::{
        OverflowError,
        accountant::BackupAccountant,
        codec::BackupEncodingError,
        container::{
            ContactContainer, DistributionListContainer, GroupContainer, HashedCspNonceContainer,
            MessageContainer, PollContainer, UserData, UserDataContainer,
        },
        metadata::{Header, LayoutV1Encrypted, METADATA_LENGTH},
        task::create::{container_writer::ContainerWriter, page_writer::PageWriter},
    },
    model::{
        contact::ContactProvider,
        conversation::ConversationProvider,
        distribution_list::DistributionListProvider,
        group::GroupProvider,
        poll::PollProvider,
        settings::SettingsProvider,
        user_profile::{IdentityData, UserProfileProvider},
    },
    provider::{NonceProvider, ProviderError},
    utils::{
        bytes::{ByteWriter as _, OwnedVecByteWriter},
        debug::{Name as _, debug_slice_length},
    },
};

mod container_writer;
mod page_writer;

/// Cause of an internal error.
#[derive(Clone, Debug, thiserror::Error)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Error), uniffi(flat_error))]
pub enum InternalErrorCause {
    /// Key derivation failed.
    #[error("Key derivation failed: {}", 0.to_string())]
    KeyDerivationFailed(argon2::Error),

    /// Unable to decrypt a struct.
    #[error("Encrypting '{name}' failed")]
    EncryptionFailed {
        /// Name of the struct.
        name: &'static str,
    },

    /// Unable to encode a struct.
    #[error("Encoding '{name}' failed: {source}")]
    EncodingFailed {
        /// Name of the struct.
        name: &'static str,

        /// Error source.
        source: BackupEncodingError,
    },

    /// An overflow occurred.
    #[error("Overflow error: {0}")]
    Overflow(#[from] OverflowError),

    /// Another kind of error occurred.
    #[error("{0}")]
    Other(String),
}
impl<T: Into<String>> From<T> for InternalErrorCause {
    fn from(message: T) -> Self {
        Self::Other(message.into())
    }
}

/// An error occurred during backup creation.
///
/// When encountering an error:
///
/// 1. Let `error` be the provided [`BackupCreateError`].
/// 2. Mark all previously stored data as invalid (e.g. by deleting it).
/// 3. Abort the protocol due to `error`.
#[derive(Clone, Debug, thiserror::Error)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Error), uniffi(flat_error))]
pub enum BackupCreateError {
    /// A foreign function considered infallible returned an error.
    #[cfg(any(test, feature = "uniffi", feature = "cli"))]
    #[error("Infallible function failed in foreign code: {0}")]
    Foreign(String),

    /// Invalid state for the requested operation.
    #[error("Invalid state: {0}")]
    InvalidState(String),

    /// An internal error happened.
    #[error("Internal error: {0}")]
    InternalError(#[from] InternalErrorCause),
}
impl From<ProviderError> for BackupCreateError {
    fn from(error: ProviderError) -> Self {
        match error {
            ProviderError::InvalidParameter(message) => Self::InternalError(message.into()),
            ProviderError::InvalidState(message) => Self::InvalidState(message),
            #[cfg(any(test, feature = "uniffi", feature = "cli"))]
            ProviderError::Foreign(message) => Self::Foreign(message),
        }
    }
}
#[cfg(feature = "uniffi")]
impl From<crate::bindings::uniffi::ConversionError> for BackupCreateError {
    fn from(error: crate::bindings::uniffi::ConversionError) -> Self {
        Self::InvalidState(error.to_string())
    }
}

/// The name of the backup file (in case of a local backup).
#[derive(Clone)]
#[cfg_attr(feature = "uniffi", derive(libthreema_macros::UniffiNewType))]
pub struct Filename(pub String);
impl Filename {
    /// Return UTC Now formatted as "YYYY-MM-DDThh-mm-ss", e.g., `2026-06-02T11-54-33`.
    fn new() -> Self {
        Self(format!(
            "{}-threema.backup",
            chrono::Utc::now().format("%Y-%m-%dT%H-%M-%S")
        ))
    }
}

/// Storage write instruction to execute as part of a [`BackupCreateInstruction`].
///
/// See each variant's steps.
pub enum LocalWriteInstruction {
    /// 1. Append the bytes at the end of the stream.
    Append(Vec<u8>),

    /// 1. Write `data` at `offset` within the stream.
    WriteAt {
        /// The _absolute_ byte offset.
        offset: usize,

        /// The bytes that must be written.
        data: Vec<u8>,
    },
}
// Note: We cannot use educe, see https://github.com/magiclen/educe/issues/34
impl fmt::Debug for LocalWriteInstruction {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Append(data) => formatter
                .debug_tuple("Append")
                .field(&format!("length={}", data.len()))
                .finish(),
            Self::WriteAt { offset, data } => formatter
                .debug_struct("WriteAt")
                .field("offset", offset)
                .field("data", &format!("length={}", data.len()))
                .finish(),
        }
    }
}
impl LocalWriteInstruction {
    /// Maximum number of bytes that can be appended in a single instruction.
    pub(crate) const MAX_APPEND_LENGTH: usize = 10 * 1024 * 1024;
}

/// An instruction of what to do next.
///
/// See each variant's steps.
#[derive(Debug)]
pub enum WriteInstruction {
    /// Apply a local write instruction. See [`LocalWriteInstruction`] for more details.
    Local(LocalWriteInstruction),

    /// TODO(PRD-32): Apply a remote storage operation.
    Remote,
}
impl From<LocalWriteInstruction> for WriteInstruction {
    fn from(instruction: LocalWriteInstruction) -> Self {
        Self::Local(instruction)
    }
}

/// A backup state update to indicate advancing.
///
/// Each variant indicates the current state supplemented with state dependent information.
/// The client may enrich this information with the category's total number of items to indicate the
/// progress to the user.
///
/// State updates can be expected to be in the following order:
///
/// 1. `InitialState`
/// 2. `Contacts`
/// 3. `DistributionLists`
/// 4. `Groups`
/// 5. `CspNonces`
/// 6. `Polls`
/// 7. `Messages`
/// 8. `FinalizeState`
#[derive(Debug)]
pub enum BackupCreateStateUpdate {
    /// The backup is still in the initial state.
    InitialState,

    /// The number of written contacts.
    Contacts(usize),

    /// The number of written distribution lists.
    DistributionLists(usize),

    /// The number of written groups.
    Groups(usize),

    /// The number of written CSP nonces.
    CspNonces(usize),

    /// The number of written polls.
    Polls(usize),

    /// The number of written messages.
    Messages(usize),

    /// The backup is in the finalize state.
    FinalizeState,
}

/// An instruction of what to do next.
///
/// When handling this instruction, run the following steps:
///
/// 1. If `state_update` is present, handle it according to the description in [`BackupCreateStateUpdate`].
/// 2. If `write_instruction` is present, handle it according to the steps defined in [`WriteInstruction`].
#[derive(Debug)]
pub struct BackupCreateInstruction {
    /// A state update of the backup create task.
    pub state_update: Option<BackupCreateStateUpdate>,

    /// A write instruction that must be handled.
    pub write_instruction: Option<WriteInstruction>,
}

/// The number of bytes that must have been written.
#[derive(Debug)]
pub struct WrittenBytes(pub usize);

/// Result of polling a [`BackupCreateTask`].
pub type BackupCreateLoop = TaskLoop<BackupCreateInstruction, WrittenBytes>;

#[derive(Debug)]
struct InitState {
    identity_data: IdentityData,
}

#[derive(Educe)]
#[educe(Debug)]
struct UserDataState {
    identity_data: IdentityData,

    #[educe(Debug(ignore))]
    container_writer: ContainerWriter<UserDataContainer>,
}

#[derive(Educe)]
#[educe(Debug)]
struct ContactState {
    #[educe(Debug(ignore))]
    container_writer: ContainerWriter<ContactContainer>,

    accountant: BackupAccountant,

    #[educe(Debug(method(debug_slice_length)))]
    remaining_contacts: Vec<ThreemaId>,
}

#[derive(Educe)]
#[educe(Debug)]
struct DistributionListState {
    #[educe(Debug(ignore))]
    container_writer: ContainerWriter<DistributionListContainer>,

    accountant: BackupAccountant,

    #[educe(Debug(method(debug_slice_length)))]
    remaining_distribution_lists: Vec<DistributionListId>,
}

#[derive(Educe)]
#[educe(Debug)]
struct GroupState {
    #[educe(Debug(ignore))]
    container_writer: ContainerWriter<GroupContainer>,

    accountant: BackupAccountant,

    #[educe(Debug(method(debug_slice_length)))]
    remaining_groups: Vec<GroupIdentity>,
}

#[derive(Educe)]
#[educe(Debug)]
struct CspNonceState {
    #[educe(Debug(ignore))]
    container_writer: ContainerWriter<HashedCspNonceContainer>,

    accountant: BackupAccountant,

    batch_index: RangeFrom<usize>,

    written_nonces: usize,
}

#[derive(Educe)]
#[educe(Debug)]
struct PollsState {
    #[educe(Debug(ignore))]
    container_writer: ContainerWriter<PollContainer>,

    accountant: BackupAccountant,

    batch_index: RangeFrom<usize>,
}

#[derive(Educe)]
#[educe(Debug)]
struct MessagesState {
    #[educe(Debug(ignore))]
    container_writer: ContainerWriter<MessageContainer>,

    accountant: BackupAccountant,

    conversation_type: ConversationType,

    batch_index: RangeFrom<usize>,
}

#[derive(Debug)]
struct FinalizeState {
    page_writer: PageWriter,
}

#[derive(Debug)]
struct DissolveState {
    written_bytes: WrittenBytes,
}

#[derive(Debug)]
enum State {
    Init(InitState),
    UserData(UserDataState),
    Contact(ContactState),
    DistributionList(DistributionListState),
    Group(GroupState),
    CspNonce(CspNonceState),
    Polls(PollsState),
    Message(MessagesState),
    Finalize(FinalizeState),
    Dissolve(DissolveState),
    Done,
    Error(BackupCreateError),
}
impl State {
    fn state_update(&self) -> Option<BackupCreateStateUpdate> {
        match self {
            Self::Init(_) | Self::UserData(_) => Some(BackupCreateStateUpdate::InitialState),
            Self::Contact(contact_state) => Some(BackupCreateStateUpdate::Contacts(
                contact_state.accountant.number_of_contacts(),
            )),
            Self::DistributionList(distribution_list_state) => {
                Some(BackupCreateStateUpdate::DistributionLists(
                    distribution_list_state.accountant.number_of_distribution_lists(),
                ))
            },
            Self::Group(group_state) => Some(BackupCreateStateUpdate::Groups(
                group_state.accountant.number_of_groups(),
            )),
            Self::CspNonce(csp_nonce_state) => {
                Some(BackupCreateStateUpdate::CspNonces(csp_nonce_state.written_nonces))
            },
            Self::Polls(writing_polls_state) => Some(BackupCreateStateUpdate::Polls(
                writing_polls_state.accountant.number_of_polls(),
            )),
            Self::Message(writing_messages_state) => Some(BackupCreateStateUpdate::Messages(
                writing_messages_state.accountant.number_of_messages(),
            )),
            Self::Finalize(_) | Self::Dissolve(_) => Some(BackupCreateStateUpdate::FinalizeState),
            Self::Done | Self::Error(_) => None,
        }
    }

    #[tracing::instrument(skip_all)]
    fn poll_init(
        context: &BackupCreateContext,
        state: InitState,
    ) -> Result<(Self, BackupCreateLoop), BackupCreateError> {
        let (state, instruction) = Self::process_init(context, state)?;
        let state_update = state.state_update();
        Ok((
            state,
            BackupCreateLoop::Instruction(BackupCreateInstruction {
                write_instruction: Some(instruction.into()),
                state_update,
            }),
        ))
    }

    fn process_init(
        context: &BackupCreateContext,
        state: InitState,
    ) -> Result<(Self, LocalWriteInstruction), BackupCreateError> {
        // Write placeholder for header.
        let instruction = {
            let mut writer = OwnedVecByteWriter::new_with_capacity(METADATA_LENGTH);

            // Write header
            writer
                .write(&Header::new(context.salt.clone()).encode())
                .map_err(|error| InternalErrorCause::EncodingFailed {
                    name: Header::NAME,
                    source: error.into(),
                })?;

            // Skip space for layout
            writer.write(&[0; LayoutV1Encrypted::LENGTH]).map_err(|error| {
                InternalErrorCause::EncodingFailed {
                    name: "Space for encrypted V1 layout",
                    source: error.into(),
                }
            })?;

            LocalWriteInstruction::Append(writer.into_inner())
        };

        // Write user data in next state.
        let state = Self::UserData(UserDataState {
            identity_data: state.identity_data,
            container_writer: ContainerWriter::new(context.root_key.page_key())?,
        });

        Ok((state, instruction))
    }

    #[tracing::instrument(skip_all)]
    fn poll_user_data(
        context: &BackupCreateContext,
        state: UserDataState,
    ) -> Result<(Self, BackupCreateLoop), BackupCreateError> {
        let (state, instruction) = Self::process_user_data(context, state)?;
        let state_update = state.state_update();
        Ok((
            state,
            BackupCreateLoop::Instruction(BackupCreateInstruction {
                write_instruction: instruction.map(WriteInstruction::from),
                state_update,
            }),
        ))
    }

    fn process_user_data(
        context: &BackupCreateContext,
        mut state: UserDataState,
    ) -> Result<(Self, Option<LocalWriteInstruction>), BackupCreateError> {
        let accountant = BackupAccountant::new(state.identity_data.user_identity);

        // Get and sanitize the settings.
        let mut settings = context
            .settings
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .get()?;
        accountant.sanitize_settings(&mut settings);

        // Write the User Data.
        {
            let container = UserDataContainer(UserData {
                identity_data: state.identity_data,
                user_profile: context
                    .user_profile
                    .lock()
                    .unwrap_or_else(PoisonError::into_inner)
                    .get()?,
                settings,
            });
            state.container_writer.add(&[container])?;
        };

        // Write contacts in the next state.
        let (container_writer, instruction) = state.container_writer.transform()?;
        let state = Self::Contact(ContactState {
            container_writer,
            accountant,
            remaining_contacts: context
                .contacts
                .lock()
                .unwrap_or_else(PoisonError::into_inner)
                .get_identities()?
                .into_iter()
                .collect(),
        });

        Ok((state, instruction))
    }

    #[tracing::instrument(skip_all)]
    fn poll_contacts(
        context: &BackupCreateContext,
        state: ContactState,
    ) -> Result<(Self, BackupCreateLoop), BackupCreateError> {
        let (state, instruction) = Self::process_contacts(context, state)?;
        let state_update = state.state_update();
        Ok((
            state,
            BackupCreateLoop::Instruction(BackupCreateInstruction {
                write_instruction: instruction.map(WriteInstruction::from),
                state_update,
            }),
        ))
    }

    fn process_contacts(
        context: &BackupCreateContext,
        mut state: ContactState,
    ) -> Result<(Self, Option<LocalWriteInstruction>), BackupCreateError> {
        // Write new contacts if the maximal append length has not been reached and as long as there are
        // contacts remaining.
        let contacts = context.contacts.lock().unwrap_or_else(PoisonError::into_inner);
        let mut containers = vec![];
        while state
            .container_writer
            .writable_buffer_below_maximal_append_length()?
            && let Some(identity) = state.remaining_contacts.pop()
        {
            let contact =
                contacts
                    .get_with_profile_pictures(identity)?
                    .ok_or(BackupCreateError::InvalidState(
                        "Contact should exist for previously queried identity".to_owned(),
                    ))?;
            if state.accountant.check_and_add_contact(&contact.contact) {
                containers.push(ContactContainer(contact));
            }
        }
        state.container_writer.add(&containers)?;

        // Transition to the next state.
        if state.remaining_contacts.is_empty() {
            // Write distribution lists in the next state.
            let (container_writer, instruction) = state.container_writer.transform()?;
            let state = Self::DistributionList(DistributionListState {
                container_writer,
                accountant: state.accountant,
                remaining_distribution_lists: context
                    .distribution_lists
                    .lock()
                    .unwrap_or_else(PoisonError::into_inner)
                    .get_ids()?
                    .into_iter()
                    .collect(),
            });

            Ok((state, instruction))
        } else {
            // There are more contacts to come, stay in state.
            let instruction = state.container_writer.write_pending()?;
            Ok((Self::Contact(state), instruction))
        }
    }

    #[tracing::instrument(skip_all)]
    fn poll_distribution_lists(
        context: &BackupCreateContext,
        state: DistributionListState,
    ) -> Result<(Self, BackupCreateLoop), BackupCreateError> {
        let (state, instruction) = Self::process_distribution_lists(context, state)?;
        let state_update = state.state_update();
        Ok((
            state,
            BackupCreateLoop::Instruction(BackupCreateInstruction {
                write_instruction: instruction.map(WriteInstruction::from),
                state_update,
            }),
        ))
    }

    fn process_distribution_lists(
        context: &BackupCreateContext,
        mut state: DistributionListState,
    ) -> Result<(Self, Option<LocalWriteInstruction>), BackupCreateError> {
        // Write new distribution lists if the maximal append length has not been reached and as long as there
        // are distribution lists remaining.
        let distribution_lists = context
            .distribution_lists
            .lock()
            .unwrap_or_else(PoisonError::into_inner);
        let mut containers = vec![];
        while state
            .container_writer
            .writable_buffer_below_maximal_append_length()?
            && let Some(distribution_list_id) = state.remaining_distribution_lists.pop()
        {
            let mut distribution_list =
                distribution_lists
                    .get(distribution_list_id)?
                    .ok_or(BackupCreateError::InvalidState(
                        "Distribution list should exist for previously queried identity".to_owned(),
                    ))?;
            if state
                .accountant
                .sanitize_and_add_distribution_list(&mut distribution_list)
            {
                containers.push(DistributionListContainer(distribution_list));
            }
        }
        state.container_writer.add(&containers)?;

        // Transition to the next state.
        if state.remaining_distribution_lists.is_empty() {
            // Write groups in the next state.
            let (container_writer, instruction) = state.container_writer.transform()?;
            let state = Self::Group(GroupState {
                container_writer,
                accountant: state.accountant,
                remaining_groups: context
                    .groups
                    .lock()
                    .unwrap_or_else(PoisonError::into_inner)
                    .get_identities()?
                    .into_iter()
                    .collect(),
            });

            Ok((state, instruction))
        } else {
            // There are more distribution lists to come, stay in state.
            let instruction = state.container_writer.write_pending()?;
            Ok((Self::DistributionList(state), instruction))
        }
    }

    #[tracing::instrument(skip_all)]
    fn poll_groups(
        context: &BackupCreateContext,
        state: GroupState,
    ) -> Result<(Self, BackupCreateLoop), BackupCreateError> {
        let (state, instruction) = Self::process_groups(context, state)?;
        let state_update = state.state_update();
        Ok((
            state,
            BackupCreateLoop::Instruction(BackupCreateInstruction {
                write_instruction: instruction.map(WriteInstruction::from),
                state_update,
            }),
        ))
    }

    fn process_groups(
        context: &BackupCreateContext,
        mut state: GroupState,
    ) -> Result<(Self, Option<LocalWriteInstruction>), BackupCreateError> {
        // Write new groups if the maximal append length has not been reached and as long as there
        // are groups remaining.
        let groups = context.groups.lock().unwrap_or_else(PoisonError::into_inner);
        let mut containers = vec![];
        while state
            .container_writer
            .writable_buffer_below_maximal_append_length()?
            && let Some(group_identity) = state.remaining_groups.pop()
        {
            let mut group =
                groups
                    .get_with_profile_picture(group_identity)?
                    .ok_or(BackupCreateError::InvalidState(
                        "Group should exist for previously queried identity".to_owned(),
                    ))?;
            if state.accountant.sanitize_and_add_group(&mut group.group) {
                containers.push(GroupContainer(group));
            }
        }
        state.container_writer.add(&containers)?;

        // Transition to the next state.
        if state.remaining_groups.is_empty() {
            // Write CSP nonces in the next state.
            let (container_writer, instruction) = state.container_writer.transform()?;
            let state = Self::CspNonce(CspNonceState {
                container_writer,
                accountant: state.accountant,
                batch_index: 0..,
                written_nonces: 0,
            });

            Ok((state, instruction))
        } else {
            // There are more groups to come, stay in state.
            let instruction = state.container_writer.write_pending()?;
            Ok((Self::Group(state), instruction))
        }
    }

    #[tracing::instrument(skip_all)]
    fn poll_csp_nonces(
        context: &BackupCreateContext,
        state: CspNonceState,
    ) -> Result<(Self, BackupCreateLoop), BackupCreateError> {
        let (state, instruction) = Self::process_csp_nonces(context, state)?;
        let state_update = state.state_update();
        Ok((
            state,
            BackupCreateLoop::Instruction(BackupCreateInstruction {
                write_instruction: instruction.map(WriteInstruction::from),
                state_update,
            }),
        ))
    }

    fn process_csp_nonces(
        context: &BackupCreateContext,
        mut state: CspNonceState,
    ) -> Result<(Self, Option<LocalWriteInstruction>), BackupCreateError> {
        let batch_index = state.batch_index.next().ok_or(InternalErrorCause::Other(
            "Reached maximum CSP nonce batch index".to_owned(),
        ))?;
        debug!(?batch_index, "Backing up CSP nonces");

        let hashed_nonce_containers: Vec<_> = context
            .csp_nonces
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .get_many(batch_index)?
            .into_iter()
            .map(HashedCspNonceContainer)
            .collect();

        if hashed_nonce_containers.is_empty() {
            // Dissolve current state
            let (container_writer, instruction) = state.container_writer.transform()?;

            let state = Self::Polls(PollsState {
                container_writer,
                accountant: state.accountant,
                batch_index: 0..,
            });

            Ok((state, instruction))
        } else {
            // Write nonces
            state.container_writer.add(&hashed_nonce_containers)?;
            state.written_nonces = state.written_nonces.saturating_add(hashed_nonce_containers.len());

            // Get next instruction
            let instruction = state.container_writer.write_pending()?;

            Ok((Self::CspNonce(state), instruction))
        }
    }

    #[tracing::instrument(skip_all)]
    fn poll_polls(
        context: &BackupCreateContext,
        state: PollsState,
    ) -> Result<(Self, BackupCreateLoop), BackupCreateError> {
        let (state, instruction) = Self::process_polls(context, state)?;
        let state_update = state.state_update();
        Ok((
            state,
            BackupCreateLoop::Instruction(BackupCreateInstruction {
                write_instruction: instruction.map(WriteInstruction::from),
                state_update,
            }),
        ))
    }

    fn process_polls(
        context: &BackupCreateContext,
        mut polls_state: PollsState,
    ) -> Result<(Self, Option<LocalWriteInstruction>), BackupCreateError> {
        let poll_containers = {
            // Get batch of polls.
            let batch_index = polls_state.batch_index.next().ok_or(InternalErrorCause::Other(
                "Reached maximum poll batch index".to_owned(),
            ))?;
            debug!(?batch_index, "Backing up polls");
            let polls = context
                .polls
                .lock()
                .unwrap_or_else(PoisonError::into_inner)
                .get_many(batch_index)?;

            // Sanity checks
            let mut poll_containers = Vec::with_capacity(polls.len());
            for poll in polls {
                if polls_state.accountant.check_and_add_poll(&poll) {
                    poll_containers.push(PollContainer(poll));
                }
            }

            poll_containers
        };

        if poll_containers.is_empty() {
            // Dissolve current state.
            let (container_writer, instruction) = polls_state.container_writer.transform()?;

            // Establish next state.
            let state = Self::Message(MessagesState {
                container_writer,
                accountant: polls_state.accountant,
                conversation_type: ConversationType::Contact,
                batch_index: 0..,
            });

            Ok((state, instruction))
        } else {
            // Write polls.
            polls_state.container_writer.add(&poll_containers)?;

            // Get next instruction.
            let instruction = polls_state.container_writer.write_pending()?;

            Ok((Self::Polls(polls_state), instruction))
        }
    }

    #[tracing::instrument(skip_all)]
    fn poll_messages(
        context: &BackupCreateContext,
        state: MessagesState,
    ) -> Result<(Self, BackupCreateLoop), BackupCreateError> {
        let (state, instruction) = Self::process_messages(context, state)?;
        let state_update = state.state_update();
        Ok((
            state,
            BackupCreateLoop::Instruction(BackupCreateInstruction {
                write_instruction: instruction.map(WriteInstruction::from),
                state_update,
            }),
        ))
    }

    fn process_messages(
        context: &BackupCreateContext,
        mut state: MessagesState,
    ) -> Result<(Self, Option<LocalWriteInstruction>), BackupCreateError> {
        // Get batch of messages states for current conversation type.
        let message_containers: Vec<MessageContainer> = {
            let batch_index = state.batch_index.next().ok_or(InternalErrorCause::Other(
                "Reached maximum message batch index".to_owned(),
            ))?;
            debug!(?batch_index, "Backing up messages");
            let message_states = context
                .conversations
                .lock()
                .unwrap_or_else(PoisonError::into_inner)
                .get_many_messages(state.conversation_type, batch_index)?;

            // Sanity checks and conversion to message containers.
            let mut message_containers = Vec::with_capacity(message_states.len());
            for mut message_state in message_states {
                if state.accountant.sanitize_and_add_message(&mut message_state) {
                    message_containers.push(MessageContainer(message_state));
                }
            }

            message_containers
        };

        if message_containers.is_empty() {
            // We have gotten all messages of this conversation type.
            match state.conversation_type {
                // After the contact messages, write all distribution list messages.
                ConversationType::Contact => {
                    return Ok((
                        Self::Message(MessagesState {
                            container_writer: state.container_writer,
                            accountant: state.accountant,
                            conversation_type: ConversationType::DistributionList,
                            batch_index: 0..,
                        }),
                        None,
                    ));
                },

                // After the distribution list messages, write all group messages.
                ConversationType::DistributionList => {
                    return Ok((
                        Self::Message(MessagesState {
                            container_writer: state.container_writer,
                            accountant: state.accountant,
                            conversation_type: ConversationType::Group,
                            batch_index: 0..,
                        }),
                        None,
                    ));
                },

                // After the group messages, *all* messages have been written, advance to the next state.
                ConversationType::Group => {
                    let mut page_writer = state.container_writer.dissolve()?;
                    let instruction = page_writer.write_pending()?;
                    return Ok((Self::Finalize(FinalizeState { page_writer }), instruction));
                },
            }
        }

        // Write past messages.
        state.container_writer.add(&message_containers)?;

        // Get next instruction.
        let instruction = state.container_writer.write_pending()?;

        Ok((Self::Message(state), instruction))
    }

    #[tracing::instrument(skip_all)]
    fn poll_finalize(
        context: &BackupCreateContext,
        mut state: FinalizeState,
    ) -> Result<(Self, BackupCreateLoop), BackupCreateError> {
        if let Some(instruction) = state.page_writer.write_pending()? {
            let state = Self::Finalize(state);
            let state_update = state.state_update();
            Ok((
                state,
                BackupCreateLoop::Instruction(BackupCreateInstruction {
                    write_instruction: Some(instruction.into()),
                    state_update,
                }),
            ))
        } else {
            let (layout, written_page_bytes) = state.page_writer.finalize()?;

            // Encrypt and encode the layout
            let encrypted_layout = layout
                .encrypt(&Header::new(context.salt.clone()), &context.root_key.layout_key())?
                .encode();

            // Write the layout *after* the header
            let instruction = LocalWriteInstruction::WriteAt {
                offset: Header::LENGTH,
                data: encrypted_layout,
            };

            // Compute the total number of written bytes
            let written_bytes = WrittenBytes(written_page_bytes.0.checked_add(METADATA_LENGTH).ok_or(
                InternalErrorCause::Overflow(OverflowError {
                    name: "Total number of written bytes",
                }),
            )?);

            Ok((
                Self::Dissolve(DissolveState { written_bytes }),
                BackupCreateLoop::Instruction(BackupCreateInstruction {
                    write_instruction: Some(instruction.into()),
                    state_update: Some(BackupCreateStateUpdate::FinalizeState),
                }),
            ))
        }
    }

    #[tracing::instrument(skip_all)]
    fn poll_dissolve(state: DissolveState) -> Result<(Self, BackupCreateLoop), BackupCreateError> {
        Ok((Self::Done, BackupCreateLoop::Done(state.written_bytes)))
    }
}

/// The initial context needed to create a backup.
pub struct BackupCreateContextInit {
    /// The password of the backup.
    pub password: DataBackupPassword,

    /// The user's identity data.
    pub identity_data: IdentityData,

    /// The user profile.
    pub user_profile: Arc<Mutex<dyn UserProfileProvider + Send + Sync>>,

    /// The settings of the user.
    pub settings: Arc<Mutex<dyn SettingsProvider + Send + Sync>>,

    /// The contacts of the user.
    pub contacts: Arc<Mutex<dyn ContactProvider + Send + Sync>>,

    /// The groups of the user.
    pub groups: Arc<Mutex<dyn GroupProvider + Send + Sync>>,

    /// The distribution lists of the user.
    pub distribution_lists: Arc<Mutex<dyn DistributionListProvider + Send + Sync>>,

    /// The previously received and sent nonces.
    pub csp_nonces: Arc<Mutex<dyn NonceProvider + Send + Sync>>,

    /// The previously received and sent polls.
    pub polls: Arc<Mutex<dyn PollProvider + Send + Sync>>,

    /// The past conversations.
    pub conversations: Arc<Mutex<dyn ConversationProvider + Send + Sync>>,
}

/// The context containing all parameters needed to initiate the task.
pub(crate) struct BackupCreateContext {
    root_key: DataBackupRootKey,
    salt: DataBackupSalt,
    user_profile: Arc<Mutex<dyn UserProfileProvider + Send + Sync>>,
    settings: Arc<Mutex<dyn SettingsProvider + Send + Sync>>,
    csp_nonces: Arc<Mutex<dyn NonceProvider + Send + Sync>>,
    contacts: Arc<Mutex<dyn ContactProvider + Send + Sync>>,
    groups: Arc<Mutex<dyn GroupProvider + Send + Sync>>,
    distribution_lists: Arc<Mutex<dyn DistributionListProvider + Send + Sync>>,
    polls: Arc<Mutex<dyn PollProvider + Send + Sync>>,
    conversations: Arc<Mutex<dyn ConversationProvider + Send + Sync>>,
}

/// Task for creating a backup.
#[derive(Name, educe::Educe)]
#[educe(Debug)]
pub struct BackupCreateTask {
    #[educe(Debug(ignore))]
    context: BackupCreateContext,
    state: State,
}
impl BackupCreateTask {
    /// Create a new task for backing up all user data.
    ///
    /// # Errors
    ///
    /// Returns a [`BackupCreateError::InternalError`] in case that deriving the key from the password fails.
    pub fn new(init: BackupCreateContextInit) -> Result<(Self, Filename), BackupCreateError> {
        let context = {
            let salt = DataBackupSalt::random();
            let root_key = init
                .password
                .derive_root_key(&salt)
                .map_err(InternalErrorCause::KeyDerivationFailed)?;
            BackupCreateContext {
                root_key,
                salt,
                user_profile: init.user_profile,
                settings: init.settings,
                contacts: init.contacts,
                groups: init.groups,
                distribution_lists: init.distribution_lists,
                csp_nonces: init.csp_nonces,
                polls: init.polls,
                conversations: init.conversations,
            }
        };

        Ok((
            Self {
                context,
                state: State::Init(InitState {
                    identity_data: init.identity_data,
                }),
            },
            Filename::new(),
        ))
    }

    /// Poll to advance the state.
    ///
    /// # Errors
    ///
    /// Returns [`BackupCreateError`] for all possible reasons.
    #[tracing::instrument(skip_all, fields(?self))]
    pub fn poll(&mut self) -> Result<BackupCreateLoop, BackupCreateError> {
        let result = match mem::replace(
            &mut self.state,
            State::Error(BackupCreateError::InvalidState(format!(
                "{} in a transitional state",
                Self::NAME
            ))),
        ) {
            State::Error(error) => Err(error),
            State::Init(state) => State::poll_init(&self.context, state),
            State::UserData(state) => State::poll_user_data(&self.context, state),
            State::Contact(state) => State::poll_contacts(&self.context, state),
            State::DistributionList(state) => State::poll_distribution_lists(&self.context, state),
            State::Group(state) => State::poll_groups(&self.context, state),
            State::CspNonce(state) => State::poll_csp_nonces(&self.context, state),
            State::Polls(state) => State::poll_polls(&self.context, state),
            State::Message(state) => State::poll_messages(&self.context, state),
            State::Finalize(state) => State::poll_finalize(&self.context, state),
            State::Dissolve(state) => State::poll_dissolve(state),
            State::Done => Err(BackupCreateError::InvalidState(format!(
                "{} already done",
                Self::NAME
            ))),
        };

        match result {
            Ok((state, instruction)) => {
                self.state = state;
                debug!(state = ?self.state, "Changed state");
                Ok(instruction)
            },
            Err(error) => {
                self.state = State::Error(error.clone());
                debug!(state = ?self.state, "Changed state to error");
                Err(error)
            },
        }
    }
}
