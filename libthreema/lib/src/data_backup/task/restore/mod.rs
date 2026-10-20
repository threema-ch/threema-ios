//! Backup restore task.
use core::{iter, mem, ops::RangeInclusive};

use educe::Educe;
use itertools::Itertools as _;
use libthreema_macros::{DebugVariantNames, Name, VariantNames};
use tracing::{debug, trace};

use crate::{
    common::{
        HashedNonce, StreamOffset,
        keys::{DataBackupRootKey, DataBackupSalt},
        task::TaskLoop,
    },
    data_backup::{
        DataBackupRestoreError,
        accountant::BackupAccountant,
        cipher::LayoutDecryptor,
        codec::container::ContainerDecoder as _,
        common::{Category, HeaderAndLayout, Layout, UserData},
        task::{
            DataBackupProviders,
            restore::reader::{PageBatch, PageDataBuffer, PageReader, PageReaderCheckpoint},
        },
    },
    model::{
        contact::ContactWithProfilePictures,
        distribution_list::DistributionList,
        group::GroupWithProfilePicture,
        message::MessageState,
        poll::Poll,
        settings::Settings,
        user_profile::{IdentityData, UserProfile},
    },
    protobuf,
    utils::{
        debug::{Name as _, debug_slice_length},
        frame::{
            FixedLengthFrameDecoder, VariableLengthFrameDecoder,
            VariableLengthFrameDecoderU32LittleEndianDelimited,
        },
    },
};

mod reader;

const SUPPORTED_VERSION_RANGE: RangeInclusive<u16> =
    protobuf::data_backup::ProtocolVersion::V0 as u16..=protobuf::data_backup::ProtocolVersion::V0 as u16;

/// Instruction to read a chunk of bytes from a local storage as part of a
/// [`DataBackupRestoreInstruction`].
///
/// 1. Let `source` be the source from which the bytes should be read from.
/// 2. Read `chunk` as the range of `source` from `offset` (inclusive) to `offset` + `length` (exclusive).
/// 3. If reading `chunk` failed, log an error, exceptionally abort the task.
/// 4. Provide `chunk` together with `offset` to the associated task as a [`DataBackupRestoreResponse`] and
///    poll again.
#[derive(Copy, Clone, Debug)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct DataBackupRestoreLocalReadInstruction {
    /// The start of the requested chunk of bytes.
    pub offset: StreamOffset,

    /// The length of the requested chunk of bytes.
    pub length: u32,
}
impl TryFrom<PageBatch> for DataBackupRestoreLocalReadInstruction {
    type Error = DataBackupRestoreError;

    fn try_from(batch: PageBatch) -> Result<Self, Self::Error> {
        Ok(Self {
            offset: batch.offset.try_into()?,
            length: batch.length,
        })
    }
}

/// 1. Let `instruction` be the provided read instruction and handle it as described in the enum variant.
#[derive(Debug)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum DataBackupRestoreReadInstruction {
    /// Apply a local storage instruction. See [`DataBackupRestoreLocalReadInstruction`] for more details.
    Local(DataBackupRestoreLocalReadInstruction),
}

/// Possible response to a [`DataBackupRestoreReadInstruction`].
#[derive(Educe)]
#[educe(Debug)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct DataBackupRestoreReadResponse {
    /// The offset as defined in the [`DataBackupRestoreLocalReadInstruction`].
    pub offset: StreamOffset,

    /// The chunk as defined in the [`DataBackupRestoreLocalReadInstruction`].
    #[educe(Debug(method(debug_slice_length)))]
    pub chunk: Vec<u8>,
}

/// Possible response for a [`DataBackupRestoreTask`].
pub struct DataBackupRestoreResponse {
    /// Required to provide (exactly once) when [`IdentityData`] was present in the
    /// [`DataBackupRestoreInstruction`].
    pub providers: Option<DataBackupProviders>,

    /// Required to provide when a [`DataBackupRestoreReadInstruction`] was present in the
    /// [`DataBackupRestoreInstruction`].
    pub read_response: Option<DataBackupRestoreReadResponse>,
}

