use derive_builder::Builder;
use educe::Educe;
use libthreema_dependencies::crypto::chacha20;
use libthreema_macros::{Name, concat_fixed_bytes};

use crate::{
    common::keys::{DataBackupLayoutKey, DataBackupSalt},
    crypto::aead::AeadRandomNonceAhead as _,
    data_backup::{
        codec::BackupDecodingError,
        container::Category,
        page::Position,
        task::{create, restore::BackupRestoreError},
    },
    protobuf,
    utils::{
        bytes::{ByteReader, ByteReaderError, OwnedVecByteReader},
        debug::Name as _,
    },
};

/// Fixed-length backup file header.
#[derive(Name, Educe)]
#[educe(Debug)]
pub(super) struct Header {
    #[educe(Debug(ignore))]
    magic_string: [u8; Self::MAGIC_STRING.len()],

    pub(super) version: u16,

    #[educe(Debug(ignore))]
    reserved: [u8; Self::RESERVED_BYTES],

    #[educe(Debug(ignore))]
    pub(super) salt: DataBackupSalt,
}
impl Header {
    pub(super) const LENGTH: usize =
        Self::MAGIC_STRING.len() + 2 /* version */ + Self::RESERVED_BYTES + DataBackupSalt::LENGTH;
    const MAGIC_STRING: [u8; 16] = *b"threema-data-bup";
    const RESERVED_BYTES: usize = 14;

    pub(super) fn new(salt: DataBackupSalt) -> Self {
        Self {
            magic_string: Self::MAGIC_STRING,
            version: protobuf::data_backup::ProtocolVersion::V0 as u16,
            reserved: [0; Self::RESERVED_BYTES],
            salt,
        }
    }

    /// Encode to the following memory layout:
    /// - `magic-string`: `b16`
    /// - `version`: `u16`
    /// - `reserved`: `b14`
    /// - `salt`: `b32`
    pub(super) fn encode(&self) -> [u8; Self::LENGTH] {
        concat_fixed_bytes!(
            self.magic_string,
            self.version.to_le_bytes(),
            self.reserved,
            self.salt.0,
        )
    }

    pub(super) fn decode_from(reader: &mut impl ByteReader) -> Result<Self, BackupRestoreError> {
        let reading_error = |source: ByteReaderError| BackupRestoreError::DecodingFailed {
            name: Self::NAME,
            source: source.into(),
        };

        // Decode and check the magic string.
        let magic_string = reader.read_fixed().map_err(reading_error)?;
        if magic_string != Self::MAGIC_STRING {
            return Err(BackupRestoreError::DecodingFailed {
                name: Self::NAME,
                source: BackupDecodingError::Other("Magic string mismatch".to_owned()),
            });
        }

        // Decode the rest.
        let version = reader.read_u16_le().map_err(reading_error)?;
        let reserved = reader.read_fixed().map_err(reading_error)?;
        let salt = DataBackupSalt(reader.read_fixed().map_err(reading_error)?);

        Ok(Self {
            magic_string,
            version,
            reserved,
            salt,
        })
    }
}

/// Fixed-size backup layout version 1 recording the first page position of each data category.
#[derive(Debug, Name, Builder)]
#[builder(pattern = "mutable")]
pub(super) struct LayoutV1 {
    user_data: Position,
    contacts: Position,
    distribution_lists: Position,
    groups: Position,
    hashed_csp_nonces: Position,
    // hashed_d2m_nonces: Position, // TODO(LIB-108): increase LENGTH accordingly!
    // blobs: Position, TODO(LIB-111): increase LENGTH accordingly!
    polls: Position,
    messages: Position,
}
impl LayoutV1 {
    // TODO(LIB-108) &  TODO(LIB-111): Update when fields are added!
    const LENGTH: usize = 7 * Position::LENGTH;

    fn encode(self) -> Result<[u8; Self::LENGTH], create::InternalErrorCause> {
        Ok(concat_fixed_bytes!(
            self.user_data.encode()?,
            self.contacts.encode()?,
            self.distribution_lists.encode()?,
            self.groups.encode()?,
            self.hashed_csp_nonces.encode()?,
            // self.hashed_d2m_nonces.encode()?, TODO(LIB-108)
            self.polls.encode()?,
            // self.blobs.encode()?, TODO(LIB-111)
            self.messages.encode()?,
        ))
    }

