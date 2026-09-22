//! Bindings for the _Data Backup_.

use core::num::TryFromIntError;

use crate::data_backup;

/// Binding version of [`data_backup::StreamOffset`].
#[derive(uniffi::Record)]
pub struct StreamOffset {
    /// The byte offset.
    pub offset: u64,
}
impl From<data_backup::StreamOffset> for StreamOffset {
    fn from(stream_offset: data_backup::StreamOffset) -> Self {
        Self {
            offset: stream_offset.0 as u64,
        }
    }
}
impl TryFrom<StreamOffset> for data_backup::StreamOffset {
    type Error = TryFromIntError;

    fn try_from(offset: StreamOffset) -> Result<Self, Self::Error> {
        Ok(Self(offset.offset.try_into()?))
    }
}

pub mod create {
    //! Bindings for creating the data backup.

    use std::sync::{Arc, Mutex};

    use libthreema_macros::UniffiNewType;

    use crate::{
        bindings::uniffi::{
            model::{
                contact::ContactProvider,
                conversation::ConversationProvider,
                distribution_list::DistributionListProvider,
                group::GroupProvider,
                poll::PollProvider,
                settings::SettingsProvider,
                user_profile::{IdentityData, UserProfileProvider},
            },
            provider::NonceProvider,
        },
        common,
        data_backup::task::create,
        utils::sync::MutexIgnorePoison as _,
    };

    /// Binding version of [`create::LocalWriteInstruction`].
    #[derive(uniffi::Enum)]
    #[expect(missing_docs, reason = "Binding version")]
    pub enum LocalWriteInstruction {
        Append(Vec<u8>),
        WriteAt { offset: u64, data: Vec<u8> },
    }
    impl From<create::LocalWriteInstruction> for LocalWriteInstruction {
        fn from(instruction: create::LocalWriteInstruction) -> Self {
            match instruction {
                create::LocalWriteInstruction::Append(data) => Self::Append(data),
                create::LocalWriteInstruction::WriteAt { offset, data } => Self::WriteAt {
                    offset: offset as u64,
                    data,
                },
            }
        }
    }

    #[derive(uniffi::Enum)]
    #[expect(missing_docs, reason = "Binding version")]
    pub enum WriteInstruction {
        Local(LocalWriteInstruction),
        Remote,
    }
    impl From<create::WriteInstruction> for WriteInstruction {
        fn from(instruction: create::WriteInstruction) -> Self {
            match instruction {
                create::WriteInstruction::Local(local_write_instruction) => {
                    Self::Local(local_write_instruction.into())
                },

                create::WriteInstruction::Remote => Self::Remote,
            }
        }
    }

    /// Binding version of [`create::BackupCreateStateUpdate`].
    #[derive(uniffi::Enum)]
    #[expect(missing_docs, reason = "Binding version")]
    pub enum BackupCreateStateUpdate {
        InitialState,
        Contacts(u64),
        DistributionLists(u64),
        Groups(u64),
        CspNonces(u64),
        Polls(u64),
        Messages(u64),
        FinalizeState,
    }
    impl From<create::BackupCreateStateUpdate> for BackupCreateStateUpdate {
        fn from(update: create::BackupCreateStateUpdate) -> Self {
            match update {
                create::BackupCreateStateUpdate::InitialState => Self::InitialState,
                create::BackupCreateStateUpdate::Contacts(written_contacts) => {
                    Self::Contacts(written_contacts as u64)
                },
                create::BackupCreateStateUpdate::DistributionLists(written_distribution_lists) => {
                    Self::DistributionLists(written_distribution_lists as u64)
                },
                create::BackupCreateStateUpdate::Groups(written_groups) => {
                    Self::Groups(written_groups as u64)
                },
                create::BackupCreateStateUpdate::CspNonces(written_nonces) => {
                    Self::CspNonces(written_nonces as u64)
                },
                create::BackupCreateStateUpdate::Polls(written_polls) => Self::Polls(written_polls as u64),
                create::BackupCreateStateUpdate::Messages(written_messages) => {
                    Self::Messages(written_messages as u64)
                },
                create::BackupCreateStateUpdate::FinalizeState => Self::FinalizeState,
            }
        }
    }

