//! Message state structs.
use core::str;

use educe::Educe;
use libthreema_macros::{Name, VariantNames};
#[cfg(any(test, feature = "cli"))]
use tracing::debug;

use crate::{
    common::{ConversationId, MessageId, MessageOverrides, ThreemaId},
    csp_e2e::message::LegacyReactionType,
    model::poll::PollId,
    utils::debug::debug_slice_length,
};
#[cfg(any(test, feature = "cli"))]
use crate::{provider::ProviderError, utils::update::TryApply};

/// A message star marker set by the user.
#[derive(Clone, Debug)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
#[cfg_attr(test, derive(PartialEq))]
pub enum MessageStarMarker {
    /// Not starred.
    None,

    /// The message has been starred.
    Star,
}

/// A text in a message.
#[derive(Clone, Educe)]
#[educe(Debug)]
#[cfg_attr(test, derive(PartialEq))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct MessageText {
    /// The text.
    #[educe(Debug(method(debug_slice_length)))]
    pub text: String,
}

/// A revision of a text in a message.
#[derive(Clone, Debug)]
#[cfg_attr(test, derive(PartialEq))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct MessageTextRevision {
    /// Unix-ish timestamp in milliseconds for when the revision has been created.
    pub created_at: u64,

    /// Text of the revision.
    pub message: MessageText,
}

/// A text message including all its revisions.
#[derive(Debug, Clone)]
#[cfg_attr(test, derive(PartialEq))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct TextMessageState {
    /// The original revision of the text message.
    pub original: MessageText,

    /// The revisions of the text message in ascending order of their reception.
    /// The last revision contains the most recent revision (i.e. the one that should
    /// be displayed).
    pub revisions: Vec<MessageTextRevision>,
}

/// A location message state.
#[derive(Clone, Debug)]
#[cfg_attr(test, derive(PartialEq))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct LocationMessageState {
    /// Latitude.
    pub latitude: f64,

    /// Longitude.
    pub longitude: f64,

    /// Accuracy of the original sender's position in meters.
    pub accuracy_m: Option<f64>,

    /// Closest name of the location or a point of interest.
    ///
    /// Empty string means that no name was provided.
    pub name: String,

    /// An arbitrary address, not following any standardized pattern. May contain line breaks.
    ///
    /// Empty string means that no address was provided.
    pub address: String,
}

/// A message indicating the event that the referred [`poll::Poll`][`crate::model::poll::Poll`] was opened.
#[derive(Clone, Debug)]
#[cfg_attr(test, derive(PartialEq))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct PollOpen {
    /// Refers to the opened poll.
    pub id: PollId,
}

/// A message indicating the event that the referred [`poll::Poll`][`crate::model::poll::Poll`] was closed.
#[derive(Clone, Debug)]
#[cfg_attr(test, derive(PartialEq))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct PollClose {
    /// Refers to the closed poll.
    pub id: PollId,
}

/// A deleted message state.
#[derive(Clone, Debug)]
#[cfg_attr(test, derive(PartialEq))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct DeletedMessageState {
    /// The message type of the original message that has been deleted.
    ///
    /// Note: If the previous type is unknown, flag it as [`MessageStateBodyType::Deleted`]. If, however, the
    /// information is necessary for modelling reasons and the type is [`MessageStateBodyType::Deleted`],
    /// convert it to a [`MessageStateBodyType`] of your choosing.
    /// Rationale: Depending on the client, the information may or may not be present and a _deleted_ type
    /// may or may not be implemented. Handling it the way described above retains as much information as
    /// possible.
    pub previous_message_type: MessageStateBodyType,

    /// Unix-ish timestamp in milliseconds when this message was deleted.
    pub deleted_at: u64,
}

