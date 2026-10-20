//! Binding version of [`message`].
use crate::{
    bindings::uniffi::{
        ConversionError,
        common::{ConversationId, ThreemaId},
    },
    common,
    model::message::{
        self, ContactDeliveryUpdate, EmojiReaction, MessageDirection, MessageReactionUpdateIntent,
        MessageStarMarker, MessageStateBody, MessageStateBodyType, MessageTextRevision,
    },
};

/// Binding version of [`message::MessageReaction`].
#[expect(missing_docs, reason = "Binding version")]
#[derive(uniffi::Record)]
pub struct MessageReaction {
    pub created_at: u64,
    pub creator_identity: ThreemaId,
    pub emoji: EmojiReaction,
}
impl From<message::MessageReaction> for MessageReaction {
    fn from(reaction: message::MessageReaction) -> Self {
        Self {
            creator_identity: reaction.creator_identity.into(),
            created_at: reaction.created_at,
            emoji: reaction.emoji,
        }
    }
}
impl TryFrom<MessageReaction> for message::MessageReaction {
    type Error = ConversionError;

    fn try_from(reaction: MessageReaction) -> Result<Self, Self::Error> {
        Ok(Self {
            creator_identity: reaction.creator_identity.try_into()?,
            created_at: reaction.created_at,
            emoji: reaction.emoji,
        })
    }
}

/// Binding version of message [`message::MessageReactionUpdate`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct MessageReactionUpdate {
    pub created_at: u64,
    pub intent: MessageReactionUpdateIntent,
    pub emoji: EmojiReaction,
}
impl From<message::MessageReactionUpdate> for MessageReactionUpdate {
    fn from(update: message::MessageReactionUpdate) -> Self {
        Self {
            created_at: update.created_at,
            intent: update.intent,
            emoji: update.emoji,
        }
    }
}

/// Binding version of [`message::MessageStateBodyUpdate`].
#[derive(uniffi::Enum)]
#[expect(missing_docs, reason = "Binding version")]
pub enum MessageStateBodyUpdate {
    UserSent(u64),
    ContactDeliveryReceipt(ContactDeliveryUpdate),
    UserRead(u64),
    StarMarker(MessageStarMarker),
    Edit(MessageTextRevision),
    Delete(u64),
    Reaction(MessageReactionUpdate),
}
impl From<message::MessageStateBodyUpdate> for MessageStateBodyUpdate {
    fn from(update: message::MessageStateBodyUpdate) -> Self {
        match update {
            message::MessageStateBodyUpdate::UserSent(sent_at) => Self::UserSent(sent_at.0),
            message::MessageStateBodyUpdate::ContactDeliveryReceipt(delivery_receipt) => {
                Self::ContactDeliveryReceipt(delivery_receipt)
            },
            message::MessageStateBodyUpdate::UserRead(read_at) => Self::UserRead(read_at.0),
            message::MessageStateBodyUpdate::StarMarker(star_marker) => Self::StarMarker(star_marker),
            message::MessageStateBodyUpdate::Edit(text_message_revision) => Self::Edit(text_message_revision),
            message::MessageStateBodyUpdate::Delete(deleted_at) => Self::Delete(deleted_at.0),
            message::MessageStateBodyUpdate::Reaction(reaction) => Self::Reaction(reaction.into()),
        }
    }
}

/// Binding version of [`message::MessageStateMetadata`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct MessageStateMetadata {
    pub conversation_id: ConversationId,
    pub creator_identity: ThreemaId,
    pub message_id: common::MessageId,
    pub message_type: MessageStateBodyType,
}
impl TryFrom<MessageStateMetadata> for message::MessageStateMetadata {
    type Error = ConversionError;

    fn try_from(metadata: MessageStateMetadata) -> Result<Self, Self::Error> {
        Ok(Self {
            conversation_id: metadata.conversation_id.try_into()?,
            creator_identity: metadata.creator_identity.try_into()?,
            message_id: metadata.message_id,
            message_type: metadata.message_type,
        })
    }
}

/// Binding version of [`message::MessageState`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct MessageState {
    pub conversation_id: ConversationId,
    pub creator_identity: ThreemaId,
    pub message_id: common::MessageId,
    pub created_at: u64,
    pub direction: MessageDirection,
    pub read_at: Option<u64>,
    pub star_marker: MessageStarMarker,
    pub reactions: Vec<MessageReaction>,
    pub body: MessageStateBody,
}
impl From<message::MessageState> for MessageState {
    fn from(state: message::MessageState) -> Self {
        Self {
            conversation_id: state.conversation_id.into(),
            creator_identity: state.creator_identity.into(),
            message_id: state.message_id,
            created_at: state.created_at,
            direction: state.direction,
            read_at: state.read_at,
            star_marker: state.star_marker,
            reactions: state.reactions.into_iter().map(MessageReaction::from).collect(),
            body: state.body,
        }
    }
}
impl TryFrom<MessageState> for message::MessageState {
    type Error = ConversionError;

    fn try_from(state: MessageState) -> Result<Self, Self::Error> {
        Ok(Self {
            conversation_id: state.conversation_id.try_into()?,
            creator_identity: state.creator_identity.try_into()?,
            message_id: state.message_id,
            created_at: state.created_at,
            direction: state.direction,
            read_at: state.read_at,
            star_marker: state.star_marker,
            reactions: state
                .reactions
                .into_iter()
                .map(message::MessageReaction::try_from)
                .collect::<Result<_, _>>()?,
            body: state.body,
        })
    }
}

/// Binding version of [`message::MessageStateUpdate`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct MessageStateUpdate {
    pub conversation_id: ConversationId,
    pub creator_identity: ThreemaId,
    pub message_id: common::MessageId,
    pub update: MessageStateBodyUpdate,
}
impl From<message::MessageStateUpdate> for MessageStateUpdate {
    fn from(update: message::MessageStateUpdate) -> Self {
        Self {
            conversation_id: update.conversation_id.into(),
            creator_identity: update.creator_identity.into(),
            message_id: update.message_id,
            update: update.update.into(),
        }
    }
}
