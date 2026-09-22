//! Binding version of [`provider`].
use std::sync::Arc;

use crate::{
    bindings::uniffi::common::HashedNonce,
    common,
    provider::{self, ProviderError},
};

/// Binding version of [`provider::NonceProvider`].
#[expect(missing_docs, clippy::missing_errors_doc, reason = "Binding version")]
#[uniffi::export(with_foreign)]
pub trait NonceProvider: Send + Sync {
    fn add_many(&self, hashed_nonces: Vec<HashedNonce>) -> Result<(), ProviderError>;
    fn get_many(&self, batch_index: u64) -> Result<Vec<HashedNonce>, ProviderError>;
    fn has(&self, hashed_nonce: HashedNonce) -> Result<bool, ProviderError>;
}
impl<T: NonceProvider + ?Sized> provider::NonceProvider for Arc<T> {
    fn add_many(&mut self, hashed_nonces: Vec<common::HashedNonce>) -> Result<(), ProviderError> {
        NonceProvider::add_many(
            self.as_ref(),
            hashed_nonces.into_iter().map(HashedNonce::from).collect(),
        )
    }

    fn get_many(&self, batch_index: usize) -> Result<Vec<common::HashedNonce>, ProviderError> {
        NonceProvider::get_many(self.as_ref(), batch_index as u64)?
            .into_iter()
            .map(|nonce| Ok(common::HashedNonce::try_from(nonce)?))
            .collect()
    }

    fn has(&self, hashed_nonce: &common::HashedNonce) -> Result<bool, ProviderError> {
        NonceProvider::has(self.as_ref(), hashed_nonce.clone().into())
    }
}