/// An emoji part of a [`MessageReaction`].
#[derive(Clone, Debug)]
#[cfg_attr(any(feature = "cli", test), derive(PartialEq))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct EmojiReaction {
    /// A single fully-qualified [emoji codepoint sequence that is part of the
    /// currently supported Unicode standard][emoji-test.txt].
    ///
    /// [emoji-test.txt]:
    /// https://www.unicode.org/Public/emoji/latest/emoji-test.txt
    pub codepoint: String,
}
impl From<LegacyReactionType> for EmojiReaction {
    fn from(legacy_reaction: LegacyReactionType) -> Self {
        match legacy_reaction {
            LegacyReactionType::Acknowledge => Self {
                codepoint: "\u{1f44d}".to_owned(),
            },
            LegacyReactionType::Decline => Self {
                codepoint: "\u{1f44e}".to_owned(),
            },
        }
    }
}

/// A reaction to a message.
#[derive(Clone, Educe)]
#[educe(Debug)]
#[cfg_attr(test, derive(PartialEq))]
pub struct MessageReaction {
    /// The creator of this reaction.
    pub creator_identity: ThreemaId,

    /// Unix-ish timestamp in milliseconds when the reaction was created.
    pub created_at: u64,

    /// The emoji.
    pub emoji: EmojiReaction,
}

/// The type of a message body state.
#[derive(Debug, Clone, Copy)]
#[cfg_attr(test, derive(PartialEq))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum MessageStateBodyType {
    /// Text message state.
    Text,

    /// Location message state.
    Location,

    /// Open poll message state.
    PollOpen,

    /// Close poll message state.
    PollClose,

    /// Deleted message state.
    Deleted,
}
impl MessageStateBodyType {
    /// Whether the message type is eligible for reactions.
    ///
    /// Caveat for [`MessageStateBodyType::Deleted`]: Even though the original type mandates whether the
    /// message is eligible for reactions, they should not be applied to messages marked as deleted.
    #[inline]
    pub(crate) const fn is_reactable(self) -> bool {
        match self {
            Self::Text | Self::Location => true,
            Self::PollOpen | Self::PollClose | Self::Deleted => false,
        }
    }

    /// Whether the message type is eligible for deletions.
    ///
    /// Caveat for [`MessageStateBodyType::Deleted`]: Even though the original type mandates whether the
    /// message is eligible for deletion, it is already deleted... so, what's the point of doing that again.
    #[inline]
    pub(crate) const fn is_deletable(self) -> bool {
        match self {
            Self::Text | Self::Location => true,
            Self::PollOpen | Self::PollClose | Self::Deleted => false,
        }
    }
}

/// Body of a stateful message.
///
/// Depending on the variant, this may or may not incorporate multiple protocol-level messages into a single
/// stateful message that is displayed.
#[derive(Debug, Clone, VariantNames)]
#[cfg_attr(test, derive(PartialEq))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum MessageStateBody {
    /// A text message state consisting of all revisions.
    Text(TextMessageState),

    /// A location message.
    Location(LocationMessageState),

    /// A message indicating the opening of a poll.
    PollOpen(PollOpen),

    /// A message indicating the closing of a poll.
    PollClose(PollClose),

    /// A message indicating that the original message was deleted.
    Deleted(DeletedMessageState),
}
#[cfg(any(test, feature = "cli"))]
impl MessageStateBody {
    #[inline]
    pub(crate) const fn message_type(&self) -> MessageStateBodyType {
        match &self {
            Self::Text(_) => MessageStateBodyType::Text,
            Self::Location(_) => MessageStateBodyType::Location,
            Self::PollOpen(_) => MessageStateBodyType::PollOpen,
            Self::PollClose(_) => MessageStateBodyType::PollClose,
            Self::Deleted(_) => MessageStateBodyType::Deleted,
        }
    }

    /// Get the text revisions, if the message is editable.
    ///
    /// Caveat for [`MessageStateBodyType::Deleted`]: Even though the original type mandates whether the
    /// message is eligible for editing, existing revisions have been removed and no new ones may be added.
    #[inline]
    fn text_revisions(&mut self) -> Option<&mut Vec<MessageTextRevision>> {
        match self {
            Self::Text(message) => Some(message.revisions.as_mut()),
            Self::Location(_) | Self::PollOpen(_) | Self::PollClose(_) | Self::Deleted(_) => None,
        }
    }
}

