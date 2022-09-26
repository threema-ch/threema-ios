//! Error types used in saltyrtc-task-relayed-data.
//!
//! The implementation is done using the
//! [`failure`](https://crates.io/crates/failure) crate.

use std::convert::From;

use saltyrtc_client::errors::SaltyError;


/// Errors that are exposed to the user of the library.
#[derive(Fail, Debug, PartialEq)]
pub enum RelayedDataError {
    /// SaltyRTC Client error.
    #[fail(display = "A SaltyRTC client error occurred: {}", _0)]
    SaltyClient(#[cause] SaltyError),

    /// A message cannot be written to / read from a channel.
    #[fail(display = "A channel error occurred: {}", _0)]
    Channel(String),

    /// An unexpected error. This should never happen and indicates a bug in
    /// the implementation.
    #[fail(display = "An unexpected error occurred: {}. This indicates a bug and should be reported!", _0)]
    Crash(String),
}

impl From<SaltyError> for RelayedDataError {
    fn from(e: SaltyError) -> Self {
        RelayedDataError::SaltyClient(e)
    }
}

/// A result with [`RelayedDataError`](enum.RelayedDataError.html) as error type.
pub type RelayedDataResult<T> = ::std::result::Result<T, RelayedDataError>;
