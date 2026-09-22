//! Backup Restore Task.

use core::mem;
use std::sync::{Arc, Mutex, PoisonError};

use educe::Educe;
use libthreema_macros::{DebugVariantNames, Name, VariantNames};
use tracing::{debug, error, trace, warn};

use crate::{
    common::{keys::DataBackupPassword, task::TaskLoop},
    data_backup::{
        OverflowError, StreamOffset,
        accountant::BackupAccountant,
        codec::BackupDecodingError,
        metadata::{Header, LayoutV1Encrypted, METADATA_LENGTH},
        page::Position,
        task::restore::container_reader::{
            ContactContainerReader, ContainerReaderResult, DistributionListContainerReader,
            GroupContainerReader, HashedCspNonceContainerReader, MessageContainerReader, PollContainerReader,
            UserDataContainerReader,
        },
    },
    model::{
        contact::ContactProvider,
        conversation::ConversationProvider,
        distribution_list::DistributionListProvider,
        group::GroupProvider,
        poll::PollProvider,
        settings::{Settings, SettingsProvider},
        user_profile::{IdentityData, UserProfile, UserProfileProvider},
    },
    protobuf,
    provider::{NonceProvider, ProviderError},
    utils::{
        bytes::OwnedVecByteReader,
        debug::{Name as _, debug_slice_length},
        frame::FixedLengthFrameDecoder,
    },
};

mod container_reader;
mod page_reader;

/// The minimum supported protocol version (inclusive).
const MINIMUM_DATA_BACKUP_VERSION: usize = protobuf::data_backup::ProtocolVersion::V0 as usize;

/// The maximum supported protocol version (inclusive).
const MAXIMUM_DATA_BACKUP_VERSION: usize = protobuf::data_backup::ProtocolVersion::V0 as usize;

/// An error occurred during backup restoration.
///
/// When encountering an error:
///
/// 1. Let `error` be the provided [`BackupRestoreError`].
/// 2. Reset the state of the app to the state prior to starting the backup restoration.
/// 3. Abort the protocol due to `error`.
#[derive(Clone, Debug, thiserror::Error)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Error), uniffi(flat_error))]
pub enum BackupRestoreError {
    /// Invalid parameter provided by foreign code.
    #[error("Invalid parameter: {0}")]
    InvalidParameter(String),

    /// A foreign function considered infallible returned an error.
    #[cfg(any(test, feature = "uniffi", feature = "cli"))]
    #[error("Infallible function failed in foreign code: {0}")]
    Foreign(String),

    /// Invalid state for the requested instruction.
    #[error("Invalid state: {0}")]
    InvalidState(String),

    /// The backup version is unsupported.
    #[error("Backup version {0} is unsupported")]
    UnsupportedVersion(u16),

    /// The backup sanity check failed.
    #[error("The backup sanity check failed: {0}")]
    SanityCheckFailed(String),

    /// Unable to decode a struct.
    #[error("Decoding '{name}' failed: {source}")]
    DecodingFailed {
        /// Name of the struct.
        name: &'static str,

        /// Error source.
        source: BackupDecodingError,
    },

    /// Unable to decrypt a struct.
    #[error("Decrypting '{name}' failed")]
    DecryptionFailed {
        /// Name of the struct.
        name: &'static str,
    },

    /// An overflow occurred.
    #[error("Overflow error: {0}")]
    Overflow(#[from] OverflowError),

    /// Another kind of error occurred.
    #[error("{0}")]
    Other(String),
}
impl From<ProviderError> for BackupRestoreError {
    fn from(error: ProviderError) -> Self {
        match error {
            ProviderError::InvalidParameter(message) => Self::Other(message),
            ProviderError::InvalidState(message) => Self::InvalidState(message),
            #[cfg(any(test, feature = "uniffi", feature = "cli"))]
            ProviderError::Foreign(message) => Self::Foreign(message),
        }
    }
}

/// Local instruction to read a chunk of a byte stream as part of a [`BackupRestoreInstruction`].
///
/// 1. Let `stream` be the stream from which the bytes should be read from.
/// 2. Read `bytes` as the range of `stream` from `offset` (inclusive) to `offset` + `length` (exclusive).
/// 3. If reading `bytes` failed, log an error, exceptionally abort the backup restoration task.
/// 4. Provide `bytes` together with `offset` to the associated task as a [`BackupRestoreResponse`] and poll
///    again.
#[derive(Copy, Clone, Debug)]
pub struct LocalReadInstruction {
    /// The start of the requested chunk.
    pub offset: StreamOffset,