    pub(super) fn encrypt(
        self,
        header: &Header,
        layout_key: &DataBackupLayoutKey,
    ) -> Result<LayoutV1Encrypted, create::InternalErrorCause> {
        let mut layout = self.encode()?.to_vec();

        let _nonce = layout_key
            .0
            .encrypt_in_place_random_nonce_ahead(&header.encode(), &mut layout)
            .map_err(|_| create::InternalErrorCause::EncryptionFailed { name: Self::NAME })?;

        Ok(LayoutV1Encrypted {
            layout_v1_box: layout.try_into().map_err(|_| {
                create::InternalErrorCause::Other(format!("Layout Box should have length {}", Self::LENGTH))
            })?,
        })
    }

    fn decode(layout: Vec<u8>) -> Result<Self, BackupRestoreError> {
        let mut reader = OwnedVecByteReader::new(layout);
        let layout = Self {
            user_data: Position::decode(&mut reader)?,
            contacts: Position::decode(&mut reader)?,
            distribution_lists: Position::decode(&mut reader)?,
            groups: Position::decode(&mut reader)?,
            hashed_csp_nonces: Position::decode(&mut reader)?,
            polls: Position::decode(&mut reader)?,
            messages: Position::decode(&mut reader)?,
        };

        let _ = reader
            .expect_consumed()
            .map_err(|error| BackupRestoreError::DecodingFailed {
                name: Self::NAME,
                source: error.into(),
            })?;

        Ok(layout)
    }

    pub(super) fn get_offset(&self, category: Category) -> Position {
        match category {
            Category::UserData => self.user_data.clone(),
            Category::Contacts => self.contacts.clone(),
            Category::DistributionLists => self.distribution_lists.clone(),
            Category::Groups => self.groups.clone(),
            Category::HashedCspNonces => self.hashed_csp_nonces.clone(),
            #[expect(clippy::todo, reason = "TODO(LIB-108)")]
            Category::HashedD2mNonces => todo!(),
            Category::Poll => self.polls.clone(),
            #[expect(clippy::todo, reason = "TODO(LIB-111)")]
            Category::Blob => todo!(),
            Category::Message => self.messages.clone(),
        }
    }
}

impl LayoutV1Builder {
    pub(super) fn set(&mut self, category: Category, start: Position) {
        let _ = match category {
            Category::UserData => self.user_data(start),
            Category::Contacts => self.contacts(start),
            Category::DistributionLists => self.distribution_lists(start),
            Category::Groups => self.groups(start),
            Category::HashedCspNonces => self.hashed_csp_nonces(start),
            #[expect(clippy::todo, reason = "TODO(LIB-108)")]
            Category::HashedD2mNonces => todo!(),
            Category::Poll => self.polls(start),
            Category::Message => self.messages(start),
            #[expect(clippy::todo, reason = "TODO(LIB-111)")]
            Category::Blob => todo!(),
        };
    }
}
/// An encrypted and authenticated [`LayoutV1`] stored immediately after the [`Header`].
#[derive(Name)]
pub(super) struct LayoutV1Encrypted {
    layout_v1_box: [u8; Self::LENGTH],
}

impl LayoutV1Encrypted {
    pub(super) const LENGTH: usize = LayoutV1::LENGTH + chacha20::NONCE_LENGTH + chacha20::TAG_LENGTH;

    #[expect(
        clippy::needless_pass_by_value,
        reason = "Prevent use of header after layout decryption"
    )]
    pub(super) fn decrypt(
        self,
        header: Header,
        layout_key: &DataBackupLayoutKey,
    ) -> Result<LayoutV1, BackupRestoreError> {
        let mut layout = self.layout_v1_box.to_vec();
        let _nonce = layout_key
            .0
            .decrypt_in_place_random_nonce_ahead(&header.encode(), &mut layout)
            .map_err(|_| BackupRestoreError::DecryptionFailed { name: Self::NAME })?;

        LayoutV1::decode(layout)
    }

    pub(super) fn encode(self) -> Vec<u8> {
        self.layout_v1_box.to_vec()
    }

    pub(super) fn decode_from(reader: &mut impl ByteReader) -> Result<Self, BackupRestoreError> {
        Ok(Self {
            layout_v1_box: reader
                .read_fixed()
                .map_err(|source| BackupRestoreError::DecodingFailed {
                    name: Self::NAME,
                    source: source.into(),
                })?,
        })
    }
}

/// Total byte length of the fixed-size metadata section (header + encrypted layout).
pub(super) const METADATA_LENGTH: usize = Header::LENGTH + LayoutV1Encrypted::LENGTH;