    /// Binding version of [`create::BackupCreateInstruction`].
    #[derive(uniffi::Record)]
    #[expect(missing_docs, reason = "Binding version")]
    pub struct BackupCreateInstruction {
        pub write_instruction: Option<WriteInstruction>,
        pub state_update: Option<BackupCreateStateUpdate>,
    }
    impl From<create::BackupCreateInstruction> for BackupCreateInstruction {
        fn from(instruction: create::BackupCreateInstruction) -> Self {
            Self {
                write_instruction: instruction.write_instruction.map(WriteInstruction::from),
                state_update: instruction.state_update.map(BackupCreateStateUpdate::from),
            }
        }
    }

    /// Binding version of [`create::WrittenBytes`].
    #[derive(UniffiNewType)]
    pub struct WrittenBytes(pub u64);
    impl From<create::WrittenBytes> for WrittenBytes {
        fn from(written_bytes: create::WrittenBytes) -> Self {
            Self(written_bytes.0 as u64)
        }
    }

    /// Binding version of [`create::BackupCreateLoop`].
    #[derive(uniffi::Enum)]
    #[expect(missing_docs, reason = "Binding version")]
    pub enum BackupCreateLoop {
        Instruction(BackupCreateInstruction),
        Done(WrittenBytes),
    }
    impl From<create::BackupCreateLoop> for BackupCreateLoop {
        fn from(create_loop: create::BackupCreateLoop) -> Self {
            match create_loop {
                create::BackupCreateLoop::Instruction(instruction) => Self::Instruction(instruction.into()),
                create::BackupCreateLoop::Done(written_bytes) => Self::Done(written_bytes.into()),
            }
        }
    }

    /// Binding version of [`create::BackupCreateContextInit`].
    #[expect(missing_docs, reason = "Binding version")]
    #[derive(uniffi::Record)]
    pub struct BackupCreateContextInit {
        pub password: String,
        pub identity_data: IdentityData,
        pub user_profile: Arc<dyn UserProfileProvider>,
        pub settings: Arc<dyn SettingsProvider>,
        pub csp_nonces: Arc<dyn NonceProvider>,
        pub contacts: Arc<dyn ContactProvider>,
        pub groups: Arc<dyn GroupProvider>,
        pub distribution_lists: Arc<dyn DistributionListProvider>,
        pub polls: Arc<dyn PollProvider>,
        pub conversations: Arc<dyn ConversationProvider>,
    }
    impl TryFrom<BackupCreateContextInit> for create::BackupCreateContextInit {
        type Error = create::BackupCreateError;

        fn try_from(init: BackupCreateContextInit) -> Result<Self, Self::Error> {
            Ok(Self {
                password: common::keys::DataBackupPassword(init.password),
                identity_data: init.identity_data.try_into()?,
                user_profile: Arc::new(Mutex::new(init.user_profile)),
                settings: Arc::new(Mutex::new(init.settings)),
                contacts: Arc::new(Mutex::new(init.contacts)),
                groups: Arc::new(Mutex::new(init.groups)),
                distribution_lists: Arc::new(Mutex::new(init.distribution_lists)),
                csp_nonces: Arc::new(Mutex::new(init.csp_nonces)),
                polls: Arc::new(Mutex::new(init.polls)),
                conversations: Arc::new(Mutex::new(init.conversations)),
            })
        }
    }

