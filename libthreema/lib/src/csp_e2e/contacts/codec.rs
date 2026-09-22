use duplicate::duplicate_item;

use crate::{
    model::contact::{ContactInit, ContactNotificationTriggerPolicyOverride, ContactUpdate},
    protobuf::{
        self,
        d2d_sync::contact::{self as protobuf_contact},
    },
    utils::update::Delta,
};

/// D2D encoder for contacts and related types.
pub(crate) trait D2dContactEncoder<TOutput>: Sized {
    /// Encode a contact or related type into the specified output.
    fn encode(&self) -> TOutput;
}

trait InternalD2dContactEncoder<TOutput>: Sized {
    fn encode(&self) -> TOutput;
}

#[duplicate_item(
    [
        input_type [ protobuf::d2d_sync::ReadReceiptPolicy ]
        output_type [ protobuf_contact::ReadReceiptPolicyOverride ]
        override_type [ protobuf_contact::read_receipt_policy_override::Override ]
        policy_transform [ policy.into() ]
    ]
    [
        input_type [ protobuf::d2d_sync::TypingIndicatorPolicy ]
        output_type [ protobuf_contact::TypingIndicatorPolicyOverride ]
        override_type [ protobuf_contact::typing_indicator_policy_override::Override ]
        policy_transform [ policy.into() ]
    ]
)]
impl InternalD2dContactEncoder<output_type> for Option<input_type> {
    fn encode(&self) -> output_type {
        output_type {
            r#override: Some(match *self {
                Some(policy) => override_type::Policy(policy_transform),
                None => override_type::Default(protobuf::common::Unit {}),
            }),
        }
    }
}

#[duplicate_item(
    [
        input_type [ protobuf::d2d_sync::ReadReceiptPolicy ]
        output_type [ protobuf_contact::ReadReceiptPolicyOverride ]
        override_type [ protobuf_contact::read_receipt_policy_override::Override ]
        policy_transform [ (*policy).into() ]
    ]
    [
        input_type [ protobuf::d2d_sync::TypingIndicatorPolicy ]
        output_type [ protobuf_contact::TypingIndicatorPolicyOverride ]
        override_type [ protobuf_contact::typing_indicator_policy_override::Override ]
        policy_transform [ (*policy).into() ]
    ]
)]
impl InternalD2dContactEncoder<Option<output_type>> for Delta<input_type> {
    fn encode(&self) -> Option<output_type> {
        match self {
            Self::Unchanged => None,
            Self::Update(policy) => Some(output_type {
                r#override: Some(override_type::Policy(policy_transform)),
            }),
            Self::Remove => Some(output_type {
                r#override: Some(override_type::Default(protobuf::common::Unit {})),
            }),
        }
    }
}

impl InternalD2dContactEncoder<protobuf_contact::NotificationTriggerPolicyOverride>
    for ContactNotificationTriggerPolicyOverride
{
    fn encode(&self) -> protobuf_contact::NotificationTriggerPolicyOverride {
        protobuf_contact::NotificationTriggerPolicyOverride {
            r#override: Some(
                protobuf_contact::notification_trigger_policy_override::Override::Policy(self.into()),
            ),
        }
    }
}
impl InternalD2dContactEncoder<Option<protobuf_contact::NotificationTriggerPolicyOverride>>
    for Delta<ContactNotificationTriggerPolicyOverride>
{
    fn encode(&self) -> Option<protobuf_contact::NotificationTriggerPolicyOverride> {
        match self {
            Self::Unchanged => None,
            Self::Update(policy) => Some(policy.encode()),
            Self::Remove => Some(protobuf_contact::NotificationTriggerPolicyOverride {
                r#override: Some(
                    protobuf_contact::notification_trigger_policy_override::Override::Default(
                        protobuf::common::Unit {},
                    ),
                ),
            }),
        }
    }
}

impl D2dContactEncoder<protobuf::d2d_sync::Contact> for ContactUpdate {
    fn encode(&self) -> protobuf::d2d_sync::Contact {
        protobuf::d2d_sync::Contact {
            identity: self.identity.as_str().to_owned(),

            public_key: None,

            created_at: None,

            first_name: self.first_name.clone(),

            last_name: self.last_name.clone(),

            nickname: self.nickname.clone(),

            verification_level: self.verification_level.map(Into::into),

            work_verification_level: self.work_verification_level.map(Into::into),

            identity_type: self.identity_type.map(Into::into),

            acquaintance_level: self.acquaintance_level.map(Into::into),

            activity_state: self.activity_state.map(Into::into),

            feature_mask: self.feature_mask.map(|feature_mask| feature_mask.0),

            sync_state: self.sync_state.map(Into::into),

            work_last_full_sync_at: self.work_last_full_sync_at,

            work_availability_status: self.work_availability_status.clone().map(Into::into),

            read_receipt_policy_override: self.read_receipt_policy_override.encode(),

            typing_indicator_policy_override: self.typing_indicator_policy_override.encode(),

            notification_trigger_policy_override: self.notification_trigger_policy_override.encode(),

            #[expect(deprecated, reason = "Must be provided until phased out")]
            deprecated_notification_sound_policy_override: None,

            contact_defined_profile_picture: None,

            user_defined_profile_picture: None,

            conversation_category: self.conversation_category.map(Into::into),

            conversation_visibility: self.conversation_visibility.map(Into::into),
        }
    }
}

impl D2dContactEncoder<protobuf::d2d_sync::Contact> for ContactInit {
    fn encode(&self) -> protobuf::d2d_sync::Contact {
        protobuf::d2d_sync::Contact {
            identity: self.identity.as_str().to_owned(),

            public_key: Some(self.public_key.0.to_bytes().into()),

            created_at: Some(self.created_at),

            first_name: Some(self.first_name.clone()),

            last_name: Some(self.last_name.clone()),

            nickname: Some(self.nickname.clone()),

            verification_level: Some(self.verification_level.into()),

            work_verification_level: Some(self.work_verification_level.into()),

            identity_type: Some(self.identity_type.into()),

            acquaintance_level: Some(self.acquaintance_level.into()),

            activity_state: Some(self.activity_state.into()),

            feature_mask: Some(self.feature_mask.0),

            sync_state: Some(self.sync_state.into()),

            work_last_full_sync_at: self.work_last_full_sync_at,

            work_availability_status: self.work_availability_status.clone().map(Into::into),

            read_receipt_policy_override: Some(self.read_receipt_policy_override.encode()),

            typing_indicator_policy_override: Some(self.typing_indicator_policy_override.encode()),

            notification_trigger_policy_override: Some(
                self.notification_trigger_policy_override.as_ref().map_or(
                    protobuf_contact::NotificationTriggerPolicyOverride {
                        r#override: Some(
                            protobuf_contact::notification_trigger_policy_override::Override::Default(
                                protobuf::common::Unit {},
                            ),
                        ),
                    },
                    ContactNotificationTriggerPolicyOverride::encode,
                ),
            ),

            #[expect(deprecated, reason = "Must be provided until phased out")]
            deprecated_notification_sound_policy_override: Some(
                protobuf_contact::DeprecatedNotificationSoundPolicyOverride {
                    r#override: Some(
                        protobuf_contact::deprecated_notification_sound_policy_override::Override::Default(
                            protobuf::common::Unit {},
                        ),
                    ),
                },
            ),

            contact_defined_profile_picture: None,

            user_defined_profile_picture: None,

            conversation_category: Some(self.conversation_category.into()),

            conversation_visibility: Some(self.conversation_visibility.into()),
        }
    }
}
