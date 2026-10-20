//! Implementation of the cross-platform _Data Backup_.
use std::sync::PoisonError;

use crate::{
    common::ThreemaIdError,
    provider::ProviderError,
    utils::{
        bytes::{ByteReaderError, ByteWriterError},
        sequence_numbers::SequenceNumberOverflow,
    },
};

mod accountant;
mod cipher;
mod codec;
mod common;
pub mod task;

/// Target number of bytes that should be buffered in a single instruction without being inefficient or
/// creating too much memory pressure.
const TARGET_INSTRUCTION_BUFFER_LENGTH: u32 = 1024 * 1024;

/// Source of an encoding error.
#[derive(Clone, Debug, thiserror::Error)]
pub enum DataBackupEncodeErrorSource {
    /// Writing failed.
    #[error(transparent)]
    ByteWriterError(#[from] ByteWriterError),

    /// Unable to encode a protobuf message.
    #[error(transparent)]
    ProstEncodeError(#[from] prost::EncodeError),

    /// Another kind of error occurred.
    #[error("{0}")]
    Other(&'static str),
}

/// Cause of an internal error during data backup creation.
#[derive(Clone, Debug, thiserror::Error)]
pub enum DataBackupCreateInternalErrorCause {
    /// Unable to encode a struct.
    #[error("Encoding '{name}' failed: {source}")]
    EncodingFailed {
        /// Name of the struct.
        name: &'static str,

        /// Error source.
        source: DataBackupEncodeErrorSource,
    },

    /// Unable to encrypt a struct.
    #[error("Encrypting '{name}' failed")]
    EncryptionFailed {
        /// Name of the struct.
        name: &'static str,
    },

    /// Unable to obtain a lock.
    #[error("Obtaining a lock failed")]
    LockPoisoned,

    /// Another kind of error occurred.
    #[error("{0}")]
    Other(String),

    /// Exhausted the available sequence numbers to use for creating pages. Should never happen.
    #[error("Sequence number overflow happened")]
    SequenceNumberOverflow(#[from] SequenceNumberOverflow),
}
impl<T: Into<String>> From<T> for DataBackupCreateInternalErrorCause {
    fn from(message: T) -> Self {
        Self::Other(message.into())
    }
}

/// An error occurred during backup creation.
///
/// When encountering an error:
///
/// 1. Let `error` be the provided [`DataBackupCreateError`].
/// 2. Delete the file created as part of this backup create process.
/// 3. Abort the protocol due to `error`.
#[derive(Clone, Debug, thiserror::Error)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Error), uniffi(flat_error))]
pub enum DataBackupCreateError {
    /// A contract violation occurred.
    ///
    /// This is likely the result of modifying the app state during the backup creation task.
    #[error("Contract violation: {0}")]
    ContractViolation(String),

    /// Some provided parameter could not be converted into the required internal representation.
    #[error("Conversion error: {0}")]
    ConversionError(String),

    /// A foreign function considered infallible returned an error.
    #[cfg(any(test, feature = "uniffi", feature = "cli"))]
    #[error("Infallible function failed in foreign code: {0}")]
    ForeignFunctionFailed(String),

    /// An internal error happened.
    #[error("Internal error: {0}")]
    InternalError(#[from] DataBackupCreateInternalErrorCause),
}
impl From<ProviderError> for DataBackupCreateError {
    fn from(error: ProviderError) -> Self {
        match error {
            ProviderError::ConversionError(message) => Self::ConversionError(message),
            ProviderError::ContractViolation(message) => Self::ContractViolation(message),

            #[cfg(any(test, feature = "uniffi", feature = "cli"))]
            ProviderError::ForeignFunctionFailed(message) => Self::ForeignFunctionFailed(message),
        }
    }
}
#[cfg(feature = "uniffi")]
impl From<crate::bindings::uniffi::ConversionError> for DataBackupCreateError {
    fn from(error: crate::bindings::uniffi::ConversionError) -> Self {
        Self::ConversionError(error.to_string())
    }
}
impl<T> From<PoisonError<T>> for DataBackupCreateError {
    fn from(_: PoisonError<T>) -> Self {
        Self::InternalError(DataBackupCreateInternalErrorCause::LockPoisoned)
    }
}

/// Source of a decoding error.
#[derive(Clone, Debug, thiserror::Error)]
pub enum DataBackupDecodeErrorSource {
    /// Reading failed.
    #[error(transparent)]
    ByteReaderError(#[from] ByteReaderError),

    /// Invalid message.
    #[error("Invalid message: {0}")]
    InvalidMessage(String),

    /// Invalid Threema ID.
    #[error("Invalid Threema ID: {0}")]
    InvalidThreemaId(#[from] ThreemaIdError),

    /// Missing field.
    #[error("Missing field in '{name}': '{field_name}'")]
    MissingField {
        /// Name of the enum/struct in which the field is missing.
        name: &'static str,

        /// Name of the missing field.
        field_name: &'static str,
    },

    /// Another kind of error occurred.
    #[error("{0}")]
    Other(String),

    /// Unable to decode a protobuf message.
    #[error(transparent)]
    ProstDecodeError(#[from] prost::DecodeError),

    /// Exhausted the available sequence numbers to use for decrypting pages.
    #[error("Sequence number overflow happened")]
    SequenceNumberOverflow(#[from] SequenceNumberOverflow),

    /// Unknown type.
    #[error("Unknown enum variant for '{name}': {variant}")]
    UnknownEnumVariant {
        /// Name of the enum.
        name: &'static str,

        /// Value of the (unknown) variant.
        variant: i32,
    },
}

/// Cause of an internal error during data backup restore.
#[derive(Clone, Debug, thiserror::Error)]
pub enum DataBackupRestoreInternalErrorCause {
    /// Unable to obtain a lock.
    #[error("Obtaining a lock failed")]
    LockPoisoned,

    /// Another kind of error occurred.
    #[error("{0}")]
    Other(String),
}
impl<T: Into<String>> From<T> for DataBackupRestoreInternalErrorCause {
    fn from(message: T) -> Self {
        Self::Other(message.into())
    }
}

/// An error occurred while restoring a backup.
///
/// When encountering an error:
///
/// 1. Let `error` be the provided [`DataBackupRestoreError`].
/// 2. Reset the state of the app to the state prior to starting the backup restoration.
/// 3. Abort the protocol due to `error`.
#[derive(Clone, Debug, thiserror::Error)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Error), uniffi(flat_error))]
pub enum DataBackupRestoreError {
    /// A contract violation occurred.
    ///
    /// This is likely the result of modifying the app state during the backup creation task.
    #[error("Contract violation: {0}")]
    ContractViolation(String),

    /// Some provided parameter could not be converted into the required internal representation.
    #[error("Conversion error: {0}")]
    ConversionError(String),

    /// Unable to decode a struct.
    #[error("Decoding '{name}' failed: {source}")]
    DecodingFailed {
        /// Name of the struct.
        name: &'static str,

        /// Error source.
        source: DataBackupDecodeErrorSource,
    },

    /// Unable to decrypt a struct.
    #[error("Decrypting '{name}' failed")]
    DecryptionFailed {
        /// Name of the struct.
        name: &'static str,
    },

    /// A foreign function considered infallible returned an error.
    #[cfg(any(test, feature = "uniffi", feature = "cli"))]
    #[error("Infallible function failed in foreign code: {0}")]
    ForeignFunctionFailed(String),

    /// The data backup is incomplete and cannot be restored.
    #[error("Incomplete backup encountered")]
    IncompleteDataBackup,

    /// An internal error happened.
    #[error("Internal error: {0}")]
    InternalError(#[from] DataBackupRestoreInternalErrorCause),

    /// Invalid state for the requested instruction.
    #[error("Invalid state: {0}")]
    InvalidState(String),

    /// The backup version is unsupported.
    #[error("Data backup version {0} is unsupported")]
    UnsupportedVersion(u16),
}
impl From<ProviderError> for DataBackupRestoreError {
    fn from(error: ProviderError) -> Self {
        match error {
            ProviderError::ConversionError(message) => Self::ConversionError(message),
            ProviderError::ContractViolation(message) => Self::ContractViolation(message),

            #[cfg(any(test, feature = "uniffi", feature = "cli"))]
            ProviderError::ForeignFunctionFailed(message) => Self::ForeignFunctionFailed(message),
        }
    }
}
impl<T> From<PoisonError<T>> for DataBackupRestoreError {
    fn from(_: PoisonError<T>) -> Self {
        Self::InternalError(DataBackupRestoreInternalErrorCause::LockPoisoned)
    }
}
