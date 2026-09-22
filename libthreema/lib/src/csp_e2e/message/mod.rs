//! Message-related structures and tasks.
use core::fmt;

use duplicate::duplicate_item;
use educe::Educe;
use libthreema_macros::Name;
use tracing::{debug, warn};

use crate::{
    common::{ConversationId, DistributionListId, GroupIdentity, MessageFlags, MessageId, ThreemaId},
    model::message::{
        ContactDeliveryUpdate, IncomingMessageDirection, LocationMessageState, MessageDirection,
        MessageReactionUpdate, MessageReactionUpdateIntent, MessageStarMarker, MessageState,
        MessageStateBody, MessageStateBodyUpdate, MessageStateMetadata, MessageStateUpdate, MessageText,
        TextMessageState,
    },
    protobuf::common::CspE2eMessageType,
    utils::{
        debug::{Name as _, debug_slice_length},
        time::utc_now_ms,
        update::Apply,
    },
};

pub mod codec;
pub(super) mod payload;
pub mod task;

/// Lifetime of the message on the server.
#[derive(Clone)]
pub(super) enum MessageLifetime {
    /// The message is kept indefinitely until received.
    Indefinite,

    /// The message is kept for a short amount of time until it is silently dropped (usually 30s).
    #[expect(unused, reason = "Not used yet")]
    Brief,

    /// The message is only transmitted if the receiver is currently online.
    ///
    /// This is a combination of the _no server queuing_ and _no server acknowledgement_ flags
    /// which are only used in conjunction.
    Ephemeral,
}

/// Message properties associated to a message type.
#[expect(
    clippy::struct_excessive_bools,
    reason = "The one place where it's reasonable"
)]
#[derive(Clone)]
pub(super) struct MessageProperties {
    /// Whether the message should be/has been pushed.
    pub(super) push_notification: bool,

    /// Lifetime of the message on the server.
    pub(super) lifetime: MessageLifetime,

    /// Whether the message requires user profile distribution.
    pub(super) user_profile_distribution: bool,

    /// Whether the message requires to create a _direct_ contact upon reception.
    pub(super) requires_direct_contact: bool,

    /// Whether the message requires replay protection (by storing the nonce).
    pub(super) replay_protection: bool,

    /// Whether the message should be reflected in case it is incoming.
    pub(super) reflect_incoming: bool,

    /// Whether the message should be reflected in case it is outgoing.
    pub(super) reflect_outgoing: bool,

    /// Whether an update that the message has been _sent_ should be reflected (in case it is
    /// outgoing).
    pub(super) reflect_sent_update: bool,

    /// Whether delivery receipts may be sent in response to this message.
    pub(super) delivery_receipts: bool,
}
impl Apply<MessageProperties> for MessageFlags {
    fn apply(&mut self, properties: MessageProperties) {
        let MessageProperties {
            push_notification,
            lifetime,
            user_profile_distribution: _user_profile_distribution,
            requires_direct_contact: _requires_direct_contact,
            reflect_incoming: _reflect_incoming,
            replay_protection: _replay_protection,
            reflect_outgoing: _reflect_outgoing,
            reflect_sent_update: _reflect_sent_update,
            delivery_receipts: _delivery_receipts,
        } = properties;

        if push_notification {
            self.0 |= Self::SEND_PUSH_NOTIFICATION;
        }
        match lifetime {
            MessageLifetime::Indefinite => {},
            MessageLifetime::Brief => {
                self.0 |= Self::SHORT_LIVED_SERVER_QUEUING;
            },
            MessageLifetime::Ephemeral => {
                self.0 |= Self::NO_SERVER_QUEUING | Self::NO_SERVER_ACKNOWLEDGEMENT;
            },
        }
    }
}

