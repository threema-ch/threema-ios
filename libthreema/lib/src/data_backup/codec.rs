//! Codecs for the data backup.

use crate::{
    common::ThreemaIdError,
    csp_e2e::message::codec::CspMessageDecodeError,
    utils::{
        bytes::{ByteReaderError, ByteWriterError},
        debug::Name,
    },
};

/// Source of a decoding error.
#[derive(Clone, Debug, thiserror::Error)]
pub enum BackupDecodingError {
    /// Error while reading.
    #[error("Decoding message failed: {0}")]
    ByteReaderError(#[from] ByteReaderError),

    /// Error during decoding of a protobuf message.
    #[error("Decoding message failed: {0}")]
    ProstDecodeError(#[from] prost::DecodeError),

    /// Missing field.
    #[error("Missing field in {message_name}: '{field_name}'")]
    MissingField {
        /// Name of the enum/struct in which the field is missing.
        message_name: &'static str,

        /// Name of the missing field.
        field_name: &'static str,
    },

    /// Unknown type.
    #[error("Unknown enum variant for '{name}': {variant}")]
    UnknownEnumVariant {
        /// Name of the enum.
        name: &'static str,

        /// Value of the (unknown) variant.
        variant: i32,
    },

    /// Invalid Threema ID.
    #[error("Invalid Threema ID: {0}")]
    InvalidThreemaId(#[from] ThreemaIdError),

    /// Invalid message.
    #[error("Invalid message: {0}")]
    InvalidMessage(String),

    /// Another kind of error occurred.
    #[error("{0}")]
    Other(String),
}

/// Source of an encoding error.
#[derive(Clone, Debug, thiserror::Error)]
pub enum BackupEncodingError {
    /// Error while reading (usually while decoding a struct).
    #[error(transparent)]
    EncodingFailed(#[from] ByteWriterError),

    /// Conversion.
    // TODO(LIB-174): Is there a better name?
    #[error("Conversion failed: {0}")]
    ConversionFailed(&'static str),
}

impl From<CspMessageDecodeError> for BackupDecodingError {
    fn from(error: CspMessageDecodeError) -> Self {
        match error {
            CspMessageDecodeError::DecodingFailed(error) => Self::ByteReaderError(error),
            CspMessageDecodeError::InvalidString(error) => Self::Other(error.to_string()),
            CspMessageDecodeError::InvalidMessage(error) => Self::InvalidMessage(error),
        }
    }
}

trait InternalBackupDecoder<TRawMessage: Name>: Sized {
    fn decode(raw_message: TRawMessage) -> Result<Self, BackupDecodingError>;

    // TODO(LIB-174): Check: Move this to utils/protobuf.rs ?
    //
    // Idea: Extend prost::Message and expose this for all protobuf messages.
    fn expect_field<T>(field_name: &'static str, value: Option<T>) -> Result<T, BackupDecodingError> {
        value.ok_or(BackupDecodingError::MissingField {
            message_name: TRawMessage::NAME,
            field_name,
        })
    }

    // TODO(LIB-174): Check: Move this to utils/protobuf.rs ?
    fn parse_enum_variant<T: TryFrom<i32> + Name>(variant: i32) -> Result<T, BackupDecodingError> {
        variant
            .try_into()
            .map_err(|_| BackupDecodingError::UnknownEnumVariant {
                name: T::NAME,
                variant,
            })
    }

    /// Parse a required option and return a [`BackupDecodingError`] if the value is `None`.
    // TODO(LIB-174): Check: Move this to utils/protobuf.rs ?
    // TODO(LIB-174): Is there a method provided by prost? Otherwise, we should add an extension.
    fn expect_and_parse_enum_variant<T: TryFrom<i32> + Name>(
        field_name: &'static str,
        variant: Option<i32>,
    ) -> Result<T, BackupDecodingError> {
        Self::parse_enum_variant::<T>(Self::expect_field(field_name, variant)?)
    }
}

trait InternalBackupEncoder<TOutput> {
    fn encode(&self) -> TOutput;
}

mod common {
    use std::collections::HashSet;

    use crate::{
        common::{ConversationId, DistributionListId, GroupIdentity, ThreemaId},
        data_backup::codec::{BackupDecodingError, InternalBackupDecoder, InternalBackupEncoder},
        protobuf,
    };

    // TODO(LIB-174): Is there a better place for this? Maybe even TryFrom/From implementations?
    impl InternalBackupDecoder<protobuf::common::Identities> for Vec<ThreemaId> {
        fn decode(raw_message: protobuf::common::Identities) -> Result<Self, BackupDecodingError> {
            let protobuf::common::Identities { identities } = raw_message;

            Ok(identities
                .into_iter()
                .map(|identity| ThreemaId::try_from(identity.as_str()))
                .collect::<Result<_, _>>()?)
        }
    }
    impl InternalBackupEncoder<protobuf::common::Identities> for Vec<ThreemaId> {
        fn encode(&self) -> protobuf::common::Identities {
            protobuf::common::Identities {
                identities: self.clone().into_iter().map(ThreemaId::into).collect(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::common::Identities> for HashSet<ThreemaId> {
        fn decode(raw_message: protobuf::common::Identities) -> Result<Self, BackupDecodingError> {
            Ok(Vec::decode(raw_message)?.into_iter().collect())
        }
    }
    impl InternalBackupEncoder<protobuf::common::Identities> for HashSet<ThreemaId> {
        fn encode(&self) -> protobuf::common::Identities {
            protobuf::common::Identities {
                identities: self.clone().into_iter().map(ThreemaId::into).collect(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::d2d::ConversationId> for ConversationId {
        fn decode(raw_message: protobuf::d2d::ConversationId) -> Result<Self, BackupDecodingError> {
            let protobuf::d2d::ConversationId { id: conversation_id } = raw_message;

            Ok(match Self::expect_field("id", conversation_id)? {
                protobuf::d2d::conversation_id::Id::Contact(threema_id) => {
                    Self::Contact(ThreemaId::try_from(threema_id.as_str())?)
                },
                protobuf::d2d::conversation_id::Id::DistributionList(distribution_list_id) => {
                    Self::DistributionList(DistributionListId(distribution_list_id))
                },
                protobuf::d2d::conversation_id::Id::Group(group_identity) => {
                    Self::Group(GroupIdentity::decode(group_identity)?)
                },
            })
        }
    }
    impl InternalBackupEncoder<protobuf::d2d::ConversationId> for ConversationId {
        fn encode(&self) -> protobuf::d2d::ConversationId {
            protobuf::d2d::ConversationId {
                id: Some(match self {
                    Self::Contact(threema_id) => {
                        protobuf::d2d::conversation_id::Id::Contact(threema_id.to_string())
                    },
                    Self::DistributionList(distribution_list_id) => {
                        protobuf::d2d::conversation_id::Id::DistributionList(distribution_list_id.0)
                    },
                    Self::Group(group_identity) => {
                        protobuf::d2d::conversation_id::Id::Group(group_identity.encode())
                    },
                }),
            }
        }
    }
}

mod profile {

    use crate::{
        data_backup::codec::{BackupDecodingError, InternalBackupDecoder, InternalBackupEncoder},
        model::profile::{ProfilePicture, ProfilePictureMediaType},
        protobuf,
    };

    impl InternalBackupDecoder<protobuf::data_backup::ProfilePicture> for ProfilePicture {
        fn decode(raw_message: protobuf::data_backup::ProfilePicture) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::ProfilePicture { media_type, data } = raw_message;

            // Parse the format type.
            let media_type = {
                let media_type: protobuf::common::image::Type = Self::parse_enum_variant(media_type)?;
                match media_type {
                    protobuf::common::image::Type::Jpeg => ProfilePictureMediaType::Jpeg,
                }
            };

            Ok(Self { media_type, data })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::ProfilePicture> for ProfilePicture {
        fn encode(&self) -> protobuf::data_backup::ProfilePicture {
            protobuf::data_backup::ProfilePicture {
                media_type: match self.media_type {
                    ProfilePictureMediaType::Jpeg => protobuf::common::image::Type::Jpeg,
                }
                .into(),
                data: self.data.clone(),
            }
        }
    }
}

mod contact {

    use crate::{
        common::{FeatureMask, ThreemaId, keys::PublicKey},
        data_backup::codec::{BackupDecodingError, InternalBackupDecoder, InternalBackupEncoder},
        model::{
            contact::{
                Contact, ContactNotificationTriggerPolicyOverride,
                ContactNotificationTriggerPolicyOverridePolicy, ContactWithProfilePictures,
            },
            profile::ProfilePicture,
        },
        protobuf::{
            self,
            d2d_sync::{
                self,
                contact::notification_trigger_policy_override::{
                    self, policy as notification_trigger_policy,
                },
            },
            data_backup,
        },
        work::properties::WorkAvailabilityStatus,
    };

    impl InternalBackupDecoder<notification_trigger_policy_override::Policy>
        for ContactNotificationTriggerPolicyOverride
    {
        fn decode(
            raw_message: notification_trigger_policy_override::Policy,
        ) -> Result<Self, BackupDecodingError> {
            let notification_trigger_policy_override::Policy { policy, expires_at } = raw_message;
            let policy = {
                let policy: notification_trigger_policy_override::policy::NotificationTriggerPolicy =
                    Self::parse_enum_variant(policy)?;
                match policy {
                    notification_trigger_policy_override::policy::NotificationTriggerPolicy::Never => {
                        ContactNotificationTriggerPolicyOverridePolicy::Never
                    },
                }
            };

            Ok(Self { policy, expires_at })
        }
    }

    impl InternalBackupDecoder<d2d_sync::contact::NotificationTriggerPolicyOverride>
        for Option<ContactNotificationTriggerPolicyOverride>
    {
        fn decode(
            raw_message: d2d_sync::contact::NotificationTriggerPolicyOverride,
        ) -> Result<Self, BackupDecodingError> {
            let d2d_sync::contact::NotificationTriggerPolicyOverride { r#override } = raw_message;

            Ok(match Self::expect_field("override", r#override)? {
                notification_trigger_policy_override::Override::Default(_) => None,
                notification_trigger_policy_override::Override::Policy(policy) => {
                    Some(ContactNotificationTriggerPolicyOverride::decode(policy)?)
                },
            })
        }
    }
    impl InternalBackupEncoder<d2d_sync::contact::NotificationTriggerPolicyOverride>
        for Option<ContactNotificationTriggerPolicyOverride>
    {
        fn encode(&self) -> d2d_sync::contact::NotificationTriggerPolicyOverride {
            d2d_sync::contact::NotificationTriggerPolicyOverride {
                r#override: Some(match self {
                    Some(policy) => notification_trigger_policy_override::Override::Policy(
                        notification_trigger_policy_override::Policy {
                            policy: match policy.policy {
                                ContactNotificationTriggerPolicyOverridePolicy::Never => {
                                    notification_trigger_policy::NotificationTriggerPolicy::Never
                                },
                            }
                            .into(),
                            expires_at: policy.expires_at,
                        },
                    ),
                    None => {
                        notification_trigger_policy_override::Override::Default(protobuf::common::Unit {})
                    },
                }),
            }
        }
    }

    impl InternalBackupDecoder<d2d_sync::WorkAvailabilityStatus> for WorkAvailabilityStatus {
        fn decode(raw_message: d2d_sync::WorkAvailabilityStatus) -> Result<Self, BackupDecodingError> {
            let d2d_sync::WorkAvailabilityStatus {
                category,
                description,
            } = raw_message;

            let category: d2d_sync::WorkAvailabilityStatusCategory = Self::parse_enum_variant(category)?;
            Ok(match category {
                d2d_sync::WorkAvailabilityStatusCategory::None => Self::None,
                d2d_sync::WorkAvailabilityStatusCategory::Unavailable => Self::Unavailable(description),
                d2d_sync::WorkAvailabilityStatusCategory::Busy => Self::Busy(description),
            })
        }
    }
    impl InternalBackupEncoder<d2d_sync::WorkAvailabilityStatus> for WorkAvailabilityStatus {
        fn encode(&self) -> d2d_sync::WorkAvailabilityStatus {
            let (category, description) = match self {
                Self::None => (d2d_sync::WorkAvailabilityStatusCategory::None, String::new()),
                Self::Unavailable(description) => (
                    d2d_sync::WorkAvailabilityStatusCategory::Unavailable,
                    description.clone(),
                ),
                Self::Busy(description) => (
                    d2d_sync::WorkAvailabilityStatusCategory::Busy,
                    description.clone(),
                ),
            };

            d2d_sync::WorkAvailabilityStatus {
                category: category.into(),
                description,
            }
        }
    }

    impl InternalBackupDecoder<data_backup::AugmentedContact> for ContactWithProfilePictures {
        fn decode(raw_message: data_backup::AugmentedContact) -> Result<Self, BackupDecodingError> {
            let data_backup::AugmentedContact {
                contact,
                last_update_at,
                contact_defined_profile_picture,
                user_defined_profile_picture,
            } = raw_message;

            let contact = Self::expect_field("contact", contact)?;
            let d2d_sync::Contact {
                identity,
                public_key,
                created_at,
                first_name,
                last_name,
                nickname,
                verification_level,
                work_verification_level,
                identity_type,
                acquaintance_level,
                activity_state,
                feature_mask,
                sync_state,
                work_last_full_sync_at,
                work_availability_status,
                read_receipt_policy_override,
                typing_indicator_policy_override,
                notification_trigger_policy_override,
                #[expect(deprecated, reason = "Must be handled until phased out")]
                deprecated_notification_sound_policy_override,
                contact_defined_profile_picture: d2d_sync_contact_defined_profile_picture,
                user_defined_profile_picture: d2d_sync_user_defined_profile_picture,
                conversation_category,
                conversation_visibility,
            } = contact;

            if deprecated_notification_sound_policy_override.is_some() {
                return Err(BackupDecodingError::Other(
                    "deprecated_notification_sound_policy_override must be None in d2d_sync::Contact"
                        .to_owned(),
                ));
            }

            if d2d_sync_contact_defined_profile_picture.is_some() {
                return Err(BackupDecodingError::Other(
                    "contact_defined_profile_picture must be None in d2d_sync::Contact".to_owned(),
                ));
            }

            if d2d_sync_user_defined_profile_picture.is_some() {
                return Err(BackupDecodingError::Other(
                    "user_defined_profile_picture must be None in d2d_sync::Contact".to_owned(),
                ));
            }

            let public_key = PublicKey::try_from(Self::expect_field("public_key", public_key)?.as_slice())
                .map_err(|_| {
                    BackupDecodingError::InvalidMessage("Public key must have 32 bytes".to_owned())
                })?;

            let created_at = Self::expect_field("created_at", created_at)?;

            let read_receipt_policy_override = read_receipt_policy_override
                .map(|policy_override| {
                    match Self::expect_field("policy_override.override", policy_override.r#override)? {
                        d2d_sync::contact::read_receipt_policy_override::Override::Default(_) => {
                            Ok(d2d_sync::ReadReceiptPolicy::default())
                        },
                        d2d_sync::contact::read_receipt_policy_override::Override::Policy(policy) => {
                            Self::parse_enum_variant(policy)
                        },
                    }
                })
                .transpose()?;

            let typing_indicator_policy_override = typing_indicator_policy_override
                .map(|policy_override| {
                    match Self::expect_field("policy_override.override", policy_override.r#override)? {
                        d2d_sync::contact::typing_indicator_policy_override::Override::Default(_) => {
                            Ok(d2d_sync::TypingIndicatorPolicy::default())
                        },
                        d2d_sync::contact::typing_indicator_policy_override::Override::Policy(policy) => {
                            Self::parse_enum_variant(policy)
                        },
                    }
                })
                .transpose()?;

            let contact = Contact {
                identity: ThreemaId::try_from(identity.as_str())?,
                public_key,
                created_at,
                last_update_at,
                first_name: Self::expect_field("first name", first_name)?,
                last_name: Self::expect_field("last name", last_name)?,
                nickname: Self::expect_field("nickname", nickname)?,
                verification_level: Self::expect_and_parse_enum_variant(
                    "verification level",
                    verification_level,
                )?,
                work_verification_level: Self::expect_and_parse_enum_variant(
                    "work verification level",
                    work_verification_level,
                )?,
                identity_type: Self::expect_and_parse_enum_variant("identity type", identity_type)?,
                acquaintance_level: Self::expect_and_parse_enum_variant(
                    "acquaintance level",
                    acquaintance_level,
                )?,
                activity_state: Self::expect_and_parse_enum_variant("activity state", activity_state)?,
                feature_mask: FeatureMask(
                    // TODO(LIB-78): lgr: Do we need to validate this feature mask?
                    Self::expect_field("feature_mask", feature_mask)?,
                ),
                sync_state: Self::expect_and_parse_enum_variant("sync state", sync_state)?,
                work_last_full_sync_at,
                work_availability_status: work_availability_status
                    .map(WorkAvailabilityStatus::decode)
                    .transpose()?,
                read_receipt_policy_override,
                typing_indicator_policy_override,
                notification_trigger_policy_override: Option::decode(Self::expect_field(
                    "notification_trigger_policy_override",
                    notification_trigger_policy_override,
                )?)?,
                conversation_category: Self::expect_and_parse_enum_variant(
                    "conversation category",
                    conversation_category,
                )?,
                conversation_visibility: Self::expect_and_parse_enum_variant(
                    "conversation visibility",
                    conversation_visibility,
                )?,
            };

            Ok(Self {
                contact,
                contact_defined_profile_picture: contact_defined_profile_picture
                    .map(ProfilePicture::decode)
                    .transpose()?,
                user_defined_profile_picture: user_defined_profile_picture
                    .map(ProfilePicture::decode)
                    .transpose()?,
            })
        }
    }
    impl InternalBackupEncoder<data_backup::AugmentedContact> for ContactWithProfilePictures {
        fn encode(&self) -> data_backup::AugmentedContact {
            let contact = d2d_sync::Contact {
                identity: self.contact.identity.to_string(),
                public_key: Some(self.contact.public_key.0.as_bytes().to_vec()),
                created_at: Some(self.contact.created_at),
                first_name: Some(self.contact.first_name.clone()),
                last_name: Some(self.contact.last_name.clone()),
                nickname: Some(self.contact.nickname.clone()),
                verification_level: Some(self.contact.verification_level as i32),
                work_verification_level: Some(self.contact.work_verification_level as i32),
                identity_type: Some(self.contact.identity_type as i32),
                acquaintance_level: Some(self.contact.acquaintance_level as i32),
                activity_state: Some(self.contact.activity_state as i32),
                feature_mask: Some(self.contact.feature_mask.0),
                sync_state: Some(self.contact.sync_state as i32),
                work_last_full_sync_at: self.contact.work_last_full_sync_at,
                work_availability_status: self
                    .contact
                    .work_availability_status
                    .as_ref()
                    .map(WorkAvailabilityStatus::encode),
                read_receipt_policy_override: self.contact.read_receipt_policy_override.map(|policy| {
                    d2d_sync::contact::ReadReceiptPolicyOverride {
                        r#override: Some(d2d_sync::contact::read_receipt_policy_override::Override::Policy(
                            policy as i32,
                        )),
                    }
                }),
                typing_indicator_policy_override: self.contact.typing_indicator_policy_override.map(
                    |policy| d2d_sync::contact::TypingIndicatorPolicyOverride {
                        r#override: Some(
                            d2d_sync::contact::typing_indicator_policy_override::Override::Policy(
                                policy as i32,
                            ),
                        ),
                    },
                ),
                notification_trigger_policy_override: Some(
                    self.contact.notification_trigger_policy_override.encode(),
                ),
                contact_defined_profile_picture: None,
                user_defined_profile_picture: None,
                conversation_category: Some(self.contact.conversation_category as i32),
                conversation_visibility: Some(self.contact.conversation_visibility as i32),

                #[expect(deprecated, reason = "Must be handled until phased out")]
                deprecated_notification_sound_policy_override: None,
            };

            data_backup::AugmentedContact {
                contact: Some(contact),
                last_update_at: self.contact.last_update_at,
                contact_defined_profile_picture: self
                    .contact_defined_profile_picture
                    .as_ref()
                    .map(ProfilePicture::encode),
                user_defined_profile_picture: self
                    .user_defined_profile_picture
                    .as_ref()
                    .map(ProfilePicture::encode),
            }
        }
    }
}

mod distribution_list {
    use crate::{
        common::ThreemaId,
        data_backup::codec::{BackupDecodingError, InternalBackupDecoder, InternalBackupEncoder},
        model::distribution_list::DistributionList,
        protobuf,
    };

    impl InternalBackupDecoder<protobuf::d2d_join::essential_data::AugmentedDistributionList>
        for DistributionList
    {
        fn decode(
            raw_message: protobuf::d2d_join::essential_data::AugmentedDistributionList,
        ) -> Result<Self, BackupDecodingError> {
            let protobuf::d2d_join::essential_data::AugmentedDistributionList {
                distribution_list,
                last_update_at,
            } = raw_message;
            let protobuf::d2d_sync::DistributionList {
                distribution_list_id,
                name,
                created_at,
                member_identities,
                conversation_category,
                conversation_visibility,
            } = Self::expect_field("distribution_list", distribution_list)?;

            Ok(Self {
                identity: crate::common::DistributionListId(distribution_list_id),
                name: Self::expect_field("name", name)?,
                created_at: Self::expect_field("created_at", created_at)?,
                last_update_at,
                members: Self::expect_field("member_identities", member_identities)?
                    .identities
                    .into_iter()
                    .map(|identity| ThreemaId::try_from(identity.as_str()))
                    .collect::<Result<_, _>>()?,
                conversation_category: Self::expect_and_parse_enum_variant(
                    "conversation_category",
                    conversation_category,
                )?,
                conversation_visibility: Self::expect_and_parse_enum_variant(
                    "conversation_visibility",
                    conversation_visibility,
                )?,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::d2d_join::essential_data::AugmentedDistributionList>
        for DistributionList
    {
        fn encode(&self) -> protobuf::d2d_join::essential_data::AugmentedDistributionList {
            protobuf::d2d_join::essential_data::AugmentedDistributionList {
                distribution_list: Some(protobuf::d2d_sync::DistributionList {
                    distribution_list_id: self.identity.0,
                    name: Some(self.name.clone()),
                    created_at: Some(self.created_at),
                    member_identities: Some(self.members.encode()),
                    conversation_category: Some(self.conversation_category as i32),
                    conversation_visibility: Some(self.conversation_visibility as i32),
                }),
                last_update_at: self.last_update_at,
            }
        }
    }
}

mod group {
    use std::collections::HashSet;

    use crate::{
        common::{GroupIdentity, ThreemaId},
        data_backup::codec::{BackupDecodingError, InternalBackupDecoder, InternalBackupEncoder},
        model::{
            group::{
                Group, GroupNotificationTriggerPolicyOverride, GroupNotificationTriggerPolicyOverridePolicy,
                GroupWithProfilePicture,
            },
            profile::ProfilePicture,
        },
        protobuf::{
            self,
            d2d_sync::group::notification_trigger_policy_override::{
                self as protobuf_notification_override, policy as protobuf_notification_policy,
            },
        },
    };

    impl InternalBackupDecoder<protobuf::common::GroupIdentity> for GroupIdentity {
        fn decode(raw_message: protobuf::common::GroupIdentity) -> Result<Self, BackupDecodingError> {
            let protobuf::common::GroupIdentity {
                group_id,
                creator_identity,
            } = raw_message;

            Ok(Self {
                group_id,
                creator_identity: ThreemaId::try_from(creator_identity.as_str())?,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::common::GroupIdentity> for GroupIdentity {
        fn encode(&self) -> protobuf::common::GroupIdentity {
            protobuf::common::GroupIdentity {
                group_id: self.group_id,
                creator_identity: self.creator_identity.to_string(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::d2d_sync::group::NotificationTriggerPolicyOverride>
        for Option<GroupNotificationTriggerPolicyOverride>
    {
        fn decode(
            raw_message: protobuf::d2d_sync::group::NotificationTriggerPolicyOverride,
        ) -> Result<Self, BackupDecodingError> {
            // Parse raw message.
            let protobuf::d2d_sync::group::NotificationTriggerPolicyOverride { r#override } = raw_message;

            // Parse override.
            Ok(match Self::expect_field("override", r#override)? {
                protobuf_notification_override::Override::Default(_) => None,
                protobuf_notification_override::Override::Policy(
                    protobuf_notification_override::Policy { policy, expires_at },
                ) => {
                    let policy = match Self::parse_enum_variant(policy)? {
                        protobuf_notification_policy::NotificationTriggerPolicy::Mentioned => {
                            GroupNotificationTriggerPolicyOverridePolicy::Mentioned
                        },
                        protobuf_notification_policy::NotificationTriggerPolicy::Never => {
                            GroupNotificationTriggerPolicyOverridePolicy::Never
                        },
                    };
                    Some(GroupNotificationTriggerPolicyOverride { policy, expires_at })
                },
            })
        }
    }
    impl InternalBackupEncoder<protobuf::d2d_sync::group::NotificationTriggerPolicyOverride>
        for GroupNotificationTriggerPolicyOverride
    {
        fn encode(&self) -> protobuf::d2d_sync::group::NotificationTriggerPolicyOverride {
            let policy = match self.policy {
                GroupNotificationTriggerPolicyOverridePolicy::Mentioned => {
                    protobuf_notification_policy::NotificationTriggerPolicy::Mentioned
                },
                GroupNotificationTriggerPolicyOverridePolicy::Never => {
                    protobuf_notification_policy::NotificationTriggerPolicy::Never
                },
            };
            protobuf::d2d_sync::group::NotificationTriggerPolicyOverride {
                r#override: Some(protobuf_notification_override::Override::Policy(
                    protobuf_notification_override::Policy {
                        policy: policy as i32,
                        expires_at: self.expires_at,
                    },
                )),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::AugmentedGroup> for GroupWithProfilePicture {
        fn decode(raw_message: protobuf::data_backup::AugmentedGroup) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::AugmentedGroup {
                group,
                last_update_at,
                profile_picture,
            } = raw_message;

            let protobuf::d2d_sync::Group {
                group_identity,
                name,
                created_at,
                user_state,
                profile_picture: _profile_picture,
                member_identities,
                notification_trigger_policy_override,

                #[expect(deprecated, reason = "Must be handled until phased out")]
                    deprecated_notification_sound_policy_override: _deprecated_override,

                conversation_category,
                conversation_visibility,
            } = Self::expect_field("group", group)?;

            Ok(Self {
                group: Group {
                    identity: GroupIdentity::decode(Self::expect_field("group_identity", group_identity)?)?,
                    name: name.unwrap_or_default(),
                    created_at: Self::expect_field("created_at", created_at)?,
                    last_update_at,
                    user_state: Self::expect_and_parse_enum_variant("user_state", user_state)?,
                    members: HashSet::decode(Self::expect_field("member_identities", member_identities)?)?,
                    notification_trigger_policy_override: notification_trigger_policy_override
                        .map(Option::decode)
                        .transpose()?
                        .flatten(),
                    conversation_category: Self::expect_and_parse_enum_variant(
                        "conversation_category",
                        conversation_category,
                    )?,
                    conversation_visibility: Self::expect_and_parse_enum_variant(
                        "conversation_visibility",
                        conversation_visibility,
                    )?,
                },
                profile_picture: profile_picture.map(ProfilePicture::decode).transpose()?,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::AugmentedGroup> for GroupWithProfilePicture {
        fn encode(&self) -> protobuf::data_backup::AugmentedGroup {
            protobuf::data_backup::AugmentedGroup {
                group: Some(protobuf::d2d_sync::Group {
                    group_identity: Some(self.group.identity.encode()),
                    name: Some(self.group.name.clone()),
                    created_at: Some(self.group.created_at),
                    user_state: Some(self.group.user_state as i32),
                    profile_picture: None,
                    member_identities: Some(self.group.members.encode()),
                    notification_trigger_policy_override: self
                        .group
                        .notification_trigger_policy_override
                        .as_ref()
                        .map(GroupNotificationTriggerPolicyOverride::encode),

                    #[expect(deprecated, reason = "Must be handled until phased out")]
                    deprecated_notification_sound_policy_override: Some(
                        protobuf::d2d_sync::group::DeprecatedNotificationSoundPolicyOverride {
                            r#override: None,
                        },
                    ),

                    conversation_category: Some(self.group.conversation_category as i32),
                    conversation_visibility: Some(self.group.conversation_visibility as i32),
                }),
                last_update_at: self.group.last_update_at,
                profile_picture: self.profile_picture.as_ref().map(ProfilePicture::encode),
            }
        }
    }
}

mod poll {
    use std::collections::HashMap;

    use super::BackupDecodingError;
    use crate::{
        common::{ConversationId, ThreemaId},
        data_backup::codec::{InternalBackupDecoder, InternalBackupEncoder},
        model::poll::{Poll, PollChoice, PollChoiceId, PollId, PollVote, PollVotes},
        protobuf::{self, data_backup::poll::poll_votes as protobuf_poll_votes},
    };

    impl InternalBackupDecoder<protobuf_poll_votes::poll_votes_list::PollVote> for PollVote {
        fn decode(
            raw_message: protobuf_poll_votes::poll_votes_list::PollVote,
        ) -> Result<Self, BackupDecodingError> {
            let protobuf_poll_votes::poll_votes_list::PollVote {
                choices,
                created_at,
                modified_at,
            } = raw_message;

            Ok(Self {
                choices: choices.into_iter().map(PollChoiceId).collect(),
                created_at,
                modified_at,
            })
        }
    }
    impl InternalBackupEncoder<protobuf_poll_votes::poll_votes_list::PollVote> for PollVote {
        fn encode(&self) -> protobuf_poll_votes::poll_votes_list::PollVote {
            protobuf_poll_votes::poll_votes_list::PollVote {
                choices: self.choices.iter().map(|choice_id| choice_id.0).collect(),
                created_at: self.created_at,
                modified_at: self.modified_at,
            }
        }
    }

    impl InternalBackupDecoder<protobuf_poll_votes::PollVotesList> for HashMap<ThreemaId, PollVote> {
        fn decode(raw_message: protobuf_poll_votes::PollVotesList) -> Result<Self, BackupDecodingError> {
            let protobuf_poll_votes::PollVotesList { participant_to_votes } = raw_message;

            participant_to_votes
                .into_iter()
                .map(|(participant, vote)| {
                    Ok::<_, BackupDecodingError>((
                        ThreemaId::try_from(participant.as_str())?,
                        PollVote::decode(vote)?,
                    ))
                })
                .collect::<Result<_, _>>()
        }
    }
    impl InternalBackupEncoder<protobuf_poll_votes::PollVotesList> for HashMap<ThreemaId, PollVote> {
        fn encode(&self) -> protobuf_poll_votes::PollVotesList {
            protobuf_poll_votes::PollVotesList {
                participant_to_votes: self
                    .iter()
                    .map(|(participant, vote)| (participant.to_string(), vote.encode()))
                    .collect(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf_poll_votes::PollVotesSummary> for HashMap<PollChoiceId, u16> {
        fn decode(raw_message: protobuf_poll_votes::PollVotesSummary) -> Result<Self, BackupDecodingError> {
            let protobuf_poll_votes::PollVotesSummary {
                poll_choice_id_to_count,
            } = raw_message;

            poll_choice_id_to_count
                .into_iter()
                .map(|(poll_choice_id, count)| {
                    let Ok(count) = count.try_into() else {
                        return Err(BackupDecodingError::Other("Overflow: vote count".to_owned()));
                    };

                    Ok((PollChoiceId(poll_choice_id), count))
                })
                .collect()
        }
    }
    impl InternalBackupEncoder<protobuf_poll_votes::PollVotesSummary> for HashMap<PollChoiceId, u16> {
        fn encode(&self) -> protobuf_poll_votes::PollVotesSummary {
            protobuf_poll_votes::PollVotesSummary {
                poll_choice_id_to_count: self
                    .iter()
                    .map(|(poll_choice_id, count)| (poll_choice_id.0, u32::from(*count)))
                    .collect(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::poll::PollVotes> for PollVotes {
        fn decode(raw_message: protobuf::data_backup::poll::PollVotes) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::poll::PollVotes { votes } = raw_message;

            Ok(match Self::expect_field("votes", votes)? {
                protobuf_poll_votes::Votes::PollVotesList(poll_votes_list) => {
                    Self::Votes(HashMap::decode(poll_votes_list)?)
                },
                protobuf_poll_votes::Votes::PollVotesSummary(poll_votes_summary) => {
                    Self::Summary(HashMap::decode(poll_votes_summary)?)
                },
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::poll::PollVotes> for PollVotes {
        fn encode(&self) -> protobuf::data_backup::poll::PollVotes {
            protobuf::data_backup::poll::PollVotes {
                votes: Some(match self {
                    Self::Votes(votes) => protobuf_poll_votes::Votes::PollVotesList(votes.encode()),
                    Self::Summary(vote_counts) => {
                        protobuf_poll_votes::Votes::PollVotesSummary(vote_counts.encode())
                    },
                }),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::poll::PollChoice> for PollChoice {
        fn decode(raw_message: protobuf::data_backup::poll::PollChoice) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::poll::PollChoice { id, description } = raw_message;

            Ok(Self {
                id: PollChoiceId(id),
                description,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::poll::PollChoice> for PollChoice {
        fn encode(&self) -> protobuf::data_backup::poll::PollChoice {
            protobuf::data_backup::poll::PollChoice {
                id: self.id.0,
                description: self.description.clone(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::Poll> for Poll {
        fn decode(raw_message: protobuf::data_backup::Poll) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::Poll {
                poll_id,
                conversation,
                creator_identity,
                created_at,
                state,
                description,
                answer_type,
                announce_type,
                display_mode,
                choices,
                votes,
            } = raw_message;

            Ok(Self {
                id: PollId(poll_id),
                conversation: ConversationId::decode(Self::expect_field("conversation", conversation)?)?,
                creator_identity: ThreemaId::try_from(creator_identity.as_str())?,
                created_at,
                state: Self::parse_enum_variant(state)?,
                description,
                answer_type: Self::parse_enum_variant(answer_type)?,
                announce_type: Self::parse_enum_variant(announce_type)?,
                display_mode: Self::parse_enum_variant(display_mode)?,
                choices: choices
                    .into_iter()
                    .map(PollChoice::decode)
                    .collect::<Result<_, _>>()?,
                votes: PollVotes::decode(Self::expect_field("votes", votes)?)?,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::Poll> for Poll {
        fn encode(&self) -> protobuf::data_backup::Poll {
            protobuf::data_backup::Poll {
                poll_id: self.id.0,
                conversation: Some(self.conversation.encode()),
                creator_identity: self.creator_identity.to_string(),
                created_at: self.created_at,
                state: self.state.into(),
                description: self.description.clone(),
                answer_type: self.answer_type.into(),
                announce_type: self.announce_type.into(),
                display_mode: self.display_mode.into(),
                choices: self.choices.iter().map(PollChoice::encode).collect(),
                votes: Some(self.votes.encode()),
            }
        }
    }
}

mod message {
    use duplicate::duplicate_item;

    use super::BackupDecodingError;
    use crate::{
        common::{ConversationId, MessageId, ThreemaId},
        csp_e2e::message::MessageOverrides,
        data_backup::codec::{InternalBackupDecoder, InternalBackupEncoder},
        model::{
            message::{
                EmojiReaction, IncomingMessageDirection, LocationMessageState, MessageDirection,
                MessageReaction, MessageStarMarker, MessageState, MessageStateBody, MessageStateBodyType,
                MessageText, MessageTextRevision, OutgoingMessageDirection, PollClose, PollOpen,
                TextMessageState,
            },
            poll::PollId,
        },
        protobuf::{self},
    };

    impl InternalBackupDecoder<i32> for MessageStarMarker {
        fn decode(raw_message: i32) -> Result<Self, BackupDecodingError> {
            Ok(match Self::parse_enum_variant(raw_message)? {
                protobuf::data_backup::MessageStarMarker::NoMarker => Self::None,
                protobuf::data_backup::MessageStarMarker::Star => Self::Star,
            })
        }
    }
    impl InternalBackupEncoder<i32> for MessageStarMarker {
        fn encode(&self) -> i32 {
            match self {
                Self::None => protobuf::data_backup::MessageStarMarker::NoMarker,
                Self::Star => protobuf::data_backup::MessageStarMarker::Star,
            }
            .into()
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::MessageReaction> for MessageReaction {
        fn decode(raw_message: protobuf::data_backup::MessageReaction) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::MessageReaction {
                created_at,
                creator_identity,
                emoji,
            } = raw_message;
            Ok(Self {
                created_at,
                creator_identity: ThreemaId::try_from(creator_identity.as_str())?,
                emoji: EmojiReaction { codepoint: emoji },
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::MessageReaction> for MessageReaction {
        fn encode(&self) -> protobuf::data_backup::MessageReaction {
            protobuf::data_backup::MessageReaction {
                created_at: self.created_at,
                creator_identity: self.creator_identity.to_string(),
                emoji: self.emoji.codepoint.clone(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::MessageOverrides> for MessageOverrides {
        fn decode(raw_message: protobuf::data_backup::MessageOverrides) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::MessageOverrides {
                disable_delivery_receipts,
            } = raw_message;

            Ok(Self {
                disable_delivery_receipts,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::MessageOverrides> for MessageOverrides {
        fn encode(&self) -> protobuf::data_backup::MessageOverrides {
            protobuf::data_backup::MessageOverrides {
                disable_delivery_receipts: self.disable_delivery_receipts,
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::MessageTextRevision> for MessageTextRevision {
        fn decode(
            raw_message: protobuf::data_backup::MessageTextRevision,
        ) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::MessageTextRevision { created_at, text } = raw_message;

            Ok(Self {
                created_at,
                message: MessageText { text },
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::MessageTextRevision> for MessageTextRevision {
        fn encode(&self) -> protobuf::data_backup::MessageTextRevision {
            protobuf::data_backup::MessageTextRevision {
                created_at: self.created_at,
                text: self.message.text.clone(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::TextMessageState> for TextMessageState {
        fn decode(raw_message: protobuf::data_backup::TextMessageState) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::TextMessageState {
                original_text,
                revisions,
            } = raw_message;

            Ok(Self {
                original: MessageText { text: original_text },
                revisions: revisions
                    .into_iter()
                    .map(MessageTextRevision::decode)
                    .collect::<Result<_, _>>()?,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::TextMessageState> for TextMessageState {
        fn encode(&self) -> protobuf::data_backup::TextMessageState {
            protobuf::data_backup::TextMessageState {
                original_text: self.original.text.clone(),
                revisions: self.revisions.iter().map(MessageTextRevision::encode).collect(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::LocationMessageState> for LocationMessageState {
        fn decode(
            raw_message: protobuf::data_backup::LocationMessageState,
        ) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::LocationMessageState {
                latitude,
                longitude,
                accuracy_m,
                name,
                address,
            } = raw_message;

            Ok(Self {
                latitude,
                longitude,
                accuracy_m,
                name: Self::expect_field("name", name)?,
                address: Self::expect_field("address", address)?,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::LocationMessageState> for LocationMessageState {
        fn encode(&self) -> protobuf::data_backup::LocationMessageState {
            protobuf::data_backup::LocationMessageState {
                latitude: self.latitude,
                longitude: self.longitude,
                accuracy_m: self.accuracy_m,
                name: Some(self.name.clone()),
                address: Some(self.address.clone()),
            }
        }
    }

    #[duplicate_item(
        poll_message;
        [ PollOpen ];
        [ PollClose ];
    ) ]
    impl InternalBackupDecoder<protobuf::data_backup::poll_message> for poll_message {
        fn decode(raw_message: protobuf::data_backup::poll_message) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::poll_message { poll_id } = raw_message;

            Ok(Self { id: PollId(poll_id) })
        }
    }
    #[duplicate_item(
        poll_message;
        [ PollOpen ];
        [ PollClose ];
    ) ]
    impl InternalBackupEncoder<protobuf::data_backup::poll_message> for poll_message {
        fn encode(&self) -> protobuf::data_backup::poll_message {
            protobuf::data_backup::poll_message { poll_id: self.id.0 }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::DeletedMessageState> for MessageStateBodyType {
        fn decode(
            raw_message: protobuf::data_backup::DeletedMessageState,
        ) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::DeletedMessageState { previous_type } = raw_message;

            Ok(match Self::parse_enum_variant(previous_type)? {
                protobuf::data_backup::MessageStateBodyType::Text => Self::Text,
                protobuf::data_backup::MessageStateBodyType::Location => Self::Location,
                protobuf::data_backup::MessageStateBodyType::Pollopen => Self::PollOpen,
                protobuf::data_backup::MessageStateBodyType::Pollclose => Self::PollClose,
                protobuf::data_backup::MessageStateBodyType::Deleted => Self::Deleted,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::DeletedMessageState> for MessageStateBodyType {
        fn encode(&self) -> protobuf::data_backup::DeletedMessageState {
            protobuf::data_backup::DeletedMessageState {
                previous_type: *self as i32,
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::MessageDirection> for MessageDirection {
        fn decode(raw_message: protobuf::data_backup::MessageDirection) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::MessageDirection { direction } = raw_message;

            Ok(match Self::expect_field("direction", direction)? {
                protobuf::data_backup::message_direction::Direction::Incoming(incoming_message_direction) => {
                    Self::Incoming(IncomingMessageDirection {
                        received_at: incoming_message_direction.received_at,
                    })
                },
                protobuf::data_backup::message_direction::Direction::Outgoing(outgoing_message_direction) => {
                    Self::Outgoing(OutgoingMessageDirection {
                        sent_at: outgoing_message_direction.sent_at,
                        delivered_at: outgoing_message_direction.delivered_at,
                    })
                },
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::MessageDirection> for MessageDirection {
        fn encode(&self) -> protobuf::data_backup::MessageDirection {
            protobuf::data_backup::MessageDirection {
                direction: match self {
                    Self::Incoming(incoming_message_direction) => {
                        Some(protobuf::data_backup::message_direction::Direction::Incoming(
                            protobuf::data_backup::IncomingMessageDirection {
                                received_at: incoming_message_direction.received_at,
                            },
                        ))
                    },
                    Self::Outgoing(outgoing_message_direction) => {
                        Some(protobuf::data_backup::message_direction::Direction::Outgoing(
                            protobuf::data_backup::OutgoingMessageDirection {
                                sent_at: outgoing_message_direction.sent_at,
                                delivered_at: outgoing_message_direction.delivered_at,
                            },
                        ))
                    },
                },
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::MessageStateBody> for MessageStateBody {
        fn decode(raw_message: protobuf::data_backup::MessageStateBody) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::MessageStateBody { body } = raw_message;

            Ok(match Self::expect_field("body", body)? {
                protobuf::data_backup::message_state_body::Body::Text(text_message_state) => {
                    Self::Text(TextMessageState::decode(text_message_state)?)
                },
                protobuf::data_backup::message_state_body::Body::Location(location_message) => {
                    Self::Location(LocationMessageState::decode(location_message)?)
                },
                protobuf::data_backup::message_state_body::Body::PollOpen(poll_open_message) => {
                    Self::PollOpen(PollOpen::decode(poll_open_message)?)
                },
                protobuf::data_backup::message_state_body::Body::PollClose(poll_close_message) => {
                    Self::PollClose(PollClose::decode(poll_close_message)?)
                },
                protobuf::data_backup::message_state_body::Body::Deleted(deleted_message) => {
                    // TODO(LIB-94): The conversion from `MessageStateBodyType`
                    // `protobuf::data_backup::MessageStateBody` and back to is somehow strange.
                    Self::Deleted(MessageStateBodyType::decode(deleted_message)?)
                },
            })
        }
    }

    impl InternalBackupEncoder<protobuf::data_backup::MessageStateBody> for MessageStateBody {
        fn encode(&self) -> protobuf::data_backup::MessageStateBody {
            protobuf::data_backup::MessageStateBody {
                body: Some(match self {
                    Self::Text(text_message_state) => {
                        protobuf::data_backup::message_state_body::Body::Text(text_message_state.encode())
                    },
                    Self::Location(location_message_state) => {
                        protobuf::data_backup::message_state_body::Body::Location(
                            location_message_state.encode(),
                        )
                    },
                    Self::PollOpen(poll_open) => {
                        protobuf::data_backup::message_state_body::Body::PollOpen(poll_open.encode())
                    },
                    Self::PollClose(poll_close) => {
                        protobuf::data_backup::message_state_body::Body::PollClose(poll_close.encode())
                    },
                    Self::Deleted(previous_type) => {
                        // TODO(LIB-94): The conversion from `MessageStateBodyType`
                        // `protobuf::data_backup::MessageStateBody` and back to is somehow strange.
                        protobuf::data_backup::message_state_body::Body::Deleted(previous_type.encode())
                    },
                }),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::MessageState> for MessageState {
        fn decode(raw_message: protobuf::data_backup::MessageState) -> Result<Self, BackupDecodingError> {
            let protobuf::data_backup::MessageState {
                conversation_id,
                creator_identity,
                message_id,
                created_at,
                direction,
                read_at,
                star_marker,
                reactions,
                body,
            } = raw_message;

            Ok(Self {
                conversation_id: ConversationId::decode(Self::expect_field(
                    "conversation_id",
                    conversation_id,
                )?)?,
                creator_identity: ThreemaId::try_from(creator_identity.as_str())?,
                message_id: MessageId(message_id),
                created_at,
                direction: MessageDirection::decode(Self::expect_field("direction", direction)?)?,
                read_at,
                star_marker: MessageStarMarker::decode(star_marker)?,
                reactions: reactions
                    .into_iter()
                    .map(MessageReaction::decode)
                    .collect::<Result<Vec<_>, _>>()?,
                body: MessageStateBody::decode(Self::expect_field("body", body)?)?,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::MessageState> for MessageState {
        fn encode(&self) -> protobuf::data_backup::MessageState {
            protobuf::data_backup::MessageState {
                conversation_id: Some(ConversationId::encode(&self.conversation_id)),
                creator_identity: self.creator_identity.to_string(),
                message_id: self.message_id.0,
                created_at: self.created_at,
                direction: Some(MessageDirection::encode(&self.direction)),
                read_at: self.read_at,
                star_marker: MessageStarMarker::encode(&self.star_marker),
                reactions: self.reactions.iter().map(MessageReaction::encode).collect(),
                body: Some(MessageStateBody::encode(&self.body)),
            }
        }
    }
}

mod user {
    use std::collections::HashSet;

    use tracing::warn;

    use crate::{
        common::{ChatServerGroup, ThreemaId, keys::ClientKey},
        data_backup::{
            codec::{BackupDecodingError, InternalBackupDecoder, InternalBackupEncoder},
            container::UserData,
        },
        model::{
            profile::ProfilePicture,
            settings::Settings,
            user_profile::{
                IdentityData, IdentityLinkEmailAddress, IdentityLinkPhoneNumber, ProfilePictureSharePolicy,
                UserProfile,
            },
        },
        protobuf::{
            self,
            d2d_sync::{self, user_profile},
            data_backup,
        },
        utils::debug::Name as _,
        work::properties::WorkAvailabilityStatus,
    };

    impl InternalBackupDecoder<user_profile::ProfilePictureShareWith> for ProfilePictureSharePolicy {
        fn decode(raw_message: user_profile::ProfilePictureShareWith) -> Result<Self, BackupDecodingError> {
            let user_profile::ProfilePictureShareWith { policy } = raw_message;

            Ok(match Self::expect_field("policy", policy)? {
                user_profile::profile_picture_share_with::Policy::Nobody(_) => Self::Nobody,
                user_profile::profile_picture_share_with::Policy::Everyone(_) => Self::Everyone,
                user_profile::profile_picture_share_with::Policy::AllowList(identities) => {
                    Self::AllowList(HashSet::decode(identities)?)
                },
            })
        }
    }
    impl InternalBackupEncoder<user_profile::ProfilePictureShareWith> for ProfilePictureSharePolicy {
        fn encode(&self) -> user_profile::ProfilePictureShareWith {
            let policy = match &self {
                Self::Nobody => {
                    user_profile::profile_picture_share_with::Policy::Nobody(protobuf::common::Unit {})
                },
                Self::Everyone => {
                    user_profile::profile_picture_share_with::Policy::Everyone(protobuf::common::Unit {})
                },
                Self::AllowList(identities) => {
                    user_profile::profile_picture_share_with::Policy::AllowList(identities.encode())
                },
            };

            user_profile::ProfilePictureShareWith { policy: Some(policy) }
        }
    }

    impl InternalBackupEncoder<user_profile::identity_links::IdentityLink> for IdentityLinkEmailAddress {
        fn encode(&self) -> user_profile::identity_links::IdentityLink {
            user_profile::identity_links::IdentityLink {
                // The protocol supports a description that is not used in the apps.
                description: String::new(),
                r#type: Some(user_profile::identity_links::identity_link::Type::Email(
                    match self {
                        Self::EmailAddress(email_address) => email_address.clone(),
                        Self::Unknown => String::new(),
                    },
                )),
            }
        }
    }
    impl InternalBackupEncoder<user_profile::identity_links::IdentityLink> for IdentityLinkPhoneNumber {
        fn encode(&self) -> user_profile::identity_links::IdentityLink {
            user_profile::identity_links::IdentityLink {
                // The protocol supports a description that is not used in the apps.
                description: String::new(),
                r#type: Some(user_profile::identity_links::identity_link::Type::PhoneNumber(
                    match self {
                        Self::PhoneNumber(phone_number) => phone_number.clone(),
                        Self::Unknown => String::new(),
                    },
                )),
            }
        }
    }

    impl InternalBackupDecoder<data_backup::IdentityData> for IdentityData {
        fn decode(raw_message: data_backup::IdentityData) -> Result<Self, BackupDecodingError> {
            let data_backup::IdentityData {
                identity,
                ck,
                csp_server_group,
            } = raw_message;

            Ok(Self {
                user_identity: ThreemaId::try_from(identity.as_str())?,
                client_key: ClientKey::from(TryInto::<[u8; ClientKey::LENGTH]>::try_into(ck).map_err(
                    |_| BackupDecodingError::InvalidMessage("client key must have 32 bytes".to_owned()),
                )?),
                csp_server_group: ChatServerGroup::try_from(csp_server_group.as_str()).map_err(|_| {
                    BackupDecodingError::InvalidMessage(format!("Invalid {}", ChatServerGroup::NAME))
                })?,
            })
        }
    }
    impl InternalBackupEncoder<data_backup::IdentityData> for IdentityData {
        fn encode(&self) -> data_backup::IdentityData {
            data_backup::IdentityData {
                identity: self.user_identity.to_string(),
                ck: self.client_key.as_bytes().to_vec(),
                csp_server_group: self.csp_server_group.as_str().to_owned(),
            }
        }
    }

    impl InternalBackupDecoder<data_backup::UserProfile> for UserProfile {
        fn decode(raw_message: data_backup::UserProfile) -> Result<Self, BackupDecodingError> {
            let data_backup::UserProfile {
                nickname,
                profile_picture,
                profile_picture_share_with,
                identity_links,
                work_availability_status,
            } = raw_message;

            // Decode identity links.
            let (linked_email_address, linked_phone_number) = {
                let user_profile::IdentityLinks {
                    links: identity_links,
                } = Self::expect_field("identity_links", identity_links)?;

                let mut linked_email_address = None;
                let mut linked_phone_number = None;
                for user_profile::identity_links::IdentityLink {
                    description: _description,
                    r#type,
                } in identity_links
                {
                    match r#type {
                        Some(user_profile::identity_links::identity_link::Type::PhoneNumber(
                            phone_number,
                        )) => {
                            if linked_phone_number.is_some() {
                                warn!("Skipping unsupported secondary linked phone number");
                            } else {
                                linked_phone_number = Some(if phone_number.is_empty() {
                                    IdentityLinkPhoneNumber::Unknown
                                } else {
                                    IdentityLinkPhoneNumber::PhoneNumber(phone_number)
                                });
                            }
                        },
                        Some(user_profile::identity_links::identity_link::Type::Email(email_address)) => {
                            if linked_email_address.is_some() {
                                warn!("Skipping unsupported secondary linked email address");
                            } else {
                                linked_email_address = Some(if email_address.is_empty() {
                                    IdentityLinkEmailAddress::Unknown
                                } else {
                                    IdentityLinkEmailAddress::EmailAddress(email_address)
                                });
                            }
                        },
                        None => {},
                    }
                }

                (linked_email_address, linked_phone_number)
            };

            Ok(Self {
                nickname: Self::expect_field("nickname", nickname)?,
                profile_picture_share_policy: ProfilePictureSharePolicy::decode(Self::expect_field(
                    "profile_picture_share_with",
                    profile_picture_share_with,
                )?)?,
                profile_picture: profile_picture.map(ProfilePicture::decode).transpose()?,
                linked_phone_number,
                linked_email_address,
                work_availability_status: work_availability_status
                    .map(WorkAvailabilityStatus::decode)
                    .transpose()?,
            })
        }
    }
    impl InternalBackupEncoder<data_backup::UserProfile> for UserProfile {
        fn encode(&self) -> data_backup::UserProfile {
            // Encode identity links.
            let identity_links = {
                let mut identity_links = Vec::new();
                if let Some(linked_email_address) = &self.linked_email_address {
                    identity_links.push(linked_email_address.encode());
                }
                if let Some(linked_phone_number) = &self.linked_phone_number {
                    identity_links.push(linked_phone_number.encode());
                }
                Some(user_profile::IdentityLinks {
                    links: identity_links,
                })
            };

            data_backup::UserProfile {
                nickname: Some(self.nickname.clone()),
                profile_picture: self.profile_picture.as_ref().map(ProfilePicture::encode),
                profile_picture_share_with: Some(self.profile_picture_share_policy.encode()),
                identity_links,
                work_availability_status: self
                    .work_availability_status
                    .clone()
                    .map(WorkAvailabilityStatus::into),
            }
        }
    }

    impl InternalBackupDecoder<d2d_sync::Settings> for Settings {
        fn decode(raw_message: d2d_sync::Settings) -> Result<Self, BackupDecodingError> {
            let d2d_sync::Settings {
                contact_sync_policy,
                unknown_contact_policy,
                read_receipt_policy,
                typing_indicator_policy,
                o2o_call_policy,
                o2o_call_connection_policy,
                o2o_call_video_policy,
                group_call_policy,
                screenshot_policy,

                #[expect(deprecated, reason = "Must be handled until phased out")]
                    deprecated_keyboard_data_collection_policy: _deprecated_keyboard_data_collection_policy,

                blocked_identities,
                exclude_from_sync_identities,
            } = raw_message;

            Ok(Self {
                contact_sync_policy: Self::expect_and_parse_enum_variant(
                    "contact sync policy",
                    contact_sync_policy,
                )?,

                unknown_contact_policy: Self::expect_and_parse_enum_variant(
                    "unknown contact policy",
                    unknown_contact_policy,
                )?,

                read_receipt_policy: Self::expect_and_parse_enum_variant(
                    "read receipt policy",
                    read_receipt_policy,
                )?,

                typing_indicator_policy: Self::expect_and_parse_enum_variant(
                    "typing_indicator policy",
                    typing_indicator_policy,
                )?,

                o2o_call_policy: Self::expect_and_parse_enum_variant("o2o_call policy", o2o_call_policy)?,

                o2o_call_connection_policy: Self::expect_and_parse_enum_variant(
                    "o2o call connection policy",
                    o2o_call_connection_policy,
                )?,

                o2o_call_video_policy: Self::expect_and_parse_enum_variant(
                    "o2o call video policy",
                    o2o_call_video_policy,
                )?,

                group_call_policy: Self::expect_and_parse_enum_variant(
                    "group call policy",
                    group_call_policy,
                )?,

                screenshot_policy: Self::expect_and_parse_enum_variant(
                    "screenshot policy",
                    screenshot_policy,
                )?,

                blocked_identities: Self::expect_field("blocked_identities", blocked_identities)?
                    .identities
                    .into_iter()
                    .map(|identity| ThreemaId::try_from(identity.as_str()))
                    .collect::<Result<_, _>>()?,

                exclude_from_sync_identities: Self::expect_field(
                    "exclude_from_sync_identities",
                    exclude_from_sync_identities,
                )?
                .identities
                .into_iter()
                .map(|identity| ThreemaId::try_from(identity.as_str()))
                .collect::<Result<_, _>>()?,
            })
        }
    }
    impl InternalBackupEncoder<d2d_sync::Settings> for Settings {
        fn encode(&self) -> d2d_sync::Settings {
            d2d_sync::Settings {
                contact_sync_policy: Some(self.contact_sync_policy as i32),
                unknown_contact_policy: Some(self.unknown_contact_policy as i32),
                read_receipt_policy: Some(self.read_receipt_policy as i32),
                typing_indicator_policy: Some(self.typing_indicator_policy as i32),
                o2o_call_policy: Some(self.o2o_call_policy as i32),
                o2o_call_connection_policy: Some(self.o2o_call_connection_policy as i32),
                o2o_call_video_policy: Some(self.o2o_call_video_policy as i32),
                group_call_policy: Some(self.group_call_policy as i32),
                screenshot_policy: Some(self.screenshot_policy as i32),

                #[expect(deprecated, reason = "Must be handled until phased out")]
                deprecated_keyboard_data_collection_policy: Some(
                    d2d_sync::settings::DeprecatedKeyboardDataCollectionPolicy::AllowDataCollection as i32,
                ),

                blocked_identities: Some(self.blocked_identities.encode()),
                exclude_from_sync_identities: Some(self.exclude_from_sync_identities.encode()),
            }
        }
    }

    impl InternalBackupDecoder<data_backup::UserData> for UserData {
        fn decode(raw_message: data_backup::UserData) -> Result<Self, BackupDecodingError> {
            let data_backup::UserData {
                identity_data,
                user_profile,
                settings,
            } = raw_message;

            Ok(Self {
                identity_data: IdentityData::decode(Self::expect_field("identity_data", identity_data)?)?,
                user_profile: UserProfile::decode(Self::expect_field("user_profile", user_profile)?)?,
                settings: Settings::decode(Self::expect_field("settings", settings)?)?,
            })
        }
    }
    impl InternalBackupEncoder<data_backup::UserData> for UserData {
        fn encode(&self) -> data_backup::UserData {
            data_backup::UserData {
                identity_data: Some(self.identity_data.encode()),
                user_profile: Some(self.user_profile.encode()),
                settings: Some(self.settings.encode()),
            }
        }
    }
}

pub(crate) mod container {
    use duplicate::duplicate_item;
    use prost::Message as _;

    use crate::{
        common::HashedNonce,
        data_backup::{
            codec::{
                BackupDecodingError, BackupEncodingError, InternalBackupDecoder as _,
                InternalBackupEncoder as _,
            },
            container::{
                ContactContainer, DistributionListContainer, GroupContainer, HashedCspNonceContainer,
                HashedD2mNonceContainer, MessageContainer, PollContainer, UserData, UserDataContainer,
            },
        },
        model::{
            contact::ContactWithProfilePictures, distribution_list::DistributionList,
            group::GroupWithProfilePicture, message::MessageState, poll::Poll,
        },
        protobuf,
        utils::{
            bytes::{ByteWriter as _, OwnedVecByteWriter},
            debug::Name,
            frame::{FrameDelimiter as _, U32LittleEndianDelimiter},
        },
    };

    // TODO(LIB-174): Check if this can be inlined in PageReader::add_page.
    pub(crate) trait VariableLengthBackupDecoder: Sized {
        /// Decode the buffer to a container.
        ///
        /// Note: `buffer` does not contain any type or length field.
        fn decode(buffer: &[u8]) -> Result<Self, BackupDecodingError>;
    }

    // TODO(LIB-174): Check if this can be inlined in PageReader::add_page.
    pub(crate) trait HashedNonceBackupDecoder: Sized {
        /// Decode a fixed length buffer to a container.
        ///
        /// Note: The return type is a result to match the signature of
        /// [`VariableLengthContainerDecoder::decode`].
        fn decode(buffer: &[u8; HashedNonce::LENGTH]) -> Result<Self, BackupDecodingError>;
    }

    pub(crate) trait BackupEncoder {
        fn encode(&self) -> Result<Vec<u8>, BackupEncodingError>;

        /// Encode a container with variable length with a u32 length delimiter.
        // TODO(LIB-174):
        // - Move to utils/protobuf
        // - Make delimiter length constant and choosable by caller, see PaddedMessage trait.
        // - This can be an extension of prost::Message
        fn encode_variable_length<TContainer: prost::Message + Name>(
            container: TContainer,
        ) -> Result<Vec<u8>, BackupEncodingError> {
            let value = container.encode_to_vec();
            let length = value.len();
            let mut writer = OwnedVecByteWriter::new_with_capacity(
                length.saturating_add(U32LittleEndianDelimiter::LENGTH),
            );

            // Convert length.
            let length: u32 = length
                .try_into()
                .map_err(|_| BackupEncodingError::ConversionFailed("Container length"))?;

            // Write &self encoded as length-value.
            writer.run(|writer| {
                writer.write_u32_le(length)?;
                writer.write(&value)
            })?;

            Ok(writer.into_inner())
        }
    }

    #[duplicate_item(
        hashed_nonce_container ;
        [ HashedCspNonceContainer ];
        [ HashedD2mNonceContainer ];
    ) ]
    impl HashedNonceBackupDecoder for hashed_nonce_container {
        fn decode(buffer: &[u8; HashedNonce::LENGTH]) -> Result<Self, BackupDecodingError> {
            Ok(Self(HashedNonce(*buffer)))
        }
    }
    #[duplicate_item(
    hashed_nonce_container     ;
        [ HashedCspNonceContainer ] ;
        [ HashedD2mNonceContainer ]  ;
    )]
    impl BackupEncoder for hashed_nonce_container {
        fn encode(&self) -> Result<Vec<u8>, BackupEncodingError> {
            Ok(self.0.0.to_vec())
        }
    }

    #[duplicate_item(
          [
              inner_type     [ UserData ]
              protobuf_type  [ data_backup::UserData ]
              container_type [ UserDataContainer ]
          ]
          [
              inner_type     [ ContactWithProfilePictures ]
              protobuf_type  [ data_backup::AugmentedContact ]
              container_type [ ContactContainer ]
          ]
          [
              inner_type     [ DistributionList ]
              protobuf_type  [ d2d_join::essential_data::AugmentedDistributionList ]
              container_type [ DistributionListContainer ]
          ]
          [
              inner_type     [ GroupWithProfilePicture ]
              protobuf_type  [ data_backup::AugmentedGroup ]
              container_type [ GroupContainer ]
          ]
          [
              inner_type     [ MessageState ]
              protobuf_type  [ data_backup::MessageState ]
              container_type [ MessageContainer ]
          ]
          [
              inner_type     [ Poll ]
              protobuf_type  [ data_backup::Poll ]
              container_type [ PollContainer ]
          ]
      )]

    impl VariableLengthBackupDecoder for container_type {
        fn decode(buffer: &[u8]) -> Result<Self, BackupDecodingError> {
            Ok(Self(inner_type::decode(protobuf::protobuf_type::decode(
                buffer,
            )?)?))
        }
    }
    #[duplicate_item(
        container_type               ;
        [ UserDataContainer         ];
        [ ContactContainer          ];
        [ DistributionListContainer ];
        [ GroupContainer            ];
        [ MessageContainer          ];
        [ PollContainer             ];
    )]
    impl BackupEncoder for container_type {
        fn encode(&self) -> Result<Vec<u8>, BackupEncodingError> {
            Self::encode_variable_length(self.0.encode())
        }
    }
}
