//! Example for restoring a data backup.
#![expect(unused_crate_dependencies, reason = "Example triggered false positive")]
mod utils;

use std::{
    collections::{HashMap, HashSet},
    fs,
    io::{self, Read as _, Seek as _},
    path,
    sync::{Arc, Mutex},
};

use clap::Parser;
use libthreema::{
    common::{
        ConversationId, DistributionListId, GroupIdentity, MessageId, ThreemaId, keys::DataBackupPassword,
    },
    data_backup::task::restore::{
        BackupRestoreLoop, BackupRestoreProviders, BackupRestoreResponse, BackupRestoreTask,
        LocalReadInstruction, ReadInstruction,
    },
    model::{poll::PollId, settings::Settings},
    protobuf,
    utils::logging::init_stderr_logging,
};
use tracing::{Level, debug, info};

use crate::{
    provider::{
        BackupContactProvider, RestoreConversationProvider, RestoreDistributionListProvider,
        RestoreGroupProvider, RestoreNonceProvider, RestorePollProvider, RestoreSettingsProvider,
        RestoreUserProfileProvider,
    },
    utils::sync::MutexIgnorePoison as _,
};

// TODO(LIB-94): Reuse the implementations fropm cli/providers (and maybe even share code)
mod provider {
    //! Provider implementations for the backup restore example.
    //!
    //! _Note: We are only interested in ensuring that the backup was correct, the actual data (profile
    //! pictures, messages, etc.) don't matter. We therefore keep only the minimal required information to
    //! do all checks required in the steps._

    #![expect(clippy::unimplemented, reason = "Unused methods for backup restore")]
    use std::{
        collections::{HashMap, HashSet},
        sync::{Arc, Mutex},
    };

    use libthreema::{
        common::{
            ConversationId, ConversationType, DistributionListId, GroupIdentity, HashedNonce, MessageId,
            ThreemaId,
        },
        model::{
            contact::{Contact, ContactProvider, ContactWithProfilePictures},
            conversation::ConversationProvider,
            distribution_list::{DistributionList, DistributionListProvider},
            group::{GroupMembershipFilter, GroupProvider, GroupWithProfilePicture},
            message::{MessageState, MessageStateMetadata, MessageStateUpdate},
            poll::{Poll, PollId, PollProvider, PollVotes},
            profile::ProfilePicture,
            settings::{Settings, SettingsProvider, SettingsUpdate},
            user_profile::{UserProfile, UserProfileProvider},
        },
        protobuf,
        provider::{NonceProvider, ProviderError},
    };
    use tracing::debug;

    use crate::utils::sync::MutexIgnorePoison as _;

    pub(crate) struct BackupContactProvider {
        pub(crate) contacts: Arc<Mutex<HashMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,
        pub(crate) user_identity: ThreemaId,
    }
    impl ContactProvider for BackupContactProvider {
        fn is_explicitly_blocked(&self, _identity: ThreemaId) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn has(&self, _identity: ThreemaId) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn count_existing(&self, _identities: &[ThreemaId]) -> Result<usize, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn get_identities(&self) -> Result<HashSet<ThreemaId>, ProviderError> {
            Ok(self.contacts.lock_ignore_poison().keys().copied().collect())
        }

        fn get(&self, _identity: ThreemaId) -> Result<Option<Contact>, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn add(&mut self, _contacts: Vec<Contact>) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn get_with_profile_pictures(
            &self,
            _identity: ThreemaId,
        ) -> Result<Option<ContactWithProfilePictures>, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn add_with_profile_pictures(
            &mut self,
            contacts: Vec<ContactWithProfilePictures>,
        ) -> Result<(), ProviderError> {
            debug!("Adding {} contacts", contacts.len());
            let mut contact_storage = self.contacts.lock_ignore_poison();
            for contact in &contacts {
                // Bail if the contact's identity is the user's identity.
                if contact.contact.identity == self.user_identity {
                    return Err(ProviderError::InvalidParameter(
                        "Unexpected encounter of user's identity in contact provider".to_owned(),
                    ));
                }

                // Bail if the contact already exists.
                if contact_storage.contains_key(&contact.contact.identity) {
                    return Err(ProviderError::InvalidState(format!(
                        "Contact {} to be added already exists",
                        contact.contact.identity
                    )));
                }
            }

            // Add all contacts.
            contact_storage.extend(
                contacts
                    .into_iter()
                    .map(|contact| (contact.contact.identity, contact.contact.acquaintance_level)),
            );

            Ok(())
        }

