//! Implementation of the cross-platform _Data Backup_.
//!
//! IMPORTANT / TODO(LIB-185): This is largely unreviewed right now!

use libthreema_macros::Name;

pub(crate) mod accountant;
pub mod codec;
pub(crate) mod container;
pub(crate) mod metadata;
pub(crate) mod page;
pub mod task;

/// A counter overflowed.
//-
// TODO(LIB-185) @lgr: I'm not happy with this error type but don't know how to improve it.
// For now, it seems both overly generic (many things are mapped to this error, e.g., actual overflows *and*
// conversion errors) and very specific at the same time (couldn't we use existing `InternalErrorCause` for
// that as well?).
//
// But I have the feeling that things will change anyway, potentially making clear how to resolve it, hence I
// left it for now...
#[derive(Clone, Debug, thiserror::Error)]
#[error("'{name}' overflowed")]
pub struct OverflowError {
    /// Name of the counter that overflowed.
    name: &'static str,
}

/// An offset within a stream.
///
/// Note: The offset is relative to the *beginning* of the stream including any metadata, i.e.
/// `StreamOffset(0)` marks the first byte of the stream.
#[derive(Copy, Clone, Debug, Eq, Hash, Name, PartialEq, PartialOrd)]
pub struct StreamOffset(pub usize);