/// Directional data associated to an incoming message.
#[derive(Clone, Copy, Debug)]
#[cfg_attr(test, derive(PartialEq))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct IncomingMessageDirection {
    /// Unix-ish timestamp in milliseconds for when the message has been received.
    pub received_at: u64,

    /// Message behaviour overrides.
    pub overrides: MessageOverrides,
}

/// Directional data associated to an outgoing message.
#[derive(Clone, Copy, Debug)]
#[cfg_attr(test, derive(PartialEq))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct OutgoingMessageDirection {
    /// Optional Unix-ish timestamp in milliseconds for when the message has been sent.
    pub sent_at: Option<u64>,

    /// Optional Unix-ish timestamp in milliseconds for when the message has been delivered.
    pub delivered_at: Option<u64>,
}

/// Direction with directional data associated to a message.
#[derive(Clone, Debug, Copy, VariantNames)]
#[cfg_attr(test, derive(PartialEq))]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum MessageDirection {
    /// Incoming.
    Incoming(IncomingMessageDirection),

    /// Outgoing.
    Outgoing(OutgoingMessageDirection),
}

/// A minimal set of metadata for a given message.
pub struct MessageStateMetadata {
    /// The conversation ID of the conversation the message is found in.
    pub conversation_id: ConversationId,

    /// Creator of the state.
    pub creator_identity: ThreemaId,

    /// The message ID of the message.
    pub message_id: MessageId,

    /// The message body state type.
    pub message_type: MessageStateBodyType,
}

/// A stateful message.
// TODO(LIB-161): Add forward security mode
#[derive(Clone, Debug, Name)]
#[cfg_attr(test, derive(PartialEq))]
pub struct MessageState {
    /// The ID of the conversation this message state belongs to.
    pub conversation_id: ConversationId,

    /// Creator of the state.
    pub creator_identity: ThreemaId,

    /// The ID of the message.
    pub message_id: MessageId,

    /// Unix-ish timestamp in milliseconds for when the message has been created.
    pub created_at: u64,

    /// Direction, containing directional specific data.
    ///
    /// Note: While alignment is required, you should always use [`MessageState::creator_identity`] as the
    /// primary source of truth to determine whether a message is incoming or outgoing!
    pub direction: MessageDirection,

    /// Optional Unix-ish timestamp in milliseconds for when the message has been marked as read.
    pub read_at: Option<u64>,

    /// Message marker.
    pub star_marker: MessageStarMarker,

    /// Reactions to this message.
    pub reactions: Vec<MessageReaction>,

    /// The message type dependent message body state.
    pub body: MessageStateBody,
}
#[cfg(any(test, feature = "cli"))]
impl MessageState {
    pub(crate) fn metadata(&self) -> MessageStateMetadata {
        MessageStateMetadata {
            conversation_id: self.conversation_id,
            creator_identity: self.creator_identity,
            message_id: self.message_id,
            message_type: self.body.message_type(),
        }
    }

    fn reactions(&mut self) -> Option<&mut Vec<MessageReaction>> {
        match self.body {
            MessageStateBody::Text(_)
            | MessageStateBody::Location(_)
            | MessageStateBody::PollOpen(_)
            | MessageStateBody::PollClose(_) => Some(self.reactions.as_mut()),
            MessageStateBody::Deleted(_) => None,
        }
    }
}

/// Unix-ish timestamp in milliseconds for when the outgoing message has been sent.
#[derive(Debug, Clone)]
pub struct UserSentTimestamp(pub u64);

/// A delivery receipt update by another contact.
#[derive(Clone, Debug, VariantNames)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum ContactDeliveryUpdate {
    /// Unix-ish timestamp in milliseconds for when the message has been received by the contact.
    Delivered(u64),

    /// Unix-ish timestamp in milliseconds for when the message has been read by the contact.
    Read(u64),
}