    /// Binding version of [`create::BackupCreateTask`].
    #[derive(uniffi::Object)]
    pub struct BackupCreateTask {
        task: Mutex<create::BackupCreateTask>,
        filename: create::Filename,
    }
    #[uniffi::export]
    impl BackupCreateTask {
        /// Binding version of [`create::BackupCreateTask::new`].
        ///
        /// Note: the filename must be retrieved with [`Self::get_filename`].
        #[expect(clippy::missing_errors_doc, reason = "Binding version")]
        #[uniffi::constructor]
        pub fn new(init: BackupCreateContextInit) -> Result<Self, create::BackupCreateError> {
            let (task, filename) = create::BackupCreateTask::new(init.try_into()?)?;

            Ok(Self {
                task: task.into(),
                filename,
            })
        }

        /// Get the filename of the backup.
        pub fn get_filename(&self) -> create::Filename {
            self.filename.clone()
        }

        /// Binding version of [`create::BackupCreateTask::poll`].
        #[expect(clippy::missing_errors_doc, reason = "Binding version")]
        pub fn poll(&self) -> Result<BackupCreateLoop, create::BackupCreateError> {
            self.task.lock_ignore_poison().poll().map(BackupCreateLoop::from)
        }
    }
}

pub mod restore {
    //! Bindings for restoring the data backup.
    use std::sync::{Arc, Mutex};

    use crate::{
        bindings::uniffi::{
            data_backup::StreamOffset,
            model::{
                contact::ContactProvider,
                conversation::ConversationProvider,
                distribution_list::DistributionListProvider,
                group::GroupProvider,
                poll::PollProvider,
                settings::SettingsProvider,
                user_profile::{IdentityData, UserProfileProvider},
            },
            provider::NonceProvider,
        },
        common::keys::DataBackupPassword,
        data_backup::task::restore,
        utils::sync::MutexIgnorePoison as _,
    };

    /// Binding version of [`restore::LocalReadInstruction`].
    #[derive(uniffi::Record)]
    pub struct LocalReadInstruction {
        /// The start of the requested chunk.
        pub offset: StreamOffset,

        /// The length of the requested chunk.
        pub length: u64,
    }
    impl From<restore::LocalReadInstruction> for LocalReadInstruction {
        fn from(instruction: restore::LocalReadInstruction) -> Self {
            Self {
                offset: instruction.offset.into(),
                length: instruction.length as u64,
            }
        }
    }

    /// Binding version of [`restore::ReadInstruction`].
    #[derive(uniffi::Enum)]
    #[expect(missing_docs, reason = "Binding version")]
    pub enum ReadInstruction {
        Local(LocalReadInstruction),
        Remote,
    }
    impl From<restore::ReadInstruction> for ReadInstruction {
        fn from(instruction: restore::ReadInstruction) -> Self {
            match instruction {
                restore::ReadInstruction::Local(instruction) => Self::Local(instruction.into()),
                restore::ReadInstruction::Remote => Self::Remote,
            }
        }
    }

    /// Binding version of [`restore::BackupRestoreResponse`].
    #[derive(uniffi::Record)]
    #[expect(missing_docs, reason = "Binding version")]
    pub struct BackupRestoreResponse {
        pub offset: StreamOffset,
        pub chunk: Vec<u8>,
    }
    impl TryFrom<BackupRestoreResponse> for restore::BackupRestoreResponse {
        type Error = restore::BackupRestoreError;

        fn try_from(response: BackupRestoreResponse) -> Result<Self, Self::Error> {
            Ok(Self {
                offset: response.offset.try_into().map_err(|_| {
                    restore::BackupRestoreError::InvalidParameter(
                        "Cannot convert stream offset to usize".to_owned(),
                    )
                })?,
                chunk: response.chunk,
            })
        }
    }

    /// Binding version of [`restore::BackupRestoreInstruction`].
    #[derive(uniffi::Record)]
    #[expect(missing_docs, reason = "Binding version")]
    pub struct BackupRestoreInstruction {
        pub identity_data: Option<IdentityData>,
        pub state_update: Option<restore::BackupRestoreStateUpdate>,
        pub read_instruction: Option<ReadInstruction>,
    }
    impl From<restore::BackupRestoreInstruction> for BackupRestoreInstruction {
        fn from(instruction: restore::BackupRestoreInstruction) -> Self {
            Self {
                identity_data: instruction.identity_data.map(IdentityData::from),
                state_update: instruction.state_update,
                read_instruction: instruction.read_instruction.map(ReadInstruction::from),
            }
        }
    }

