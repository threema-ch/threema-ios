//! Codecs for the data backup.
use crate::{data_backup::DataBackupDecodeErrorSource, utils::debug::Name};

trait InternalBackupDecoder<TRawMessage: Name>: Sized {
    fn decode(raw_message: TRawMessage) -> Result<Self, DataBackupDecodeErrorSource>;

    // TODO(LIB-174): Check: Move this to utils/protobuf.rs ?
    //
    // Idea: Extend prost::Message and expose this for all protobuf messages.
    fn expect_field<T>(value: Option<T>, field_name: &'static str) -> Result<T, DataBackupDecodeErrorSource> {
        value.ok_or(DataBackupDecodeErrorSource::MissingField {
            name: TRawMessage::NAME,
            field_name,
        })
    }

    // TODO(LIB-174): Check: Move this to utils/protobuf.rs ?
    fn parse_enum_variant<T>(variant: i32) -> Result<T, DataBackupDecodeErrorSource>
    where
        T: TryFrom<i32> + Name,
    {
        variant
            .try_into()
            .map_err(|_| DataBackupDecodeErrorSource::UnknownEnumVariant {
                name: T::NAME,
                variant,
            })
    }

    /// Decode an optional enum variant and return a [`BackupDecodingError`] if the value is `None` or if the
    /// variant could not be decoded.
    // TODO(LIB-174): Check: Move this to utils/protobuf.rs ?
    // TODO(LIB-174): Is there a method provided by prost? Otherwise, we should add an extension.
    fn expect_and_parse_enum_variant<T>(
        variant: Option<i32>,
        field_name: &'static str,
    ) -> Result<T, DataBackupDecodeErrorSource>
    where
        T: TryFrom<i32> + Name,
    {
        Self::parse_enum_variant::<T>(Self::expect_field(variant, field_name)?)
    }
}

trait InternalBackupEncoder<TOutput> {
    fn encode(self) -> TOutput;
}

mod common {
    use std::collections::HashSet;

    use crate::{
        common::{ConversationId, DistributionListId, GroupIdentity, ThreemaId},
        data_backup::{
            DataBackupDecodeErrorSource,
            codec::{InternalBackupDecoder, InternalBackupEncoder},
        },
        protobuf,
    };