/// Unix-ish timestamp in milliseconds for when the incoming message has been read.
#[derive(Clone, Debug)]
pub struct UserReadTimestamp(pub u64);

/// Unix-ish timestamp in milliseconds for when the message has been deleted.
#[derive(Clone, Debug)]
pub struct DeletedTimestamp(pub u64);

/// The intent when updating a message with a reaction.
#[derive(Clone, Debug)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum MessageReactionUpdateIntent {
    /// Apply the reaction (if it does not already exist).
    Apply,

    /// Withdraw the reaction (if it already exists).
    Withdraw,

    /// Replace any reaction at the specified message of the specified sender with this reaction.
    Replace,
}

/// A message reaction update.
#[derive(Clone, Debug)]
pub struct MessageReactionUpdate {
    /// Unix-ish timestamp in milliseconds when the reaction was created (or withdrawn).
    pub created_at: u64,

    /// Whether the reaction should be added, withdrawn or replaced.
    pub intent: MessageReactionUpdateIntent,

    /// The emoji.
    pub emoji: EmojiReaction,
}

/// A message body state update.
///
/// See each variant's steps which is expected to be invoked with the following information:
///
/// - `update-creator`: The creator (i.e. origin) of the update.
/// - `conversation`: The associated conversation.
/// - `message`: The [message][`MessageState`] this update intends to be applied on.
#[derive(Debug, Clone, VariantNames)]
pub enum MessageStateBodyUpdate {
    /// Mark an outgoing message as _sent_ by the user.
    ///
    /// 1. If `update-creator` is not the user, return [`crate::provider::ProviderError::ContractViolation`].
    /// 2. If `message.creator` is not the user, return [`crate::provider::ProviderError::ContractViolation`].
    /// 3. If `message.direction` is not [`MessageDirection::Outgoing`], return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 4. Apply the enclosed value of `body` to `message.direction.sent_at`.
    UserSent(UserSentTimestamp),

    /// Apply a delivery receipt from another contact to an outgoing message.
    ///
    /// 1. If `conversation` is not a 1:1 contact conversation, return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 2. If `update-creator` is the user, return [`crate::provider::ProviderError::ContractViolation`].
    /// 3. If `message.creator` is not the user, return [`crate::provider::ProviderError::ContractViolation`].
    /// 4. If `message.direction` is not [`MessageDirection::Outgoing`], return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 5. If `update.body` is [`ContactDeliveryUpdate::Delivered`], apply the enclosed timestamp to
    ///    `message.direction.delivered_at`.
    /// 6. If `update.body` is [`ContactDeliveryUpdate::Read`], apply the enclosed timestamp to
    ///    `message.read_at`.
    /// 7. (Unreachable).
    ContactDeliveryReceipt(ContactDeliveryUpdate),

    /// Mark an incoming message as _read_ by the user.
    ///
    /// 1. If `conversation` is not a 1:1 contact conversation, return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 4. If `update-creator` is not the user, return [`crate::provider::ProviderError::ContractViolation`].
    /// 3. If `message.creator` is the user, return [`crate::provider::ProviderError::ContractViolation`].
    /// 5. If `message.direction` is not [`MessageDirection::Incoming`], return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 6. Apply the enclosed timestamp to `message.read_at`.
    UserRead(UserReadTimestamp),

    /// Update the star marker of a message.
    ///
    /// 1. If the `update-creator` is not the user, return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 2. Apply the enclosed marker to `message.star_marker`.
    StarMarker(MessageStarMarker),

    /// Apply an edit revision to a message.
    ///
    /// 1. If `conversation` is a distribution list, return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 2. If `update-creator` does not equal `message.creator`, return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 3. If `message` has been [_deleted_][`crate::model::message::MessageStateBody::Deleted`], return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 4. If `message` is not eligible for editing, return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 5. Add the enclosed text revision to `message.body` as the most recent revision.
    Edit(MessageTextRevision),