        fn update(
            &mut self,
            _updates: Vec<libthreema::model::contact::ContactUpdate>,
        ) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn set_contact_defined_profile_picture(
            &self,
            _identity: ThreemaId,
            _profile_picture: Option<ProfilePicture>,
        ) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn set_user_defined_profile_picture(
            &self,
            _identity: ThreemaId,
            _profile_picture: Option<ProfilePicture>,
        ) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup restore");
        }
    }

    pub(crate) struct RestoreGroupProvider {
        pub(crate) groups: Arc<Mutex<HashMap<GroupIdentity, HashSet<ThreemaId>>>>,
        pub(crate) user_identity: ThreemaId,
        pub(crate) contacts: Arc<Mutex<HashMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,
    }
    impl GroupProvider for RestoreGroupProvider {
        fn is_part_of_any_group(
            &self,
            _identity: ThreemaId,
            _filter: GroupMembershipFilter,
        ) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn get_identities(&self) -> Result<HashSet<GroupIdentity>, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn get_with_profile_picture(
            &self,
            _identity: GroupIdentity,
        ) -> Result<Option<GroupWithProfilePicture>, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn add_with_profile_picture(
            &mut self,
            mut groups: Vec<GroupWithProfilePicture>,
        ) -> Result<(), ProviderError> {
            let mut group_storage = self.groups.lock_ignore_poison();
            let contacts = self.contacts.lock_ignore_poison();

            for group in &mut groups {
                let group_id = group.group.identity;

                // Bail if the group already exists.
                if group_storage.contains_key(&group_id) {
                    return Err(ProviderError::InvalidState(format!(
                        "Group {group_id} already exists"
                    )));
                }

                // Bail if creator is neither the user nor a known contact.
                if !(group_id.creator_identity == self.user_identity
                    || contacts.contains_key(&group_id.creator_identity))
                {
                    return Err(ProviderError::InvalidState(format!(
                        "Creator of group {group_id} is not known"
                    )));
                }

                // Bail if a member's identity is the user's identity or refers to an unknown contact.
                for member in &group.group.members {
                    if *member == self.user_identity {
                        return Err(ProviderError::InvalidParameter(format!(
                            "Unexpected encounter of user's identity in members of group {group_id}"
                        )));
                    }
                    if !contacts.contains_key(member) {
                        return Err(ProviderError::InvalidState(format!(
                            "Member of group {group_id} is not known"
                        )));
                    }
                }
            }

            // Add all groups.
            group_storage.extend(
                groups
                    .into_iter()
                    .map(|group| (group.group.identity, group.group.members)),
            );

            Ok(())
        }

        fn set_profile_picture(
            &mut self,
            _identity: GroupIdentity,
            _profile_picture: Option<ProfilePicture>,
        ) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup restore");
        }
    }

    pub(crate) struct RestoreDistributionListProvider {
        pub(crate) distribution_lists: Arc<Mutex<HashMap<DistributionListId, HashSet<ThreemaId>>>>,
        pub(crate) user_identity: ThreemaId,
        pub(crate) contacts: Arc<Mutex<HashMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,
    }
    impl DistributionListProvider for RestoreDistributionListProvider {
        fn get_ids(&self) -> Result<HashSet<DistributionListId>, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn get(&self, _identity: DistributionListId) -> Result<Option<DistributionList>, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn add(&mut self, distribution_lists: Vec<DistributionList>) -> Result<(), ProviderError> {
            debug!("Adding {} distribution lists", distribution_lists.len());
            let mut distribution_list_storage = self.distribution_lists.lock_ignore_poison();
            let contacts = self.contacts.lock_ignore_poison();

            for distribution_list in &distribution_lists {
                let distribution_list_id = distribution_list.identity;

                // Bail if distribution list already exists.
                if distribution_list_storage.contains_key(&distribution_list_id) {
                    return Err(ProviderError::InvalidState(format!(
                        "Distribution list {distribution_list_id} already exists"
                    )));
                }

                // Bail if a member's identity is the user's identity or refers to an unknown contact.
                for member in &distribution_list.members {
                    if *member == self.user_identity {
                        return Err(ProviderError::InvalidParameter(format!(
                            "Distribution list {distribution_list_id} references user in members",
                        )));
                    }
                    if !contacts.contains_key(member) {
                        return Err(ProviderError::InvalidState(format!(
                            "Distribution list {distribution_list_id} references unknown member {member}"
                        )));
                    }
                }
            }

            // Add all distribution lists.
            distribution_list_storage.extend(
                distribution_lists
                    .into_iter()
                    .map(|distribution_list| (distribution_list.identity, distribution_list.members)),
            );

            Ok(())
        }
    }

    pub(crate) struct RestoreSettingsProvider {
        pub(crate) settings: Arc<Mutex<Settings>>,
    }
    impl SettingsProvider for RestoreSettingsProvider {
        fn get(&self) -> Result<Settings, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn set(&mut self, settings: Settings) -> Result<(), ProviderError> {
            debug!(?settings, "Settings restored");
            *self.settings.lock_ignore_poison() = settings;
            Ok(())
        }

        fn update(&mut self, _update: SettingsUpdate) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup restore");
        }
    }

    pub(crate) struct RestoreUserProfileProvider;
    impl UserProfileProvider for RestoreUserProfileProvider {
        fn get(&self) -> Result<UserProfile, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn set(&mut self, user_profile: UserProfile) -> Result<(), ProviderError> {
            debug!(?user_profile, "Set user profile");
            Ok(())
        }
    }

    pub(crate) struct RestoreConversationProvider {
        pub(crate) contacts: Arc<Mutex<HashMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,
        pub(crate) groups: Arc<Mutex<HashMap<GroupIdentity, HashSet<ThreemaId>>>>,
        pub(crate) messages: Arc<Mutex<HashSet<(ThreemaId, MessageId)>>>,
        pub(crate) distribution_lists: Arc<Mutex<HashMap<DistributionListId, HashSet<ThreemaId>>>>,
    }
    impl ConversationProvider for RestoreConversationProvider {
        fn add_messages(&mut self, messages: Vec<MessageState>) -> Result<(), ProviderError> {
            debug!("Adding {} message states", messages.len());
            let contacts = self.contacts.lock_ignore_poison();
            let groups = self.groups.lock_ignore_poison();
            let distribution_lists = self.distribution_lists.lock_ignore_poison();
            let mut registered_messages = self.messages.lock_ignore_poison();
            for message in &messages {
                // Check whether the referred contact/distribution list/group exists and is in the expected
                // state.
                match &message.conversation_id {
                    ConversationId::Contact(identity) => {
                        let Some(contact) = contacts.get(identity) else {
                            return Err(ProviderError::InvalidState(format!(
                                "Contact {identity} does not exist",
                            )));
                        };
                        if !matches!(*contact, protobuf::d2d_sync::contact::AcquaintanceLevel::Direct) {
                            return Err(ProviderError::InvalidState(format!(
                                "Contact {identity} does not have acquaintance level direct",
                            )));
                        }
                    },
                    ConversationId::DistributionList(distribution_list_id) => {
                        if !distribution_lists.contains_key(distribution_list_id) {
                            return Err(ProviderError::InvalidState(format!(
                                "Distribution list {distribution_list_id} does not exist"
                            )));
                        }
                    },
                    ConversationId::Group(group_identity) => {
                        if !groups.contains_key(group_identity) {
                            return Err(ProviderError::InvalidState(format!(
                                "Group {group_identity} does not exist",
                            )));
                        }
                    },
                }

                // TODO(LIB-94): This is different from the steps and is only correct for contact messages.
                // This also holds for the add step
                //
                // Check if the message was already added to the conversation.
                if registered_messages.contains(&(message.creator_identity, message.message_id)) {
                    return Err(ProviderError::InvalidState(format!(
                        "Message {} already exists in conversation {}",
                        message.message_id, message.conversation_id,
                    )));
                }
            }
            // Add all message states to the corresponding conversation.
            for message in messages {
                let _ = registered_messages.insert((message.creator_identity, message.message_id));
            }

            Ok(())
        }

        fn set_typing_indicator(
            &mut self,
            _sender_identity: ThreemaId,
            _is_typing: bool,
        ) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup restore")
        }

        fn update_messages(&mut self, _updates: Vec<MessageStateUpdate>) -> Result<(), ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn get_many_messages(
            &self,
            _conversation_type: ConversationType,
            _batch_index: usize,
        ) -> Result<Vec<MessageState>, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn get_messages_metadata(
            &self,
            _conversation_id: ConversationId,
            _message_ids: &[MessageId],
        ) -> Result<Vec<MessageStateMetadata>, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn is_message_marked_used(
            &self,
            _sender_identity: ThreemaId,
            _message_id: MessageId,
        ) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup restore")
        }
    }

    pub(crate) struct RestorePollProvider {
        pub(crate) user_identity: ThreemaId,
        pub(crate) contacts: Arc<Mutex<HashMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,
        pub(crate) groups: Arc<Mutex<HashMap<GroupIdentity, HashSet<ThreemaId>>>>,
        pub(crate) polls: Arc<Mutex<HashSet<(ConversationId, PollId)>>>,
    }
    impl PollProvider for RestorePollProvider {
        fn get_many(&self, _batch_index: usize) -> Result<Vec<Poll>, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn add(&mut self, polls: Vec<Poll>) -> Result<(), ProviderError> {
            debug!("Adding {} polls", polls.len());
            let contacts = self.contacts.lock_ignore_poison();
            let groups = self.groups.lock_ignore_poison();
            let mut polls_storage = self.polls.lock_ignore_poison();
            for poll in &polls {
                let poll_id = poll.id;
                // Bail if referred conversation does not exist or if it is a distribution list.
                match poll.conversation {
                    ConversationId::Contact(contact) => {
                        if !contacts.contains_key(&contact) {
                            return Err(ProviderError::InvalidState(format!(
                                "Poll {poll_id} references an unknown contact conversation {contact}",
                            )));
                        }
                    },

                    ConversationId::DistributionList(_) => {
                        return Err(ProviderError::InvalidParameter(format!(
                            "Poll {poll_id} references a distribution list which is not supported",
                        )));
                    },

                    ConversationId::Group(group_identity) => {
                        if !groups.contains_key(&group_identity) {
                            return Err(ProviderError::InvalidState(format!(
                                "Poll {poll_id} references an unknown group {group_identity}",
                            )));
                        }
                    },
                }

                // Bail if poll already exists.
                if polls_storage.contains(&(poll.conversation, poll_id)) {
                    return Err(ProviderError::InvalidState(format!(
                        "Poll {poll_id} already exists",
                    )));
                }

                // Bail if a voter refers to an unknown contact.
                if let PollVotes::Votes(voters) = &poll.votes {
                    for voter in voters.keys() {
                        if *voter != self.user_identity && !contacts.contains_key(voter) {
                            return Err(ProviderError::InvalidState(format!(
                                "Poll {poll_id} contains voter {voter} that is not a known contact",
                            )));
                        }
                    }
                }
            }

            // Add all polls.
            polls_storage.extend(polls.into_iter().map(|poll| (poll.conversation, poll.id)));

            Ok(())
        }
    }

    pub(crate) struct RestoreNonceProvider {
        pub(crate) nonce_counter: Arc<Mutex<usize>>,
    }
    impl NonceProvider for RestoreNonceProvider {
        fn has(&self, _hashed_nonce: &HashedNonce) -> Result<bool, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }

        fn add_many(&mut self, hashed_nonces: Vec<HashedNonce>) -> Result<(), ProviderError> {
            let mut nonce_counter = self.nonce_counter.lock_ignore_poison();
            *nonce_counter = nonce_counter.saturating_add(hashed_nonces.len());
            Ok(())
        }

        fn get_many(&self, _batch_index: usize) -> Result<Vec<HashedNonce>, ProviderError> {
            unimplemented!("Not needed for backup restore");
        }
    }
}