/// Message properties associated to a group message type.
///
/// This is a reduced version of [`MessageProperties`].
#[expect(
    clippy::struct_excessive_bools,
    reason = "The one place where it's reasonable"
)]
struct GroupMessageProperties {
    push_notification: bool,
    lifetime: MessageLifetime,
    user_profile_distribution: bool,
    replay_protection: bool,
    reflect_incoming: bool,
    reflect_outgoing: bool,
    reflect_sent_update: bool,
}
impl GroupMessageProperties {
    const fn into_message_properties(self) -> MessageProperties {
        MessageProperties {
            push_notification: self.push_notification,
            lifetime: self.lifetime,
            user_profile_distribution: self.user_profile_distribution,
            requires_direct_contact: false,
            replay_protection: self.replay_protection,
            reflect_incoming: self.reflect_incoming,
            reflect_outgoing: self.reflect_outgoing,
            reflect_sent_update: self.reflect_sent_update,
            delivery_receipts: false,
        }
    }
}

/// Message behaviour overrides that need to be stored.
#[derive(Clone, Copy, Name)]
#[cfg_attr(test, derive(PartialEq, Default))]
pub(crate) struct MessageOverrides {
    /// Whether delivery receipts should be omitted. If `true`, this overrides the default behaviour.
    pub(crate) disable_delivery_receipts: bool,
}
impl Apply<MessageOverrides> for MessageProperties {
    fn apply(&mut self, overrides: MessageOverrides) {
        if overrides.disable_delivery_receipts {
            self.delivery_receipts = false;
        }
    }
}
impl Apply<MessageOverrides> for MessageFlags {
    fn apply(&mut self, overrides: MessageOverrides) {
        if overrides.disable_delivery_receipts {
            self.0 |= Self::NO_DELIVERY_RECEIPTS;
        }
    }
}
impl fmt::Debug for MessageOverrides {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        // Keep this format in sync with [`MessageFlags`]!
        write!(
            formatter,
            "{}({})",
            Self::NAME,
            itertools::join(
                [self.disable_delivery_receipts.then_some("no-receipts")]
                    .into_iter()
                    .flatten(),
                ", ",
            ),
        )
    }
}
impl From<MessageFlags> for MessageOverrides {
    fn from(flags: MessageFlags) -> Self {
        Self {
            disable_delivery_receipts: flags.0 & MessageFlags::NO_DELIVERY_RECEIPTS != 0,
        }
    }
}

#[derive(Clone, Educe)]
#[educe(Debug)]
pub(super) struct TextMessage {
    /// Text of the message.
    #[educe(Debug(method(debug_slice_length)))]
    pub(super) text: String,
}
impl TextMessage {
    const CONTACT_EXEMPT_FROM_BLOCKING: bool = false;
    const CONTACT_PROPERTIES: MessageProperties = MessageProperties {
        push_notification: true,
        lifetime: MessageLifetime::Indefinite,
        user_profile_distribution: true,
        requires_direct_contact: true,
        replay_protection: true,
        reflect_incoming: true,
        reflect_outgoing: true,
        reflect_sent_update: true,
        delivery_receipts: true,
    };
    const CONTACT_TYPE: CspE2eMessageType = CspE2eMessageType::Text;
    const GROUP_EXEMPT_FROM_BLOCKING: bool = false;
    const GROUP_PROPERTIES: GroupMessageProperties = GroupMessageProperties {
        push_notification: true,
        lifetime: MessageLifetime::Indefinite,
        user_profile_distribution: true,
        replay_protection: true,
        reflect_incoming: true,
        reflect_outgoing: true,
        reflect_sent_update: true,
    };
    const GROUP_TYPE: CspE2eMessageType = CspE2eMessageType::GroupText;
}
impl From<&TextMessage> for MessageStateBody {
    fn from(message: &TextMessage) -> Self {
        Self::Text(TextMessageState {
            original: MessageText {
                text: message.text.clone(),
            },
            revisions: vec![],
        })
    }
}

#[derive(Clone, Name)]
pub(super) struct LocationMessage {
    /// Latitude.
    pub(super) latitude: f64,

    /// Longitude.
    pub(super) longitude: f64,

    /// Accuracy of the original sender's position in meters.
    pub(super) accuracy_m: Option<f64>,

    /// Closest name of the location or a point of interest.
    ///
    /// Empty string means that no name was provided.
    pub(super) name: String,