    /// Mark a message as deleted, replacing its content with a placeholder and removing most of its visible
    /// properties.
    ///
    /// 1. If `conversation` is a distribution list, return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 2. If `update-creator` does not equal `message.creator`, return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 3. If `message` has been [_deleted_][`crate::model::message::MessageStateBody::Deleted`], return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 4. If `message` is not eligible for deletion, return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 5. Remove all reactions from `message`.
    /// 6. Set `message.body` to [`MessageStateBody::Deleted`] using the enclosed timestamp and the type of
    ///    `message`.
    Delete(DeletedTimestamp),

    /// Update the reactions of a message.
    ///
    /// 1. If `conversation` is a distribution list, return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 2. If `message` has been [_deleted_][`crate::model::message::MessageStateBody::Deleted`], return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 3. If `message` is not eligible for reactions, return
    ///    [`crate::provider::ProviderError::ContractViolation`].
    /// 4. Let `update` be the enclosed [`MessageReactionUpdate`].
    /// 5. If `update.intent` is [`MessageReactionUpdateIntent::Apply`]:
    ///    1. Look up a reaction from the `update-creator` matching `update.emoji` and let `existing` be the
    ///       result.
    ///    2. If `existing` is defined, log a notice, discard `update` and return.
    ///    3. Add a new reaction based on `update` to `message.reactions`.
    /// 6. If `update.intent` is [`MessageReactionUpdateIntent::Withdraw`], remove a reaction from the
    ///    `update-creator` matching `update.emoji` within `message.reactions` (if it exists).
    /// 7. If `update.intent` is [`MessageReactionUpdateIntent::Replace`]:
    ///    1. Remove all reactions from the `update-creator` within `message.reactions`.
    ///    2. Add a new reaction based on `update` to `message.reactions`.
    Reaction(MessageReactionUpdate),
}

/// An update to a message state.
///
/// Can be created by:
///
/// - incoming messages from other contacts,
/// - events of the user, e.g. _starring_ a message.
///
/// Consequently, the origin of an update is carried by the [`MessageStateUpdate::creator_identity`] field and
/// the user's Threema ID is used for events created by the user.
#[derive(Debug)]
pub struct MessageStateUpdate {
    /// The ID of the conversation the referred message (and also the origin for that matter)
    /// belongs to.
    pub conversation_id: ConversationId,

    /// Creator of the update.
    ///
    /// Note: The creator of an update is not necessarily the creator of the referred state. Each
    /// [`MessageStateBodyUpdate`] variant needs to handle this explicitly.
    pub creator_identity: ThreemaId,

    /// The ID of the message this update should be applied to (sometimes referred to as the _referred
    /// message ID_).
    pub message_id: MessageId,

    /// The update to be applied to the referred message.
    pub update: MessageStateBodyUpdate,
}

#[cfg(any(test, feature = "cli"))]
struct MessageStateUpdateApplyFrom<T> {
    user_identity: ThreemaId,
    creator_identity: ThreemaId,
    update: T,
}
#[cfg(any(test, feature = "cli"))]
impl TryApply<MessageStateUpdateApplyFrom<UserSentTimestamp>> for MessageState {
    type Error = ProviderError;

    fn try_apply(
        &mut self,
        update_context: MessageStateUpdateApplyFrom<UserSentTimestamp>,
    ) -> Result<(), Self::Error> {
        // Ensure that the user is the creator of the update.
        if update_context.creator_identity != update_context.user_identity {
            return Err(ProviderError::ContractViolation(
                "Only the user can update sent timestamps".to_owned(),
            ));
        }

        // Ensure that the message is outgoing.
        if self.creator_identity != update_context.user_identity {
            return Err(ProviderError::ContractViolation(
                "Cannot apply a sent timestamp to an incoming message".to_owned(),
            ));
        }
        let MessageDirection::Outgoing(direction) = &mut self.direction else {
            return Err(ProviderError::ContractViolation(
                "Inconsistent direction when attempting to apply an incoming message update".to_owned(),
            ));
        };

        // Apply the timestamp.
        direction.sent_at = Some(update_context.update.0);
        Ok(())
    }
}
#[cfg(any(test, feature = "cli"))]
impl TryApply<MessageStateUpdateApplyFrom<ContactDeliveryUpdate>> for MessageState {
    type Error = ProviderError;

