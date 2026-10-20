//! Bindings for the _Data Backup_.

use std::sync::{Arc, Mutex};

use crate::{
    bindings::uniffi::{
        model::{
            contact::ContactProvider, conversation::ConversationProvider,
            distribution_list::DistributionListProvider, group::GroupProvider, poll::PollProvider,
            settings::SettingsProvider, user_profile::UserProfileProvider,
        },
        provider::NonceProvider,
    },
    data_backup,
};

/// Binding version of [`data_backup::task::DataBackupProviders`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct DataBackupProviders {
    pub user_profile: Arc<dyn UserProfileProvider>,
    pub settings: Arc<dyn SettingsProvider>,
    pub contacts: Arc<dyn ContactProvider>,
    pub groups: Arc<dyn GroupProvider>,
    pub distribution_lists: Arc<dyn DistributionListProvider>,
    pub csp_nonces: Arc<dyn NonceProvider>,
    pub polls: Arc<dyn PollProvider>,
    pub conversations: Arc<dyn ConversationProvider>,
}
impl From<DataBackupProviders> for data_backup::task::DataBackupProviders {
    fn from(providers: DataBackupProviders) -> Self {
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

pub mod create {
    //! Bindings for creating the data backup.
    use std::sync::Mutex;

    use crate::{
        bindings::uniffi::{data_backup::DataBackupProviders, model::user_profile::IdentityData},
        data_backup::{
            DataBackupCreateError,
            task::create::{self, DataBackupCreateInstruction},
        },
    };

    /// Binding version of [`create::DataBackupCreateLoop`].
    #[derive(uniffi::Enum)]
    #[expect(missing_docs, reason = "Binding version")]
    pub enum DataBackupCreateLoop {
        Instruction(DataBackupCreateInstruction),
        Done,
    }
    impl From<create::DataBackupCreateLoop> for DataBackupCreateLoop {
        fn from(create_loop: create::DataBackupCreateLoop) -> Self {
            match create_loop {
                create::DataBackupCreateLoop::Instruction(instruction) => Self::Instruction(instruction),
                create::DataBackupCreateLoop::Done(()) => Self::Done,
            }
        }
    }

    /// Binding version of [`create::DataBackupCreateInit`].
    #[expect(missing_docs, reason = "Binding version")]
    #[derive(uniffi::Record)]
    pub struct DataBackupCreateInit {
        pub password: String,
        pub identity_data: IdentityData,
        pub providers: DataBackupProviders,
    }
    impl TryFrom<DataBackupCreateInit> for create::DataBackupCreateInit {
        type Error = DataBackupCreateError;

        fn try_from(init: DataBackupCreateInit) -> Result<Self, Self::Error> {
            Ok(Self {
                password: init.password,
                identity_data: init.identity_data.try_into()?,
                providers: init.providers.into(),
            })
        }
    }

    /// Binding version of [`create::DataBackupCreateTask`].
    #[derive(uniffi::Object)]
    pub struct DataBackupCreateTask {
        task: Mutex<create::DataBackupCreateTask>,
        filename: String,
    }
    #[uniffi::export]
    impl DataBackupCreateTask {
        /// Binding version of [`create::DataBackupCreateTask::new`].
        ///
        /// Note: the filename must be retrieved with [`Self::get_filename`].
        #[expect(clippy::missing_errors_doc, reason = "Binding version")]
        #[uniffi::constructor]
        pub fn new(init: DataBackupCreateInit) -> Result<Self, DataBackupCreateError> {
            let (task, filename) = create::DataBackupCreateTask::new(init.try_into()?);

            Ok(Self {
                task: task.into(),
                filename,
            })
        }

        /// Get the filename of the backup.
        pub fn get_filename(&self) -> String {
            self.filename.clone()
        }

        /// Binding version of [`create::DataBackupCreateTask::poll`].
        #[expect(clippy::missing_errors_doc, reason = "Binding version")]
        pub fn poll(&self) -> Result<DataBackupCreateLoop, DataBackupCreateError> {
            self.task.lock()?.poll().map(DataBackupCreateLoop::from)
        }
    }
}

pub mod restore {
    //! Bindings for restoring the data backup.
    use std::sync::Mutex;

    use crate::{
        bindings::uniffi::{data_backup::DataBackupProviders, model::user_profile::IdentityData},
        data_backup::{
            DataBackupRestoreError,
            task::restore::{
                self, DataBackupRestoreReadInstruction, DataBackupRestoreReadResponse,
                DataBackupRestoreStateUpdate,
            },
        },
    };

    /// Binding version of [`restore::DataBackupRestoreInstruction`].
    #[derive(uniffi::Record)]
    #[expect(missing_docs, reason = "Binding version")]
    pub struct DataBackupRestoreInstruction {
        pub identity_data: Option<IdentityData>,
        pub state_update: Option<DataBackupRestoreStateUpdate>,
        pub read_instruction: Option<DataBackupRestoreReadInstruction>,
    }
    impl From<restore::DataBackupRestoreInstruction> for DataBackupRestoreInstruction {
        fn from(instruction: restore::DataBackupRestoreInstruction) -> Self {
            Self {
                identity_data: instruction.identity_data.map(IdentityData::from),
                state_update: instruction.state_update,
                read_instruction: instruction.read_instruction,
            }
        }
    }

    /// Binding version of [`restore::DataBackupRestoreResponse`].
    #[derive(uniffi::Record)]
    #[expect(missing_docs, reason = "Binding version")]
    pub struct DataBackupRestoreResponse {
        pub providers: Option<DataBackupProviders>,
        pub read_response: Option<DataBackupRestoreReadResponse>,
    }
    impl From<DataBackupRestoreResponse> for restore::DataBackupRestoreResponse {
        fn from(response: DataBackupRestoreResponse) -> Self {
            Self {
                providers: response.providers.map(Into::into),
                read_response: response.read_response,
            }
        }
    }

    /// Binding version of [`restore::DataBackupRestoreLoop`].
    #[derive(uniffi::Enum)]
    #[expect(missing_docs, reason = "Binding version")]
    pub enum DataBackupRestoreLoop {
        Instruction(DataBackupRestoreInstruction),
        Done,
    }
    impl From<restore::DataBackupRestoreLoop> for DataBackupRestoreLoop {
        fn from(restore_loop: restore::DataBackupRestoreLoop) -> Self {
            match restore_loop {
                restore::DataBackupRestoreLoop::Instruction(instruction) => {
                    Self::Instruction(instruction.into())
                },
                restore::DataBackupRestoreLoop::Done(()) => Self::Done,
            }
        }
    }

    /// Binding version of [`restore::DataBackupRestoreTask`].
    #[derive(uniffi::Object)]
    pub struct DataBackupRestoreTask(Mutex<restore::DataBackupRestoreTask>);
    #[uniffi::export]
    impl DataBackupRestoreTask {
        /// Binding version of [`restore::DataBackupRestoreTask::new`].
        #[uniffi::constructor]
        #[must_use]
        pub fn new(password: String) -> Self {
            Self(Mutex::new(restore::DataBackupRestoreTask::new(password)))
        }

        /// Binding version of [`restore::DataBackupRestoreTask::poll`].
        #[expect(clippy::missing_errors_doc, reason = "Binding version")]
        pub fn poll(&self) -> Result<DataBackupRestoreLoop, DataBackupRestoreError> {
            Ok(self.0.lock()?.poll()?.into())
        }

        /// Binding version of [`restore::DataBackupRestoreTask::response`].
        #[expect(clippy::missing_errors_doc, reason = "Binding version")]
        pub fn response(&self, response: DataBackupRestoreResponse) -> Result<(), DataBackupRestoreError> {
            self.0.lock()?.response(response.into())
        }
    }
}