struct FileReader {
    file: fs::File,
}
impl FileReader {
    fn new(path: &path::PathBuf) -> Self {
        Self {
            file: fs::OpenOptions::new()
                .read(true)
                .open(path)
                .expect("backup file should be valid"),
        }
    }

    fn read_at(&mut self, offset: usize, length: usize) -> anyhow::Result<Vec<u8>> {
        let mut buffer = vec![0_u8; length];
        let _ = self.file.seek(io::SeekFrom::Start(offset as u64))?;
        self.file.read_exact(&mut buffer)?;
        Ok(buffer)
    }

    fn handle(&mut self, instruction: &LocalReadInstruction) -> anyhow::Result<BackupRestoreResponse> {
        Ok(BackupRestoreResponse {
            offset: instruction.offset,
            chunk: self.read_at(instruction.offset.0, instruction.length)?,
        })
    }

    fn file_size(&self) -> anyhow::Result<u64> {
        Ok(self.file.metadata()?.len())
    }
}

struct ExampleBackupRestorer {
    file_reader: FileReader,
    task: BackupRestoreTask,
    contacts: Arc<Mutex<HashMap<ThreemaId, protobuf::d2d_sync::contact::AcquaintanceLevel>>>,
    groups: Arc<Mutex<HashMap<GroupIdentity, HashSet<ThreemaId>>>>,
    distribution_lists: Arc<Mutex<HashMap<DistributionListId, HashSet<ThreemaId>>>>,
    messages: Arc<Mutex<HashSet<(ThreemaId, MessageId)>>>,
    polls: Arc<Mutex<HashSet<(ConversationId, PollId)>>>,
    csp_nonces: Arc<Mutex<usize>>,
}
impl ExampleBackupRestorer {
    fn new(path: &path::PathBuf, password: DataBackupPassword) -> Self {
        Self {
            file_reader: FileReader::new(path),
            task: BackupRestoreTask::new(password),
            contacts: Arc::new(Mutex::new(HashMap::new())),
            groups: Arc::new(Mutex::new(HashMap::new())),
            distribution_lists: Arc::new(Mutex::new(HashMap::new())),
            messages: Arc::new(Mutex::new(HashSet::new())),
            polls: Arc::new(Mutex::new(HashSet::new())),
            csp_nonces: Arc::new(Mutex::new(0)),
        }
    }