    /// The length of the requested chunk.
    pub length: usize,
}
impl LocalReadInstruction {
    /// Create a [`LocalReadInstruction`] for a given page position.
    pub(super) fn read_page(position: &Position) -> Result<Self, OverflowError> {
        Ok(Self {
            offset: position.offset.try_into()?,
            length: position.page_size.0,
        })
    }
}

/// 1. Let `instruction` be the provided read instruction.
/// 2. If `instruction` is 'Remote' log a warning that the instruction is not supported yet and abort these
///    steps.
/// 6. Run the read instruction as specified in [`LocalReadInstruction`].
#[derive(Debug)]
pub enum ReadInstruction {
    /// Apply a local storage instruction. See [`LocalReadInstruction`] for more details.
    Local(LocalReadInstruction),

    /// TODO(PRD-32): Apply a remote storage instruction.
    Remote,
}
impl From<LocalReadInstruction> for ReadInstruction {
    fn from(instruction: LocalReadInstruction) -> Self {
        Self::Local(instruction)
    }
}

/// Possible response for a [`BackupRestoreTask`].
#[derive(Educe)]
#[educe(Debug)]
pub struct BackupRestoreResponse {
    /// The offset as defined in the [`LocalReadInstruction`].
    pub offset: StreamOffset,

    /// The chunk as defined in the [`LocalReadInstruction`].
    #[educe(Debug(method(debug_slice_length)))]
    pub chunk: Vec<u8>,
}

/// A backup restore update to indicate advancing to the next state.
///
/// Steps:
/// 1. Change the displayed state to the indicated state.
///
/// State updates can be expected to be in the following order:
/// 1. `Contacts`
/// 2. `DistributionLists`
/// 3. `Groups`
/// 4. `CspNonces`
/// 5. `Polls`
/// 6. `Messages`
#[derive(VariantNames, DebugVariantNames)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum BackupRestoreStateUpdate {
    /// The next step is to restore contacts.
    Contacts,

    /// The next step is to restore distribution lists.
    DistributionLists,

    /// The next step is to restore groups.
    Groups,

    /// The next step is to restore CSP nonces.
    CspNonces,

    /// The next step is to restore polls.
    Polls,

    /// The next step is to restore messages.
    Messages,
}

/// An instruction as part of the backup restoration.
///
/// 1. If `user_data` is present:
///    1. Add `user_data` to the application storage.
///    2. Initialize the providers as [`BackupRestoreProviders`] and pass them back by calling
///       [`BackupRestoreTask::add_providers`].
/// 2. If `state_update` is present, handle it according to the steps defined in [`BackupRestoreStateUpdate`].
/// 3. If `read_instruction` is present, handle it according to the steps defined in [`ReadInstruction`].
pub struct BackupRestoreInstruction {
    /// User data.
    /// TODO(LIB-176): Handout as dedicated instruction?
    pub identity_data: Option<IdentityData>,

    /// The state that has been completed.
    pub state_update: Option<BackupRestoreStateUpdate>,

    /// The read instruction that should be processed by the client.
    pub read_instruction: Option<ReadInstruction>,
}

/// Result of polling a [`BackupRestoreTask`].
pub type BackupRestoreLoop = TaskLoop<BackupRestoreInstruction, ()>;

struct LayoutState {
    password: DataBackupPassword,
    header_and_layout_decoder: FixedLengthFrameDecoder<{ METADATA_LENGTH }>,
}

struct ReadUserDataState {
    container_reader: UserDataContainerReader,
}