    // TODO(LIB-174): Is there a better place for this? Maybe even TryFrom/From implementations?
    impl InternalBackupDecoder<protobuf::common::Identities> for Vec<ThreemaId> {
        fn decode(raw_message: protobuf::common::Identities) -> Result<Self, DataBackupDecodeErrorSource> {
            let protobuf::common::Identities { identities } = raw_message;

            Ok(identities
                .into_iter()
                .map(|identity| ThreemaId::try_from(identity.as_str()))
                .collect::<Result<_, _>>()?)
        }
    }
    impl InternalBackupEncoder<protobuf::common::Identities> for Vec<ThreemaId> {
        fn encode(self) -> protobuf::common::Identities {
            protobuf::common::Identities {
                identities: self.into_iter().map(ThreemaId::into).collect(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::common::Identities> for HashSet<ThreemaId> {
        fn decode(raw_message: protobuf::common::Identities) -> Result<Self, DataBackupDecodeErrorSource> {
            Ok(Vec::decode(raw_message)?.into_iter().collect())
        }
    }
    impl InternalBackupEncoder<protobuf::common::Identities> for HashSet<ThreemaId> {
        fn encode(self) -> protobuf::common::Identities {
            protobuf::common::Identities {
                identities: self.into_iter().map(ThreemaId::into).collect(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::d2d::ConversationId> for ConversationId {
        fn decode(raw_message: protobuf::d2d::ConversationId) -> Result<Self, DataBackupDecodeErrorSource> {
            let protobuf::d2d::ConversationId { id: conversation_id } = raw_message;

            Ok(match Self::expect_field(conversation_id, "conversation_id")? {
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
        fn encode(self) -> protobuf::d2d::ConversationId {
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
        data_backup::codec::{DataBackupDecodeErrorSource, InternalBackupDecoder, InternalBackupEncoder},
        model::profile::{ProfilePicture, ProfilePictureMediaType},
        protobuf,
    };

    impl InternalBackupDecoder<protobuf::data_backup::ProfilePicture> for ProfilePicture {
        fn decode(
            raw_message: protobuf::data_backup::ProfilePicture,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
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
        fn encode(self) -> protobuf::data_backup::ProfilePicture {
            protobuf::data_backup::ProfilePicture {
                media_type: match self.media_type {
                    ProfilePictureMediaType::Jpeg => protobuf::common::image::Type::Jpeg,
                }
                .into(),
                data: self.data,
            }
        }
    }
}

mod contact {
    use crate::{
        common::{FeatureMask, ThreemaId, keys::PublicKey},
        data_backup::codec::{DataBackupDecodeErrorSource, InternalBackupDecoder, InternalBackupEncoder},
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
        ) -> Result<Self, DataBackupDecodeErrorSource> {
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
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let d2d_sync::contact::NotificationTriggerPolicyOverride { r#override } = raw_message;

            Ok(match Self::expect_field(r#override, "override")? {
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
        fn encode(self) -> d2d_sync::contact::NotificationTriggerPolicyOverride {
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
        fn decode(
            raw_message: d2d_sync::WorkAvailabilityStatus,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let d2d_sync::WorkAvailabilityStatus {
                category,
                description,
            } = raw_message;

            Ok(match Self::parse_enum_variant(category)? {
                d2d_sync::WorkAvailabilityStatusCategory::None => Self::None,
                d2d_sync::WorkAvailabilityStatusCategory::Unavailable => Self::Unavailable(description),
                d2d_sync::WorkAvailabilityStatusCategory::Busy => Self::Busy(description),
            })
        }
    }
    impl InternalBackupEncoder<d2d_sync::WorkAvailabilityStatus> for WorkAvailabilityStatus {
        fn encode(self) -> d2d_sync::WorkAvailabilityStatus {
            let (category, description) = match self {
                Self::None => (d2d_sync::WorkAvailabilityStatusCategory::None, String::new()),
                Self::Unavailable(description) => {
                    (d2d_sync::WorkAvailabilityStatusCategory::Unavailable, description)
                },
                Self::Busy(description) => (d2d_sync::WorkAvailabilityStatusCategory::Busy, description),
            };

            d2d_sync::WorkAvailabilityStatus {
                category: category.into(),
                description,
            }
        }
    }

    impl InternalBackupDecoder<data_backup::AugmentedContact> for ContactWithProfilePictures {
        fn decode(raw_message: data_backup::AugmentedContact) -> Result<Self, DataBackupDecodeErrorSource> {
            let data_backup::AugmentedContact {
                contact,
                last_update_at,
                contact_defined_profile_picture,
                user_defined_profile_picture,
            } = raw_message;

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
            } = Self::expect_field(contact, "contact")?;

            if deprecated_notification_sound_policy_override.is_some() {
                return Err(DataBackupDecodeErrorSource::InvalidMessage(
                    "deprecated_notification_sound_policy_override must be None in d2d_sync::Contact"
                        .to_owned(),
                ));
            }

            if d2d_sync_contact_defined_profile_picture.is_some() {
                return Err(DataBackupDecodeErrorSource::InvalidMessage(
                    "contact_defined_profile_picture must be None in d2d_sync::Contact".to_owned(),
                ));
            }

            if d2d_sync_user_defined_profile_picture.is_some() {
                return Err(DataBackupDecodeErrorSource::InvalidMessage(
                    "user_defined_profile_picture must be None in d2d_sync::Contact".to_owned(),
                ));
            }

            let public_key = PublicKey::try_from(Self::expect_field(public_key, "public_key")?.as_slice())
                .map_err(|_| {
                    DataBackupDecodeErrorSource::InvalidMessage("Public key must have 32 bytes".to_owned())
                })?;

            let created_at = Self::expect_field(created_at, "created_at")?;

            let read_receipt_policy_override = read_receipt_policy_override
                .map(|policy_override| {
                    match Self::expect_field(policy_override.r#override, "policy_override.override")? {
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
                    match Self::expect_field(policy_override.r#override, "policy_override.override")? {
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
                first_name: Self::expect_field(first_name, "first_name")?,
                last_name: Self::expect_field(last_name, "last_name")?,
                nickname: Self::expect_field(nickname, "nickname")?,
                verification_level: Self::expect_and_parse_enum_variant(
                    verification_level,
                    "verification_level",
                )?,
                work_verification_level: Self::expect_and_parse_enum_variant(
                    work_verification_level,
                    "work_verification_level",
                )?,
                identity_type: Self::expect_and_parse_enum_variant(identity_type, "identity type")?,
                acquaintance_level: Self::expect_and_parse_enum_variant(
                    acquaintance_level,
                    "acquaintance_level",
                )?,
                activity_state: Self::expect_and_parse_enum_variant(activity_state, "activity_state")?,
                feature_mask: FeatureMask(Self::expect_field(feature_mask, "feature_mask")?),
                sync_state: Self::expect_and_parse_enum_variant(sync_state, "sync_state")?,
                work_last_full_sync_at,
                work_availability_status: work_availability_status
                    .map(WorkAvailabilityStatus::decode)
                    .transpose()?,
                read_receipt_policy_override,
                typing_indicator_policy_override,
                notification_trigger_policy_override: Option::decode(Self::expect_field(
                    notification_trigger_policy_override,
                    "notification_trigger_policy_override",
                )?)?,
                conversation_category: Self::expect_and_parse_enum_variant(
                    conversation_category,
                    "conversation_category",
                )?,
                conversation_visibility: Self::expect_and_parse_enum_variant(
                    conversation_visibility,
                    "conversation_visibility",
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
        fn encode(self) -> data_backup::AugmentedContact {
            let contact = d2d_sync::Contact {
                identity: self.contact.identity.to_string(),
                public_key: Some(self.contact.public_key.0.as_bytes().to_vec()),
                created_at: Some(self.contact.created_at),
                first_name: Some(self.contact.first_name),
                last_name: Some(self.contact.last_name),
                nickname: Some(self.contact.nickname),
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
                    .map(ProfilePicture::encode),
                user_defined_profile_picture: self.user_defined_profile_picture.map(ProfilePicture::encode),
            }
        }
    }
}

mod distribution_list {
    use crate::{
        common::ThreemaId,
        data_backup::codec::{DataBackupDecodeErrorSource, InternalBackupDecoder, InternalBackupEncoder},
        model::distribution_list::DistributionList,
        protobuf,
    };

    impl InternalBackupDecoder<protobuf::d2d_join::essential_data::AugmentedDistributionList>
        for DistributionList
    {
        fn decode(
            raw_message: protobuf::d2d_join::essential_data::AugmentedDistributionList,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
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
            } = Self::expect_field(distribution_list, "distribution_list")?;

            Ok(Self {
                identity: crate::common::DistributionListId(distribution_list_id),
                name: Self::expect_field(name, "name")?,
                created_at: Self::expect_field(created_at, "created_at")?,
                last_update_at,
                members: Self::expect_field(member_identities, "member_identities")?
                    .identities
                    .into_iter()
                    .map(|identity| ThreemaId::try_from(identity.as_str()))
                    .collect::<Result<_, _>>()?,
                conversation_category: Self::expect_and_parse_enum_variant(
                    conversation_category,
                    "conversation_category",
                )?,
                conversation_visibility: Self::expect_and_parse_enum_variant(
                    conversation_visibility,
                    "conversation_visibility",
                )?,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::d2d_join::essential_data::AugmentedDistributionList>
        for DistributionList
    {
        fn encode(self) -> protobuf::d2d_join::essential_data::AugmentedDistributionList {
            protobuf::d2d_join::essential_data::AugmentedDistributionList {
                distribution_list: Some(protobuf::d2d_sync::DistributionList {
                    distribution_list_id: self.identity.0,
                    name: Some(self.name),
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
        data_backup::codec::{DataBackupDecodeErrorSource, InternalBackupDecoder, InternalBackupEncoder},
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
        fn decode(raw_message: protobuf::common::GroupIdentity) -> Result<Self, DataBackupDecodeErrorSource> {
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
        fn encode(self) -> protobuf::common::GroupIdentity {
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
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            // Parse raw message.
            let protobuf::d2d_sync::group::NotificationTriggerPolicyOverride { r#override } = raw_message;

            // Parse override.
            Ok(match Self::expect_field(r#override, "override")? {
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
        fn encode(self) -> protobuf::d2d_sync::group::NotificationTriggerPolicyOverride {
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
        fn decode(
            raw_message: protobuf::data_backup::AugmentedGroup,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
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
            } = Self::expect_field(group, "group")?;

            Ok(Self {
                group: Group {
                    identity: GroupIdentity::decode(Self::expect_field(group_identity, "group_identity")?)?,
                    name: name.unwrap_or_default(),
                    created_at: Self::expect_field(created_at, "created_at")?,
                    last_update_at,
                    user_state: Self::expect_and_parse_enum_variant(user_state, "user_state")?,
                    members: HashSet::decode(Self::expect_field(member_identities, "member_identities")?)?,
                    notification_trigger_policy_override: notification_trigger_policy_override
                        .map(Option::decode)
                        .transpose()?
                        .flatten(),
                    conversation_category: Self::expect_and_parse_enum_variant(
                        conversation_category,
                        "conversation_category",
                    )?,
                    conversation_visibility: Self::expect_and_parse_enum_variant(
                        conversation_visibility,
                        "conversation_visibility",
                    )?,
                },
                profile_picture: profile_picture.map(ProfilePicture::decode).transpose()?,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::AugmentedGroup> for GroupWithProfilePicture {
        fn encode(self) -> protobuf::data_backup::AugmentedGroup {
            protobuf::data_backup::AugmentedGroup {
                group: Some(protobuf::d2d_sync::Group {
                    group_identity: Some(self.group.identity.encode()),
                    name: Some(self.group.name),
                    created_at: Some(self.group.created_at),
                    user_state: Some(self.group.user_state as i32),
                    profile_picture: None,
                    member_identities: Some(self.group.members.encode()),
                    notification_trigger_policy_override: self
                        .group
                        .notification_trigger_policy_override
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
                profile_picture: self.profile_picture.map(ProfilePicture::encode),
            }
        }
    }
}

mod poll {
    use std::collections::HashMap;

    use crate::{
        common::{ConversationId, ThreemaId},
        data_backup::{
            DataBackupDecodeErrorSource,
            codec::{InternalBackupDecoder, InternalBackupEncoder},
        },
        model::poll::{Poll, PollChoice, PollChoiceId, PollId, PollVote, PollVotes, PollVotesSummary},
        protobuf::{self, data_backup::poll::poll_votes as protobuf_poll_votes},
    };

    impl InternalBackupDecoder<protobuf_poll_votes::poll_votes_list::PollVote> for PollVote {
        fn decode(
            raw_message: protobuf_poll_votes::poll_votes_list::PollVote,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
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
        fn encode(self) -> protobuf_poll_votes::poll_votes_list::PollVote {
            protobuf_poll_votes::poll_votes_list::PollVote {
                choices: self.choices.into_iter().map(|choice_id| choice_id.0).collect(),
                created_at: self.created_at,
                modified_at: self.modified_at,
            }
        }
    }

    impl InternalBackupDecoder<protobuf_poll_votes::PollVotesList> for HashMap<ThreemaId, PollVote> {
        fn decode(
            raw_message: protobuf_poll_votes::PollVotesList,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let protobuf_poll_votes::PollVotesList { participant_to_votes } = raw_message;

            participant_to_votes
                .into_iter()
                .map(|(participant, vote)| {
                    Ok::<_, DataBackupDecodeErrorSource>((
                        ThreemaId::try_from(participant.as_str())?,
                        PollVote::decode(vote)?,
                    ))
                })
                .collect::<Result<_, _>>()
        }
    }
    impl InternalBackupEncoder<protobuf_poll_votes::PollVotesList> for HashMap<ThreemaId, PollVote> {
        fn encode(self) -> protobuf_poll_votes::PollVotesList {
            protobuf_poll_votes::PollVotesList {
                participant_to_votes: self
                    .into_iter()
                    .map(|(participant, vote)| (participant.to_string(), vote.encode()))
                    .collect(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf_poll_votes::PollVotesSummary> for PollVotesSummary {
        fn decode(
            raw_message: protobuf_poll_votes::PollVotesSummary,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let protobuf_poll_votes::PollVotesSummary {
                poll_choice_id_to_count,
                user_choices,
            } = raw_message;

            Ok(Self {
                summary: poll_choice_id_to_count
                    .into_iter()
                    .map(|(poll_choice_id, count)| {
                        let Ok(count) = count.try_into() else {
                            return Err(DataBackupDecodeErrorSource::InvalidMessage(
                                "Overflow: vote count".to_owned(),
                            ));
                        };

                        Ok((PollChoiceId(poll_choice_id), count))
                    })
                    .collect::<Result<_, _>>()?,
                user_choices: user_choices.into_iter().map(PollChoiceId).collect(),
            })
        }
    }
    impl InternalBackupEncoder<protobuf_poll_votes::PollVotesSummary> for PollVotesSummary {
        fn encode(self) -> protobuf_poll_votes::PollVotesSummary {
            protobuf_poll_votes::PollVotesSummary {
                poll_choice_id_to_count: self
                    .summary
                    .into_iter()
                    .map(|(poll_choice_id, count)| (poll_choice_id.0, u32::from(count)))
                    .collect(),
                user_choices: self
                    .user_choices
                    .into_iter()
                    .map(|poll_choice_id| poll_choice_id.0)
                    .collect(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::poll::PollVotes> for PollVotes {
        fn decode(
            raw_message: protobuf::data_backup::poll::PollVotes,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let protobuf::data_backup::poll::PollVotes { votes } = raw_message;

            Ok(match Self::expect_field(votes, "votes")? {
                protobuf_poll_votes::Votes::PollVotesList(poll_votes_list) => {
                    Self::Votes(HashMap::decode(poll_votes_list)?)
                },
                protobuf_poll_votes::Votes::PollVotesSummary(votes_summary) => {
                    Self::Summary(PollVotesSummary::decode(votes_summary)?)
                },
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::poll::PollVotes> for PollVotes {
        fn encode(self) -> protobuf::data_backup::poll::PollVotes {
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
        fn decode(
            raw_message: protobuf::data_backup::poll::PollChoice,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let protobuf::data_backup::poll::PollChoice { id, description } = raw_message;

            Ok(Self {
                id: PollChoiceId(id),
                description,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::poll::PollChoice> for PollChoice {
        fn encode(self) -> protobuf::data_backup::poll::PollChoice {
            protobuf::data_backup::poll::PollChoice {
                id: self.id.0,
                description: self.description,
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::Poll> for Poll {
        fn decode(raw_message: protobuf::data_backup::Poll) -> Result<Self, DataBackupDecodeErrorSource> {
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
                conversation: ConversationId::decode(Self::expect_field(conversation, "conversation")?)?,
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
                votes: PollVotes::decode(Self::expect_field(votes, "votes")?)?,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::Poll> for Poll {
        fn encode(self) -> protobuf::data_backup::Poll {
            protobuf::data_backup::Poll {
                poll_id: self.id.0,
                conversation: Some(self.conversation.encode()),
                creator_identity: self.creator_identity.to_string(),
                created_at: self.created_at,
                state: self.state.into(),
                description: self.description,
                answer_type: self.answer_type.into(),
                announce_type: self.announce_type.into(),
                display_mode: self.display_mode.into(),
                choices: self.choices.into_iter().map(PollChoice::encode).collect(),
                votes: Some(self.votes.encode()),
            }
        }
    }
}

mod message {
    use duplicate::duplicate_item;

    use crate::{
        common::{
            ConversationId, MessageId, MessageOverrides, MessageOverridesDeliveryReceiptPolicy, ThreemaId,
        },
        data_backup::{
            DataBackupDecodeErrorSource,
            codec::{InternalBackupDecoder, InternalBackupEncoder},
        },
        model::{
            message::{
                DeletedMessageState, EmojiReaction, IncomingMessageDirection, LocationMessageState,
                MessageDirection, MessageReaction, MessageStarMarker, MessageState, MessageStateBody,
                MessageStateBodyType, MessageText, MessageTextRevision, OutgoingMessageDirection, PollClose,
                PollOpen, TextMessageState,
            },
            poll::PollId,
        },
        protobuf::{
            self, data_backup::incoming_message_direction::message_overrides as protobuf_message_overrides,
        },
    };

    impl InternalBackupDecoder<protobuf::data_backup::MessageReaction> for MessageReaction {
        fn decode(
            raw_message: protobuf::data_backup::MessageReaction,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
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
        fn encode(self) -> protobuf::data_backup::MessageReaction {
            protobuf::data_backup::MessageReaction {
                created_at: self.created_at,
                creator_identity: self.creator_identity.to_string(),
                emoji: self.emoji.codepoint,
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::MessageTextRevision> for MessageTextRevision {
        fn decode(
            raw_message: protobuf::data_backup::MessageTextRevision,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let protobuf::data_backup::MessageTextRevision { created_at, text } = raw_message;

            Ok(Self {
                created_at,
                message: MessageText { text },
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::MessageTextRevision> for MessageTextRevision {
        fn encode(self) -> protobuf::data_backup::MessageTextRevision {
            protobuf::data_backup::MessageTextRevision {
                created_at: self.created_at,
                text: self.message.text,
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::TextMessageState> for TextMessageState {
        fn decode(
            raw_message: protobuf::data_backup::TextMessageState,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
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
        fn encode(self) -> protobuf::data_backup::TextMessageState {
            protobuf::data_backup::TextMessageState {
                original_text: self.original.text,
                revisions: self
                    .revisions
                    .into_iter()
                    .map(MessageTextRevision::encode)
                    .collect(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::LocationMessageState> for LocationMessageState {
        fn decode(
            raw_message: protobuf::data_backup::LocationMessageState,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
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
                name: Self::expect_field(name, "name")?,
                address: Self::expect_field(address, "address")?,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::LocationMessageState> for LocationMessageState {
        fn encode(self) -> protobuf::data_backup::LocationMessageState {
            protobuf::data_backup::LocationMessageState {
                latitude: self.latitude,
                longitude: self.longitude,
                accuracy_m: self.accuracy_m,
                name: Some(self.name),
                address: Some(self.address),
            }
        }
    }

    #[duplicate_item(
        poll_message;
        [ PollOpen ];
        [ PollClose ];
    )]
    impl InternalBackupDecoder<protobuf::data_backup::poll_message> for poll_message {
        fn decode(
            raw_message: protobuf::data_backup::poll_message,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let protobuf::data_backup::poll_message { poll_id } = raw_message;

            Ok(Self { id: PollId(poll_id) })
        }
    }
    #[duplicate_item(
        poll_message;
        [ PollOpen ];
        [ PollClose ];
    )]
    impl InternalBackupEncoder<protobuf::data_backup::poll_message> for poll_message {
        fn encode(self) -> protobuf::data_backup::poll_message {
            protobuf::data_backup::poll_message { poll_id: self.id.0 }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::DeletedMessageState> for DeletedMessageState {
        fn decode(
            raw_message: protobuf::data_backup::DeletedMessageState,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let protobuf::data_backup::DeletedMessageState {
                previous_type,
                deleted_at,
            } = raw_message;

            Ok(Self {
                previous_message_type: match Self::parse_enum_variant(previous_type)? {
                    protobuf::data_backup::MessageStateBodyType::Text => MessageStateBodyType::Text,
                    protobuf::data_backup::MessageStateBodyType::Location => MessageStateBodyType::Location,
                    protobuf::data_backup::MessageStateBodyType::Pollopen => MessageStateBodyType::PollOpen,
                    protobuf::data_backup::MessageStateBodyType::Pollclose => MessageStateBodyType::PollClose,
                    protobuf::data_backup::MessageStateBodyType::Deleted => MessageStateBodyType::Deleted,
                },
                deleted_at,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::DeletedMessageState> for DeletedMessageState {
        fn encode(self) -> protobuf::data_backup::DeletedMessageState {
            protobuf::data_backup::DeletedMessageState {
                previous_type: self.previous_message_type as i32,
                deleted_at: self.deleted_at,
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::incoming_message_direction::MessageOverrides>
        for MessageOverrides
    {
        fn decode(
            raw_message: protobuf::data_backup::incoming_message_direction::MessageOverrides,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let protobuf::data_backup::incoming_message_direction::MessageOverrides {
                delivery_receipt_policy,
            } = raw_message;

            Ok(Self {
                delivery_receipt_policy: match Self::parse_enum_variant(delivery_receipt_policy)? {
                    protobuf_message_overrides::DeliveryReceiptPolicy::DefaultDeliveryReceiptPolicy => {
                        MessageOverridesDeliveryReceiptPolicy::Default
                    },
                    protobuf_message_overrides::DeliveryReceiptPolicy::DontSendDeliveryReceipt => {
                        MessageOverridesDeliveryReceiptPolicy::DontSend
                    },
                },
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::incoming_message_direction::MessageOverrides>
        for MessageOverrides
    {
        fn encode(self) -> protobuf::data_backup::incoming_message_direction::MessageOverrides {
            protobuf::data_backup::incoming_message_direction::MessageOverrides {
                delivery_receipt_policy: match self.delivery_receipt_policy {
                    MessageOverridesDeliveryReceiptPolicy::Default => {
                        protobuf_message_overrides::DeliveryReceiptPolicy::DefaultDeliveryReceiptPolicy
                    },
                    MessageOverridesDeliveryReceiptPolicy::DontSend => {
                        protobuf_message_overrides::DeliveryReceiptPolicy::DontSendDeliveryReceipt
                    },
                }
                .into(),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::IncomingMessageDirection> for IncomingMessageDirection {
        fn decode(
            raw_message: protobuf::data_backup::IncomingMessageDirection,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let protobuf::data_backup::IncomingMessageDirection {
                received_at,
                overrides,
            } = raw_message;

            Ok(Self {
                received_at,
                overrides: MessageOverrides::decode(Self::expect_field(overrides, "overrides")?)?,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::IncomingMessageDirection> for IncomingMessageDirection {
        fn encode(self) -> protobuf::data_backup::IncomingMessageDirection {
            protobuf::data_backup::IncomingMessageDirection {
                received_at: self.received_at,
                overrides: Some(self.overrides.encode()),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::OutgoingMessageDirection> for OutgoingMessageDirection {
        fn decode(
            raw_message: protobuf::data_backup::OutgoingMessageDirection,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let protobuf::data_backup::OutgoingMessageDirection {
                sent_at,
                delivered_at,
            } = raw_message;

            Ok(Self {
                sent_at,
                delivered_at,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::OutgoingMessageDirection> for OutgoingMessageDirection {
        fn encode(self) -> protobuf::data_backup::OutgoingMessageDirection {
            protobuf::data_backup::OutgoingMessageDirection {
                sent_at: self.sent_at,
                delivered_at: self.delivered_at,
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::MessageDirection> for MessageDirection {
        fn decode(
            raw_message: protobuf::data_backup::MessageDirection,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let protobuf::data_backup::MessageDirection { direction } = raw_message;

            Ok(match Self::expect_field(direction, "direction")? {
                protobuf::data_backup::message_direction::Direction::Incoming(incoming_message_direction) => {
                    Self::Incoming(IncomingMessageDirection::decode(incoming_message_direction)?)
                },
                protobuf::data_backup::message_direction::Direction::Outgoing(outgoing_message_direction) => {
                    Self::Outgoing(OutgoingMessageDirection::decode(outgoing_message_direction)?)
                },
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::MessageDirection> for MessageDirection {
        fn encode(self) -> protobuf::data_backup::MessageDirection {
            protobuf::data_backup::MessageDirection {
                direction: match self {
                    Self::Incoming(incoming_message_direction) => {
                        Some(protobuf::data_backup::message_direction::Direction::Incoming(
                            incoming_message_direction.encode(),
                        ))
                    },
                    Self::Outgoing(outgoing_message_direction) => {
                        Some(protobuf::data_backup::message_direction::Direction::Outgoing(
                            outgoing_message_direction.encode(),
                        ))
                    },
                },
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::MessageStateBody> for MessageStateBody {
        fn decode(
            raw_message: protobuf::data_backup::MessageStateBody,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let protobuf::data_backup::MessageStateBody { body } = raw_message;

            Ok(match Self::expect_field(body, "body")? {
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
                    Self::Deleted(DeletedMessageState::decode(deleted_message)?)
                },
            })
        }
    }

    impl InternalBackupEncoder<protobuf::data_backup::MessageStateBody> for MessageStateBody {
        fn encode(self) -> protobuf::data_backup::MessageStateBody {
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
                    Self::Deleted(deleted_message_state) => {
                        protobuf::data_backup::message_state_body::Body::Deleted(
                            deleted_message_state.encode(),
                        )
                    },
                }),
            }
        }
    }

    impl InternalBackupDecoder<protobuf::data_backup::MessageState> for MessageState {
        fn decode(
            raw_message: protobuf::data_backup::MessageState,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
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
                    conversation_id,
                    "conversation_id",
                )?)?,
                creator_identity: ThreemaId::try_from(creator_identity.as_str())?,
                message_id: MessageId(message_id),
                created_at,
                direction: MessageDirection::decode(Self::expect_field(direction, "direction")?)?,
                read_at,
                star_marker: match Self::parse_enum_variant(star_marker)? {
                    protobuf::data_backup::MessageStarMarker::NoMarker => MessageStarMarker::None,
                    protobuf::data_backup::MessageStarMarker::Star => MessageStarMarker::Star,
                },
                reactions: reactions
                    .into_iter()
                    .map(MessageReaction::decode)
                    .collect::<Result<Vec<_>, _>>()?,
                body: MessageStateBody::decode(Self::expect_field(body, "body")?)?,
            })
        }
    }
    impl InternalBackupEncoder<protobuf::data_backup::MessageState> for MessageState {
        fn encode(self) -> protobuf::data_backup::MessageState {
            protobuf::data_backup::MessageState {
                conversation_id: Some(ConversationId::encode(self.conversation_id)),
                creator_identity: self.creator_identity.to_string(),
                message_id: self.message_id.0,
                created_at: self.created_at,
                direction: Some(MessageDirection::encode(self.direction)),
                read_at: self.read_at,
                star_marker: match self.star_marker {
                    MessageStarMarker::None => protobuf::data_backup::MessageStarMarker::NoMarker,
                    MessageStarMarker::Star => protobuf::data_backup::MessageStarMarker::Star,
                }
                .into(),
                reactions: self.reactions.into_iter().map(MessageReaction::encode).collect(),
                body: Some(MessageStateBody::encode(self.body)),
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
            codec::{DataBackupDecodeErrorSource, InternalBackupDecoder, InternalBackupEncoder},
            common::UserData,
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
        fn decode(
            raw_message: user_profile::ProfilePictureShareWith,
        ) -> Result<Self, DataBackupDecodeErrorSource> {
            let user_profile::ProfilePictureShareWith { policy } = raw_message;

            Ok(match Self::expect_field(policy, "policy")? {
                user_profile::profile_picture_share_with::Policy::Nobody(_) => Self::Nobody,
                user_profile::profile_picture_share_with::Policy::Everyone(_) => Self::Everyone,
                user_profile::profile_picture_share_with::Policy::AllowList(identities) => {
                    Self::AllowList(HashSet::decode(identities)?)
                },
            })
        }
    }
    impl InternalBackupEncoder<user_profile::ProfilePictureShareWith> for ProfilePictureSharePolicy {
        fn encode(self) -> user_profile::ProfilePictureShareWith {
            let policy = match self {
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
        fn encode(self) -> user_profile::identity_links::IdentityLink {
            user_profile::identity_links::IdentityLink {
                // The protocol supports a description that is not used in the apps.
                description: String::new(),
                r#type: Some(user_profile::identity_links::identity_link::Type::Email(
                    match self {
                        Self::EmailAddress(email_address) => email_address,
                        Self::Unknown => String::new(),
                    },
                )),
            }
        }
    }
    impl InternalBackupEncoder<user_profile::identity_links::IdentityLink> for IdentityLinkPhoneNumber {
        fn encode(self) -> user_profile::identity_links::IdentityLink {
            user_profile::identity_links::IdentityLink {
                // The protocol supports a description that is not used in the apps.
                description: String::new(),
                r#type: Some(user_profile::identity_links::identity_link::Type::PhoneNumber(
                    match self {
                        Self::PhoneNumber(phone_number) => phone_number,
                        Self::Unknown => String::new(),
                    },
                )),
            }
        }
    }

    impl InternalBackupDecoder<data_backup::IdentityData> for IdentityData {
        fn decode(raw_message: data_backup::IdentityData) -> Result<Self, DataBackupDecodeErrorSource> {
            let data_backup::IdentityData {
                identity,
                ck,
                csp_server_group,
            } = raw_message;

            Ok(Self {
                user_identity: ThreemaId::try_from(identity.as_str())?,
                client_key: ClientKey::from(TryInto::<[u8; ClientKey::LENGTH]>::try_into(ck).map_err(
                    |_| {
                        DataBackupDecodeErrorSource::InvalidMessage(
                            "Client key must have 32 bytes".to_owned(),
                        )
                    },
                )?),
                csp_server_group: ChatServerGroup::try_from(csp_server_group.as_str()).map_err(|_| {
                    DataBackupDecodeErrorSource::InvalidMessage(format!("Invalid {}", ChatServerGroup::NAME))
                })?,
            })
        }
    }
    impl InternalBackupEncoder<data_backup::IdentityData> for IdentityData {
        fn encode(self) -> data_backup::IdentityData {
            data_backup::IdentityData {
                identity: self.user_identity.to_string(),
                ck: self.client_key.as_bytes().to_vec(),
                csp_server_group: self.csp_server_group.as_str().to_owned(),
            }
        }
    }

    impl InternalBackupDecoder<data_backup::UserProfile> for UserProfile {
        fn decode(raw_message: data_backup::UserProfile) -> Result<Self, DataBackupDecodeErrorSource> {
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
                } = Self::expect_field(identity_links, "identity_links")?;

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
                nickname: Self::expect_field(nickname, "nickname")?,
                profile_picture_share_policy: ProfilePictureSharePolicy::decode(Self::expect_field(
                    profile_picture_share_with,
                    "profile_picture_share_with",
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
        fn encode(self) -> data_backup::UserProfile {
            // Encode identity links.
            let identity_links = {
                let mut identity_links = Vec::new();
                if let Some(linked_email_address) = self.linked_email_address {
                    identity_links.push(linked_email_address.encode());
                }
                if let Some(linked_phone_number) = self.linked_phone_number {
                    identity_links.push(linked_phone_number.encode());
                }
                Some(user_profile::IdentityLinks {
                    links: identity_links,
                })
            };

            data_backup::UserProfile {
                nickname: Some(self.nickname),
                profile_picture: self.profile_picture.map(ProfilePicture::encode),
                profile_picture_share_with: Some(self.profile_picture_share_policy.encode()),
                identity_links,
                work_availability_status: self.work_availability_status.map(WorkAvailabilityStatus::into),
            }
        }
    }

    impl InternalBackupDecoder<d2d_sync::Settings> for Settings {
        fn decode(raw_message: d2d_sync::Settings) -> Result<Self, DataBackupDecodeErrorSource> {
            let d2d_sync::Settings {
                #[expect(deprecated, reason = "Must be handled until phased out")]
                    deprecated_contact_sync_policy: _deprecated_contact_sync_policy,

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
                unknown_contact_policy: Self::expect_and_parse_enum_variant(
                    unknown_contact_policy,
                    "unknown_contact_policy",
                )?,
                read_receipt_policy: Self::expect_and_parse_enum_variant(
                    read_receipt_policy,
                    "read_receipt_policy",
                )?,
                typing_indicator_policy: Self::expect_and_parse_enum_variant(
                    typing_indicator_policy,
                    "typing_indicator_policy",
                )?,
                o2o_call_policy: Self::expect_and_parse_enum_variant(o2o_call_policy, "o2o_call policy")?,
                o2o_call_connection_policy: Self::expect_and_parse_enum_variant(
                    o2o_call_connection_policy,
                    "o2o_call_connection_policy",
                )?,
                o2o_call_video_policy: Self::expect_and_parse_enum_variant(
                    o2o_call_video_policy,
                    "o2o_call_video_policy",
                )?,
                group_call_policy: Self::expect_and_parse_enum_variant(
                    group_call_policy,
                    "group_call_policy",
                )?,
                screenshot_policy: Self::expect_and_parse_enum_variant(
                    screenshot_policy,
                    "screenshot_policy",
                )?,
                blocked_identities: Self::expect_field(blocked_identities, "blocked_identities")?
                    .identities
                    .into_iter()
                    .map(|identity| ThreemaId::try_from(identity.as_str()))
                    .collect::<Result<_, _>>()?,

                exclude_from_sync_identities: Self::expect_field(
                    exclude_from_sync_identities,
                    "exclude_from_sync_identities",
                )?
                .identities
                .into_iter()
                .map(|identity| ThreemaId::try_from(identity.as_str()))
                .collect::<Result<_, _>>()?,
            })
        }
    }
    impl InternalBackupEncoder<d2d_sync::Settings> for Settings {
        fn encode(self) -> d2d_sync::Settings {
            d2d_sync::Settings {
                #[expect(deprecated, reason = "Must be handled until phased out")]
                deprecated_contact_sync_policy: Some(
                    d2d_sync::settings::DeprecatedContactSyncPolicy::NotSynced as i32,
                ),
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
        fn decode(raw_message: data_backup::UserData) -> Result<Self, DataBackupDecodeErrorSource> {
            let data_backup::UserData {
                identity_data,
                user_profile,
                settings,
            } = raw_message;

            Ok(Self {
                identity_data: IdentityData::decode(Self::expect_field(identity_data, "identity_data")?)?,
                user_profile: UserProfile::decode(Self::expect_field(user_profile, "user_profile")?)?,
                settings: Settings::decode(Self::expect_field(settings, "settings")?)?,
            })
        }
    }
    impl InternalBackupEncoder<data_backup::UserData> for UserData {
        fn encode(self) -> data_backup::UserData {
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
        data_backup::{
            DataBackupCreateError, DataBackupCreateInternalErrorCause, DataBackupDecodeErrorSource,
            DataBackupEncodeErrorSource, DataBackupRestoreError,
            codec::{InternalBackupDecoder, InternalBackupEncoder},
            common::UserData,
        },
        model::{
            contact::ContactWithProfilePictures, distribution_list::DistributionList,
            group::GroupWithProfilePicture, message::MessageState, poll::Poll,
        },
        protobuf,
        utils::debug::Name,
    };

    /// Decode a variable length item.
    ///
    /// Note: This trait requires that the data was already sized to the correct length and stripped of the
    /// u32 little endian length delimiter.
    pub(crate) trait ContainerDecoder: Sized {
        fn decode(bytes: &[u8]) -> Result<Self, DataBackupRestoreError>;
    }
    #[duplicate_item(
        destination_type               decoded_type                                           ;
        [ UserData                   ] [ data_backup::UserData                               ];
        [ ContactWithProfilePictures ] [ data_backup::AugmentedContact                       ];
        [ DistributionList           ] [ d2d_join::essential_data::AugmentedDistributionList ];
        [ GroupWithProfilePicture    ] [ data_backup::AugmentedGroup                         ];
        [ MessageState               ] [ data_backup::MessageState                           ];
        [ Poll                       ] [ data_backup::Poll                                   ];
    )]
    impl ContainerDecoder for destination_type {
        fn decode(bytes: &[u8]) -> Result<Self, DataBackupRestoreError> {
            InternalBackupDecoder::decode(protobuf::decoded_type::decode(bytes).map_err(|error| {
                DataBackupRestoreError::DecodingFailed {
                    name: Self::NAME,
                    source: DataBackupDecodeErrorSource::from(error),
                }
            })?)
            .map_err(|error| DataBackupRestoreError::DecodingFailed {
                name: Self::NAME,
                source: error,
            })
        }
    }

    /// Encode a variable length item, placing a u32 little endian ahead to determine the length.
    pub(crate) trait ContainerEncoder: Name {
        fn encode_u32_le_delimited(self) -> Result<Vec<u8>, DataBackupCreateError>;
    }

    #[duplicate_item(
        source_type                   ;
        [ UserData                   ];
        [ ContactWithProfilePictures ];
        [ DistributionList           ];
        [ GroupWithProfilePicture    ];
        [ MessageState               ];
        [ Poll                       ];
    )]
    impl ContainerEncoder for source_type {
        fn encode_u32_le_delimited(self) -> Result<Vec<u8>, DataBackupCreateError> {
            use crate::utils::protobuf::DelimitedMessageU32LittleEndian as _;

            InternalBackupEncoder::encode(self)
                .encode_u32_le_delimited_to_vec()
                .map_err(|_| {
                    DataBackupCreateError::InternalError(DataBackupCreateInternalErrorCause::EncodingFailed {
                        name: Self::NAME,
                        source: DataBackupEncodeErrorSource::Other("Contained data length exceeds a u32"),
                    })
                })
        }
    }
}
