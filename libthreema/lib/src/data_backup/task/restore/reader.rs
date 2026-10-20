use crate::{
    common::keys::DataBackupPageKey,
    data_backup::{
        DataBackupRestoreError, DataBackupRestoreInternalErrorCause, TARGET_INSTRUCTION_BUFFER_LENGTH,
        cipher::{PageDecryptor, PageNumber},
        common::{Category, CategorySpan, Offset, Page},
    },
    utils::frame::{FixedLengthFrameDecoder, FrameDelimiter, VariableLengthFrameDecoder},
};

/// Buffers a stream of data from decrypted and decoded pages for subsequent processing.
pub(super) trait PageDataBuffer {
    /// Add page data to the buffer.
    fn add_data(&mut self, data: &[u8]);
}
impl<const LENGTH: usize> PageDataBuffer for FixedLengthFrameDecoder<LENGTH> {
    fn add_data(&mut self, data: &[u8]) {
        let _ = self.add_chunks(&[data]);
    }
}
impl<const DELIMITER_LENGTH: usize, TDelimiter: FrameDelimiter<DELIMITER_LENGTH>> PageDataBuffer
    for VariableLengthFrameDecoder<DELIMITER_LENGTH, TDelimiter>
{
    fn add_data(&mut self, data: &[u8]) {
        let _ = self.add_chunks(&[data]);
    }
}

/// Checkpoint to construct a new/subsequent [`PageReader`] from.
pub(super) struct PageReaderCheckpoint {
    pub(super) key: DataBackupPageKey,
}

/// A batch span of encrypted pages to feed into the reader.
///
/// Note: The contained length must be `N * length-with-overhead` with `N >= 1`.
pub(super) struct PageBatch {
    pub(super) offset: Offset,
    pub(super) length: u32,
}

/// Buffers incoming encrypted pages to decrypt page data from it.
pub(super) struct PageReader<TBuffer: PageDataBuffer> {
    decryptor: PageDecryptor,
    number: PageNumber,
    span: CategorySpan,
    buffer: TBuffer,
    max_batch_length: u32,
}
impl<TBuffer: PageDataBuffer> PageReader<TBuffer> {
    pub(super) fn new(
        checkpoint: PageReaderCheckpoint,
        category: Category,
        span: CategorySpan,
        buffer: TBuffer,
    ) -> Result<Self, DataBackupRestoreInternalErrorCause> {
        // Compute the largest multiple of page length (with overhead) that fits into the target instruction
        // buffer length, but never less than a single page, so a batch is never zero.
        let max_batch_length = {
            let length_with_overhead = span.page_length.length_with_overhead;
            TARGET_INSTRUCTION_BUFFER_LENGTH
                .checked_rem(length_with_overhead)
                .and_then(|remainder| TARGET_INSTRUCTION_BUFFER_LENGTH.checked_sub(remainder))
                .ok_or_else(|| {
                    DataBackupRestoreInternalErrorCause::Other("Computed batch length overflowed".to_owned())
                })?
                .max(length_with_overhead)
        };
        Ok(Self {
            decryptor: PageDecryptor::new(checkpoint.key, category),
            number: PageNumber::new(),
            span,
            buffer,
            max_batch_length,
        })
    }

    /// Hand out the underlying buffer implementation for draining / post-processing of the page data buffer.
    #[inline]
    pub(super) fn buffer(&mut self) -> &mut TBuffer {
        &mut self.buffer
    }

    /// Request the next batch of pages, or [`None`] if the page category has been read into the buffer
    /// completely.
    #[inline]
    pub(super) fn next_batch(&self) -> Result<Option<PageBatch>, DataBackupRestoreError> {
        let remaining_length = self.span.length().ok_or_else(|| {
            DataBackupRestoreError::InternalError(DataBackupRestoreInternalErrorCause::Other(format!(
                "Invalid category span {:?}",
                self.span
            )))
        })?;
        if remaining_length == 0 {
            return Ok(None);
        }
        Ok(Some(PageBatch {
            offset: self.span.start,
            length: remaining_length.min(self.max_batch_length),
        }))
    }

    /// Add an encrypted page by decrypting and decoding it into the reader's buffer.
    pub(super) fn add_pages(
        &mut self,
        offset: Offset,
        encrypted_pages: &[u8],
    ) -> Result<(), DataBackupRestoreError> {
        // Validate offset.
        if offset != self.span.start {
            return Err(DataBackupRestoreError::ContractViolation(format!(
                "Unexpected page at offset {offset}, expected {}",
                self.span.start
            )));
        }

        // Drain all encrypted pages.
        for encrypted_page in encrypted_pages.chunks(self.span.page_length.length_with_overhead as usize) {
            // Check if there are still expected pages.
            if self.span.is_empty() {
                return Err(DataBackupRestoreError::ContractViolation(
                    "Unexpected page after the page category was fully read".to_owned(),
                ));
            }

            // Decrypt and decode page.
            //
            // Note: Decoding implicitly validates the length of the page, so we can skip doing this.
            let page = Page::decode(
                self.span.page_length,
                self.decryptor
                    .decrypt(&mut self.number, encrypted_page.to_vec())?,
            )?;

            // Update the offset and add the page data to the buffer.
            self.span
                .start
                .add(self.span.page_length.length_with_overhead as usize)
                .ok_or_else(|| {
                    DataBackupRestoreError::InternalError(DataBackupRestoreInternalErrorCause::Other(
                        "Resulting page offset exceeds u64".to_owned(),
                    ))
                })?;
            self.buffer.add_data(&page);
        }
        Ok(())
    }

    /// Expect the reader to have consumed all pages.
    #[inline]
    pub(super) fn expect_consumed(self) -> Result<PageReaderCheckpoint, DataBackupRestoreError> {
        if !self.span.is_empty() {
            return Err(DataBackupRestoreError::InternalError(
                DataBackupRestoreInternalErrorCause::Other(format!(
                    "Pages left over to read, {:?}",
                    self.span
                )),
            ));
        }
        Ok(PageReaderCheckpoint {
            key: self.decryptor.dissolve(),
        })
    }
}
