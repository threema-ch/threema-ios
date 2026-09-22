//! UniFFI bindings.
use std::sync::Arc;

use crate::bindings::uniffi::utils::logging::{LogDispatcher, LogLevel, init_logging};

pub mod common;
pub mod crypto;
pub mod csp_e2e;
pub mod d2d_rendezvous;
pub mod data_backup;
pub mod https;
pub mod id_backup;
pub mod model;
pub mod provider;
pub mod remote_secret;
pub mod utils;
pub mod work;

/// An item could not be converted to its internal counterpart. This indicates a violation of the contract
/// defined by the respective item.
#[derive(Debug, thiserror::Error, uniffi::Error)]
#[uniffi(flat_error)]
pub enum ConversionError {
    /// The item could not be converted because a contract was not adhered to.
    #[error("Contract violation for {name}: {reason}")]
    ContractViolation {
        /// Name of the affected item.
        name: String,

        /// Reason why it could not be converted.
        reason: String,
    },
}

/// Used for (foreign) functions that are considered infallible. In case the foreign function fails,
/// this error will be propagated back.
#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum InfallibleError {
    /// A foreign function considered infallible returned an error.
    #[error("Infallible function failed in foreign code: {0}")]
    Foreign(String),
}
impl From<uniffi::UnexpectedUniFFICallbackError> for InfallibleError {
    fn from(error: uniffi::UnexpectedUniFFICallbackError) -> Self {
        Self::Foreign(error.reason)
    }
}

/// Initialise libthreema.
///
/// IMPORTANT: This must be called **once** before making any other calls to libthreema in order to
/// set up the log dispatcher.
#[uniffi::export]
pub fn initialize(min_log_level: LogLevel, log_dispatcher: Arc<dyn LogDispatcher>) {
    init_logging(min_log_level, log_dispatcher);
}