    fn create_providers(&self, user_identity: ThreemaId) -> BackupRestoreProviders {
        BackupRestoreProviders {
            user_profile: Arc::new(Mutex::new(RestoreUserProfileProvider {})),
            contacts: Arc::new(Mutex::new(BackupContactProvider {
                contacts: Arc::clone(&self.contacts),
                user_identity,
            })),
            groups: Arc::new(Mutex::new(RestoreGroupProvider {
                groups: Arc::clone(&self.groups),
                user_identity,
                contacts: Arc::clone(&self.contacts),
            })),
            distribution_lists: Arc::new(Mutex::new(RestoreDistributionListProvider {
                distribution_lists: Arc::clone(&self.distribution_lists),
                user_identity,
                contacts: Arc::clone(&self.contacts),
            })),
            csp_nonces: Arc::new(Mutex::new(RestoreNonceProvider {
                nonce_counter: Arc::clone(&self.csp_nonces),
            })),
            polls: Arc::new(Mutex::new(RestorePollProvider {
                user_identity,
                polls: Arc::clone(&self.polls),
                contacts: Arc::clone(&self.contacts),
                groups: Arc::clone(&self.groups),
            })),
            settings: Arc::new(Mutex::new(RestoreSettingsProvider {
                settings: Arc::new(Mutex::new(Settings::default())),
            })),
            conversations: Arc::new(Mutex::new(RestoreConversationProvider {
                messages: Arc::clone(&self.messages),
                contacts: Arc::clone(&self.contacts),
                groups: Arc::clone(&self.groups),
                distribution_lists: Arc::clone(&self.distribution_lists),
            })),
        }
    }

