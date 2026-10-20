use core::fmt;

use arrayref::array_refs;
use derive_builder::Builder;
use educe::Educe;
use libthreema_dependencies::crypto::chacha20;
use libthreema_macros::{Name, VariantNames, concat_fixed_bytes};

use crate::{
    common::{StreamOffset, keys::DataBackupSalt},
    data_backup::{
        DataBackupCreateInternalErrorCause, DataBackupDecodeErrorSource, DataBackupEncodeErrorSource,
        DataBackupRestoreError, DataBackupRestoreInternalErrorCause,
    },
    model::{
        settings::Settings,
        user_profile::{IdentityData, UserProfile},
    },
    protobuf,
    utils::{
        bytes::{ByteReader as _, ByteWriter as _, OwnedVecByteReader, OwnedVecByteWriter, SliceByteReader},
        debug::Name as _,
    },
};

/// User data to be stored in or restored from a data backup.
#[derive(Name)]
pub(super) struct UserData {
    pub(super) identity_data: IdentityData,
    pub(super) user_profile: UserProfile,
    pub(super) settings: Settings,
}

/// Byte offset, relative to the beginning of the content (i.e. the category pages).
///
/// Note: Using a relative offset allows us to separate header and layout of the backup from the content.
#[derive(Copy, Clone, Debug, Eq, Name, PartialEq, PartialOrd)]
pub(super) struct Offset(pub(super) u64);
impl Offset {
    const LENGTH: usize = 8;

    #[inline]
    pub(super) fn add(&mut self, length: usize) -> Option<()> {
        self.0 = self.0.checked_add(length.try_into().ok()?)?;
        Some(())
    }

    #[inline]
    fn decode(bytes: [u8; Self::LENGTH]) -> Self {
        Self(u64::from_le_bytes(bytes))
    }

    #[inline]
    fn encode(self) -> [u8; Self::LENGTH] {
        self.0.to_le_bytes()
    }
}
impl TryFrom<Offset> for StreamOffset {
    type Error = DataBackupRestoreInternalErrorCause;

    #[inline]
    fn try_from(offset: Offset) -> Result<Self, Self::Error> {
        Ok(Self(offset.0.checked_add(HeaderAndLayout::LENGTH as u64).ok_or(
            DataBackupRestoreInternalErrorCause::from(
                "Relative offset + header and layout length exceeds u64",
            ),
        )?))
    }
}
impl TryFrom<StreamOffset> for Offset {
    type Error = DataBackupRestoreError;

    #[inline]
    fn try_from(offset: StreamOffset) -> Result<Self, Self::Error> {
        Ok(Self(offset.0.checked_sub(HeaderAndLayout::LENGTH as u64).ok_or(
            DataBackupRestoreError::ContractViolation(format!("Stream offset < {}", HeaderAndLayout::LENGTH)),
        )?))
    }
}
impl fmt::Display for Offset {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

/// Length of a page of the same [`Category`].
///
/// Note: The page length remains constant across a page category.
#[derive(Copy, Clone, Educe, Name)]
#[educe(Debug(named_field = false))]
pub(super) struct PageLength {
    pub(super) length: u32,