    /// An arbitrary address, not following any standardized pattern. May contain line breaks.
    ///
    /// Empty string means that no address was provided.
    pub(super) address: String,
}
impl LocationMessage {
    const CONTACT_EXEMPT_FROM_BLOCKING: bool = false;
    const CONTACT_PROPERTIES: MessageProperties = MessageProperties {
        push_notification: true,
        lifetime: MessageLifetime::Indefinite,
        user_profile_distribution: true,
        requires_direct_contact: true,
        replay_protection: true,
        reflect_incoming: true,
        reflect_outgoing: true,
        reflect_sent_update: true,
        delivery_receipts: true,
    };
    const CONTACT_TYPE: CspE2eMessageType = CspE2eMessageType::Location;
    const GROUP_EXEMPT_FROM_BLOCKING: bool = false;
    const GROUP_PROPERTIES: GroupMessageProperties = GroupMessageProperties {
        push_notification: true,
        lifetime: MessageLifetime::Indefinite,
        user_profile_distribution: true,
        replay_protection: true,
        reflect_incoming: true,
        reflect_outgoing: true,
        reflect_sent_update: true,
    };
    const GROUP_TYPE: CspE2eMessageType = CspE2eMessageType::Location;
}
impl fmt::Debug for LocationMessage {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(Self::NAME)
    }
}
impl From<&LocationMessage> for MessageStateBody {
    fn from(message: &LocationMessage) -> Self {
        Self::Location(LocationMessageState {
            latitude: message.latitude,
            longitude: message.longitude,
            accuracy_m: message.accuracy_m,
            address: message.address.clone(),
            name: message.name.clone(),
        })
    }
}

/// The type of delivery receipt.
#[derive(Debug, Clone, Copy, strum::FromRepr)]
#[repr(u8)]
pub(super) enum DeliveryReceiptType {
    /// The referred messages have been received (i.e. it was delivered to the recipient).
    Received = 0x01,

    /// The referred messages have been read.
    Read = 0x02,
}

/// The type of legacy reaction.
#[derive(Debug, Clone, Copy, strum::FromRepr)]
#[repr(u8)]
pub(crate) enum LegacyReactionType {
    /// The user reacted with _acknowledge_ (i.e. _thumbs up_) to the messages.
    Acknowledge = 0x03,

    /// The user reacted with _decline_ (i.e. _thumbs down_) to the messages.
    Decline = 0x04,
}

/// A delivery receipt.
///
/// Note: This only covers real delivery receipts, not legacy reactions. These are always mapped to and from
/// [`LegacyReactionMessage`].
#[derive(Clone)]
pub(super) struct DeliveryReceiptMessage {
    /// Type of delivery receipt.
    pub(super) receipt_type: DeliveryReceiptType,

    /// Message ids of referred messages the receipt type should be applied to.
    pub(super) message_ids: Vec<MessageId>,
}
impl DeliveryReceiptMessage {
    const CONTACT_EXEMPT_FROM_BLOCKING: bool = false;
    const CONTACT_PROPERTIES: MessageProperties = MessageProperties {
        push_notification: false,
        lifetime: MessageLifetime::Indefinite,
        user_profile_distribution: false,
        requires_direct_contact: false,
        replay_protection: false,
        reflect_incoming: true,
        reflect_outgoing: true,
        reflect_sent_update: false,
        delivery_receipts: false,
    };
    const CONTACT_TYPE: CspE2eMessageType = CspE2eMessageType::DeliveryReceipt;

    pub(super) fn to_incoming_state_updates(
        &self,
        user_identity: ThreemaId,
        sender_identity: ThreemaId,
        created_at: u64,
        conversation_id: ConversationId,
        referred_messages_metadata: &[MessageStateMetadata],
    ) -> Vec<MessageStateUpdate> {
        let update = MessageStateBodyUpdate::ContactDeliveryReceipt(match &self.receipt_type {
            DeliveryReceiptType::Received => ContactDeliveryUpdate::Delivered(created_at),
            DeliveryReceiptType::Read => ContactDeliveryUpdate::Read(created_at),
        });

        // Create a state update for each referred message, if found and applicable.
        self.message_ids
            .iter()
            .filter_map(|message_id| {
                // Filter unknown.
                let Some(metadata) = referred_messages_metadata
                    .iter()
                    .find(|metadata| metadata.message_id == *message_id)
                else {
                    debug!(
                        referred_message_id = ?message_id,
                        "Discarding incoming delivery receipt referring to an unknown message",
                    );
                    return None;
                };

                // Ensure an outgoing message is referred.
                if metadata.creator_identity != user_identity {
                    warn!(
                        referred_message_id = ?message_id,
                        "Discarding incoming delivery receipt for an incoming message",
                    );
                    return None;
                }

                // Map to state update.
                Some(MessageStateUpdate {
                    conversation_id,
                    creator_identity: sender_identity,
                    message_id: *message_id,
                    update: update.clone(),
                })
            })
            .collect()
    }
}