/// A state update, indicating transition to the next state in the data backup restore task.
///
/// When handling this state update, run the following steps:
///
/// 1. Let `state_update` be the [`DataBackupRestoreStateUpdate`].
/// 2. Advance the displayed status indicator to `state_update`.
///
/// Note: State updates can be expected to appear in the declaration order below.
#[derive(Clone, Copy, Debug)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
#[cfg_attr(test, derive(PartialEq, Eq))]
pub enum DataBackupRestoreStateUpdate {
    /// Now restoring user data.
    UserData,

    /// Now restoring contacts.
    Contacts,

    /// Now restoring distribution lists.
    DistributionLists,

    /// Now restoring groups.
    Groups,

    /// Now restoring CSP nonces.
    CspNonces,

    /// Now restoring polls.
    Polls,

    /// Now restoring messages.
    Messages,
}

/// An instruction returned by the restore task that the client must handle before polling again.
///
/// When handling this instruction, run the following steps:
///
/// 1. If `identity_data` is present:
///    1. Add `identity_data` to the application storage.
///    2. If the app is built for the _OnPrem_ flavour and the MDM parameters indicate that remote secret is
///       enabled, create and run a [`crate::remote_secret::setup::create::RemoteSecretCreateTask`].
///    3. Provide the [`DataBackupProviders`] as a response to the task.
/// 2. If `state_update` is present, handle it according to the steps defined in
///    [`DataBackupRestoreStateUpdate`].
/// 3. If `read_instruction` is present, handle it according to the steps defined in
///    [`DataBackupRestoreReadInstruction`].
pub struct DataBackupRestoreInstruction {
    /// User data.
    pub identity_data: Option<IdentityData>,

    /// The state to which the data backup restore task was advanced to.
    pub state_update: Option<DataBackupRestoreStateUpdate>,

    /// The read instruction that should be processed by the client.
    pub read_instruction: Option<DataBackupRestoreReadInstruction>,
}

/// Result of polling a [`DataBackupRestoreTask`].
pub type DataBackupRestoreLoop = TaskLoop<DataBackupRestoreInstruction, ()>;

/// [`HeaderAndLayout`] frame decoder.
type HeaderAndLayoutDecoder = FixedLengthFrameDecoder<{ HeaderAndLayout::LENGTH }>;

/// Acts as glue between reading pages and the respective location in the layout.
struct LayoutTracker {
    layout: Layout,
}
impl LayoutTracker {
    /// Create a page reader for a specific category, starting at the respective category span as declared by
    /// the layout.
    fn next_reader<TBuffer>(
        &mut self,
        checkpoint: PageReaderCheckpoint,
        category: Category,
        buffer: TBuffer,
    ) -> Result<PageReader<TBuffer>, DataBackupRestoreError>
    where
        TBuffer: PageDataBuffer,
    {
        let span = self.layout.span(category)?;
        Ok(PageReader::new(checkpoint, category, span, buffer)?)
    }
}

struct LayoutState {
    password: String,
    decoder: HeaderAndLayoutDecoder,
}

#[derive(Name)]
struct ReadUserDataState {
    layout_tracker: LayoutTracker,
    page_reader: PageReader<VariableLengthFrameDecoderU32LittleEndianDelimited>,
}

/// Note: This is an intermediate state that exists solely to give the clients a chance to add the providers.
struct AddUserDataState {
    layout_tracker: LayoutTracker,
    user_profile: UserProfile,
    settings: Box<Settings>,
    accountant: BackupAccountant,
    providers: Option<DataBackupProviders>,
    page_reader_checkpoint: PageReaderCheckpoint,
}

struct ContactsState {
    layout_tracker: LayoutTracker,
    accountant: BackupAccountant,
    providers: DataBackupProviders,
    page_reader: PageReader<VariableLengthFrameDecoderU32LittleEndianDelimited>,
}

