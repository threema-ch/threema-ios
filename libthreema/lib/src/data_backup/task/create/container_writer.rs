use core::marker::PhantomData;

use educe::Educe;
use tracing::trace;

use super::page_writer::{AllocatedPage, PageWriter};
use crate::{
    common::keys::DataBackupPageKey,
    data_backup::{
        codec::container::BackupEncoder,
        container::ContainerCategory,
        task::create::{BackupCreateError, InternalErrorCause, LocalWriteInstruction},
    },
    utils::debug::Name,
};

struct FrameEncoder {
    data: Vec<u8>,
}
impl FrameEncoder {
    fn new() -> Self {
        Self { data: vec![] }
    }

    // Dissolve the frame encoder and return any remaining bytes.
    //
    /// Note: If any chunks have been added, the returned vector will be non-empty.
    #[inline]
    fn dissolve(self) -> Vec<u8> {
        self.data
    }

    // Append `chunk` to the encoders queue.
    #[inline]
    fn add_chunk(&mut self, chunk: &[u8]) {
        self.data.extend_from_slice(chunk);
    }

    /// Return a frame of `length` bytes if there are **strictly more** than `length` bytes available.
    ///
    /// Note: Keeping up to `length` bytes ensures that the very last (partial) frame can only be obtained
    /// with [`Self::dissolve()`].
    #[inline]
    fn get(&mut self, length: usize) -> Option<Vec<u8>> {
        // IMPORTANT: This must be greater equal (`<=`) to ensure that the very last (partial) frame is kept.
        // operation.
        if self.data.len() <= length {
            return None;
        }
        Some(self.data.drain(..length).as_slice().to_vec())
    }
}

#[derive(Educe)]
#[educe(Debug)]
pub(crate) struct ContainerWriter<TContainer> {
    #[educe(Debug(ignore))]
    encoder: FrameEncoder,

    #[educe(Debug(ignore))]
    page_writer: PageWriter,

    // INVARIANT: allocated_page is `Some` (except in a small, well-defined scope)
    #[educe(Debug(ignore))]
    allocated_page: Option<AllocatedPage>,

    #[educe(Debug(ignore))]
    _phantom: PhantomData<TContainer>,
}

impl<TContainer: BackupEncoder + ContainerCategory + Name> ContainerWriter<TContainer> {
    /// Create a new container writer encrypting pages with the given `page_key`.
    ///
    /// Note: This must be used exactly once during the entire backup process.
    pub(crate) fn new(page_key: DataBackupPageKey) -> Result<Self, InternalErrorCause> {
        trace!(
            category = TContainer::CATEGORY.variant_name(),
            "Creating new container writer"
        );

        Self::new_with_page_writer(PageWriter::new(page_key))
    }

    fn new_with_page_writer(mut page_writer: PageWriter) -> Result<Self, InternalErrorCause> {
        // INVARIANT: Establish that allocated_page is `Some`
        let allocated_page = Some(page_writer.allocate_first(TContainer::CATEGORY)?);

        Ok(Self {
            encoder: FrameEncoder::new(),
            page_writer,
            allocated_page,
            _phantom: PhantomData,
        })
    }

    /// Transform a container writer to handle containers of another type.
    pub(crate) fn transform<TNextContainer: BackupEncoder + ContainerCategory + Name>(
        self,
    ) -> Result<(ContainerWriter<TNextContainer>, Option<LocalWriteInstruction>), BackupCreateError> {
        trace!(
            from_category = TContainer::CATEGORY.variant_name(),
            to_category = TNextContainer::CATEGORY.variant_name(),
            "Transform container writer"
        );

        let mut page_writer = self.dissolve()?;
        let instruction = page_writer.write_pending()?;
        let next_container_writer = ContainerWriter::<TNextContainer>::new_with_page_writer(page_writer)?;

        Ok((next_container_writer, instruction))
    }

    pub(crate) fn add(&mut self, containers: &[TContainer]) -> Result<(), BackupCreateError> {
        trace!(
            containers_length = containers.len(),
            "Add containers to container writer"
        );
        for container in containers {
            self.encoder.add_chunk(&container.encode().map_err(|error| {
                InternalErrorCause::EncodingFailed {
                    name: TContainer::NAME,
                    source: error,
                }
            })?);

            // Iterate over chunks and write them to pages.
            while let Some(chunk) = self.encoder.get(TContainer::CATEGORY.page_capacity()) {
                // INVARIANT: self.allocated_page is `Some` before and after this statement.
                self.allocated_page = {
                    let filled_page = self
                        .allocated_page
                        .take()
                        .expect("Allocated page must be Some")
                        .fill(chunk)?;

                    // We could optimize here by only adding a new page if really needed.
                    // However, this complicates the API quite a bit and the chance that the
                    // last page is perfectly aligned (no padding) is  small.
                    Some(self.page_writer.add_and_allocate_next(filled_page)?)
                };
            }
        }
        Ok(())
    }

    pub(super) fn writable_buffer_below_maximal_append_length(&self) -> Result<bool, InternalErrorCause> {
        self.page_writer.writable_buffer_below_maximal_append_length()
    }

    pub(crate) fn write_pending(&mut self) -> Result<Option<LocalWriteInstruction>, InternalErrorCause> {
        self.page_writer.write_pending()
    }

    pub(crate) fn dissolve(mut self) -> Result<PageWriter, BackupCreateError> {
        // Add any remaining contents.
        let filled_page = self
            .allocated_page
            .expect("allocated page must be Some")
            .fill(self.encoder.dissolve())?;
        self.page_writer.add_final(filled_page)?;

        Ok(self.page_writer)
    }
}
