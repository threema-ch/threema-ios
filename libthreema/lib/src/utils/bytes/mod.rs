//! Byte-related utilities and extensions.
use core::ptr;

mod reader;
mod writer;

pub use reader::*;
pub use writer::*;

// TODO(LIB-31): Should be unnecessary
pub(crate) trait InsertSlice {
    fn insert_at(&mut self, offset: usize, bytes: &[u8]);
}
impl InsertSlice for Vec<u8> {
    /// Inserts a [`u8`] slice at a specific offset.
    ///
    /// This is an *O*(*n*) operation and usually less efficient than concatenating items to a
    /// [`Vec<u8>`].
    ///
    /// Note: This is stolen from [`String::insert_str`].
    ///
    /// # Panics
    ///
    /// Panics if `offset` is larger than the `Vec<u8>`'s length.
    #[inline]
    fn insert_at(&mut self, offset: usize, bytes: &[u8]) {
        let current_length = self.len();
        let additional_length = bytes.len();

        // Make room for the additional bytes
        self.reserve(additional_length);

        #[expect(
            clippy::arithmetic_side_effects,
            clippy::multiple_unsafe_ops_per_block,
            reason = "TODO(LIB-16)"
        )]
        // # Safety: The underlying vector MUST contain bytes.
        unsafe {
            // Move the existing bytes at the specific offset by the amount of bytes to add
            ptr::copy(
                self.as_ptr().add(offset),
                self.as_mut_ptr().add(offset + additional_length),
                current_length - offset,
            );

            // Copy the bytes to the correct offset
            ptr::copy_nonoverlapping(bytes.as_ptr(), self.as_mut_ptr().add(offset), additional_length);

            self.set_len(current_length + additional_length);
        }
    }
}