    #[educe(Debug(ignore))]
    pub(super) length_with_overhead: u32,
}
impl PageLength {
    const ENCODE_LENGTH: usize = 4;
    const MIN_LENGTH: u32 = 128;
    #[expect(
        clippy::cast_possible_truncation,
        reason = "We need a u32 here and this will never blow up a u32"
    )]
    const OVERHEAD_LENGTH: u32 = Self::ENCODE_LENGTH as u32 + chacha20::TAG_LENGTH as u32;

    #[inline]
    const fn new<const LENGTH: u32>() -> Self {
        Self {
            length: LENGTH,
            length_with_overhead: const {
                LENGTH
                    .checked_add(Self::OVERHEAD_LENGTH)
                    .expect("Length + overhead must not exceed u32")
            },
        }
    }

    #[inline]
    fn decode(bytes: [u8; Self::ENCODE_LENGTH]) -> Result<Self, DataBackupRestoreError> {
        let length = u32::from_le_bytes(bytes);

        // Ensure the length is somewhat sane.
        if length < Self::MIN_LENGTH {
            return Err(DataBackupRestoreError::DecodingFailed {
                name: Self::NAME,
                source: DataBackupDecodeErrorSource::Other(format!(
                    "Length is {length}, expected at least {}",
                    Self::MIN_LENGTH
                )),
            });
        }
        let length_with_overhead = length.checked_add(Self::OVERHEAD_LENGTH).ok_or_else(|| {
            DataBackupRestoreError::DecodingFailed {
                name: Self::NAME,
                source: DataBackupDecodeErrorSource::Other(format!(
                    "Length {length} with overhead exceeds a u32",
                )),
            }
        })?;

        Ok(Self {
            length,
            length_with_overhead,
        })
    }

    #[inline]
    fn encode(self) -> [u8; Self::ENCODE_LENGTH] {
        self.length.to_le_bytes()
    }
}

/// Category of items contained in the backup.
#[derive(Clone, Copy, VariantNames)]
#[repr(u8)]
pub(super) enum Category {
    UserData = 0x00,
    Contacts = 0x01,
    DistributionLists = 0x02,
    Groups = 0x03,
    CspNonces = 0x04,
    #[expect(dead_code, reason = "TODO(LIB-108)")]
    D2mNonces = 0x05,
    Polls = 0x06,
    Messages = 0x07,
    #[expect(dead_code, reason = "TODO(LIB-111)")]
    Blobs = 0x08,
}
impl Category {
    /// The page length used for the category without encoding or encryption overhead.
    ///
    /// IMPORTANT: This should only be used for encoding. For decoding, the declared page length
    /// within the layout mandates the page length.
    #[inline]
    pub(super) const fn page_length(self) -> PageLength {
        // TODO(LIB-120): Tune page length of each category for good performance while not blowing up the
        // storage budget, especially for remote backups.
        match self {
            Self::UserData
            | Self::Contacts
            | Self::DistributionLists
            | Self::Groups
            | Self::CspNonces
            | Self::D2mNonces
            | Self::Polls
            | Self::Messages => PageLength::new::<{ 16 * 1024 }>(),
            Self::Blobs => PageLength::new::<{ 512 * 1024 }>(),
        }
    }
}

/// Raw bytes of the backup file header.
#[derive(Name)]
pub(super) struct HeaderBytes(pub(super) [u8; Header::LENGTH]);

/// Backup file header.
#[derive(Name)]
pub(super) struct Header {
    pub(super) version: u16,
    pub(super) salt: DataBackupSalt,
    pub(super) bytes: HeaderBytes,
}
impl Header {
    const LENGTH: usize =
        Self::MAGIC_STRING.len() + Self::VERSION_LENGTH + Self::RESERVED_LENGTH + DataBackupSalt::LENGTH;
    const MAGIC_STRING: [u8; 16] = *b"threema-data-bup";
    const RESERVED_LENGTH: usize = 14;
    const VERSION_LENGTH: usize = 2;

    fn decode(bytes: [u8; Self::LENGTH]) -> Result<Self, DataBackupRestoreError> {
        let (magic_string, version, _reserved, salt) = array_refs![
            &bytes,
            Header::MAGIC_STRING.len(),
            Header::VERSION_LENGTH,
            Header::RESERVED_LENGTH,
            DataBackupSalt::LENGTH
        ];

        // Check the magic string.
        if *magic_string != Self::MAGIC_STRING {
            return Err(DataBackupRestoreError::DecodingFailed {
                name: Self::NAME,
                source: DataBackupDecodeErrorSource::Other("Magic string mismatch".to_owned()),
            });
        }

        // Decode version and salt.
        let version = u16::from_le_bytes(*version);
        let salt = DataBackupSalt(*salt);

        Ok(Self {
            version,
            salt,
            bytes: HeaderBytes(bytes),
        })
    }

