use std::collections::HashMap;

use educe::Educe;
use libthreema_dependencies::crypto::aead::AeadInPlace as _;
use libthreema_macros::Name;
use tracing::{debug, error, trace};

use crate::{
    common::keys::DataBackupPageKey,
    data_backup::{
        OverflowError,
        container::Category,
        metadata::{LayoutV1, LayoutV1Builder},
        page::{DataBackupNonce, EncryptedPage, Page, PageOffset, Position},
        task::create::{BackupCreateError, InternalErrorCause, LocalWriteInstruction, WrittenBytes},
    },
    utils::{
        bytes::{ByteWriter as _, OwnedVecByteWriter},
        debug::{Name as _, debug_collection_length},
    },
};

#[derive(Name)]
pub(super) struct FilledPage {
    category: Category,
    offset: PageOffset,
    chunk: Vec<u8>,
    padding_length: usize,
}

impl FilledPage {
    fn encode_and_encrypt(
        self,
        page_key: &mut DataBackupPageKey,
        continue_at: Option<Position>,
    ) -> Result<EncryptedPage, InternalErrorCause> {
        let mut encoded_page = {
            Page {
                continue_at,
                chunk: self.chunk,
                padding_length: self.padding_length,
            }
            .encode()?
        };

        let encrypted_page = {
            let nonce = DataBackupNonce::from_category_and_offset(self.category, self.offset)?;
            page_key
                .0
                .encrypt_in_place(&nonce.0.into(), &[], &mut encoded_page)
                .map_err(|_| InternalErrorCause::EncryptionFailed { name: Self::NAME })?;

            EncryptedPage(encoded_page)
        };

        Ok(encrypted_page)
    }
}

pub(super) struct AllocatedPage {
    offset: PageOffset,
    category: Category,
}

impl AllocatedPage {
    pub(super) fn fill(self, chunk: Vec<u8>) -> Result<FilledPage, InternalErrorCause> {
        let padding_length =
            self.category
                .page_capacity()
                .checked_sub(chunk.len())
                .ok_or(InternalErrorCause::Other(
                    "Chunk is larger than page capacity".to_owned(),
                ))?;

        Ok(FilledPage {
            offset: self.offset,
            category: self.category,
            chunk,
            padding_length,
        })
    }
}

#[derive(Educe, Name)]
#[educe(Debug)]
pub(super) struct PageWriter {
    allocation_offset: PageOffset,

    writing_offset: PageOffset,

    #[educe(Debug(method(debug_collection_length)))]
    pending_page_writes: HashMap<PageOffset, EncryptedPage>,

    #[educe(Debug(ignore))]
    page_key: DataBackupPageKey,

    #[educe(Debug(ignore))]
    layout_builder: LayoutV1Builder,
}

impl PageWriter {
    pub(super) fn new(page_key: DataBackupPageKey) -> Self {
        Self {
            allocation_offset: PageOffset(0),
            writing_offset: PageOffset(0),
            pending_page_writes: HashMap::new(),
            page_key,
            layout_builder: LayoutV1Builder::default(),
        }
    }

    /// Allocate the first page of the given `category`.
    pub(super) fn allocate_first(&mut self, category: Category) -> Result<AllocatedPage, InternalErrorCause> {
        trace!(allocation_offset = ?self.allocation_offset, "Allocating first page.");
        let allocated_page = self.allocate(category)?;

        // Set the start of the category in the layout builder.
        let start = Position {
            offset: allocated_page.offset,
            page_size: category.encrypted_page_size(),
        };
        self.layout_builder.set(category, start);

        Ok(allocated_page)
    }

    /// Add a page and directly allocate the next page *of the same category*.
    pub(super) fn add_and_allocate_next(
        &mut self,
        page: FilledPage,
    ) -> Result<AllocatedPage, BackupCreateError> {
        trace!(allocation_offset = ?self.allocation_offset, page_offset = ?page.offset, "Add page and allocate next one");

        // Allocate the next page and store the reference it from the current page.
        let next_page = self.allocate(page.category)?;
        let continue_at = Some(Position {
            offset: next_page.offset,
            page_size: page.category.encrypted_page_size(),
        });

        // Encrypt the page and add it to pending pages.
        let offset = page.offset;
        let encrypted_page = page.encode_and_encrypt(&mut self.page_key, continue_at)?;
        let _ = self.pending_page_writes.insert(offset, encrypted_page);

        // Return the next allocated page.
        Ok(next_page)
    }