/// Note: This is an intermediate state that exists solely to give the clients a chance to add the providers.
struct AddUserDataState {
    container_reader: ContactContainerReader,
    user_profile: UserProfile,
    settings: Settings,
    accountant: BackupAccountant,
}

struct ContactState {
    container_reader: ContactContainerReader,
    accountant: BackupAccountant,
}

struct DistributionListState {
    container_reader: DistributionListContainerReader,
    accountant: BackupAccountant,
}

struct GroupState {
    container_reader: GroupContainerReader,
    accountant: BackupAccountant,
}

struct CspNonceState {
    container_reader: HashedCspNonceContainerReader,
    accountant: BackupAccountant,
}

struct PollState {
    container_reader: PollContainerReader,
    accountant: BackupAccountant,
}

struct MessageState {
    container_reader: MessageContainerReader,
    accountant: BackupAccountant,
}

#[derive(DebugVariantNames, VariantNames)]
enum State {
    Layout(LayoutState),
    ReadUserData(ReadUserDataState),
    AddUserData(Box<AddUserDataState>),
    Contact(ContactState),
    DistributionList(DistributionListState),
    Group(GroupState),
    CspNonce(CspNonceState),
    Poll(PollState),
    Message(MessageState),
    Done,
    Error(BackupRestoreError),
}
impl State {
    #[tracing::instrument(skip_all)]
    fn poll_reading_layout(mut state: LayoutState) -> Result<(Self, BackupRestoreLoop), BackupRestoreError> {
        // Poll the header and the encrypted layout.
        trace!(decoder = ?state.header_and_layout_decoder, "Poll");
        let Some((header, encrypted_layout)) = state
            .header_and_layout_decoder
            .next_frame_and_then(|bytes| {
                let mut reader = OwnedVecByteReader::new(bytes.to_vec());
                let header = Header::decode_from(&mut reader)?;
                if !(MINIMUM_DATA_BACKUP_VERSION..=MAXIMUM_DATA_BACKUP_VERSION)
                    .contains(&(header.version as usize))
                {
                    return Err(BackupRestoreError::UnsupportedVersion(header.version));
                }
                let encrypted_layout = LayoutV1Encrypted::decode_from(&mut reader)?;

                Ok((header, encrypted_layout))
            })
            .transpose()?
        else {
            let read_instruction = Some(
                LocalReadInstruction {
                    offset: StreamOffset(state.header_and_layout_decoder.buffered_length()),
                    length: state.header_and_layout_decoder.required_length(),
                }
                .into(),
            );

            return Ok((
                Self::Layout(state),
                BackupRestoreLoop::Instruction(BackupRestoreInstruction {
                    identity_data: None,
                    state_update: None,
                    read_instruction,
                }),
            ));
        };
        debug!(?header, "Decoded header and encrypted layout");

        // Decrypt layout.
        trace!("Decrypting and decoding layout");
        let (layout, page_key) = {
            let backup_root_key = state
                .password
                .derive_root_key(&header.salt)
                .map_err(|error| BackupRestoreError::Other(format!("Key derivation failed: {error}")))?;

            let layout = encrypted_layout.decrypt(header, &backup_root_key.layout_key())?;
            let page_key = backup_root_key.page_key();

            (layout, page_key)
        };
        debug!(?layout, "Decoded and decrypted layout");

        // Advance to next state.
        let container_reader = UserDataContainerReader::new(page_key, layout);
        let instruction = BackupRestoreLoop::Instruction(BackupRestoreInstruction {
            identity_data: None,
            state_update: None,
            read_instruction: container_reader.instruction()?.map(ReadInstruction::from),
        });
        let state = Self::ReadUserData(ReadUserDataState { container_reader });
        debug!(?state, "Changing state");
        Ok((state, instruction))
    }

