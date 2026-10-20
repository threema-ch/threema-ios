//! Builder utilities for data backup tests.
//!
//! Provides builders for `Contact`, `Group`, and `DistributionList` with defaults for test data.

mod roundtrip;

use std::collections::HashSet;

use derive_builder::Builder;

use crate::{
    common::{DistributionListId, FeatureMask, GroupIdentity, ThreemaId, keys::PublicKey},
    model::{contact::Contact, distribution_list::DistributionList, group::Group},
    protobuf,
};

// ── Contact builder ──

#[derive(Builder)]
#[builder(
    pattern = "owned",
    name = "TestContactBuilder",
    build_fn(name = "build_inner")
)]
pub(crate) struct TestContact {
    #[builder(setter(into))]
    identity: ThreemaId,

    #[builder(setter(into))]
    public_key: PublicKey,

    #[builder(default = "1_000_000")]
    created_at: u64,

    #[builder(default = "None")]
    last_update_at: Option<u64>,

    #[builder(default = "String::new()")]
    first_name: String,

    #[builder(default = "String::new()")]
    last_name: String,

    #[builder(default = "String::new()")]
    nickname: String,

    #[builder(default = "protobuf::d2d_sync::contact::VerificationLevel::Unverified")]
    verification_level: protobuf::d2d_sync::contact::VerificationLevel,

    #[builder(default = "protobuf::d2d_sync::contact::WorkVerificationLevel::None")]
    work_verification_level: protobuf::d2d_sync::contact::WorkVerificationLevel,

    #[builder(default = "protobuf::d2d_sync::contact::IdentityType::Regular")]
    identity_type: protobuf::d2d_sync::contact::IdentityType,

    #[builder(default = "protobuf::d2d_sync::contact::AcquaintanceLevel::Direct")]
    acquaintance_level: protobuf::d2d_sync::contact::AcquaintanceLevel,

    #[builder(default = "protobuf::d2d_sync::contact::ActivityState::Active")]
    activity_state: protobuf::d2d_sync::contact::ActivityState,

    #[builder(default = "FeatureMask(0)")]
    feature_mask: FeatureMask,

    #[builder(default = "protobuf::d2d_sync::contact::SyncState::Initial")]
    sync_state: protobuf::d2d_sync::contact::SyncState,

    #[builder(default = "None")]
    work_last_full_sync_at: Option<u64>,

    #[builder(default = "None")]
    work_availability_status: Option<crate::work::properties::WorkAvailabilityStatus>,

    #[builder(default = "None")]
    read_receipt_policy_override: Option<protobuf::d2d_sync::ReadReceiptPolicy>,

    #[builder(default = "None")]
    typing_indicator_policy_override: Option<protobuf::d2d_sync::TypingIndicatorPolicy>,

    #[builder(default = "None")]
    notification_trigger_policy_override:
        Option<crate::model::contact::ContactNotificationTriggerPolicyOverride>,

    #[builder(default = "protobuf::d2d_sync::ConversationCategory::Default")]
    conversation_category: protobuf::d2d_sync::ConversationCategory,

    #[builder(default = "protobuf::d2d_sync::ConversationVisibility::Normal")]
    conversation_visibility: protobuf::d2d_sync::ConversationVisibility,
}
impl TestContactBuilder {
    fn build(self) -> Contact {
        let data = self.build_inner().unwrap();
        Contact {
            identity: data.identity,
            public_key: data.public_key,
            created_at: data.created_at,
            last_update_at: data.last_update_at,
            first_name: data.first_name,
            last_name: data.last_name,
            nickname: data.nickname,
            verification_level: data.verification_level,
            work_verification_level: data.work_verification_level,
            identity_type: data.identity_type,
            acquaintance_level: data.acquaintance_level,
            activity_state: data.activity_state,
            feature_mask: data.feature_mask,
            sync_state: data.sync_state,
            work_last_full_sync_at: data.work_last_full_sync_at,
            work_availability_status: data.work_availability_status,
            read_receipt_policy_override: data.read_receipt_policy_override,
            typing_indicator_policy_override: data.typing_indicator_policy_override,
            notification_trigger_policy_override: data.notification_trigger_policy_override,
            conversation_category: data.conversation_category,
            conversation_visibility: data.conversation_visibility,
        }
    }
}

