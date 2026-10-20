//! Ciphers for the data backup.
use libthreema_dependencies::crypto::{aead::AeadInPlace as _, chacha20};
use libthreema_macros::concat_fixed_bytes;

use crate::{
    common::keys::{DataBackupLayoutKey, DataBackupPageKey},
    data_backup::{
        DataBackupCreateError, DataBackupCreateInternalErrorCause, DataBackupRestoreError,
        common::{Category, HeaderBytes, Layout, LayoutEncrypted, Page},
    },
    utils::{
        debug::Name as _,
        sequence_numbers::{SequenceNumberOverflow, SequenceNumberU32},
    },
};

/// Nonce used to encrypt the layout.
///
/// This must only be used in combination with the [`DataBackupLayoutKey`].
///
/// Note: This is fine to be all-zero since it's exactly used once per layout key. The [`LAYOUT_NONCE`] cannot
/// overlap with a [`PageNonce`] because they are used with a different key.
const LAYOUT_NONCE: [u8; chacha20::STANDARD_NONCE_LENGTH] = [0; chacha20::STANDARD_NONCE_LENGTH];

pub(super) struct LayoutEncryptor(DataBackupLayoutKey);
impl LayoutEncryptor {
    #[inline]
    pub(super) fn new(key: DataBackupLayoutKey) -> Self {
        Self(key)
    }

    pub(super) fn encrypt(
        self,
        header: &HeaderBytes,
        layout: [u8; Layout::LENGTH],
    ) -> Result<LayoutEncrypted, DataBackupCreateError> {
        let mut layout = layout.to_vec();
        self.0
            .0
            .encrypt_in_place(&LAYOUT_NONCE.into(), &header.0, &mut layout)
            .map_err(|_| DataBackupCreateInternalErrorCause::EncryptionFailed { name: Layout::NAME })?;
        Ok(LayoutEncrypted(
            layout.try_into().expect("Encrypted layout length is fixed"),
        ))
    }
}

pub(super) struct LayoutDecryptor(DataBackupLayoutKey);
impl LayoutDecryptor {
    #[inline]
    pub(super) fn new(key: DataBackupLayoutKey) -> Self {
        Self(key)
    }

    #[expect(clippy::needless_pass_by_value, reason = "Prevent reuse")]
    pub(super) fn decrypt(
        self,
        header: HeaderBytes,
        layout: LayoutEncrypted,
    ) -> Result<Vec<u8>, DataBackupRestoreError> {
        let mut layout = layout.0.to_vec();
        self.0
            .0
            .decrypt_in_place(&LAYOUT_NONCE.into(), &header.0, &mut layout)
            .map_err(|_| DataBackupRestoreError::DecryptionFailed { name: Layout::NAME })?;
        Ok(layout)
    }
}

/// Page number, incremented for each page within a category.
pub(super) struct PageNumber(SequenceNumberU32);
impl PageNumber {
    pub(super) fn new() -> Self {
        Self(SequenceNumberU32::new(0))
    }
}

/// Nonce used to encrypt a page.
///
/// IMPORTANT: This must only be used in combination with a [`DataBackupPageKey`].
pub(super) struct PageNonce([u8; chacha20::STANDARD_NONCE_LENGTH]);
impl PageNonce {
    #[inline]
    pub(super) fn new(category: Category, number: &mut PageNumber) -> Result<Self, SequenceNumberOverflow> {
        let category = category as u64;
        let number = number.0.get_and_increment()?.0;
        Ok(Self(concat_fixed_bytes!(
            category.to_le_bytes(),
            number.to_le_bytes()
        )))
    }
}

pub(super) struct PageEncryptor {
    key: DataBackupPageKey,
    category: Category,
}
impl PageEncryptor {
    #[inline]
    pub(super) fn new(key: DataBackupPageKey, category: Category) -> Self {
        Self { key, category }
    }

    pub(super) fn encrypt(
        &self,
        number: &mut PageNumber,
        mut page: Vec<u8>,
    ) -> Result<Vec<u8>, DataBackupCreateInternalErrorCause> {
        let nonce = PageNonce::new(self.category, number)?;
        self.key
            .0
            .encrypt_in_place(&nonce.0.into(), &[], &mut page)
            .map_err(|_| DataBackupCreateInternalErrorCause::EncryptionFailed { name: Page::NAME })?;
        Ok(page)
    }

    #[inline]
    pub(super) fn dissolve(self) -> DataBackupPageKey {
        self.key
    }
}

pub(super) struct PageDecryptor {
    key: DataBackupPageKey,
    category: Category,
}
impl PageDecryptor {
    #[inline]
    pub(super) fn new(key: DataBackupPageKey, category: Category) -> Self {
        Self { key, category }
    }

    pub(super) fn decrypt(
        &self,
        number: &mut PageNumber,
        mut page: Vec<u8>,
    ) -> Result<Vec<u8>, DataBackupRestoreError> {
        let nonce = PageNonce::new(self.category, number).map_err(|error| {
            DataBackupRestoreError::DecodingFailed {
                name: Page::NAME,
                source: error.into(),
            }
        })?;
        self.key
            .0
            .decrypt_in_place(&nonce.0.into(), &[], &mut page)
            .map_err(|_| DataBackupRestoreError::DecryptionFailed { name: Page::NAME })?;
        Ok(page)
    }

    #[inline]
    pub(super) fn dissolve(self) -> DataBackupPageKey {
        self.key
    }
}