/// A legacy reaction message.
///
/// Note: Delivery receipts containing legacy reactions are always mapped to and from this message internally.
#[derive(Clone)]
pub(super) struct LegacyReactionMessage {
    /// Type of legacy reaction.
    pub(super) reaction_type: LegacyReactionType,

    /// Message ids of referred messages the reaction should be applied to.
    pub(super) message_ids: Vec<MessageId>,
}
impl LegacyReactionMessage {
    const CONTACT_EXEMPT_FROM_BLOCKING: bool = false;
    const CONTACT_PROPERTIES: MessageProperties = MessageProperties {
        push_notification: false,
        lifetime: MessageLifetime::Indefinite,
        user_profile_distribution: true,
        requires_direct_contact: false,
        replay_protection: true,
        reflect_incoming: true,
        reflect_outgoing: true,
        reflect_sent_update: false,
        delivery_receipts: false,
    };
    const CONTACT_TYPE: CspE2eMessageType = CspE2eMessageType::DeliveryReceipt;
    const GROUP_EXEMPT_FROM_BLOCKING: bool = false;
    const GROUP_PROPERTIES: GroupMessageProperties = GroupMessageProperties {
        push_notification: false,
        lifetime: MessageLifetime::Indefinite,
        user_profile_distribution: true,
        replay_protection: true,
        reflect_incoming: true,
        reflect_outgoing: true,
        reflect_sent_update: false,
    };
    const GROUP_TYPE: CspE2eMessageType = CspE2eMessageType::GroupDeliveryReceipt;

    pub(super) fn to_incoming_state_updates(
        &self,
        user_identity: ThreemaId,
        sender_identity: ThreemaId,
        created_at: u64,
        conversation_id: ConversationId,
        referred_messages_metadata: &[MessageStateMetadata],
    ) -> Vec<MessageStateUpdate> {
        // Create a state update for each referred message, if found and applicable.
        self.message_ids
            .iter()
            .filter_map(|message_id| {
                // Filter unknown.
                let Some(metadata) = referred_messages_metadata
                    .iter()
                    .find(|metadata| metadata.message_id == *message_id)
                else {
                    debug!(
                        referred_message_id = ?message_id,
                        "Discarding incoming legacy reaction referring to an unknown message",
                    );
                    return None;
                };

                // Ensure an outgoing message is referred.
                if metadata.creator_identity != user_identity {
                    warn!(
                        referred_message_id = ?message_id,
                        "Discarding incoming legacy reaction for an incoming message",
                    );
                    return None;
                }

                // Ensure the message is eligible for reactions.
                if !metadata.message_type.is_reactable() {
                    debug!(
                        referred_message_id = ?message_id,
                        "Discarding incoming legacy reaction for {:?} not eligible for reactions",
                        metadata.message_type
                    );
                    return None;
                }

                // Map to state update.
                Some(MessageStateUpdate {
                    conversation_id,
                    creator_identity: sender_identity,
                    message_id: *message_id,
                    update: MessageStateBodyUpdate::Reaction(MessageReactionUpdate {
                        created_at,
                        intent: MessageReactionUpdateIntent::Replace,
                        emoji: self.reaction_type.into(),
                    }),
                })
            })
            .collect()
    }
}

/// A group setup message.
#[derive(Clone)]
pub(super) struct GroupSetupMessage {
    /// Members of the group.
    #[expect(unused, reason = "Will be used in LIB-143")]
    pub(super) members: Vec<ThreemaId>,
}
impl GroupSetupMessage {
    const GROUP_PROPERTIES: GroupMessageProperties = GroupMessageProperties {
        push_notification: false,
        lifetime: MessageLifetime::Indefinite,
        user_profile_distribution: true,
        replay_protection: true,
        reflect_incoming: true,
        reflect_outgoing: true,
        reflect_sent_update: false,
    };
    const TYPE: CspE2eMessageType = CspE2eMessageType::GroupSetup;
}