    /// Allocate a page of the given category.
    fn allocate(&mut self, category: Category) -> Result<AllocatedPage, InternalErrorCause> {
        // The allocated page starts at the current allocation offset...
        let offset = self.allocation_offset;

        // ... and ends after its encrypted page size.
        self.allocation_offset
            .try_increment(category.encrypted_page_size())?;

        Ok(AllocatedPage { offset, category })
    }

    /// Add the final page of its category (i.e., without allocating a new page).
    pub(super) fn add_final(&mut self, page: FilledPage) -> Result<(), BackupCreateError> {
        trace!(offset = ?page.offset, category = page.category.variant_name(),  "Adding final page");

        let offset = page.offset;
        let encrypted_page = page.encode_and_encrypt(&mut self.page_key, None)?;
        let _ = self.pending_page_writes.insert(offset, encrypted_page);

        Ok(())
    }

    pub(super) fn writable_buffer_below_maximal_append_length(&self) -> Result<bool, InternalErrorCause> {
        let initial_offset = self.writing_offset.0;
        let mut offset = self.writing_offset;

        while let Some(next_page) = self.pending_page_writes.get(&offset) {
            offset.try_increment(next_page.len())?;
        }

        Ok(offset
            .0
            .checked_sub(initial_offset)
            .expect("offset must be bigger than initial offset")
            < LocalWriteInstruction::MAX_APPEND_LENGTH)
    }

    /// Return all bytes that can be appended to the memory.
    ///
    /// Note, this ensures that the number of bytes to be appended is not larger than
    /// [`StorageInstruction::MAX_APPEND_LENGTH`].
    pub(super) fn write_pending(&mut self) -> Result<Option<LocalWriteInstruction>, InternalErrorCause> {
        trace!("Writing pending pages");
        let mut writer = OwnedVecByteWriter::new_with_capacity(LocalWriteInstruction::MAX_APPEND_LENGTH);

        while let Some(next_page) = self.pending_page_writes.get(&self.writing_offset)
            && writer
                .offset()
                .checked_add(next_page.len().0)
                .ok_or(OverflowError {
                    name: "writer offset",
                })?
                < LocalWriteInstruction::MAX_APPEND_LENGTH
        {
            let next_page = self
                .pending_page_writes
                .remove(&self.writing_offset)
                .expect("Previously queried page must exist");
            trace!(offset = ?self.writing_offset, "Writing page");
            self.writing_offset.try_increment(next_page.len())?;
            next_page
                .encode_into(&mut writer)
                .map_err(|error| InternalErrorCause::EncodingFailed {
                    name: EncryptedPage::NAME,
                    source: error.into(),
                })?;
        }

        let instruction = {
            let data = writer.into_inner();
            if data.is_empty() {
                None
            } else {
                Some(LocalWriteInstruction::Append(data))
            }
        };
        Ok(instruction)
    }

    /// IMPORTANT: The caller must ensure that all pending pages have been written by repeatedly calling
    /// [`Self::write_pending()`] until [`None`] is returned.
    pub(super) fn finalize(self) -> Result<(LayoutV1, WrittenBytes), BackupCreateError> {
        debug!("Finalizing {}", Self::NAME);

        if !self.pending_page_writes.is_empty() {
            let message = "Pending page writes should be empty";
            error!(?self, pending = ?self.pending_page_writes.keys(), message);
            return Err(BackupCreateError::InvalidState(message.to_owned()));
        }

        let layout = self
            .layout_builder
            .build()
            .map_err(|error| InternalErrorCause::from(error.to_string()))?;

        Ok((layout, WrittenBytes(self.allocation_offset.0)))
    }
}