    #[expect(clippy::needless_pass_by_value, reason = "Prevent reuse")]
    pub(super) fn encode(salt: DataBackupSalt) -> HeaderBytes {
        HeaderBytes(concat_fixed_bytes!(
            Self::MAGIC_STRING,
            (protobuf::data_backup::ProtocolVersion::V0 as u16).to_le_bytes(),
            [0; Self::RESERVED_LENGTH],
            salt.0
        ))
    }

    fn stub() -> HeaderBytes {
        Self::encode(DataBackupSalt([0; DataBackupSalt::LENGTH]))
    }
}

/// A category's span, i.e. the byte offset from where the category's encrypted pages start up until the end
/// (exclusive).
///
/// Also includes the page length.
#[derive(Name)]
pub(super) struct CategorySpan {
    pub(super) start: Offset,
    pub(super) end: Offset,
    pub(super) page_length: PageLength,
}
impl CategorySpan {
    #[inline]
    pub(super) fn is_empty(&self) -> bool {
        self.start == self.end
    }

    #[inline]
    pub(super) fn length(&self) -> Option<u32> {
        let length = self.end.0.checked_sub(self.start.0)?;
        length.try_into().ok()
    }
}
impl fmt::Debug for CategorySpan {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}({}..{})", Self::NAME, self.start, self.end)
    }
}

/// A category's position, containing the start offset of contained pages and the page length.
///
/// Note: The span must be calculated from the start offset and the start offset of the subsequent category
/// (or the snapshot seal). See [`CategorySpan`].
#[derive(Copy, Clone, Debug, Name)]
pub(super) struct CategoryPosition {
    pub(super) offset: Offset,
    pub(super) length: PageLength,
}
impl CategoryPosition {
    const LENGTH: usize = Offset::LENGTH + PageLength::ENCODE_LENGTH;

    #[inline]
    fn decode(bytes: &[u8; Self::LENGTH]) -> Result<Self, DataBackupRestoreError> {
        let (offset, length) = array_refs![bytes, Offset::LENGTH, PageLength::ENCODE_LENGTH];
        Ok(Self {
            offset: Offset::decode(*offset),
            length: PageLength::decode(*length)?,
        })
    }

    #[inline]
    fn encode(self) -> [u8; Self::LENGTH] {
        concat_fixed_bytes!(self.offset.encode(), self.length.encode())
    }

    #[inline]
    fn span_to(self, next: Offset) -> Result<CategorySpan, DataBackupRestoreError> {
        // Ensure the offset range is valid and contains a multiple of the announced page length.
        {
            let total_length =
                next.0
                    .checked_sub(self.offset.0)
                    .ok_or_else(|| DataBackupRestoreError::DecodingFailed {
                        name: Self::NAME,
                        source: DataBackupDecodeErrorSource::Other(format!(
                            "Category span between {}..{} is invalid",
                            self.offset, next,
                        )),
                    })?;
            if !total_length.is_multiple_of(self.length.length_with_overhead.into()) {
                return Err(DataBackupRestoreError::DecodingFailed {
                    name: Self::NAME,
                    source: DataBackupDecodeErrorSource::Other(format!(
                        "Category span {}..{} is not a multiple of the page length {}",
                        self.offset, next, self.length.length_with_overhead,
                    )),
                });
            }
        }

        Ok(CategorySpan {
            start: self.offset,
            end: next,
            page_length: self.length,
        })
    }
}

/// Backup layout, containing the category span of each category and the snapshot seal.
#[derive(Debug, Name, Builder)]
#[builder(pattern = "mutable")]
pub(super) struct Layout {
    user_data: CategoryPosition,
    contacts: CategoryPosition,
    distribution_lists: CategoryPosition,
    groups: CategoryPosition,
    csp_nonces: CategoryPosition,
    polls: CategoryPosition,
    messages: CategoryPosition,

