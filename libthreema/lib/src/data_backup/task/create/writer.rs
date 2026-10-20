use libthreema_macros::Name;

use crate::{
    common::keys::DataBackupPageKey,
    data_backup::{
        DataBackupCreateInternalErrorCause, DataBackupEncodeErrorSource,
        cipher::{PageEncryptor, PageNumber},
        common::{Category, Offset, Page, PageLength},
    },
    utils::{
        bytes::{ByteWriter as _, ByteWriterError, OwnedVecByteWriter},
        debug::Name as _,
    },
};

/// Checkpoint to construct a new/subsequent [`PageWriter`] from.
pub(super) struct PageWriterCheckpoint {
    pub(super) key: DataBackupPageKey,
    pub(super) offset: Offset,
}

/// Buffers incoming page data to create encrypted pages from it.
#[derive(Name)]
pub(super) struct PageWriter {
    length: PageLength,
    encryptor: PageEncryptor,
    number: PageNumber,
    offset: Offset,
    data: Vec<u8>,
}
impl PageWriter {
    pub(super) fn new(checkpoint: PageWriterCheckpoint, category: Category) -> Self {
        let length = category.page_length();
        Self {
            length,
            encryptor: PageEncryptor::new(checkpoint.key, category),
            number: PageNumber::new(),
            offset: checkpoint.offset,
            data: Vec::with_capacity(length.length as usize),
        }
    }

    /// Return the buffered amount of bytes contained in the writer.
    ///
    /// Note: This is the raw amount of page data, ignoring any overhead from encoding and encrypting pages.
    #[inline]
    pub(super) fn buffered_length(&self) -> usize {
        self.data.len()
    }

    /// Add page data to the writer's buffer.
    #[inline]
    pub(super) fn add_data(&mut self, data: &[u8]) {
        self.data.extend_from_slice(data);
    }

    #[inline]
    fn encode_and_encrypt_page(
        length: PageLength,
        encryptor: &PageEncryptor,
        number: &mut PageNumber,
        offset: &mut Offset,
        data: &[u8],
    ) -> Result<Vec<u8>, DataBackupCreateInternalErrorCause> {
        // Encode the page.
        let encoded_page = Page::encode(length, data)?;

        // Encrypt the page.
        //
        // Note: If the encryption fails, we already have increased the internal page number. But the caller
        // is not expected to continue using the writer in case of errors anyways.
        let encrypted_page = encryptor.encrypt(number, encoded_page)?;

        // Update the offset.
        offset
            .add(encrypted_page.len())
            .ok_or_else(|| DataBackupCreateInternalErrorCause::from("Resulting page offset exceeds u64"))?;

        Ok(encrypted_page)
    }

    fn next_complete(&mut self) -> Result<Option<Vec<u8>>, DataBackupCreateInternalErrorCause> {
        // Get the next correctly sized page, if sufficient bytes are available.
        let length = self.length.length as usize;
        if self.data.len() < length {
            return Ok(None);
        }
        let content = self.data.drain(..length);

        // Encode and encrypt the page.
        Ok(Some(Self::encode_and_encrypt_page(
            self.length,
            &self.encryptor,
            &mut self.number,
            &mut self.offset,
            content.as_slice(),
        )?))
    }

    /// Encode and encrypt all available complete pages.
    pub(super) fn drain_complete(&mut self) -> Result<Vec<u8>, DataBackupCreateInternalErrorCause> {
        // Write all complete pages.
        let mut writer = OwnedVecByteWriter::new_empty();
        while let Some(page) = self.next_complete()? {
            writer
                .write(&page)
                .map_err(|error| DataBackupCreateInternalErrorCause::EncodingFailed {
                    name: Self::NAME,
                    source: DataBackupEncodeErrorSource::from(error),
                })?;
        }
        Ok(writer.into_inner())
    }

    /// Dissolve, encoding and encrypting all remaining pages, padding any excess bytes.
    pub(super) fn drain_all(
        mut self,
    ) -> Result<(Vec<u8>, PageWriterCheckpoint), DataBackupCreateInternalErrorCause> {
        let mut writer = OwnedVecByteWriter::new_empty();
        let encoding_failed = |error: ByteWriterError| DataBackupCreateInternalErrorCause::EncodingFailed {
            name: Self::NAME,
            source: DataBackupEncodeErrorSource::from(error),
        };

        // Write all complete pages.
        while let Some(page) = self.next_complete()? {
            writer.write(&page).map_err(encoding_failed)?;
        }

        // Write the last (incomplete) page, if any bytes are available.
        if !self.data.is_empty() {
            let page = Self::encode_and_encrypt_page(
                self.length,
                &self.encryptor,
                &mut self.number,
                &mut self.offset,
                &self.data,
            )?;
            writer.write(&page).map_err(encoding_failed)?;
        }

        Ok((
            writer.into_inner(),
            PageWriterCheckpoint {
                key: self.encryptor.dissolve(),
                offset: self.offset,
            },
        ))
    }
}