struct DistributionListsState {
    layout_tracker: LayoutTracker,
    accountant: BackupAccountant,
    providers: DataBackupProviders,
    page_reader: PageReader<VariableLengthFrameDecoderU32LittleEndianDelimited>,
}

struct GroupsState {
    layout_tracker: LayoutTracker,
    accountant: BackupAccountant,
    providers: DataBackupProviders,
    page_reader: PageReader<VariableLengthFrameDecoderU32LittleEndianDelimited>,
}

struct CspNoncesState {
    layout_tracker: LayoutTracker,
    accountant: BackupAccountant,
    providers: DataBackupProviders,
    page_reader: PageReader<FixedLengthFrameDecoder<{ HashedNonce::LENGTH }>>,
}

struct PollsState {
    layout_tracker: LayoutTracker,
    accountant: BackupAccountant,
    providers: DataBackupProviders,
    page_reader: PageReader<VariableLengthFrameDecoderU32LittleEndianDelimited>,
}

struct MessagesState {
    accountant: BackupAccountant,
    providers: DataBackupProviders,
    page_reader: PageReader<VariableLengthFrameDecoderU32LittleEndianDelimited>,
}

#[derive(DebugVariantNames, VariantNames)]
enum State {
    Layout(LayoutState),
    ReadUserData(ReadUserDataState),
    AddUserData(AddUserDataState),
    Contacts(ContactsState),
    DistributionLists(DistributionListsState),
    Groups(GroupsState),
    CspNonces(CspNoncesState),
    Polls(PollsState),
    Messages(MessagesState),
    Done,
    Error(DataBackupRestoreError),
}
impl State {
    #[tracing::instrument(skip_all)]
    fn poll_layout(mut state: LayoutState) -> Result<(Self, DataBackupRestoreLoop), DataBackupRestoreError> {
        // Read the header and the encrypted layout.
        let Some((header, layout)) = state
            .decoder
            .next_frame_and_then(HeaderAndLayout::decode)
            .transpose()?
        else {
            let instruction = DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                identity_data: None,
                state_update: None,
                read_instruction: Some(DataBackupRestoreReadInstruction::Local(
                    DataBackupRestoreLocalReadInstruction {
                        offset: StreamOffset(state.decoder.buffered_length() as u64),
                        length: state
                            .decoder
                            .required_length()
                            .try_into()
                            .expect("Length of header and layout fits into u32"),
                    },
                )),
            });
            return Ok((Self::Layout(state), instruction));
        };
        trace!(version = header.version, "Decoded header and encrypted layout");

        // Check version and whether the backup was written completely (does not contain stub values).
        if !SUPPORTED_VERSION_RANGE.contains(&header.version) {
            return Err(DataBackupRestoreError::UnsupportedVersion(header.version));
        }
        if header.salt.0 == [0; DataBackupSalt::LENGTH] {
            return Err(DataBackupRestoreError::IncompleteDataBackup);
        }

        // Decrypt and decode layout.
        let key = DataBackupRootKey::from_password(state.password, &header.salt);
        let layout = Layout::decode(&LayoutDecryptor::new(key.layout_key()).decrypt(header.bytes, layout)?)?;
        trace!(?layout, "Decoded and decrypted layout");

        // Advance to the next state.
        let mut layout_tracker = LayoutTracker { layout };
        let page_reader = layout_tracker.next_reader(
            PageReaderCheckpoint { key: key.page_key() },
            Category::UserData,
            VariableLengthFrameDecoder::new(),
        )?;
        Ok((
            Self::ReadUserData(ReadUserDataState {
                layout_tracker,
                page_reader,
            }),
            DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                identity_data: None,
                state_update: Some(DataBackupRestoreStateUpdate::UserData),
                read_instruction: None,
            }),
        ))
    }

    #[tracing::instrument(skip_all)]
    fn poll_read_user_data(
        mut state: ReadUserDataState,
    ) -> Result<(Self, DataBackupRestoreLoop), DataBackupRestoreError> {
        // Read user data, or request more data.
        let Some(mut user_data) = state
            .page_reader
            .buffer()
            .next_frame_and_then(UserData::decode)
            .transpose()?
        else {
            let Some(batch) = state.page_reader.next_batch()? else {
                return Err(DataBackupRestoreError::IncompleteDataBackup);
            };
            return Ok((
                Self::ReadUserData(state),
                DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                    identity_data: None,
                    state_update: None,
                    read_instruction: Some(DataBackupRestoreReadInstruction::Local(batch.try_into()?)),
                }),
            ));
        };
        let page_reader_checkpoint = state.page_reader.expect_consumed()?;

        // Sanitize settings.
        let accountant = BackupAccountant::new(user_data.identity_data.user_identity);
        user_data.settings = accountant.sanitize_settings(user_data.settings);

        // Advance to the next state.
        Ok((
            Self::AddUserData(AddUserDataState {
                layout_tracker: state.layout_tracker,
                user_profile: user_data.user_profile,
                settings: Box::new(user_data.settings),
                accountant,
                providers: None,
                page_reader_checkpoint,
            }),
            DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                identity_data: Some(user_data.identity_data),
                state_update: None,
                read_instruction: None,
            }),
        ))
    }

    /// Note: This is an intermediate state to allow the caller to provide providers.
    #[tracing::instrument(skip_all)]
    fn poll_add_user_data(
        mut state: AddUserDataState,
    ) -> Result<(Self, DataBackupRestoreLoop), DataBackupRestoreError> {
        // Bail if the providers have not been added.
        let Some(providers) = state.providers else {
            return Err(DataBackupRestoreError::ContractViolation(
                "Providers must be initialized".to_owned(),
            ));
        };

        // Set the user profile.
        debug!("Applying user profile");
        trace!(user_profile = ?state.user_profile);
        providers.user_profile.lock()?.set(state.user_profile)?;

        // Set the settings.
        debug!("Applying user settings");
        trace!(settings = ?state.settings);
        providers.settings.lock()?.set(*state.settings)?;

        // Advance to the next state.
        let page_reader = state.layout_tracker.next_reader(
            state.page_reader_checkpoint,
            Category::Contacts,
            VariableLengthFrameDecoder::new(),
        )?;
        Ok((
            Self::Contacts(ContactsState {
                layout_tracker: state.layout_tracker,
                accountant: state.accountant,
                providers,
                page_reader,
            }),
            DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                identity_data: None,
                state_update: Some(DataBackupRestoreStateUpdate::Contacts),
                read_instruction: None,
            }),
        ))
    }

    #[tracing::instrument(skip_all)]
    fn poll_contacts(
        mut state: ContactsState,
    ) -> Result<(Self, DataBackupRestoreLoop), DataBackupRestoreError> {
        // Read contacts.
        let contacts = iter::from_fn(|| {
            state
                .page_reader
                .buffer()
                .next_frame_and_then(ContactWithProfilePictures::decode)
        })
        .filter_ok(|contact| state.accountant.check_and_add_contact(&contact.contact))
        .collect::<Result<Vec<_>, _>>()?;
        state
            .providers
            .contacts
            .lock()?
            .add_with_profile_pictures(contacts)?;

        // Request more data until all contacts have been read.
        if let Some(batch) = state.page_reader.next_batch()? {
            return Ok((
                Self::Contacts(state),
                DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                    identity_data: None,
                    state_update: None,
                    read_instruction: Some(DataBackupRestoreReadInstruction::Local(batch.try_into()?)),
                }),
            ));
        }
        let page_reader_checkpoint = state.page_reader.expect_consumed()?;

        // Advance to the next state.
        let page_reader = state.layout_tracker.next_reader(
            page_reader_checkpoint,
            Category::DistributionLists,
            VariableLengthFrameDecoder::new(),
        )?;
        Ok((
            Self::DistributionLists(DistributionListsState {
                layout_tracker: state.layout_tracker,
                accountant: state.accountant,
                providers: state.providers,
                page_reader,
            }),
            DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                identity_data: None,
                state_update: Some(DataBackupRestoreStateUpdate::DistributionLists),
                read_instruction: None,
            }),
        ))
    }

    #[tracing::instrument(skip_all)]
    fn poll_distribution_lists(
        mut state: DistributionListsState,
    ) -> Result<(Self, DataBackupRestoreLoop), DataBackupRestoreError> {
        // Read distribution lists.
        let distribution_lists = iter::from_fn(|| {
            state
                .page_reader
                .buffer()
                .next_frame_and_then(DistributionList::decode)
        })
        .filter_map_ok(|distribution_list| {
            state
                .accountant
                .sanitize_and_add_distribution_list(distribution_list)
        })
        .collect::<Result<Vec<_>, _>>()?;
        state
            .providers
            .distribution_lists
            .lock()?
            .add(distribution_lists)?;

        // Request more data until all distribution lists have been read.
        if let Some(batch) = state.page_reader.next_batch()? {
            return Ok((
                Self::DistributionLists(state),
                DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                    identity_data: None,
                    state_update: None,
                    read_instruction: Some(DataBackupRestoreReadInstruction::Local(batch.try_into()?)),
                }),
            ));
        }
        let page_reader_checkpoint = state.page_reader.expect_consumed()?;

        // Advance to the next state.
        let page_reader = state.layout_tracker.next_reader(
            page_reader_checkpoint,
            Category::Groups,
            VariableLengthFrameDecoder::new(),
        )?;
        Ok((
            Self::Groups(GroupsState {
                layout_tracker: state.layout_tracker,
                accountant: state.accountant,
                providers: state.providers,
                page_reader,
            }),
            DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                identity_data: None,
                state_update: Some(DataBackupRestoreStateUpdate::Groups),
                read_instruction: None,
            }),
        ))
    }

    fn poll_groups(mut state: GroupsState) -> Result<(Self, DataBackupRestoreLoop), DataBackupRestoreError> {
        // Read groups.
        let groups = iter::from_fn(|| {
            state
                .page_reader
                .buffer()
                .next_frame_and_then(GroupWithProfilePicture::decode)
        })
        .filter_map_ok(|group| state.accountant.sanitize_and_add_group(group))
        .collect::<Result<Vec<_>, _>>()?;
        state.providers.groups.lock()?.add_with_profile_picture(groups)?;

        // Request more data until all groups have been read.
        if let Some(batch) = state.page_reader.next_batch()? {
            return Ok((
                Self::Groups(state),
                DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                    identity_data: None,
                    state_update: None,
                    read_instruction: Some(DataBackupRestoreReadInstruction::Local(batch.try_into()?)),
                }),
            ));
        }
        let page_reader_checkpoint = state.page_reader.expect_consumed()?;

        // Advance to the next state.
        let page_reader = state.layout_tracker.next_reader(
            page_reader_checkpoint,
            Category::CspNonces,
            FixedLengthFrameDecoder::new(),
        )?;
        Ok((
            Self::CspNonces(CspNoncesState {
                layout_tracker: state.layout_tracker,
                accountant: state.accountant,
                providers: state.providers,
                page_reader,
            }),
            DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                identity_data: None,
                state_update: Some(DataBackupRestoreStateUpdate::CspNonces),
                read_instruction: None,
            }),
        ))
    }

    #[tracing::instrument(skip_all)]
    fn poll_csp_nonces(
        mut state: CspNoncesState,
    ) -> Result<(Self, DataBackupRestoreLoop), DataBackupRestoreError> {
        // Read CSP nonces.
        let nonces = iter::from_fn(|| {
            state
                .page_reader
                .buffer()
                .next_frame_and_then(|nonce| HashedNonce::from(*nonce))
        })
        .collect::<Vec<_>>();
        state.providers.csp_nonces.lock()?.add_many(nonces)?;

        // Request more data until all CSP nonces have been read.
        if let Some(batch) = state.page_reader.next_batch()? {
            return Ok((
                Self::CspNonces(state),
                DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                    identity_data: None,
                    state_update: None,
                    read_instruction: Some(DataBackupRestoreReadInstruction::Local(batch.try_into()?)),
                }),
            ));
        }
        let page_reader_checkpoint = state.page_reader.expect_consumed()?;

        // Advance to the next state.
        let page_reader = state.layout_tracker.next_reader(
            page_reader_checkpoint,
            Category::Polls,
            VariableLengthFrameDecoder::new(),
        )?;
        Ok((
            Self::Polls(PollsState {
                layout_tracker: state.layout_tracker,
                accountant: state.accountant,
                providers: state.providers,
                page_reader,
            }),
            DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                identity_data: None,
                state_update: Some(DataBackupRestoreStateUpdate::Polls),
                read_instruction: None,
            }),
        ))
    }

    fn poll_polls(mut state: PollsState) -> Result<(Self, DataBackupRestoreLoop), DataBackupRestoreError> {
        // Read polls.
        let polls = iter::from_fn(|| state.page_reader.buffer().next_frame_and_then(Poll::decode))
            .filter_ok(|poll| state.accountant.check_and_add_poll(poll))
            .collect::<Result<Vec<_>, _>>()?;
        state.providers.polls.lock()?.add(polls)?;

        // Request more data until all polls have been read.
        if let Some(batch) = state.page_reader.next_batch()? {
            return Ok((
                Self::Polls(state),
                DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                    identity_data: None,
                    state_update: None,
                    read_instruction: Some(DataBackupRestoreReadInstruction::Local(batch.try_into()?)),
                }),
            ));
        }
        let page_reader_checkpoint = state.page_reader.expect_consumed()?;

        // Advance to the next state.
        let page_reader = state.layout_tracker.next_reader(
            page_reader_checkpoint,
            Category::Messages,
            VariableLengthFrameDecoder::new(),
        )?;
        Ok((
            Self::Messages(MessagesState {
                accountant: state.accountant,
                providers: state.providers,
                page_reader,
            }),
            DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                identity_data: None,
                state_update: Some(DataBackupRestoreStateUpdate::Messages),
                read_instruction: None,
            }),
        ))
    }

    #[tracing::instrument(skip_all)]
    fn poll_messages(
        mut state: MessagesState,
    ) -> Result<(Self, DataBackupRestoreLoop), DataBackupRestoreError> {
        // Read messages.
        let messages = iter::from_fn(|| {
            state
                .page_reader
                .buffer()
                .next_frame_and_then(MessageState::decode)
        })
        .filter_map_ok(|message| state.accountant.sanitize_and_add_message(message))
        .collect::<Result<Vec<_>, _>>()?;
        state.providers.conversations.lock()?.add_messages(messages)?;

        // Request more data until all messages have been read.
        if let Some(batch) = state.page_reader.next_batch()? {
            return Ok((
                Self::Messages(state),
                DataBackupRestoreLoop::Instruction(DataBackupRestoreInstruction {
                    identity_data: None,
                    state_update: None,
                    read_instruction: Some(DataBackupRestoreReadInstruction::Local(batch.try_into()?)),
                }),
            ));
        }
        let _ = state.page_reader.expect_consumed()?;

        // Advance to the next state.
        Ok((Self::Done, DataBackupRestoreLoop::Done(())))
    }
}

