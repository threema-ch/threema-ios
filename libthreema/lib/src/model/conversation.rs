//! Conversation-related stuff.
use crate::{
    common::{ConversationId, ConversationType, MessageId, ThreemaId},
    model::message::{MessageState, MessageStateMetadata, MessageStateUpdate},
    provider::ProviderError,
};

/// Conversation storage interface.
///
/// # Contract
///
/// The following modifications do not require an interaction with libthreema:
///
/// - Emptying or removing a conversation (**not** the associated contact, distribution list or group).
/// - Removing a message from a conversation **locally**.
pub trait ConversationProvider {
    /// Add a message.
    ///
    /// 1. For each `message` of `messages`:
    ///    1. If `message` refers to a 1:1 contact conversation:
    ///       1. Look up the referred contact and let `contact` be the result.¹
    ///       2. If `contact` is not defined, return [`ProviderError::ContractViolation`].
    ///       3. If `contact` does not have acquaintance level _direct_, return
    ///          [`ProviderError::ContractViolation`].
    ///    2. If `message` refers to a distribution list conversation and the referred distribution list does
    ///       not exist, return [`ProviderError::ContractViolation`].
    ///    3. If `message` refers to a group conversation and the referred group does not exist, return
    ///       [`ProviderError::ContractViolation`].
    ///    4. If `message.message_id` is already present in the referred conversation (i.e. the message has
    ///       already been added at some point), return [`ProviderError::ContractViolation`].²
    /// 2. Add each message of `messages` to the referred conversation³.
    ///
    /// ¹: This must consider contacts with any acquaintance level, including _deleted_.
    ///
    /// ²: The caller is responsible to discard any duplicated message IDs prior to calling this
    /// method.
    ///
    /// ³: This implicitly creates a conversation if it does not already exist.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters or an invalid state. Otherwise, this function is
    /// considered infallible and should not return an error.
    fn add_messages(&mut self, messages: Vec<MessageState>) -> Result<(), ProviderError>;

    /// Set the typing indicator for a specific 1:1 conversation.
    ///
    /// 1. If the referred contact does not exist, return [`ProviderError::ContractViolation`].¹
    /// 2. If `is_typing` is `true`, start a timer to display that the sender is typing in the associated
    ///    conversation for the next 15s.
    /// 3. If `is_typing` is `false`, cancel any running timer displaying that the sender is typing in the
    ///    associated conversation.
    ///
    /// ¹: This must consider contacts with any acquaintance level, including _deleted_.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters or an invalid state. Otherwise, this function is
    /// considered infallible and should not return an error.
    fn set_typing_indicator(
        &mut self,
        sender_identity: ThreemaId,
        is_typing: bool,
    ) -> Result<(), ProviderError>;

    /// Update existing messages.
    ///
    /// 1. For each `update` of `updates`:
    ///    1. If `update` refers to a 1:1 contact conversation and the referred contact does not exist, return
    ///       [`ProviderError::ContractViolation`].¹
    ///    2. If `update` refers to a distribution list conversation and the referred distribution list does
    ///       not exist, return [`ProviderError::ContractViolation`].
    ///    3. If `update` refers to a group conversation and the referred group does not exist, return
    ///       [`ProviderError::ContractViolation`].
    ///    4. If the message referred to by `update` does not exist in the referred conversation, return
    ///       [`ProviderError::ContractViolation`].
    /// 2. For each `update` of `updates`:
    ///    1. Look up the message referred to by `update` in the referred conversation and let `message` be
    ///       the result.
    ///    2. Run the steps defined by the respective
    ///       [`update`-variant][`crate::model::message::MessageStateBodyUpdate`] with the following input:
    ///       - `update-creator` set to `update.creator`
    ///       - `conversation`
    ///       - `message`
    ///
    /// ¹: This must consider contacts with any acquaintance level, including _deleted_.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters or an invalid state. Otherwise, this function is
    /// considered infallible and should not return an error.
    fn update_messages(&mut self, updates: Vec<MessageStateUpdate>) -> Result<(), ProviderError>;

    /// 1. Look up all past messages of all conversations of type `conversation_type` and let `messages` be
    ///    the result.
    /// 2. Deterministically partition `messages` into non-empty, incrementally zero-based numbered batches¹.
    /// 3. Return the batch with index `batch_index`.
    ///
    /// Note: Messages must be naturally ordered. If, in a given conversation, message A is displayed before
    /// message B (e.g., message A is *older*), then message A must also appear before message B (either in
    /// an earlier batch or with respect to their place in the returned vector).
    ///
    /// ¹: IMPORTANT: Batches must be non-overlapping between function calls! However, the surrounding
    /// protocol ensures that the batching mechanism is only used in a uninterruptible (_read-only_) state.
    /// A batch should contain about 2^10 past messages. An empty batch signals that no further past messages
    /// are available.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters. Otherwise, this function is
    /// considered infallible and should not return an error.
    //-
    // TODO(LIB-168): Replace with iterator pattern.
    fn get_many_messages(
        &self,
        conversation_type: ConversationType,
        batch_index: usize,
    ) -> Result<Vec<MessageState>, ProviderError>;

    /// Get message metadata for specific messages.
    ///
    /// 1. If `conversation_id` refers to a 1:1 contact conversation and the referred contact does not exist,
    ///    return [`ProviderError::ContractViolation`].¹
    /// 2. If `conversation_id` refers to a distribution list conversation and the referred distribution list
    ///    does not exist, return [`ProviderError::ContractViolation`].
    /// 3. If `conversation_id` refers to a group conversation and the referred group does not exist, return
    ///    [`ProviderError::ContractViolation`].
    /// 4. Let `metadata` be an empty list.
    /// 5. For each `message-id` of `message_ids`:
    ///    1. Look up a message by `message-id` in the conversation with `conversation_id`.
    ///    2. If `message` is defined, create a [`MessageStateMetadata`] from `message` and add it to
    ///       `metadata`.
    /// 6. Return `metadata`.
    ///
    /// ¹: This must consider contacts with any acquaintance level, including _deleted_.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters or an invalid state. Otherwise, this function is
    /// considered infallible and should not return an error.
    fn get_messages_metadata(
        &self,
        conversation_id: ConversationId,
        message_ids: &[MessageId],
    ) -> Result<Vec<MessageStateMetadata>, ProviderError>;

    /// Return whether a message with message `id` from `sender_identity` has been marked as used (i.e. points
    /// to an existing message or was explicitly marked used at some point).
    ///
    /// TODO(LIB-16): Known problematic because checking the message ID early and bailing may prevent
    /// reflection.
    ///
    /// # Errors
    ///
    /// This function is considered infallible and should not return an error.
    fn is_message_marked_used(
        &self,
        sender_identity: ThreemaId,
        message_id: MessageId,
    ) -> Result<bool, ProviderError>;
}