    /// IMPORTANT: This must be positioned after the last snapshot category. Only incremental updates are
    /// allowed after this seal.
    snapshot_seal: Offset,
}
impl Layout {
    // TODO(LIB-108) & TODO(LIB-111): Update when fields are added.
    const CATEGORY_COUNT: usize = 7;
    pub(super) const LENGTH: usize = (Self::CATEGORY_COUNT * CategoryPosition::LENGTH) + Offset::LENGTH;

    pub(super) fn decode(bytes: &[u8]) -> Result<Self, DataBackupRestoreError> {
        // Decode first.
        let mut reader = SliceByteReader::new(bytes);
        let mut read_position = || -> Result<CategoryPosition, DataBackupRestoreError> {
            let position = reader
                .read_fixed()
                .map_err(|error| DataBackupRestoreError::DecodingFailed {
                    name: Self::NAME,
                    source: error.into(),
                })?;
            CategoryPosition::decode(&position)
        };
        let user_data = read_position()?;
        let contacts = read_position()?;
        let distribution_lists = read_position()?;
        let groups = read_position()?;
        let csp_nonces = read_position()?;
        let polls = read_position()?;
        let messages = read_position()?;
        let snapshot_seal = reader
            .run_owned(|mut reader| {
                let snapshot_seal = Offset::decode(reader.read_fixed()?);
                let _ = reader.expect_consumed()?;
                Ok(snapshot_seal)
            })
            .map_err(|error| DataBackupRestoreError::DecodingFailed {
                name: Self::NAME,
                source: error.into(),
            })?;

        // Ensure that the first category starts at zero.
        if user_data.offset.0 != 0 {
            return Err(DataBackupRestoreError::DecodingFailed {
                name: Self::NAME,
                source: DataBackupDecodeErrorSource::Other(format!(
                    "First layout category starts at offset {}, expected 0",
                    user_data.offset.0,
                )),
            });
        }

        Ok(Self {
            user_data,
            contacts,
            distribution_lists,
            groups,
            csp_nonces,
            polls,
            messages,
            snapshot_seal,
        })
    }

    #[inline]
    pub(super) fn encode(self) -> [u8; Self::LENGTH] {
        concat_fixed_bytes!(
            self.user_data.encode(),
            self.contacts.encode(),
            self.distribution_lists.encode(),
            self.groups.encode(),
            self.csp_nonces.encode(),
            self.polls.encode(),
            self.messages.encode(),
            self.snapshot_seal.encode(),
        )
    }

    pub(super) fn span(&self, category: Category) -> Result<CategorySpan, DataBackupRestoreError> {
        match category {
            Category::UserData => self.user_data.span_to(self.contacts.offset),
            Category::Contacts => self.contacts.span_to(self.distribution_lists.offset),
            Category::DistributionLists => self.distribution_lists.span_to(self.groups.offset),
            Category::Groups => self.groups.span_to(self.csp_nonces.offset),
            // TODO(LIB-108): Must point to D2M nonces!
            Category::CspNonces => self.csp_nonces.span_to(self.polls.offset),
            #[expect(clippy::todo, reason = "TODO(LIB-108)")]
            Category::D2mNonces => todo!(),
            Category::Polls => self.polls.span_to(self.messages.offset),
            // TODO(LIB-111): Must point to blobs!
            Category::Messages => self.messages.span_to(self.snapshot_seal),
            #[expect(clippy::todo, reason = "TODO(LIB-111)")]
            Category::Blobs => todo!(),
        }
    }
}
impl LayoutBuilder {
    pub(super) fn set(&mut self, category: Category, position: CategoryPosition) {
        let _ = match category {
            Category::UserData => self.user_data(position),
            Category::Contacts => self.contacts(position),
            Category::DistributionLists => self.distribution_lists(position),
            Category::Groups => self.groups(position),
            Category::CspNonces => self.csp_nonces(position),
            #[expect(clippy::todo, reason = "TODO(LIB-108)")]
            Category::D2mNonces => todo!(),
            Category::Polls => self.polls(position),
            Category::Messages => self.messages(position),
            #[expect(clippy::todo, reason = "TODO(LIB-111)")]
            Category::Blobs => todo!(),
        };
    }
}

