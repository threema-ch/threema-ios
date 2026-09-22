use core::convert::TryInto;

use libthreema_dependencies::crypto::chacha20;
use libthreema_macros::{Name, concat_fixed_bytes};

use crate::{
    data_backup::{
        OverflowError, StreamOffset,
        container::Category,
        metadata::METADATA_LENGTH,
        task::{create, restore::BackupRestoreError},
    },
    utils::{
        bytes::{ByteReader as _, ByteWriter, ByteWriterError, OwnedVecByteReader, OwnedVecByteWriter},
        debug::Name as _,
    },
};

#[derive(Copy, Clone, Debug, Eq, Hash, Name, PartialEq, PartialOrd)]
pub(super) struct PageOffset(pub(super) usize);
impl PageOffset {
    const LENGTH: usize = 8;

    #[inline]
    pub(super) fn try_increment(
        &mut self,
        increment: EncryptedPageSize,
    ) -> Result<(), create::InternalErrorCause> {
        self.0 = self
            .0
            .checked_add(increment.0)
            .ok_or(OverflowError { name: Self::NAME })?;
        Ok(())
    }

    #[inline]
    pub(super) fn encode(self) -> Result<[u8; Self::LENGTH], OverflowError> {
        Ok(u64::try_from(self.0)
            .map_err(|_| OverflowError { name: Self::NAME })?
            .to_le_bytes())
    }

    #[inline]
    pub(super) fn decode(reader: &mut OwnedVecByteReader) -> Result<Self, BackupRestoreError> {
        Ok(Self(
            reader
                .read_u64_le()
                .map_err(|error| BackupRestoreError::DecodingFailed {
                    name: Self::NAME,
                    source: error.into(),
                })?
                .try_into()
                .map_err(|_| OverflowError { name: Self::NAME })?,
        ))
    }
}
impl TryFrom<PageOffset> for StreamOffset {
    type Error = OverflowError;

    #[inline]
    fn try_from(page_offset: PageOffset) -> Result<Self, Self::Error> {
        Ok(Self(
            page_offset
                .0
                .checked_add(METADATA_LENGTH)
                .ok_or(OverflowError { name: Self::NAME })?,
        ))
    }
}
impl core::fmt::Display for PageOffset {
    fn fmt(&self, formatter: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        write!(formatter, "{}({})", Self::NAME, self.0)
    }
}

/// The number of bytes of an encrypted page.
#[derive(Copy, Clone, Debug, Name, Hash, PartialEq, Eq)]
pub(super) struct EncryptedPageSize(pub(super) usize);
impl EncryptedPageSize {
    const LENGTH: usize = 8;

    #[inline]
    pub(super) fn encode(self) -> Result<[u8; Self::LENGTH], OverflowError> {
        Ok(TryInto::<u64>::try_into(self.0)
            .map_err(|_| OverflowError { name: Self::NAME })?
            .to_le_bytes())
    }

    #[inline]
    pub(super) fn decode(reader: &mut OwnedVecByteReader) -> Result<Self, BackupRestoreError> {
        Ok(Self(
            reader
                .read_u64_le()
                .map_err(|error| BackupRestoreError::DecodingFailed {
                    name: Self::NAME,
                    source: error.into(),
                })?
                .try_into()
                .map_err(|_| OverflowError { name: Self::NAME })?,
        ))
    }
}
impl core::fmt::Display for EncryptedPageSize {
    fn fmt(&self, formatter: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        write!(formatter, "{}", self.0)
    }
}

#[derive(Debug, Clone, Hash, PartialEq, Eq)]
pub(super) struct Position {
    pub(super) offset: PageOffset,
    pub(super) page_size: EncryptedPageSize,
}
impl Position {
    pub(super) const LENGTH: usize = PageOffset::LENGTH + EncryptedPageSize::LENGTH;
    pub(super) const NONE: Self = Self {
        offset: PageOffset(0),
        page_size: EncryptedPageSize(0),
    };

    #[inline]
    pub(super) fn encode(self) -> Result<[u8; Self::LENGTH], OverflowError> {
        Ok(concat_fixed_bytes!(
            self.offset.encode()?,
            self.page_size.encode()?,
        ))
    }

    #[inline]
    pub(super) fn decode(reader: &mut OwnedVecByteReader) -> Result<Self, BackupRestoreError> {
        Ok(Self {
            offset: PageOffset::decode(reader)?,
            page_size: EncryptedPageSize::decode(reader)?,
        })
    }
}

pub(super) struct DataBackupNonce(pub(super) [u8; chacha20::NONCE_LENGTH]);
impl DataBackupNonce {
    #[inline]
    pub(super) fn from_category_and_offset(
        category: Category,
        offset: PageOffset,
    ) -> Result<Self, OverflowError> {
        Self::from_category_and_position(
            category,
            Position {
                offset,
                page_size: category.encrypted_page_size(),
            },
        )
    }

    #[inline]
    pub(super) fn from_category_and_position(
        category: Category,
        position: Position,
    ) -> Result<Self, OverflowError> {
        Ok(Self(concat_fixed_bytes!(
            [0; 7],
            [category as u8],
            position.encode()?
        )))
    }
}

#[derive(Name)]
pub(super) struct Page {
    pub(super) continue_at: Option<Position>,
    pub(super) chunk: Vec<u8>,
    pub(super) padding_length: usize,
}
impl Page {
    pub(super) const ENCODING_OVERHEAD: usize = 8 /* chunk length */ + Position::LENGTH;
    pub(super) const ENCRYPTION_OVERHEAD: usize = chacha20::TAG_LENGTH;

    /// Encode into the following memory layout:
    /// - `chunk_length`: `u64`
    /// - `continue_at`: `Position::LENGTH`
    /// - `chunk`: `b{chunk_length}`
    /// - `padding`: `b{category.page_capacity - chunk_length}`
    pub(super) fn encode(self) -> Result<Vec<u8>, create::InternalErrorCause> {
        let chunk_length: u64 = self
            .chunk
            .len()
            .try_into()
            .map_err(|_| OverflowError { name: "chunk length" })?;
        let continue_at = self.continue_at.unwrap_or(Position::NONE).encode()?;

        let mut writer = OwnedVecByteWriter::new_with_capacity(
            self.chunk
                .len()
                .saturating_add(Self::ENCODING_OVERHEAD)
                .saturating_add(self.padding_length),
        );
        writer
            .run(|writer| {
                writer.write_u64_le(chunk_length)?;
                writer.write(&continue_at)?;
                writer.write(&self.chunk)?;
                writer.write(&vec![0; self.padding_length])
            })
            .map_err(|error| create::InternalErrorCause::EncodingFailed {
                name: Self::NAME,
                source: error.into(),
            })?;

        Ok(writer.into_inner())
    }
}

/// An encrypted and authenticated backup page ready to be written to the backup stream.
#[derive(Name)]
pub(super) struct EncryptedPage(pub(super) Vec<u8>);
impl EncryptedPage {
    #[inline]
    pub(super) fn len(&self) -> EncryptedPageSize {
        EncryptedPageSize(self.0.len())
    }

    #[inline]
    pub(super) fn encode_into(self, writer: &mut impl ByteWriter) -> Result<(), ByteWriterError> {
        writer.write(&self.0)
    }
}