    /// Binding version of [`restore::BackupRestoreLoop`].
    #[derive(uniffi::Enum)]
    #[expect(missing_docs, reason = "Binding version")]
    pub enum BackupRestoreLoop {
        Instruction(BackupRestoreInstruction),
        Done,
    }
    impl From<restore::BackupRestoreLoop> for BackupRestoreLoop {
        fn from(restore_loop: restore::BackupRestoreLoop) -> Self {
            match restore_loop {
                restore::BackupRestoreLoop::Instruction(instruction) => Self::Instruction(instruction.into()),
                restore::BackupRestoreLoop::Done(()) => Self::Done,
            }
        }
    }

    /// Binding version of [`restore::BackupRestoreProviders`].
    #[derive(uniffi::Record)]
    #[expect(missing_docs, reason = "Binding version")]
    pub struct BackupRestoreProviders {
        pub user_profile: Arc<dyn UserProfileProvider>,
        pub settings: Arc<dyn SettingsProvider>,
        pub csp_nonces: Arc<dyn NonceProvider>,
        pub contacts: Arc<dyn ContactProvider>,
        pub groups: Arc<dyn GroupProvider>,
        pub distribution_lists: Arc<dyn DistributionListProvider>,
        pub polls: Arc<dyn PollProvider>,
        pub conversations: Arc<dyn ConversationProvider>,
    }
    impl From<BackupRestoreProviders> for restore::BackupRestoreProviders {
        fn from(providers: BackupRestoreProviders) -> Self {
            Self {
                user_profile: Arc::new(Mutex::new(providers.user_profile)),
                settings: Arc::new(Mutex::new(providers.settings)),
                contacts: Arc::new(Mutex::new(providers.contacts)),
                groups: Arc::new(Mutex::new(providers.groups)),
                distribution_lists: Arc::new(Mutex::new(providers.distribution_lists)),
                csp_nonces: Arc::new(Mutex::new(providers.csp_nonces)),
                polls: Arc::new(Mutex::new(providers.polls)),
                conversations: Arc::new(Mutex::new(providers.conversations)),
            }
        }
    }

    /// Binding version of [`restore::BackupRestoreTask`].
    #[derive(uniffi::Object)]
    pub struct BackupRestoreTask(Mutex<restore::BackupRestoreTask>);
    #[uniffi::export]
    impl BackupRestoreTask {
        /// Binding version of [`restore::BackupRestoreTask::new`].
        #[uniffi::constructor]
        #[must_use]
        pub fn new(password: DataBackupPassword) -> Self {
            Self(Mutex::new(restore::BackupRestoreTask::new(password)))
        }

        /// Binding version of [`restore::BackupRestoreTask::poll`].
        #[expect(clippy::missing_errors_doc, reason = "Binding version")]
        pub fn poll(&self) -> Result<BackupRestoreLoop, restore::BackupRestoreError> {
            Ok(self.0.lock_ignore_poison().poll()?.into())
        }

        /// Binding version of [`restore::BackupRestoreTask::add_providers`].
        #[expect(clippy::missing_errors_doc, reason = "Binding version")]
        pub fn add_providers(
            &self,
            providers: BackupRestoreProviders,
        ) -> Result<(), restore::BackupRestoreError> {
            self.0.lock_ignore_poison().add_providers(providers.into())
        }

        /// Binding version of [`restore::BackupRestoreTask::response`].
        #[expect(clippy::missing_errors_doc, reason = "Binding version")]
        pub fn response(
            &self,
            read_response: BackupRestoreResponse,
        ) -> Result<u64, restore::BackupRestoreError> {
            self.0
                .lock_ignore_poison()
                .response(read_response.try_into()?)
                .map(|read_bytes| read_bytes as u64)
        }
    }
}