pub(crate) fn minimal_contact(identity: ThreemaId, key: PublicKey) -> Contact {
    TestContactBuilder::default()
        .identity(identity)
        .public_key(key)
        .build()
}

// ── Group builder ──

#[derive(Builder)]
#[builder(pattern = "owned", name = "TestGroupBuilder", build_fn(name = "build_inner"))]
pub(crate) struct TestGroup {
    #[builder(setter(into))]
    identity: GroupIdentity,

    #[builder(default = "\"Test Group\".to_owned()")]
    name: String,

    #[builder(default = "1_000_000")]
    created_at: u64,

    #[builder(default = "None")]
    last_update_at: Option<u64>,

    #[builder(default = "protobuf::d2d_sync::group::UserState::Member")]
    user_state: protobuf::d2d_sync::group::UserState,

    #[builder(default = "HashSet::new()")]
    members: HashSet<ThreemaId>,

    #[builder(default = "None")]
    notification_trigger_policy_override: Option<crate::model::group::GroupNotificationTriggerPolicyOverride>,

    #[builder(default = "protobuf::d2d_sync::ConversationCategory::Default")]
    conversation_category: protobuf::d2d_sync::ConversationCategory,

    #[builder(default = "protobuf::d2d_sync::ConversationVisibility::Normal")]
    conversation_visibility: protobuf::d2d_sync::ConversationVisibility,
}
impl TestGroupBuilder {
    fn build(self) -> Group {
        let data = self.build_inner().unwrap();
        Group {
            identity: data.identity,
            name: data.name,
            created_at: data.created_at,
            last_update_at: data.last_update_at,
            user_state: data.user_state,
            members: data.members,
            notification_trigger_policy_override: data.notification_trigger_policy_override,
            conversation_category: data.conversation_category,
            conversation_visibility: data.conversation_visibility,
        }
    }
}

pub(crate) fn minimal_group(creator: ThreemaId, group_id: u64, members: HashSet<ThreemaId>) -> Group {
    TestGroupBuilder::default()
        .identity(GroupIdentity {
            group_id,
            creator_identity: creator,
        })
        .members(members)
        .build()
}

// ── Distribution list builder ──

#[derive(Builder)]
#[builder(
    pattern = "owned",
    name = "TestDistributionListBuilder",
    build_fn(name = "build_inner")
)]
pub(crate) struct TestDistributionList {
    #[builder(setter(into))]
    identity: DistributionListId,

    #[builder(default = "\"Test DL\".to_owned()")]
    name: String,

    #[builder(default = "1_000_000")]
    created_at: u64,

    #[builder(default = "1_000_000")]
    last_update_at: u64,

    #[builder(default = "HashSet::new()")]
    members: HashSet<ThreemaId>,

    #[builder(default = "protobuf::d2d_sync::ConversationCategory::Default")]
    conversation_category: protobuf::d2d_sync::ConversationCategory,

    #[builder(default = "protobuf::d2d_sync::ConversationVisibility::Normal")]
    conversation_visibility: protobuf::d2d_sync::ConversationVisibility,
}
impl TestDistributionListBuilder {
    fn build(self) -> DistributionList {
        let data = self.build_inner().unwrap();
        DistributionList {
            identity: data.identity,
            name: data.name,
            created_at: data.created_at,
            last_update_at: data.last_update_at,
            members: data.members,
            conversation_category: data.conversation_category,
            conversation_visibility: data.conversation_visibility,
        }
    }
}

pub(crate) fn minimal_distribution_list(id: u64, members: HashSet<ThreemaId>) -> DistributionList {
    TestDistributionListBuilder::default()
        .identity(DistributionListId(id))
        .members(members)
        .build()
}