/// Task for restoring a data backup.
///
/// The task progresses through the states as indicated by [`DataBackupRestoreStateUpdate`] sequentially. Any
/// error condition returned by the restore task should result in a rollback of the partial data backup on
/// client side!
#[derive(Educe, Name)]
#[educe(Debug)]
pub struct DataBackupRestoreTask {
    state: State,
}
impl DataBackupRestoreTask {
    /// Create a new task for restoring a data backup.
    #[must_use]
    #[tracing::instrument(skip_all)]
    pub fn new(password: String) -> Self {
        Self {
            state: State::Layout(LayoutState {
                password,
                decoder: FixedLengthFrameDecoder::new(),
            }),
        }
    }

    /// Poll to advance the state.
    ///
    /// Returns a [`DataBackupRestoreLoop`] indicating the next action. If this method returns an error, the
    /// task is permanently in the error state. Subsequent calls will return the same error.
    ///
    /// # Errors
    ///
    /// Returns [`DataBackupRestoreError`] for all possible reasons, including provider errors propagated from
    /// the client application.
    #[tracing::instrument(skip_all, fields(?self))]
    pub fn poll(&mut self) -> Result<DataBackupRestoreLoop, DataBackupRestoreError> {
        let result = match mem::replace(
            &mut self.state,
            State::Error(DataBackupRestoreError::ContractViolation(format!(
                "{} in a transitional state",
                Self::NAME
            ))),
        ) {
            State::Layout(state) => State::poll_layout(state),
            State::ReadUserData(state) => State::poll_read_user_data(state),
            State::AddUserData(state) => State::poll_add_user_data(state),
            State::Contacts(state) => State::poll_contacts(state),
            State::DistributionLists(state) => State::poll_distribution_lists(state),
            State::Groups(state) => State::poll_groups(state),
            State::CspNonces(state) => State::poll_csp_nonces(state),
            State::Polls(state) => State::poll_polls(state),
            State::Messages(state) => State::poll_messages(state),
            State::Done => Err(DataBackupRestoreError::ContractViolation(format!(
                "{} already done",
                Self::NAME
            ))),
            State::Error(error) => Err(error),
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

    /// Possible results after handling a [`DataBackupRestoreInstruction`].
    ///
    /// # Errors
    ///
    /// Returns a [`DataBackupRestoreError`] if the task is in an invalid state.
    #[tracing::instrument(skip_all, fields(state = ?self.state))]
    pub fn response(
        &mut self,
        DataBackupRestoreResponse {
            providers,
            read_response,
        }: DataBackupRestoreResponse,
    ) -> Result<(), DataBackupRestoreError> {
        // Handle providers.
        if let Some(providers) = providers {
            let State::AddUserData(state) = &mut self.state else {
                return Err(DataBackupRestoreError::ContractViolation(format!(
                    "Must be in '{}' state to add providers",
                    State::ADD_USER_DATA,
                )));
            };
            if state.providers.is_some() {
                return Err(DataBackupRestoreError::ContractViolation(
                    "Providers have already been added".to_owned(),
                ));
            }
            state.providers = Some(providers);
        }

        // Handle read response.
        if let Some(read_response) = read_response {
            // Add chunk to the respective decoder/reader.
            let chunk_length = read_response.chunk.len();
            trace!(length = ?chunk_length, "Adding chunk");
            match &mut self.state {
                State::Layout(state) => {
                    let _ = state.decoder.add_chunks(&[read_response.chunk.as_slice()]);
                    Ok(())
                },
                State::ReadUserData(state) => state
                    .page_reader
                    .add_pages(read_response.offset.try_into()?, &read_response.chunk),
                State::Contacts(state) => state
                    .page_reader
                    .add_pages(read_response.offset.try_into()?, &read_response.chunk),
                State::DistributionLists(state) => state
                    .page_reader
                    .add_pages(read_response.offset.try_into()?, &read_response.chunk),
                State::Groups(state) => state
                    .page_reader
                    .add_pages(read_response.offset.try_into()?, &read_response.chunk),
                State::CspNonces(state) => state
                    .page_reader
                    .add_pages(read_response.offset.try_into()?, &read_response.chunk),
                State::Polls(state) => state
                    .page_reader
                    .add_pages(read_response.offset.try_into()?, &read_response.chunk),
                State::Messages(state) => state
                    .page_reader
                    .add_pages(read_response.offset.try_into()?, &read_response.chunk),
                State::AddUserData(_) | State::Done | State::Error(_) => {
                    return Err(DataBackupRestoreError::ContractViolation(format!(
                        "Cannot add a chunk in the '{}' state",
                        self.state.variant_name()
                    )));
                },
            }?;
        }

        Ok(())
    }
}
