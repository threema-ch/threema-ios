use core::mem;

use educe::Educe;
use libthreema_dependencies::crypto::aead::AeadInPlace as _;
use libthreema_macros::{DebugVariantNames, Name, VariantNames};
use tracing::trace;

use crate::{
    common::keys::DataBackupPageKey,
    data_backup::{
        OverflowError,
        container::Category,
        page::{DataBackupNonce, EncryptedPage, PageOffset, Position},
        task::restore::{BackupRestoreError, LocalReadInstruction},
    },
    utils::{
        bytes::{ByteReader as _, OwnedVecByteReader},
        debug::{Name as _, debug_slice_length},
    },
};

/// A decrypted page with the padding already removed.
#[derive(Name, Educe)]
#[educe(Debug)]
pub(super) struct DecryptedPage {
    #[educe(Debug(method(debug_slice_length)))]
    chunk: Vec<u8>,

    continue_at: Option<Position>,
}

impl DecryptedPage {
    pub(super) fn decode(buffer: Vec<u8>) -> Result<Self, BackupRestoreError> {
        let mut reader = OwnedVecByteReader::new(buffer);

        let chunk_length = reader
            .read_u64_le()
            .map_err(|error| BackupRestoreError::DecodingFailed {
                name: "chunk length",
                source: error.into(),
            })?
            .try_into()
            .map_err(|_| OverflowError { name: "chunk length" })?;

        let continue_at = match Position::decode(&mut reader)? {
            Position::NONE => None,
            position => Some(position),
        };

        let chunk = reader
            .read(chunk_length)
            .map_err(|error| BackupRestoreError::DecodingFailed {
                name: Self::NAME,
                source: error.into(),
            })?
            .to_vec();

        // Skip the padding and thus don't call `reader.expect_consumed()`  here.

        Ok(Self { chunk, continue_at })
    }
}

#[derive(VariantNames, DebugVariantNames)]
enum State {
    AwaitingPage(Position),
    BufferedPage(DecryptedPage),
    Done,
    Error(BackupRestoreError),
}

pub(super) enum PageReaderResult {
    Idle,
    Some(Vec<u8>),
    Final(Vec<u8>),
}

#[derive(Name, Educe)]
#[educe(Debug)]
pub(super) struct PageReader {
    #[educe(Debug(ignore))]
    page_key: DataBackupPageKey,

    state: State,
}

impl PageReader {
    pub(super) fn new(page_key: DataBackupPageKey, initial_page_position: &Position) -> Self {
        trace!(?initial_page_position, "Creating new page reader");
        Self {
            page_key,
            state: State::AwaitingPage(initial_page_position.clone()),
        }
    }

    /// Add an encrypted page to the page reader.
    ///
    /// Note: Pages will only be decrypted once [`Self::poll`] is called.
    pub(super) fn add_page(
        &mut self,
        category: Category,
        offset: PageOffset,
        encrypted_page: EncryptedPage,
    ) -> Result<(), BackupRestoreError> {
        let State::AwaitingPage(expected_position) = &self.state else {
            return Err(BackupRestoreError::InvalidState(
                "No page is expected to be added".to_owned(),
            ));
        };

        // Validate position.
        let position = Position {
            offset,
            page_size: encrypted_page.len(),
        };
        if expected_position != &position {
            return Err(BackupRestoreError::InvalidParameter("Unexpected page".to_owned()));
        }

        // Decrypt and decode page.
        let mut encrypted_page = encrypted_page.0;
        let nonce = DataBackupNonce::from_category_and_position(category, position)?;
        self.page_key
            .0
            .decrypt_in_place(&nonce.0.into(), &[], &mut encrypted_page)
            .map_err(|_| BackupRestoreError::DecryptionFailed {
                name: EncryptedPage::NAME,
            })?;
        let page = DecryptedPage::decode(encrypted_page)?;
        trace!(?page, "Decrypted page");

        self.state = State::BufferedPage(page);

        Ok(())
    }

    pub(super) fn instruction(&self) -> Result<Option<LocalReadInstruction>, BackupRestoreError> {
        match &self.state {
            State::AwaitingPage(position) => Ok(Some(LocalReadInstruction::read_page(position)?)),
            State::BufferedPage(..) | State::Done => Ok(None),
            State::Error(error) => Err(error.clone()),
        }
    }

    pub(super) fn poll(&mut self) -> Result<PageReaderResult, BackupRestoreError> {
        let result = match mem::replace(
            &mut self.state,
            State::Error(BackupRestoreError::InvalidState(format!(
                "{} in a transitional state",
                Self::NAME
            ))),
        ) {
            state @ State::AwaitingPage(_) => Ok((state, PageReaderResult::Idle)),
            State::Done => Err(BackupRestoreError::InvalidState(format!(
                "{} already done",
                Self::NAME
            ))),
            State::Error(error) => Err(error),
            State::BufferedPage(decrypted_page) => Ok(match decrypted_page.continue_at {
                Some(position) => (
                    State::AwaitingPage(position),
                    PageReaderResult::Some(decrypted_page.chunk),
                ),
                None => (State::Done, PageReaderResult::Final(decrypted_page.chunk)),
            }),
        };

        match result {
            Ok((state, instruction)) => {
                self.state = state;
                Ok(instruction)
            },
            Err(error) => {
                self.state = State::Error(error.clone());
                Err(error)
            },
        }
    }

    /// Dissolve the page reader and check that all pages have been read.
    pub(super) fn dissolve(self) -> Result<DataBackupPageKey, BackupRestoreError> {
        if matches!(self.state, State::Done) {
            Ok(self.page_key)
        } else {
            Err(BackupRestoreError::InvalidState(format!(
                "{} can only be dissolved in 'Done' state",
                Self::NAME
            )))
        }
    }
}
