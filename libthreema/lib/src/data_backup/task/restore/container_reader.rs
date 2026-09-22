use std::collections::VecDeque;

use duplicate::duplicate_item;
use educe::Educe;

use crate::{
    common::{HashedNonce, keys::DataBackupPageKey},
    data_backup::{
        codec::container::{HashedNonceBackupDecoder, VariableLengthBackupDecoder},
        container::{
            ContactContainer, ContainerCategory, DistributionListContainer, GroupContainer,
            HashedCspNonceContainer, HashedD2mNonceContainer, MessageContainer, PollContainer,
            UserDataContainer,
        },
        metadata::{LayoutV1, METADATA_LENGTH},
        page::{EncryptedPage, PageOffset},
        task::restore::{
            BackupRestoreError, BackupRestoreResponse, LocalReadInstruction,
            page_reader::{PageReader, PageReaderResult},
        },
    },
    utils::{
        debug::{Name, debug_collection_length},
        frame::{
            FixedLengthFrameDecoder, FrameDelimiter as _, U32LittleEndianDelimiter,
            VariableLengthFrameDecoder,
        },
    },
};

/// Result returned by [`ContainerReader::pop`] and [`ContainerReader::drain`].
pub(super) enum ContainerReaderResult<TContainer> {
    /// No containers are available right now, but there are more to come.
    Idle,

    /// One or more containers are available.
    Some(TContainer),

    /// The container reader is done and all containers have been consumed.
    Done,
}

#[derive(Debug)]
enum PageReaderState {
    Alive,
    Done,
}

/// A container reader to add chunks and decode them container by container.
///
/// See, e.g.,  [`HashedCspNonceContainerReader`] or [`EssentialDataContainerReader`] for specific
/// instantiations.
#[derive(Educe)]
#[educe(Debug)]
pub(super) struct ContainerReader<TContainer, TFrameDecoder> {
    page_reader_state: PageReaderState,

    page_reader: PageReader,

    #[educe(Debug(ignore))]
    frame_decoder: TFrameDecoder,

    #[educe(Debug(ignore))]
    layout: LayoutV1,

    #[educe(Debug(method(debug_collection_length)))]
    buffered_containers: VecDeque<TContainer>,
}