    fn run(mut self) -> anyhow::Result<()> {
        let file_size = self.file_reader.file_size()?;
        info!("Restoring backup");

        let mut last_progress = 0_u64;
        loop {
            match self.task.poll()? {
                BackupRestoreLoop::Instruction(instruction) => {
                    if let Some(user_data) = instruction.identity_data {
                        debug!(?user_data, "Restored user data");
                        self.task
                            .add_providers(self.create_providers(user_data.user_identity))?;
                    }

                    if let Some(state_update) = instruction.state_update {
                        debug!(?state_update, "Changed state");
                    }

                    // Handle read instruction.
                    let read_response = match instruction.read_instruction {
                        Some(ReadInstruction::Local(instruction)) => self.file_reader.handle(&instruction)?,
                        _ => {
                            continue;
                        },
                    };
                    let read_bytes = self.task.response(read_response)? as u64;

                    // Log progress when it increases by at least 1%.
                    let progress = read_bytes
                        .saturating_mul(100)
                        .checked_div(file_size)
                        .expect("File size should not be zero.");
                    if progress > last_progress {
                        last_progress = progress;
                        debug!("Progress: {progress}%");
                    }
                },
                BackupRestoreLoop::Done(()) => {
                    info!(
                        "Successfully restored {} contacts, {} groups, {} distribution list, {} messages, \
                         {} polls, {} csp nonces",
                        self.contacts.lock_ignore_poison().len(),
                        self.groups.lock_ignore_poison().len(),
                        self.distribution_lists.lock_ignore_poison().len(),
                        self.messages.lock_ignore_poison().len(),
                        self.polls.lock_ignore_poison().len(),
                        self.csp_nonces.lock_ignore_poison(),
                    );

                    return Ok(());
                },
            }
        }
    }
}

#[derive(Parser)]
#[command()]
struct DataBackupCommand {
    /// Path to the backup file.
    #[arg(short, long)]
    path: path::PathBuf,

    /// Password used for the backup to be restored.
    #[arg(long)]
    password: String,

    /// Turn on debugging information.
    /// Use -v -vv to control log level.
    #[arg(short, action = clap::ArgAction::Count)]
    verbose: u8,
}

fn main() -> anyhow::Result<()> {
    let arguments = DataBackupCommand::parse();
    let log_level = match arguments.verbose {
        1 => Level::DEBUG,
        2 => Level::TRACE,
        _ => Level::INFO,
    };
    init_stderr_logging(log_level);
    ExampleBackupRestorer::new(&arguments.path, DataBackupPassword(arguments.password)).run()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use crate::DataBackupCommand;

    #[test]
    fn verify_cli() {
        use clap::CommandFactory;
        DataBackupCommand::command().debug_assert();
    }
}