    #[tracing::instrument(skip_all)]
    fn poll_read_user_data(
        mut state: ReadUserDataState,
    ) -> Result<(Self, BackupRestoreLoop), BackupRestoreError> {
        // Get the next container.
        let read_instruction = state.container_reader.instruction()?.map(ReadInstruction::from);
        let mut user_data = match state.container_reader.pop()? {
            ContainerReaderResult::Idle => {
                return Ok((
                    Self::ReadUserData(state),
                    BackupRestoreLoop::Instruction(BackupRestoreInstruction {
                        identity_data: None,
                        state_update: None,
                        read_instruction,
                    }),
                ));
            },
            ContainerReaderResult::Some(container) => container.0,
            ContainerReaderResult::Done => {
                return Err(BackupRestoreError::Other(
                    "Missing User Data in the backup".to_owned(),
                ));
            },
        };

        // Sanitize settings.
        let accountant = BackupAccountant::new(user_data.identity_data.user_identity);
        accountant.sanitize_settings(&mut user_data.settings);

        // Advance to next state.
        let next_container_reader = {
            let (page_key, layout) = state.container_reader.dissolve()?;
            ContactContainerReader::new(page_key, layout)
        };
        let state = Self::AddUserData(Box::new(AddUserDataState {
            container_reader: next_container_reader,
            user_profile: user_data.user_profile,
            settings: user_data.settings,
            accountant,
        }));
        debug!(?state, "Changing state");
        Ok((
            state,
            BackupRestoreLoop::Instruction(BackupRestoreInstruction {
                identity_data: Some(user_data.identity_data),
                state_update: None,
                read_instruction,
            }),
        ))
    }

    /// Note: This CANNOT be done in the [`Self::poll_read_user_data`] method as callers must have a chance to
    /// initialize the providers before.
    #[tracing::instrument(skip_all)]
    fn poll_add_user_data(
        context: &BackupRestoreProviders,
        state: AddUserDataState,
    ) -> Result<(Self, BackupRestoreLoop), BackupRestoreError> {
        // Set the user profile.
        context
            .user_profile
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .set(state.user_profile)?;

        // Set the settings.
        context
            .settings
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .set(state.settings)?;

        // Advance to the next state.
        let read_instruction = state.container_reader.instruction()?.map(ReadInstruction::from);
        let state = Self::Contact(ContactState {
            container_reader: state.container_reader,
            accountant: state.accountant,
        });
        debug!(?state, "Changing state");
        Ok((
            state,
            BackupRestoreLoop::Instruction(BackupRestoreInstruction {
                identity_data: None,
                state_update: Some(BackupRestoreStateUpdate::Contacts),
                read_instruction,
            }),
        ))
    }

    #[tracing::instrument(skip_all)]
    fn poll_contacts(
        context: &BackupRestoreProviders,
        mut state: ContactState,
    ) -> Result<(Self, BackupRestoreLoop), BackupRestoreError> {
        // Read the next available contacts.
        let (state, state_update, instruction) = match state.container_reader.drain()? {
            ContainerReaderResult::Idle => {
                // There might be more contacts to come, stay in current state.
                let instruction = state.container_reader.instruction()?;
                (Self::Contact(state), None, instruction)
            },
            ContainerReaderResult::Some(containers) => {
                // Add contacts
                context
                    .contacts
                    .lock()
                    .unwrap_or_else(PoisonError::into_inner)
                    .add_with_profile_pictures(
                        containers
                            .into_iter()
                            .map(|container| container.0)
                            .filter(|contact| state.accountant.check_and_add_contact(&contact.contact))
                            .collect(),
                    )?;

                // There might be more contacts to come, stay in current state.
                let instruction = state.container_reader.instruction()?;
                (Self::Contact(state), None, instruction)
            },
            ContainerReaderResult::Done => {
                // There are no contacts, advance to the next state.
                let (state, instruction) = {
                    let next_container_reader = {
                        let (page_key, layout) = state.container_reader.dissolve()?;
                        DistributionListContainerReader::new(page_key, layout)
                    };
                    let instruction = next_container_reader.instruction()?;

                    (
                        Self::DistributionList(DistributionListState {
                            container_reader: next_container_reader,
                            accountant: state.accountant,
                        }),
                        instruction,
                    )
                };

                debug!(?state, "Changing state");
                (
                    state,
                    Some(BackupRestoreStateUpdate::DistributionLists),
                    instruction,
                )
            },
        };

        Ok((
            state,
            BackupRestoreLoop::Instruction(BackupRestoreInstruction {
                identity_data: None,
                state_update,
                read_instruction: instruction.map(ReadInstruction::from),
            }),
        ))
    }