#[duplicate_item(
    [
        frame_decoder_type     [ FixedLengthFrameDecoder ]
        frame_decoder_generics [ { HashedNonce::LENGTH} ]
        decode_trait           [ HashedNonceBackupDecoder ]
    ]
    [
        frame_decoder_type     [ VariableLengthFrameDecoder ]
        frame_decoder_generics [ { U32LittleEndianDelimiter::LENGTH }, U32LittleEndianDelimiter ]
        decode_trait           [ VariableLengthBackupDecoder ]
    ]
)]
impl<TContainer: ContainerCategory + Name + decode_trait>
    ContainerReader<TContainer, frame_decoder_type<frame_decoder_generics>>
{
    pub(super) fn new(page_key: DataBackupPageKey, layout: LayoutV1) -> Self {
        Self {
            page_reader: PageReader::new(page_key, &layout.get_offset(TContainer::CATEGORY)),
            page_reader_state: PageReaderState::Alive,
            frame_decoder: frame_decoder_type::new(),
            layout,
            buffered_containers: VecDeque::new(),
        }
    }

    /// Pass the [`BackupRestoreResponse`] as [`EncryptedPage`] to the page reader and buffer the available
    /// containers.
    pub(super) fn add_page(
        &mut self,
        read_response: BackupRestoreResponse,
    ) -> Result<(), BackupRestoreError> {
        // Add the page.
        let page_offset = PageOffset(read_response.offset.0.checked_sub(METADATA_LENGTH).ok_or(
            BackupRestoreError::InvalidParameter(format!(
                "Provided response offset must be >= {METADATA_LENGTH}"
            )),
        )?);
        self.page_reader.add_page(
            TContainer::CATEGORY,
            page_offset,
            EncryptedPage(read_response.chunk),
        )?;

        // Try to decode the next containers.
        let chunk = match self.page_reader.poll()? {
            PageReaderResult::Idle => None,
            PageReaderResult::Some(chunk) => Some(chunk),
            PageReaderResult::Final(chunk) => {
                // The page reader won't give us any more chunks in the future.
                self.page_reader_state = PageReaderState::Done;
                Some(chunk)
            },
        };

        // If we got a new chunk, decode and buffer it.
        if let Some(chunk) = chunk {
            let _ = self.frame_decoder.add_chunks(&[&chunk]);
            while let Some(container) = self.frame_decoder.next_frame_and_then(TContainer::decode) {
                let container = container.map_err(|source| BackupRestoreError::DecodingFailed {
                    name: TContainer::NAME,
                    source,
                })?;
                self.buffered_containers.push_back(container);
            }
        }

        Ok(())
    }

    fn map_page_reader_state<TReaderResultContainer>(
        &self,
    ) -> Result<ContainerReaderResult<TReaderResultContainer>, BackupRestoreError> {
        Ok(match self.page_reader_state {
            PageReaderState::Alive => ContainerReaderResult::Idle,
            PageReaderState::Done => {
                if self.frame_decoder.buffered_length() != 0 {
                    return Err(BackupRestoreError::InvalidState(
                        "Container reader is done, but frame decoder is non-empty".to_owned(),
                    ));
                }
                ContainerReaderResult::Done
            },
        })
    }

    /// Return the next buffered container, or indicate that no containers are currently available.
    #[expect(clippy::allow_attributes, reason = "duplicate shenanigans")]
    #[allow(dead_code, reason = "Only used for reader with variable length frame decoder")]
    pub(super) fn pop(&mut self) -> Result<ContainerReaderResult<TContainer>, BackupRestoreError> {
        // Return the container if there is one.
        if let Some(container) = self.buffered_containers.pop_front() {
            return Ok(ContainerReaderResult::Some(container));
        }

        self.map_page_reader_state()
    }

    /// Drain all buffered containers and return them.
    pub(super) fn drain(&mut self) -> Result<ContainerReaderResult<Vec<TContainer>>, BackupRestoreError> {
        let containers = self.buffered_containers.drain(..).collect::<Vec<_>>();

        // Return the containers if there are some.
        if !containers.is_empty() {
            return Ok(ContainerReaderResult::Some(containers));
        }

        self.map_page_reader_state()
    }

    /// Dissolve the reader and return the underlying page key and layout.
    pub(super) fn dissolve(self) -> Result<(DataBackupPageKey, LayoutV1), BackupRestoreError> {
        if !matches!(self.page_reader_state, PageReaderState::Done)
            || !self.buffered_containers.is_empty()
            || self.frame_decoder.buffered_length() != 0
        {
            return Err(BackupRestoreError::InvalidState(
                "Cannot dissolve non-empty container reader".to_owned(),
            ));
        }
        let page_key = self.page_reader.dissolve()?;
        Ok((page_key, self.layout))
    }

    pub(super) fn instruction(&self) -> Result<Option<LocalReadInstruction>, BackupRestoreError> {
        self.page_reader.instruction()
    }
}

pub(super) type HashedCspNonceContainerReader =
    ContainerReader<HashedCspNonceContainer, FixedLengthFrameDecoder<{ HashedNonce::LENGTH }>>;
#[expect(dead_code, reason = "TODO(LIB-108): Backup D2M nonces")]
pub(super) type HashedD2mNonceContainerReader =
    ContainerReader<HashedD2mNonceContainer, FixedLengthFrameDecoder<{ HashedNonce::LENGTH }>>;

type VariableLengthContainerReader<TContainer> = ContainerReader<
    TContainer,
    VariableLengthFrameDecoder<{ U32LittleEndianDelimiter::LENGTH }, U32LittleEndianDelimiter>,
>;
pub(super) type UserDataContainerReader = VariableLengthContainerReader<UserDataContainer>;
pub(super) type ContactContainerReader = VariableLengthContainerReader<ContactContainer>;
pub(super) type DistributionListContainerReader = VariableLengthContainerReader<DistributionListContainer>;
pub(super) type GroupContainerReader = VariableLengthContainerReader<GroupContainer>;
pub(super) type PollContainerReader = VariableLengthContainerReader<PollContainer>;
pub(super) type MessageContainerReader = VariableLengthContainerReader<MessageContainer>;
