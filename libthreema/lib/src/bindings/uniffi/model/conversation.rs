//! Binding version of [`conversation`].

use std::sync::Arc;

use crate::{
    bindings::uniffi::{
        common::{ConversationId, ThreemaId},
        model::message::{MessageState, MessageStateMetadata, MessageStateUpdate},
    },
    common::{self, ConversationType, MessageId},
    model::{self, conversation},
    provider::ProviderError,
};

/// Binding version of [`conversation::ConversationProvider`].
#[expect(missing_docs, clippy::missing_errors_doc, reason = "Binding version")]
#[uniffi::export(with_foreign)]
pub trait ConversationProvider: Send + Sync {
    fn add_messages(&self, messages: Vec<MessageState>) -> Result<(), ProviderError>;

    fn set_typing_indicator(&self, sender_identity: ThreemaId, is_typing: bool) -> Result<(), ProviderError>;

    fn update_messages(&self, updates: Vec<MessageStateUpdate>) -> Result<(), ProviderError>;

    fn get_many_messages(
        &self,
        conversation_type: ConversationType,
        batch_index: u64,
    ) -> Result<Vec<MessageState>, ProviderError>;

    fn get_messages_metadata(
        &self,
        conversation_id: ConversationId,
        message_ids: Vec<MessageId>,
    ) -> Result<Vec<MessageStateMetadata>, ProviderError>;

    fn is_message_marked_used(
        &self,
        sender_identity: ThreemaId,
        message_id: MessageId,
    ) -> Result<bool, ProviderError>;
}
impl<T: ConversationProvider + ?Sized> conversation::ConversationProvider for Arc<T> {
    fn add_messages(&mut self, messages: Vec<model::message::MessageState>) -> Result<(), ProviderError> {
        ConversationProvider::add_messages(
            self.as_ref(),
            messages.into_iter().map(MessageState::from).collect(),
        )
    }

    fn set_typing_indicator(
        &mut self,
        sender_identity: common::ThreemaId,
        is_typing: bool,
    ) -> Result<(), ProviderError> {
        ConversationProvider::set_typing_indicator(self.as_ref(), sender_identity.into(), is_typing)
    }

    fn update_messages(
        &mut self,
        updates: Vec<model::message::MessageStateUpdate>,
    ) -> Result<(), ProviderError> {
        ConversationProvider::update_messages(
            self.as_ref(),
            updates.into_iter().map(MessageStateUpdate::from).collect(),
        )
    }

    fn get_many_messages(
        &self,
        conversation_type: ConversationType,
        batch_index: usize,
    ) -> Result<Vec<model::message::MessageState>, ProviderError> {
        ConversationProvider::get_many_messages(self.as_ref(), conversation_type, batch_index as u64)?
            .into_iter()
            .map(|message| Ok(model::message::MessageState::try_from(message)?))
            .collect()
    }

    fn get_messages_metadata(
        &self,
        conversation_id: common::ConversationId,
        message_ids: &[MessageId],
    ) -> Result<Vec<model::message::MessageStateMetadata>, ProviderError> {
        ConversationProvider::get_messages_metadata(
            self.as_ref(),
            conversation_id.into(),
            message_ids.to_vec(),
        )?
        .into_iter()
        .map(|metadata| Ok(model::message::MessageStateMetadata::try_from(metadata)?))
        .collect()
    }

    fn is_message_marked_used(
        &self,
        sender_identity: common::ThreemaId,
        message_id: MessageId,
    ) -> Result<bool, ProviderError> {
        ConversationProvider::is_message_marked_used(self.as_ref(), sender_identity.into(), message_id)
    }
}