/// An encrypted and authenticated [`Layout`], stored immediately after the [`Header`].
#[derive(Name)]
pub(super) struct LayoutEncrypted(pub(super) [u8; Self::LENGTH]);
impl LayoutEncrypted {
    const LENGTH: usize = Layout::LENGTH + chacha20::TAG_LENGTH;

    fn stub() -> Self {
        Self([0; Self::LENGTH])
    }
}

/// Codec for the combination of [`Header`] and [`Layout`].
#[derive(Name)]
pub(super) struct HeaderAndLayout;
impl HeaderAndLayout {
    pub(super) const LENGTH: usize = Header::LENGTH + LayoutEncrypted::LENGTH;

    pub(super) fn decode(
        bytes: &[u8; Self::LENGTH],
    ) -> Result<(Header, LayoutEncrypted), DataBackupRestoreError> {
        let (header, layout) = array_refs![bytes, Header::LENGTH, LayoutEncrypted::LENGTH];
        Ok((Header::decode(*header)?, LayoutEncrypted(*layout)))
    }

    #[expect(clippy::needless_pass_by_value, reason = "Prevent reuse")]
    pub(super) fn encode(header: HeaderBytes, layout: LayoutEncrypted) -> [u8; Self::LENGTH] {
        concat_fixed_bytes!(header.0, layout.0)
    }

    pub(super) fn stub() -> [u8; Self::LENGTH] {
        Self::encode(Header::stub(), LayoutEncrypted::stub())
    }
}

/// Codec for pages of the same category.
#[derive(Name)]
pub(super) struct Page;
impl Page {
    pub(super) fn encode(
        length: PageLength,
        data: &[u8],
    ) -> Result<Vec<u8>, DataBackupCreateInternalErrorCause> {
        // Determine padding length.
        let data_length: u32 = data
            .len()
            .try_into()
            .map_err(|_| DataBackupCreateInternalErrorCause::from("Page data length exceeds u32"))?;
        let padding_length = length.length.checked_sub(data_length).ok_or_else(|| {
            DataBackupCreateInternalErrorCause::from("Page data length exceeds page capacity")
        })?;

        // Encode the page header and data and padding.
        //
        // Note: We still left space for the encryption overhead, so resizing the buffer won't be needed.
        let mut writer = OwnedVecByteWriter::new_with_capacity(length.length_with_overhead as usize);
        writer
            .run(|writer| {
                writer.write_u32_le(data_length)?;
                writer.write(data)?;
                if padding_length > 0 {
                    writer.write_in_place(padding_length as usize)?.fill(0x00);
                }
                Ok(())
            })
            .map_err(|error| DataBackupCreateInternalErrorCause::EncodingFailed {
                name: Self::NAME,
                source: DataBackupEncodeErrorSource::from(error),
            })?;
        Ok(writer.into_inner())
    }

    pub(super) fn decode(length: PageLength, page: Vec<u8>) -> Result<Vec<u8>, DataBackupRestoreError> {
        // Validate the page data length.
        {
            let page_length = page.len().saturating_sub(PageLength::ENCODE_LENGTH);
            if page_length != length.length as usize {
                return Err(DataBackupRestoreError::DecodingFailed {
                    name: Self::NAME,
                    source: DataBackupDecodeErrorSource::Other(format!(
                        "Unexpected page length {page_length}, expected {}",
                        length.length
                    )),
                });
            }
        }

        // Decode the page header and data, discarding any padding.
        OwnedVecByteReader::new(page)
            .run_owned(|mut reader| {
                let data_length = reader.read_u32_le()?;
                let mut data = reader.read_remaining_owned();
                data.truncate(data_length as usize);
                Ok(data)
            })
            .map_err(|error| DataBackupRestoreError::DecodingFailed {
                name: Self::NAME,
                source: error.into(),
            })
    }
}