/// A control message from Threema Web, requesting a session to be resumed.
#[derive(Clone, Educe)]
#[educe(Debug)]
pub(super) struct WebSessionResumeMessage {
    /// Raw `push-payload` of a `web-session-resume` message.
    #[educe(Debug(method(debug_slice_length)))]
    pub(super) push_payload: Vec<u8>,
}
impl WebSessionResumeMessage {
    const CONTACT_EXEMPT_FROM_BLOCKING: bool = true;
    const CONTACT_PROPERTIES: MessageProperties = MessageProperties {
        push_notification: false,
        lifetime: MessageLifetime::Ephemeral,
        user_profile_distribution: false,
        requires_direct_contact: false,
        replay_protection: true,
        reflect_incoming: false,
        reflect_outgoing: false,
        reflect_sent_update: false,
        delivery_receipts: false,
    };
    const CONTACT_TYPE: CspE2eMessageType = CspE2eMessageType::WebSessionResume;
}

/// The body of a contact message.
#[derive(Clone)]
pub(super) enum ContactMessageBody {
    Text(TextMessage),
    Location(LocationMessage),
    DeliveryReceipt(DeliveryReceiptMessage),
    LegacyReaction(LegacyReactionMessage),
    WebSessionResume(WebSessionResumeMessage),
    // TODO(LIB-16): Complete
}
impl ContactMessageBody {
    /// Get the 1:1 message's type.
    #[inline]
    const fn message_type(&self) -> CspE2eMessageType {
        match &self {
            Self::Text(_) => TextMessage::CONTACT_TYPE,
            Self::Location(_) => LocationMessage::CONTACT_TYPE,
            Self::DeliveryReceipt(_) => DeliveryReceiptMessage::CONTACT_TYPE,
            Self::LegacyReaction(_) => LegacyReactionMessage::CONTACT_TYPE,
            Self::WebSessionResume(_) => WebSessionResumeMessage::CONTACT_TYPE,
        }
    }

    /// Get the 1:1 message's properties.
    #[inline]
    const fn properties(&self) -> MessageProperties {
        match &self {
            Self::Text(_) => TextMessage::CONTACT_PROPERTIES,
            Self::Location(_) => LocationMessage::CONTACT_PROPERTIES,
            Self::DeliveryReceipt(_) => DeliveryReceiptMessage::CONTACT_PROPERTIES,
            Self::LegacyReaction(_) => LegacyReactionMessage::CONTACT_PROPERTIES,
            Self::WebSessionResume(_) => WebSessionResumeMessage::CONTACT_PROPERTIES,
        }
    }

    /// Determine whether the 1:1 message is exempt from blocking.
    #[inline]
    const fn is_exempt_from_blocking(&self) -> bool {
        match &self {
            Self::Text(_) => TextMessage::CONTACT_EXEMPT_FROM_BLOCKING,
            Self::Location(_) => LocationMessage::CONTACT_EXEMPT_FROM_BLOCKING,
            Self::DeliveryReceipt(_) => DeliveryReceiptMessage::CONTACT_EXEMPT_FROM_BLOCKING,
            Self::LegacyReaction(_) => LegacyReactionMessage::CONTACT_EXEMPT_FROM_BLOCKING,
            Self::WebSessionResume(_) => WebSessionResumeMessage::CONTACT_EXEMPT_FROM_BLOCKING,
        }
    }
}

/// The message body of a distribution list message.
#[derive(Clone)]
#[expect(unused, reason = "LIB-57")]
pub(super) enum DistributionListMessageBody {
    Text(TextMessage),
    Location(LocationMessage),
    // TODO(LIB-57): Complete
}
impl DistributionListMessageBody {
    /// Get the distribution list message's type.
    ///
    /// Note: These are always 1:1 message types, so we're reusing them.
    #[inline]
    const fn message_type(&self) -> CspE2eMessageType {
        match &self {
            Self::Text(_) => TextMessage::CONTACT_TYPE,
            Self::Location(_) => LocationMessage::CONTACT_TYPE,
        }
    }

