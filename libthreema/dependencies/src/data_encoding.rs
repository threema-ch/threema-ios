//! Minimally required items of the `data_encoding` crate.
//!
//! Rationale: We only want to expose [`HEXLOWER_PERMISSIVE`] and not the more strict
//! [`data_encoding::HEXLOWER`] variant to support permissive case-mixed decoding while always encoding in
//! lowercase.

pub use data_encoding::{BASE32, BASE64, HEXLOWER_PERMISSIVE};