    #[tracing::instrument(skip_all)]
    fn poll_distribution_lists(
        context: &BackupRestoreProviders,
        mut state: DistributionListState,
    ) -> Result<(Self, BackupRestoreLoop), BackupRestoreError> {
        // Read the next available distribution lists.
        let (state, state_update, instruction) = match state.container_reader.drain()? {
            ContainerReaderResult::Idle => {
                // There might be more distribution lists to come, stay in current state.
                let instruction = state.container_reader.instruction()?;
                (Self::DistributionList(state), None, instruction)
            },
            ContainerReaderResult::Some(containers) => {
                // Add distribution lists.
                context
                    .distribution_lists
                    .lock()
                    .unwrap_or_else(PoisonError::into_inner)
                    .add(
                        containers
                            .into_iter()
                            .map(|container| container.0)
                            .filter_map(|mut distribution_list| {
                                state
                                    .accountant
                                    .sanitize_and_add_distribution_list(&mut distribution_list)
                                    .then_some(distribution_list)
                            })
                            .collect(),
                    )?;

                // There might be more distribution lists to come, stay in current state.
                let instruction = state.container_reader.instruction()?;
                (Self::DistributionList(state), None, instruction)
            },
            ContainerReaderResult::Done => {
                // There are no distribution lists, advance to the next state.
                let (state, instruction) = {
                    let next_container_reader = {
                        let (page_key, layout) = state.container_reader.dissolve()?;
                        GroupContainerReader::new(page_key, layout)
                    };
                    let instruction = next_container_reader.instruction()?;

                    (
                        Self::Group(GroupState {
                            container_reader: next_container_reader,
                            accountant: state.accountant,
                        }),
                        instruction,
                    )
                };

                debug!(?state, "Changing state");
                (state, Some(BackupRestoreStateUpdate::Groups), instruction)
            },
        };

        Ok((
            state,
            BackupRestoreLoop::Instruction(BackupRestoreInstruction {
                identity_data: None,
                state_update,
                read_instruction: instruction.map(ReadInstruction::from),
            }),
        ))
    }

    #[tracing::instrument(skip_all)]
    fn poll_groups(
        context: &BackupRestoreProviders,
        mut state: GroupState,
    ) -> Result<(Self, BackupRestoreLoop), BackupRestoreError> {
        // Read the next available groups.
        let (state, state_update, instruction) = match state.container_reader.drain()? {
            ContainerReaderResult::Idle => {
                // There might be more groups to come, stay in current state.
                let instruction = state.container_reader.instruction()?;
                (Self::Group(state), None, instruction)
            },
            ContainerReaderResult::Some(containers) => {
                // Add groups.
                context
                    .groups
                    .lock()
                    .unwrap_or_else(PoisonError::into_inner)
                    .add_with_profile_picture(
                        containers
                            .into_iter()
                            .map(|container| container.0)
                            .filter_map(|mut group| {
                                state
                                    .accountant
                                    .sanitize_and_add_group(&mut group.group)
                                    .then_some(group)
                            })
                            .collect(),
                    )?;

                // There might be more groups to come, stay in current state.
                let instruction = state.container_reader.instruction()?;
                (Self::Group(state), None, instruction)
            },
            ContainerReaderResult::Done => {
                // There are no groups, advance to the next state.
                let (state, instruction) = {
                    let next_container_reader = {
                        let (page_key, layout) = state.container_reader.dissolve()?;
                        HashedCspNonceContainerReader::new(page_key, layout)
                    };
                    let instruction = next_container_reader.instruction()?;

                    (
                        Self::CspNonce(CspNonceState {
                            container_reader: next_container_reader,
                            accountant: state.accountant,
                        }),
                        instruction,
                    )
                };

                debug!(?state, "Changing state");
                (state, Some(BackupRestoreStateUpdate::CspNonces), instruction)
            },
        };

        Ok((
            state,
            BackupRestoreLoop::Instruction(BackupRestoreInstruction {
                identity_data: None,
                state_update,
                read_instruction: instruction.map(ReadInstruction::from),
            }),
        ))
    }