    /// Get the distribution list message's properties.
    ///
    /// Note: The properties are identical to the 1:1 message's properties, so we're reusing them.
    #[inline]
    const fn properties(&self) -> MessageProperties {
        match &self {
            Self::Text(_) => TextMessage::CONTACT_PROPERTIES,
            Self::Location(_) => LocationMessage::CONTACT_PROPERTIES,
        }
    }
}

/// The message body of a group message.
#[derive(Clone)]
pub(super) enum GroupMessageBody {
    Text(TextMessage),
    Location(LocationMessage),
    LegacyReaction(LegacyReactionMessage),
    #[expect(unused, reason = "LIB-143")]
    GroupSetup(GroupSetupMessage),
    // TODO(LIB-53): Complete
}
impl GroupMessageBody {
    /// Get the group message's type.
    #[inline]
    const fn message_type(&self) -> CspE2eMessageType {
        match &self {
            Self::Text(_) => TextMessage::GROUP_TYPE,
            Self::Location(_) => LocationMessage::GROUP_TYPE,
            Self::LegacyReaction(_) => LegacyReactionMessage::GROUP_TYPE,
            Self::GroupSetup(_) => GroupSetupMessage::TYPE,
        }
    }

    /// Get the group message's properties.
    #[inline]
    const fn properties(&self) -> GroupMessageProperties {
        match &self {
            Self::Text(_) => TextMessage::GROUP_PROPERTIES,
            Self::Location(_) => LocationMessage::GROUP_PROPERTIES,
            Self::LegacyReaction(_) => LegacyReactionMessage::GROUP_PROPERTIES,
            Self::GroupSetup(_) => GroupSetupMessage::GROUP_PROPERTIES,
        }
    }

    /// Determine whether the group message is exempt from blocking.
    #[inline]
    const fn is_exempt_from_blocking(&self) -> bool {
        match &self {
            Self::Text(_) => TextMessage::GROUP_EXEMPT_FROM_BLOCKING,
            Self::Location(_) => LocationMessage::GROUP_EXEMPT_FROM_BLOCKING,
            Self::LegacyReaction(_) => LegacyReactionMessage::GROUP_EXEMPT_FROM_BLOCKING,
            // TODO(LIB-143): Handle exemption logic properly.
            Self::GroupSetup(_) => false,
        }
    }
}

/// A distribution list message (always outgoing).
#[expect(unused, reason = "LIB-57")]
#[derive(Clone)]
pub(super) struct DistributionListMessage {
    /// The distribution list ID.
    pub(super) distribution_list_id: DistributionListId,

    /// The message body.
    pub(super) body: DistributionListMessageBody,
}

/// A group message.
#[derive(Clone)]
pub(super) struct GroupMessage {
    /// The identity of the group.
    pub(super) group_identity: GroupIdentity,

    /// The message body.
    pub(super) body: GroupMessageBody,
}

/// The message body of an incoming message.
#[derive(Clone)]
pub(super) enum IncomingMessageBody {
    Contact(ContactMessageBody),
    Group(GroupMessage),
}
impl IncomingMessageBody {
    /// Get the message's type.
    #[inline]
    const fn message_type(&self) -> CspE2eMessageType {
        match &self {
            Self::Contact(body) => body.message_type(),
            Self::Group(body) => body.body.message_type(),
        }
    }

    /// Get the message's properties.
    #[inline]
    const fn properties(&self) -> MessageProperties {
        match &self {
            Self::Contact(body) => body.properties(),
            Self::Group(body) => body.body.properties().into_message_properties(),
        }
    }

    /// Determine whether the message is exempt from blocking.
    #[inline]
    const fn is_exempt_from_blocking(&self) -> bool {
        match &self {
            Self::Contact(body) => body.is_exempt_from_blocking(),
            Self::Group(body) => body.body.is_exempt_from_blocking(),
        }
    }
}

/// An outgoing contact message.
#[expect(unused, reason = "LIB-51")]
#[derive(Clone)]
pub(super) struct OutgoingContactMessage {
    /// The Threema ID of the sender.
    pub(super) receiver_identity: ThreemaId,

    /// The message body.
    pub(super) body: ContactMessageBody,
}