    fn try_apply(
        &mut self,
        update_context: MessageStateUpdateApplyFrom<ContactDeliveryUpdate>,
    ) -> Result<(), Self::Error> {
        // Ensure the update does only update 1:1 conversations.
        if !matches!(self.conversation_id, ConversationId::Contact(_)) {
            return Err(ProviderError::ContractViolation(format!(
                "Unsupported conversation {} for incoming delivery update",
                self.conversation_id.variant_name()
            )));
        }

        // Ensure that the update creator is not the user.
        if update_context.creator_identity == update_context.user_identity {
            return Err(ProviderError::ContractViolation(
                "Cannot apply an incoming delivery update from the user".to_owned(),
            ));
        }

        // Ensure the message is outgoing.
        if self.creator_identity != update_context.user_identity {
            return Err(ProviderError::ContractViolation(
                "Cannot apply a sent timestamp to an incoming message".to_owned(),
            ));
        }
        let MessageDirection::Outgoing(direction) = &mut self.direction else {
            return Err(ProviderError::ContractViolation(
                "Inconsistent direction when attempting to apply an incoming message update".to_owned(),
            ));
        };

        // Apply the timestamp.
        match update_context.update {
            ContactDeliveryUpdate::Delivered(delivered_at) => direction.delivered_at = Some(delivered_at),
            ContactDeliveryUpdate::Read(read) => self.read_at = Some(read),
        }
        Ok(())
    }
}
#[cfg(any(test, feature = "cli"))]
impl TryApply<MessageStateUpdateApplyFrom<UserReadTimestamp>> for MessageState {
    type Error = ProviderError;

    fn try_apply(
        &mut self,
        update_context: MessageStateUpdateApplyFrom<UserReadTimestamp>,
    ) -> Result<(), Self::Error> {
        // Ensure the update does only update 1:1 conversations.
        if !matches!(self.conversation_id, ConversationId::Contact(_)) {
            return Err(ProviderError::ContractViolation(format!(
                "Unsupported conversation {} for applying the user's read timestamp",
                self.conversation_id.variant_name()
            )));
        }

        // Ensure that the original message is incoming.
        if self.creator_identity == update_context.user_identity {
            return Err(ProviderError::ContractViolation(
                "Cannot apply an incoming read timestamp to an outgoing message".to_owned(),
            ));
        }
        if !matches!(self.direction, MessageDirection::Incoming(_)) {
            return Err(ProviderError::ContractViolation(
                "Inconsistent direction when attempting to apply the user-read timestamp".to_owned(),
            ));
        }

        // Ensure that the update creator is the user.
        if update_context.creator_identity != update_context.user_identity {
            return Err(ProviderError::ContractViolation(
                "Only the user can update the read timestamp of an incoming message".to_owned(),
            ));
        }

        // Apply the timestamp.
        self.read_at = Some(update_context.update.0);
        Ok(())
    }
}
#[cfg(any(test, feature = "cli"))]
impl TryApply<MessageStateUpdateApplyFrom<MessageStarMarker>> for MessageState {
    type Error = ProviderError;

    fn try_apply(
        &mut self,
        update_context: MessageStateUpdateApplyFrom<MessageStarMarker>,
    ) -> Result<(), Self::Error> {
        // Ensure the update creator is the user.
        if update_context.creator_identity != update_context.user_identity {
            return Err(ProviderError::ContractViolation(format!(
                "Cannot apply a message star marker from non-user origin {}",
                update_context.creator_identity,
            )));
        }

        // Apply the message star marker.
        self.star_marker = update_context.update;
        Ok(())
    }
}
#[cfg(any(test, feature = "cli"))]
impl TryApply<MessageStateUpdateApplyFrom<MessageTextRevision>> for MessageState {
    type Error = ProviderError;

