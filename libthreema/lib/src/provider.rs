//! Provider-related structs and definitions.
//!
//! Note: More specific providers are located next to their models.
use crate::common::HashedNonce;

/// Provider errors.
#[derive(Debug, thiserror::Error)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Error))]
#[cfg_attr(
    feature = "wasm",
    derive(tsify::Tsify, serde::Deserialize),
    serde(
        tag = "type",
        content = "details",
        rename_all = "kebab-case",
        rename_all_fields = "camelCase"
    ),
    tsify(from_wasm_abi)
)]
pub enum ProviderError {
    /// Some provided parameter could not be converted into the required internal representation.
    ///
    /// This error may be returned by both libthreema and apps and is intended for simple conversion errors
    /// where parameter data doesn't conform to the defined standard.
    ///
    /// # Examples
    ///
    /// - A [`u16`] was expected but the provided input is larger than `65535`.
    /// - When a Threema ID is expected but the string violates the definition of a Threema ID.
    /// - When a 32 byte sequence is expected but a byte sequence with a different length was provided.
    #[error("Conversion error: {0}")]
    ConversionError(String),

    /// An API contract was violated.
    ///
    /// This error may be returned by both libthreema and apps and is intended to be used for any API contract
    /// violations that go beyond simple conversion errors.
    ///
    /// # Examples
    ///
    /// - A task state machine requires a specific input variant but receives another variant.
    /// - A distribution list is being added where one of the members is an unknown contact.
    #[error("Contract violation: {0}")]
    ContractViolation(String),

    /// A foreign function considered infallible returned an error.
    ///
    /// This error is used by UniFFI when an unexpected error is being encountered while calling across FFI
    /// boundaries. It should not be used for any other case!
    #[cfg(any(test, feature = "uniffi", feature = "cli"))]
    #[error("Unexpected error from foreign function: {0}")]
    ForeignFunctionFailed(String),
}
#[cfg(feature = "uniffi")]
impl From<uniffi::UnexpectedUniFFICallbackError> for ProviderError {
    fn from(error: uniffi::UnexpectedUniFFICallbackError) -> Self {
        Self::ForeignFunctionFailed(error.reason)
    }
}
#[cfg(feature = "uniffi")]
impl From<crate::bindings::uniffi::ConversionError> for ProviderError {
    fn from(error: crate::bindings::uniffi::ConversionError) -> Self {
        Self::ConversionError(error.to_string())
    }
}

/// Nonce provider interface.
pub trait NonceProvider {
    /// 1. Store the hashed nonces in the storage, disregarding whether a hashed nonce was already present
    ///    before.
    ///
    /// # Errors
    ///
    /// This function is considered infallible and should not return an error.
    fn add_many(&mut self, hashed_nonces: Vec<HashedNonce>) -> Result<(), ProviderError>;

    /// 1. Deterministically partition the stored hashed nonces into non-empty, incrementally zero-based
    ///    numbered batches¹.
    /// 2. Return the batch with index `batch_index`.
    ///
    /// ¹: IMPORTANT: Batches must be non-overlapping between function calls! However, the surrounding
    /// protocol ensures that the batching mechanism is only used in a uninterruptible (_read-only_) state.
    /// A batch should contain about 2^15 hashed nonces. An empty batch signals that no further nonces are
    /// available.
    ///
    /// # Errors
    ///
    /// In case libthreema provides invalid parameters.
    //-
    // TODO(LIB-168): Replace with iterator pattern.
    fn get_many(&self, batch_index: usize) -> Result<Vec<HashedNonce>, ProviderError>;

    /// 1. Look up `hashed_nonce` in the associated context.
    /// 2. Return whether `hashed_nonce` already exists in the storage.
    ///
    /// # Errors
    ///
    /// This function is considered infallible and should not return an error.
    fn has(&self, hashed_nonce: &HashedNonce) -> Result<bool, ProviderError>;
}

/// Makes dirty shortcuts to get things done faster initially. Contains the pure essence of tech debt. Expect
/// things to be changed or removed quickly.
pub trait ShortcutProvider {
    /// Handle a `web-session-resume` sent from `*3MAPUSH`.
    ///
    /// # Errors
    ///
    /// This function is considered infallible and should not return an error.
    fn handle_web_session_resume_payload(&mut self, payload: Vec<u8>) -> Result<(), ProviderError>;
}