/// The message body of an outgoing message.
#[expect(unused, reason = "LIB-51")]
#[derive(Clone)]
pub(super) enum OutgoingMessageBody {
    Contact(OutgoingContactMessage),
    DistributionList(DistributionListMessage),
    Group(GroupMessage),
}
impl OutgoingMessageBody {
    /// Get the message's type.
    #[inline]
    const fn message_type(&self) -> CspE2eMessageType {
        match &self {
            Self::Contact(body) => body.body.message_type(),
            Self::DistributionList(body) => body.body.message_type(),
            Self::Group(body) => body.body.message_type(),
        }
    }

    /// Get the message's properties.
    #[inline]
    const fn properties(&self) -> MessageProperties {
        match &self {
            Self::Contact(body) => body.body.properties(),
            Self::DistributionList(body) => body.body.properties(),
            Self::Group(body) => body.body.properties().into_message_properties(),
        }
    }
}

/// An incoming message.
#[derive(Clone)]
pub(super) struct IncomingMessage {
    /// Identity of the sender.
    pub(super) sender_identity: ThreemaId,

    /// The ID of the message.
    pub(super) message_id: MessageId,

    /// Behaviour overrides.
    pub(super) overrides: MessageOverrides,

    /// Unix-ish timestamp in milliseconds for when the message has been created.
    pub(super) created_at: u64,

    /// The message body.
    pub(super) body: IncomingMessageBody,
}
impl IncomingMessage {
    /// Get the associated [`ConversationId`].
    #[inline]
    pub(super) fn conversation_id(&self) -> ConversationId {
        match &self.body {
            IncomingMessageBody::Contact(_) => ConversationId::Contact(self.sender_identity),
            IncomingMessageBody::Group(group_message) => ConversationId::Group(group_message.group_identity),
        }
    }

    /// Determine whether the message is exempt from blocking.
    #[inline]
    pub(super) fn is_exempt_from_blocking(&self) -> bool {
        self.body.is_exempt_from_blocking()
    }

    /// Convert to an initial [`MessageState`].
    ///
    /// IMPORTANT: The caller must ensure that the body is the reference to the unpacked body of this message!
    pub(super) fn to_state<TBody: Into<MessageStateBody>>(&self, body: TBody) -> MessageState {
        MessageState {
            conversation_id: self.conversation_id(),
            creator_identity: self.sender_identity,
            message_id: self.message_id,
            created_at: self.created_at,
            direction: MessageDirection::Incoming(IncomingMessageDirection {
                received_at: utc_now_ms(),
            }),
            read_at: None,
            star_marker: MessageStarMarker::None,
            reactions: vec![],
            body: body.into(),
        }
    }
}

/// An outgoing message.
#[derive(Clone)]
pub(super) struct OutgoingMessage {
    /// The ID of the message.
    pub(super) message_id: MessageId,

    /// Behaviour overrides.
    pub(super) overrides: MessageOverrides,

    /// Unix-ish timestamp in milliseconds for when the message has been created.
    pub(super) created_at: u64,

    /// The message's body for the respective conversation.
    pub(super) body: OutgoingMessageBody,
}
impl OutgoingMessage {
    /// Computes [`MessageFlags`] from the [`MessageProperties`] and then the [`MessageOverrides`].
    pub(super) fn flags(&self) -> MessageFlags {
        MessageFlags::default()
            .chain_apply(self.properties())
            .chain_apply(self.overrides)
    }
}

#[expect(unused, reason = "LIB-51")]
#[duplicate_item(
    struct_name;
    [ IncomingMessage ];
    [ OutgoingMessage ];
)]
impl struct_name {
    /// Get the message's type.
    #[inline]
    #[must_use]
    pub(super) fn message_type(&self) -> CspE2eMessageType {
        self.body.message_type()
    }

    /// Get the message's properties.
    ///
    /// IMPORTANT: This does **NOT** include the overrides from [`MessageOverrides`]!
    #[inline]
    const fn properties(&self) -> MessageProperties {
        self.body.properties()
    }

    /// Get the effective message's properties, i.e. those with the [`MessageOverrides`] applied.
    #[inline]
    pub(super) fn effective_properties(&self) -> MessageProperties {
        self.body.properties().chain_apply(self.overrides)
    }
}