    #[tracing::instrument(skip_all)]
    fn poll_csp_nonces(
        context: &BackupRestoreProviders,
        mut state: CspNonceState,
    ) -> Result<(Self, BackupRestoreLoop), BackupRestoreError> {
        let mut csp_nonce_provider = context.csp_nonces.lock().unwrap_or_else(PoisonError::into_inner);
        let (state, state_update, instruction) = match state.container_reader.drain()? {
            ContainerReaderResult::Idle => {
                let instruction = state.container_reader.instruction()?;
                (Self::CspNonce(state), None, instruction)
            },
            ContainerReaderResult::Some(hashed_csp_nonces) => {
                let instruction = state.container_reader.instruction()?;
                csp_nonce_provider.add_many(
                    hashed_csp_nonces
                        .into_iter()
                        .map(|container| container.0)
                        .collect(),
                )?;
                (Self::CspNonce(state), None, instruction)
            },
            ContainerReaderResult::Done => {
                let next_container_reader = {
                    let (page_key, layout) = state.container_reader.dissolve()?;
                    PollContainerReader::new(page_key, layout)
                };
                let instruction = next_container_reader.instruction()?;
                let state = Self::Poll(PollState {
                    container_reader: next_container_reader,
                    accountant: state.accountant,
                });
                debug!(?state, "Changing state");
                (state, Some(BackupRestoreStateUpdate::Polls), instruction)
            },
        };

        Ok((
            state,
            BackupRestoreLoop::Instruction(BackupRestoreInstruction {
                identity_data: None,
                state_update,
                read_instruction: instruction.map(ReadInstruction::from),
            }),
        ))
    }

    #[tracing::instrument(skip_all)]
    fn poll_polls(
        context: &BackupRestoreProviders,
        mut state: PollState,
    ) -> Result<(Self, BackupRestoreLoop), BackupRestoreError> {
        let (state, state_update, instruction) = match state.container_reader.drain()? {
            ContainerReaderResult::Idle => {
                let instruction = state.container_reader.instruction()?;
                (Self::Poll(state), None, instruction)
            },
            ContainerReaderResult::Some(polls) => {
                let instruction = state.container_reader.instruction()?;
                context.polls.lock().unwrap_or_else(PoisonError::into_inner).add(
                    polls
                        .into_iter()
                        .map(|container| container.0)
                        .filter(|poll| state.accountant.check_and_add_poll(poll))
                        .collect(),
                )?;

                (Self::Poll(state), None, instruction)
            },

            ContainerReaderResult::Done => {
                // Advance to next state.
                let next_container_reader = {
                    let (page_key, layout) = state.container_reader.dissolve()?;
                    MessageContainerReader::new(page_key, layout)
                };
                let instruction = next_container_reader.instruction()?;
                let state = Self::Message(MessageState {
                    container_reader: next_container_reader,
                    accountant: state.accountant,
                });
                debug!(?state, "Changing state");
                (state, Some(BackupRestoreStateUpdate::Messages), instruction)
            },
        };

        Ok((
            state,
            BackupRestoreLoop::Instruction(BackupRestoreInstruction {
                identity_data: None,
                state_update,
                read_instruction: instruction.map(ReadInstruction::from),
            }),
        ))
    }

