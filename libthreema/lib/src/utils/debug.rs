//! Debug-related utilities.
use core::fmt;

use libthreema_dependencies::{crypto::x25519, data_encoding::HEXLOWER_PERMISSIVE};

/// Formatter to format a slice to its length.
pub(crate) fn debug_slice_length<E, T>(slice: T, formatter: &mut fmt::Formatter<'_>) -> fmt::Result
where
    T: AsRef<[E]>,
{
    write!(formatter, "length={}", slice.as_ref().len())
}

/// Formatter to format arbitrary collections that implement [`IntoIterator`] with [`ExactSizeIterator`].
#[expect(dead_code, reason = "Will use later")]
pub(crate) fn debug_collection_length<'collection, TCollection>(
    collection: &'collection TCollection,
    formatter: &mut fmt::Formatter<'_>,
) -> fmt::Result
where
    &'collection TCollection: IntoIterator,
    <&'collection TCollection as IntoIterator>::IntoIter: ExactSizeIterator,
{
    write!(formatter, "length={}", collection.into_iter().len())
}

/// Formatter to redact a string, replacing its content with an equal amount of `*`s.
///
/// Note: The byte length is used for replacing, so the resulting string may not accurately represent the
/// length as humans would perceive it (i.e. graphemes).
pub(crate) fn debug_str_redacted(field: &str, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
    formatter.write_str(&"*".repeat(field.len()))
}

/// Formatter to format a [`x25519::StaticSecret`] to its public key.
pub(crate) fn debug_static_secret(
    static_secret: &x25519::StaticSecret,
    formatter: &mut fmt::Formatter<'_>,
) -> fmt::Result {
    formatter
        .debug_tuple("PublicKey")
        .field(&HEXLOWER_PERMISSIVE.encode(x25519::PublicKey::from(static_secret).as_bytes()))
        .finish()
}

/// Makes something name-able.
pub(crate) trait Name {
    const NAME: &'static str;
}