    fn try_apply(
        &mut self,
        update_context: MessageStateUpdateApplyFrom<MessageTextRevision>,
    ) -> Result<(), Self::Error> {
        // Ensure the update does not target a distribution list.
        if matches!(self.conversation_id, ConversationId::DistributionList(_)) {
            return Err(ProviderError::ContractViolation(format!(
                "Unsupported conversation {} for editing",
                self.conversation_id.variant_name()
            )));
        }

        // Ensure the update creator is the original creator of the message.
        if update_context.creator_identity != self.creator_identity {
            return Err(ProviderError::ContractViolation(
                "Message can only be edited by its creator".to_owned(),
            ));
        }

        // Determine whether the message is eligible for editing.
        //
        // Note: When a text revision is yielded, we have implicitly ensured that the message has not been
        // deleted.
        let Some(text_revisions) = self.body.text_revisions() else {
            return Err(ProviderError::ContractViolation(format!(
                "Message {} is not eligible for editing",
                self.body.variant_name()
            )));
        };

        // Add to text revisions.
        text_revisions.push(update_context.update);
        Ok(())
    }
}
#[cfg(any(test, feature = "cli"))]
impl TryApply<MessageStateUpdateApplyFrom<DeletedTimestamp>> for MessageState {
    type Error = ProviderError;

    fn try_apply(
        &mut self,
        update_context: MessageStateUpdateApplyFrom<DeletedTimestamp>,
    ) -> Result<(), Self::Error> {
        // Ensure the update does not target a distribution list.
        if matches!(self.conversation_id, ConversationId::DistributionList(_)) {
            return Err(ProviderError::ContractViolation(format!(
                "Unsupported conversation {} for deletion",
                self.conversation_id.variant_name()
            )));
        }

        // Ensure the update creator is the original creator of the message.
        if update_context.creator_identity != self.creator_identity {
            return Err(ProviderError::ContractViolation(
                "Message can only be deleted by its creator".to_owned(),
            ));
        }

        // Determine whether the message is eligible for deletion.
        //
        // Note: This implicitly checks if the message has already been deleted.
        let message_type = self.body.message_type();
        if !message_type.is_deletable() {
            return Err(ProviderError::ContractViolation(format!(
                "Message {} is not eligible for deletion",
                self.body.variant_name()
            )));
        }

        // Purge reactions and replace with a _deleted_ message.
        self.reactions = vec![];
        self.body = MessageStateBody::Deleted(DeletedMessageState {
            previous_message_type: message_type,
            deleted_at: update_context.update.0,
        });
        Ok(())
    }
}
#[cfg(any(test, feature = "cli"))]
impl TryApply<MessageStateUpdateApplyFrom<MessageReactionUpdate>> for MessageState {
    type Error = ProviderError;

