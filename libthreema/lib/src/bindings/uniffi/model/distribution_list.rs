//! Binding version of [`distribution_list`].
use std::{collections::HashSet, sync::Arc};

use crate::{
    bindings::uniffi::{ConversionError, common::ThreemaId},
    common::{self, DistributionListId},
    model::distribution_list,
    protobuf,
    provider::ProviderError,
};

/// Binding version of [`distribution_list::DistributionList`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct DistributionList {
    pub identity: DistributionListId,
    pub name: String,
    pub created_at: u64,
    pub last_update_at: u64,
    pub members: Vec<ThreemaId>,
    pub conversation_category: protobuf::d2d_sync::ConversationCategory,
    pub conversation_visibility: protobuf::d2d_sync::ConversationVisibility,
}
impl TryFrom<DistributionList> for distribution_list::DistributionList {
    type Error = ConversionError;

    fn try_from(distribution_list: DistributionList) -> Result<Self, Self::Error> {
        Ok(Self {
            identity: distribution_list.identity,
            name: distribution_list.name,
            created_at: distribution_list.created_at,
            last_update_at: distribution_list.last_update_at,
            members: distribution_list
                .members
                .into_iter()
                .map(common::ThreemaId::try_from)
                .collect::<Result<_, _>>()?,
            conversation_category: distribution_list.conversation_category,
            conversation_visibility: distribution_list.conversation_visibility,
        })
    }
}
impl From<distribution_list::DistributionList> for DistributionList {
    fn from(distribution_list: distribution_list::DistributionList) -> Self {
        Self {
            identity: distribution_list.identity,
            name: distribution_list.name,
            created_at: distribution_list.created_at,
            last_update_at: distribution_list.last_update_at,
            members: distribution_list
                .members
                .into_iter()
                .map(ThreemaId::from)
                .collect(),
            conversation_category: distribution_list.conversation_category,
            conversation_visibility: distribution_list.conversation_visibility,
        }
    }
}

/// Binding version of [`distribution_list::DistributionListProvider`].
#[expect(missing_docs, clippy::missing_errors_doc, reason = "Binding version")]
#[uniffi::export(with_foreign)]
pub trait DistributionListProvider: Send + Sync {
    fn add(&self, distribution_lists: Vec<DistributionList>) -> Result<(), ProviderError>;
    fn get(&self, id: DistributionListId) -> Result<Option<DistributionList>, ProviderError>;
    fn get_ids(&self) -> Result<Vec<DistributionListId>, ProviderError>;
}
impl<T: DistributionListProvider + ?Sized> distribution_list::DistributionListProvider for Arc<T> {
    fn add(
        &mut self,
        distribution_lists: Vec<distribution_list::DistributionList>,
    ) -> Result<(), ProviderError> {
        DistributionListProvider::add(
            self.as_ref(),
            distribution_lists
                .into_iter()
                .map(DistributionList::from)
                .collect(),
        )
    }

    fn get(
        &self,
        id: DistributionListId,
    ) -> Result<Option<distribution_list::DistributionList>, ProviderError> {
        DistributionListProvider::get(self.as_ref(), id)?
            .map(|distribution_list| Ok(distribution_list::DistributionList::try_from(distribution_list)?))
            .transpose()
    }

    fn get_ids(&self) -> Result<HashSet<DistributionListId>, ProviderError> {
        Ok(DistributionListProvider::get_ids(self.as_ref())?
            .into_iter()
            .collect())
    }
}