    #[tracing::instrument(skip_all)]
    fn poll_messages(
        context: &BackupRestoreProviders,
        mut state: MessageState,
    ) -> Result<(Self, BackupRestoreLoop), BackupRestoreError> {
        Ok(match state.container_reader.drain()? {
            ContainerReaderResult::Idle => {
                let read_instruction = state.container_reader.instruction()?.map(ReadInstruction::from);
                (
                    Self::Message(state),
                    BackupRestoreLoop::Instruction(BackupRestoreInstruction {
                        identity_data: None,
                        state_update: None,
                        read_instruction,
                    }),
                )
            },
            ContainerReaderResult::Some(messages) => {
                let read_instruction = state.container_reader.instruction()?.map(ReadInstruction::from);
                context
                    .conversations
                    .lock()
                    .unwrap_or_else(PoisonError::into_inner)
                    .add_messages(
                        messages
                            .into_iter()
                            .filter_map(|mut container| {
                                state
                                    .accountant
                                    .sanitize_and_add_message(&mut container.0)
                                    .then_some(container.0)
                            })
                            .collect(),
                    )?;
                (
                    Self::Message(state),
                    BackupRestoreLoop::Instruction(BackupRestoreInstruction {
                        identity_data: None,
                        state_update: None,
                        read_instruction,
                    }),
                )
            },
            ContainerReaderResult::Done => {
                // Dissolve to do sanity checks and discard the result as we are done with the entire backup
                // restore.
                let _ = state.container_reader.dissolve()?;
                let state = Self::Done;
                debug!(?state, "Changing state");
                (state, BackupRestoreLoop::Done(()))
            },
        })
    }
}

/// The initial context needed to restore a backup.
pub struct BackupRestoreProviders {
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

/// Task for restoring a backup.
#[derive(Educe, Name)]
#[educe(Debug)]
pub struct BackupRestoreTask {
    #[educe(Debug(ignore))]
    providers: Option<BackupRestoreProviders>,
    state: State,
    read_bytes: usize,
}
impl BackupRestoreTask {
    /// Create a new task for restoring a backup.
    pub fn new(password: DataBackupPassword) -> Self {
        debug!("Creating backup restore task");
        let header_and_layout_decoder = FixedLengthFrameDecoder::new();
        let state = State::Layout(LayoutState {
            password,
            header_and_layout_decoder,
        });

        debug!(?state, "Starting with initial state");
        Self {
            providers: None,
            state,
            read_bytes: 0,
        }
    }

    fn poll_with_providers<PollFn, TState>(
        providers: Option<&BackupRestoreProviders>,
        poll_function: PollFn,
        state: TState,
    ) -> Result<(State, BackupRestoreLoop), BackupRestoreError>
    where
        PollFn:
            FnOnce(&BackupRestoreProviders, TState) -> Result<(State, BackupRestoreLoop), BackupRestoreError>,
    {
        match providers {
            Some(providers) => poll_function(providers, state),
            None => Err(BackupRestoreError::InvalidState(
                "Providers must be initialized".to_owned(),
            )),
        }
    }

    /// Poll to advance the state.
    ///
    /// # Errors
    ///
    /// Returns [`BackupRestoreError`] for all possible reasons.
    #[tracing::instrument(skip_all, fields(?self))]
    pub fn poll(&mut self) -> Result<BackupRestoreLoop, BackupRestoreError> {
        let result = match mem::replace(
            &mut self.state,
            State::Error(BackupRestoreError::InvalidState(format!(
                "{} in a transitional state",
                Self::NAME
            ))),
        ) {
            State::Layout(state) => State::poll_reading_layout(state),
            State::ReadUserData(state) => State::poll_read_user_data(state),
            State::AddUserData(state) => {
                Self::poll_with_providers(self.providers.as_ref(), State::poll_add_user_data, *state)
            },
            State::Contact(state) => {
                Self::poll_with_providers(self.providers.as_ref(), State::poll_contacts, state)
            },
            State::DistributionList(state) => {
                Self::poll_with_providers(self.providers.as_ref(), State::poll_distribution_lists, state)
            },
            State::Group(state) => {
                Self::poll_with_providers(self.providers.as_ref(), State::poll_groups, state)
            },
            State::CspNonce(state) => {
                Self::poll_with_providers(self.providers.as_ref(), State::poll_csp_nonces, state)
            },
            State::Poll(state) => {
                Self::poll_with_providers(self.providers.as_ref(), State::poll_polls, state)
            },
            State::Message(state) => {
                Self::poll_with_providers(self.providers.as_ref(), State::poll_messages, state)
            },
            State::Done => Err(BackupRestoreError::InvalidState(format!(
                "{} already done",
                Self::NAME
            ))),
            State::Error(error) => Err(error),
        };

        match result {
            Ok((state, instruction)) => {
                self.state = state;
                Ok(instruction)
            },
            Err(error) => {
                self.state = State::Error(error.clone());
                Err(error)
            },
        }
    }