    fn try_apply(
        &mut self,
        update_context: MessageStateUpdateApplyFrom<MessageReactionUpdate>,
    ) -> Result<(), Self::Error> {
        // Ensure the update does not target a distribution list.
        if matches!(self.conversation_id, ConversationId::DistributionList(_)) {
            return Err(ProviderError::ContractViolation(format!(
                "Unsupported conversation {} for reactions",
                self.conversation_id.variant_name()
            )));
        }

        // Determine whether the message is eligible for reactions.
        //
        // Note: This implicitly checks if the message has already been deleted.
        let Some(reactions) = self.reactions() else {
            return Err(ProviderError::ContractViolation(format!(
                "Message {} is not eligible for reactions",
                self.body.variant_name()
            )));
        };

        // Apply the reaction according to the intent
        match update_context.update.intent {
            MessageReactionUpdateIntent::Apply => {
                // Check if there already is a matching existing reaction.
                if reactions
                    .iter()
                    .find(|reaction| {
                        reaction.creator_identity == update_context.creator_identity
                            && reaction.emoji == update_context.update.emoji
                    })
                    .is_some()
                {
                    debug!(
                        "Discarding reaction that already exists on message {}",
                        self.message_id
                    );
                    return Ok(());
                }

                // Apply the new reaction.
                reactions.push(MessageReaction {
                    creator_identity: update_context.creator_identity,
                    created_at: update_context.update.created_at,
                    emoji: update_context.update.emoji,
                });
            },

            MessageReactionUpdateIntent::Withdraw => {
                // Lookup a matching existing reaction and remove it, if any.
                if let Some(position) = reactions.iter().position(|reaction| {
                    reaction.emoji == update_context.update.emoji
                        && reaction.creator_identity == update_context.creator_identity
                }) {
                    let _ = reactions.remove(position);
                } else {
                    debug!(
                        "Reaction to withdraw does not exist on message {}",
                        self.message_id
                    );
                }
            },

            MessageReactionUpdateIntent::Replace => {
                // Remove all reactions from the sender.
                reactions.retain(|reaction| reaction.creator_identity != update_context.creator_identity);

                // Add the reaction.
                reactions.push(MessageReaction {
                    creator_identity: update_context.creator_identity,
                    created_at: update_context.update.created_at,
                    emoji: update_context.update.emoji,
                });
            },
        }
        Ok(())
    }
}

#[cfg(any(test, feature = "cli"))]
pub(crate) struct MessageStateUpdateApplyContext {
    pub(crate) user_identity: ThreemaId,
    pub(crate) update: MessageStateUpdate,
}
#[cfg(any(test, feature = "cli"))]
impl TryApply<MessageStateUpdateApplyContext> for MessageState {
    type Error = ProviderError;

    fn try_apply(
        &mut self,
        MessageStateUpdateApplyContext {
            user_identity,
            update,
        }: MessageStateUpdateApplyContext,
    ) -> Result<(), Self::Error> {
        // Ensure the update is applied to a matching message.
        if !(self.conversation_id == update.conversation_id && self.message_id == update.message_id) {
            return Err(ProviderError::ContractViolation(
                "Message update does not match message".to_owned(),
            ));
        }

        // Apply the update.
        match update.update {
            MessageStateBodyUpdate::ContactDeliveryReceipt(delivery_update) => {
                self.try_apply(MessageStateUpdateApplyFrom {
                    user_identity,
                    creator_identity: update.creator_identity,
                    update: delivery_update,
                })
            },
            MessageStateBodyUpdate::UserSent(sent) => self.try_apply(MessageStateUpdateApplyFrom {
                user_identity,
                creator_identity: update.creator_identity,
                update: sent,
            }),
            MessageStateBodyUpdate::UserRead(delivery_update) => {
                self.try_apply(MessageStateUpdateApplyFrom {
                    user_identity,
                    creator_identity: update.creator_identity,
                    update: delivery_update,
                })
            },
            MessageStateBodyUpdate::Edit(text_revision) => self.try_apply(MessageStateUpdateApplyFrom {
                user_identity,
                creator_identity: update.creator_identity,
                update: text_revision,
            }),
            MessageStateBodyUpdate::Delete(deleted) => self.try_apply(MessageStateUpdateApplyFrom {
                user_identity,
                creator_identity: update.creator_identity,
                update: deleted,
            }),
            MessageStateBodyUpdate::StarMarker(star_marker) => self.try_apply(MessageStateUpdateApplyFrom {
                user_identity,
                creator_identity: update.creator_identity,
                update: star_marker,
            }),
            MessageStateBodyUpdate::Reaction(reaction) => self.try_apply(MessageStateUpdateApplyFrom {
                user_identity,
                creator_identity: update.creator_identity,
                update: reaction,
            }),
        }
    }
}
