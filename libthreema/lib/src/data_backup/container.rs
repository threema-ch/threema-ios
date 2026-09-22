use duplicate::duplicate_item;
use libthreema_macros::{DebugVariantNames, Name, VariantNames};

use crate::{
    common::HashedNonce,
    data_backup::page::{EncryptedPageSize, Page},
    model::{
        contact::ContactWithProfilePictures,
        distribution_list::DistributionList,
        group::GroupWithProfilePicture,
        message::MessageState,
        poll::Poll,
        settings::Settings,
        user_profile::{IdentityData, UserProfile},
    },
};

#[derive(Debug, Name)]
pub(super) struct UserData {
    pub(super) identity_data: IdentityData,
    pub(super) user_profile: UserProfile,
    pub(super) settings: Settings,
}

#[derive(Name)]
pub(super) struct UserDataContainer(pub(super) UserData);

#[derive(Name)]
pub(super) struct ContactContainer(pub(super) ContactWithProfilePictures);

#[derive(Name)]
pub(super) struct DistributionListContainer(pub(super) DistributionList);

#[derive(Name)]
pub(super) struct GroupContainer(pub(super) GroupWithProfilePicture);

#[derive(Name)]
pub(super) struct HashedCspNonceContainer(pub(super) HashedNonce);

#[derive(Name)]
pub(super) struct HashedD2mNonceContainer(pub(super) HashedNonce);

#[derive(Name)]
pub(super) struct PollContainer(pub(super) Poll);

#[derive(Name)]
pub(super) struct MessageContainer(pub(super) MessageState);

/// Category of a data backup container, used to determine the page layout and nonce derivation.
#[derive(Clone, Copy, VariantNames, DebugVariantNames)]
#[repr(u8)]
pub(super) enum Category {
    UserData = 0,
    Contacts = 1,
    DistributionLists = 2,
    Groups = 3,
    HashedCspNonces = 4,
    HashedD2mNonces = 5,
    Poll = 6,
    #[expect(dead_code, reason = "TODO(LIB-111): Backup file messages")]
    Blob = 7,
    Message = 8,
}
impl Category {
    /// Return the maximum number of unencrypted bytes that a single page of this category can hold.
    #[inline]
    pub(super) const fn page_capacity(self) -> usize {
        // TODO(LIB-120): Fine-tune performance
        match self {
            Self::UserData
            | Self::Contacts
            | Self::DistributionLists
            | Self::Groups
            | Self::HashedCspNonces
            | Self::HashedD2mNonces
            | Self::Poll
            | Self::Message
            | Self::Blob => 1024 * 1024,
        }
    }

    #[inline]
    pub(super) const fn encrypted_page_size(self) -> EncryptedPageSize {
        EncryptedPageSize(
            self.page_capacity()
                .checked_add(Page::ENCODING_OVERHEAD)
                .expect("capacity + encoding overhead must fit usize")
                .checked_add(Page::ENCRYPTION_OVERHEAD)
                .expect("capacity + encoding overhead + encryption_overhead must fit usize"),
        )
    }
}

pub(super) trait ContainerCategory {
    const CATEGORY: Category;
}

#[duplicate_item(
    container                        category                      ;
    [ UserDataContainer          ] [ Category::UserData           ];
    [ ContactContainer           ] [ Category::Contacts           ];
    [ DistributionListContainer  ] [ Category::DistributionLists  ];
    [ GroupContainer             ] [ Category::Groups             ];
    [ HashedCspNonceContainer    ] [ Category::HashedCspNonces    ];
    [ HashedD2mNonceContainer    ] [ Category::HashedD2mNonces    ];
    [ PollContainer              ] [ Category::Poll               ];
    [ MessageContainer           ] [ Category::Message            ];
)]
impl ContainerCategory for container {
    const CATEGORY: Category = category;
}