    /// Add providers.
    ///
    /// Important: This must be done if and only if [`BackupRestoreTask::poll`] returned the identity data as
    /// part of the [`BackupRestoreInstruction`].
    ///
    /// # Errors
    ///
    /// Returns a [`BackupRestoreError`] if the task is in an invalid state.
    pub fn add_providers(&mut self, providers: BackupRestoreProviders) -> Result<(), BackupRestoreError> {
        match &self.state {
            State::AddUserData(_) => match self.providers.replace(providers) {
                Some(_) => {
                    let message = "Providers have already been added".to_owned();
                    error!(message);
                    Err(BackupRestoreError::InvalidState(message))
                },
                None => Ok(()),
            },
            State::Layout(_)
            | State::ReadUserData(_)
            | State::Contact(_)
            | State::DistributionList(_)
            | State::Group(_)
            | State::CspNonce(_)
            | State::Poll(_)
            | State::Message(_)
            | State::Done => {
                let message = format!("Providers can only be added in {} state", State::ADD_USER_DATA);
                error!(message);
                Err(BackupRestoreError::InvalidState(message))
            },
            State::Error(error) => {
                let message = "Cannot add providers in the error state".to_owned();
                error!(?error, message);
                Err(BackupRestoreError::InvalidState(message))
            },
        }
    }

    /// Add a chunk after handling a [`BackupRestoreInstruction`].
    ///
    /// Returns the number of bytes that have been read so far. Divided by the total length of the stream this
    /// indicates a rough progress of the restore process.
    ///
    /// # Errors
    ///
    /// Returns a [`BackupRestoreError`] if the task is in an invalid state.
    #[tracing::instrument(skip_all, fields(?read_response, state = ?self.state ))]
    pub fn response(&mut self, read_response: BackupRestoreResponse) -> Result<usize, BackupRestoreError> {
        let chunk_length = read_response.chunk.len();
        trace!(length = ?chunk_length, "Adding chunk");

        match &mut self.state {
            State::Layout(reading_layout_state) => {
                if read_response.offset.0 != 0 {
                    return Err(BackupRestoreError::InvalidParameter(
                        "Provided data must be at offset 0".to_owned(),
                    ));
                }

                let _ = reading_layout_state
                    .header_and_layout_decoder
                    .add_chunks(&[read_response.chunk.as_slice()]);
                Ok(())
            },
            State::ReadUserData(state) => state.container_reader.add_page(read_response),
            State::AddUserData(state) => state.container_reader.add_page(read_response),
            State::Contact(state) => state.container_reader.add_page(read_response),
            State::DistributionList(state) => state.container_reader.add_page(read_response),
            State::Group(state) => state.container_reader.add_page(read_response),
            State::CspNonce(state) => state.container_reader.add_page(read_response),
            State::Poll(state) => state.container_reader.add_page(read_response),
            State::Message(state) => state.container_reader.add_page(read_response),
            State::Done => {
                let message = "Cannot add a chunk in the done state".to_owned();
                error!(message);
                Err(BackupRestoreError::InvalidState(message))
            },
            State::Error(error) => {
                let message = "Cannot add a chunk in the error state".to_owned();
                error!(?error, message);
                Err(BackupRestoreError::InvalidState(message))
            },
        }?;

        self.read_bytes = self
            .read_bytes
            .checked_add(chunk_length)
            .ok_or(OverflowError { name: "read bytes" })?;

        Ok(self.read_bytes)
    }
}
