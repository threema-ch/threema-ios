//! The transaction manager.

use prost::Message as _;

use crate::{
    common::keys::DeviceGroupTransactionScopeCipher,
    crypto::aead::AeadRandomNonceAhead as _,
    csp_e2e::{CspE2eProtocolError, CspE2eProtocolInternalErrorCause},
    protobuf,
};

/// An error occured when registering or unregistering a transaction.
#[derive(Debug, thiserror::Error)]
pub(super) enum TransactionManagerError {
    /// Usage of nested transactions.
    #[error("Transaction of scope {} already running", scope.as_str_name())]
    NestedTransactions {
        /// The scope of the transaction that is already running.
        scope: protobuf::d2d::transaction_scope::Scope,
    },

    /// The scope of the currently registered transaction and the transaction being unregistered do not match.
    #[error("Running transaction is not of scope {}", scope.as_str_name())]
    ScopeMismatch {
        /// The scope of the transaction that is already running.
        scope: protobuf::d2d::transaction_scope::Scope,
    },

    /// The transaction cannot be unregistered because no transaction is currently running.
    #[error("No transaction is currently running")]
    NoRunningTransaction,

    /// The transaction scope could not be encrypted.
    #[error("Encrypting transaction scope failed")]
    EncryptionFailed,
}
impl From<TransactionManagerError> for CspE2eProtocolError {
    fn from(value: TransactionManagerError) -> Self {
        Self::InternalError(CspE2eProtocolInternalErrorCause::TransactionManagementFailed(
            value.to_string(),
        ))
    }
}

/// Ensures that no more than one transaction is running at a time as multiple transactions are a protocol
/// violation.
pub(crate) struct TransactionManager {
    running_transaction: Option<protobuf::d2d::transaction_scope::Scope>,
    transaction_scope_key: DeviceGroupTransactionScopeCipher,
}
impl TransactionManager {
    pub(crate) fn new(transaction_scope_key: DeviceGroupTransactionScopeCipher) -> Self {
        Self {
            running_transaction: None,
            transaction_scope_key,
        }
    }

    /// Register a transaction and encrypt the transaction scope.
    pub(super) fn register(
        &mut self,
        scope: protobuf::d2d::transaction_scope::Scope,
    ) -> Result<Vec<u8>, TransactionManagerError> {
        if let Some(transaction_scope) = self.running_transaction {
            return Err(TransactionManagerError::NestedTransactions {
                scope: transaction_scope,
            });
        }

        // Encrypt the transaction the scope.
        //
        // Note: We don't care if the scope is replayed, so not storing the nonce here.
        let mut encoded_scope = protobuf::d2d::TransactionScope { scope: scope.into() }.encode_to_vec();
        let _ = self
            .transaction_scope_key
            .0
            .encrypt_in_place_random_nonce_ahead(b"", &mut encoded_scope)
            .map_err(|_| TransactionManagerError::EncryptionFailed)?;

        // Register the transaction.
        self.running_transaction = Some(scope);

        Ok(encoded_scope)
    }

    /// Unregister a transaction.
    pub(super) fn unregister(
        &mut self,
        expected_scope: protobuf::d2d::transaction_scope::Scope,
    ) -> Result<(), TransactionManagerError> {
        self.ensure_transaction_running(expected_scope)?;
        // Unregister the transaction.
        self.running_transaction = None;
        Ok(())
    }

    /// Ensures a transaction with `expected_scope` is currently running.
    pub(super) fn ensure_transaction_running(
        &self,
        expected_scope: protobuf::d2d::transaction_scope::Scope,
    ) -> Result<(), TransactionManagerError> {
        let Some(scope) = self.running_transaction else {
            return Err(TransactionManagerError::NoRunningTransaction);
        };
        if expected_scope != scope {
            return Err(TransactionManagerError::ScopeMismatch { scope });
        }

        Ok(())
    }

    #[cfg(test)]
    pub(crate) fn running_transaction(&self) -> Option<protobuf::d2d::transaction_scope::Scope> {
        self.running_transaction
    }
}

#[cfg(test)]
mod tests {
    use assert_matches::assert_matches;
    use rstest::rstest;

    use super::*;
    use crate::{common::keys::DeviceGroupKey, protobuf};

    #[rstest]
    fn register_valid_transaction(
        #[values(
            protobuf::d2d::transaction_scope::Scope::UserProfileSync,
            protobuf::d2d::transaction_scope::Scope::ContactSync,
            protobuf::d2d::transaction_scope::Scope::GroupSync,
            protobuf::d2d::transaction_scope::Scope::DistributionListSync,
            protobuf::d2d::transaction_scope::Scope::SettingsSync,
            protobuf::d2d::transaction_scope::Scope::MdmParameterSync,
            protobuf::d2d::transaction_scope::Scope::NewDeviceSync,
            protobuf::d2d::transaction_scope::Scope::DropDevice,
            protobuf::d2d::transaction_scope::Scope::WorkSyncDelta,
            protobuf::d2d::transaction_scope::Scope::O2oCall
        )]
        scope: protobuf::d2d::transaction_scope::Scope,
    ) -> anyhow::Result<()> {
        let mut manager = TransactionManager::new(DeviceGroupKey::random().transaction_scope_key());
        let _ = manager.register(scope)?;
        assert_matches!(manager.running_transaction(), Some(running_scope) =>
            assert_eq!(running_scope, scope));
        Ok(())
    }

    #[rstest]
    fn multi_register_transaction(
        #[values(
            protobuf::d2d::transaction_scope::Scope::GroupSync,
            protobuf::d2d::transaction_scope::Scope::ContactSync
        )]
        scope: protobuf::d2d::transaction_scope::Scope,
    ) -> anyhow::Result<()> {
        let mut manager = TransactionManager::new(DeviceGroupKey::random().transaction_scope_key());
        let _ = manager.register(protobuf::d2d::transaction_scope::Scope::GroupSync)?;
        let error = manager.register(scope);
        assert_matches!(error, Err(TransactionManagerError::NestedTransactions { scope })
            => assert_eq!(scope, protobuf::d2d::transaction_scope::Scope::GroupSync));

        Ok(())
    }

    #[test]
    fn unregister_no_running_transaction() {
        let mut manager = TransactionManager::new(DeviceGroupKey::random().transaction_scope_key());
        let error = manager.unregister(protobuf::d2d::transaction_scope::Scope::GroupSync);
        assert_matches!(error, Err(TransactionManagerError::NoRunningTransaction));
    }

    #[test]
    fn unregister_wrong_transaction() -> anyhow::Result<()> {
        let mut manager = TransactionManager::new(DeviceGroupKey::random().transaction_scope_key());
        let _ = manager.register(protobuf::d2d::transaction_scope::Scope::GroupSync)?;
        let error = manager.unregister(protobuf::d2d::transaction_scope::Scope::ContactSync);
        assert_matches!(error, Err(TransactionManagerError::ScopeMismatch { scope })
            => assert_eq!(scope, protobuf::d2d::transaction_scope::Scope::GroupSync));

        Ok(())
    }

    #[rstest]
    fn unregister_valid_transaction(
        #[values(
            protobuf::d2d::transaction_scope::Scope::UserProfileSync,
            protobuf::d2d::transaction_scope::Scope::ContactSync,
            protobuf::d2d::transaction_scope::Scope::GroupSync,
            protobuf::d2d::transaction_scope::Scope::DistributionListSync,
            protobuf::d2d::transaction_scope::Scope::SettingsSync,
            protobuf::d2d::transaction_scope::Scope::MdmParameterSync,
            protobuf::d2d::transaction_scope::Scope::NewDeviceSync,
            protobuf::d2d::transaction_scope::Scope::DropDevice,
            protobuf::d2d::transaction_scope::Scope::WorkSyncDelta,
            protobuf::d2d::transaction_scope::Scope::O2oCall
        )]
        scope: protobuf::d2d::transaction_scope::Scope,
    ) -> anyhow::Result<()> {
        let mut manager = TransactionManager::new(DeviceGroupKey::random().transaction_scope_key());
        let _ = manager.register(scope)?;
        assert_matches!(manager.running_transaction(), Some(running_scope) =>
            assert_eq!(running_scope, scope));
        manager.unregister(scope)?;
        assert!(manager.running_transaction().is_none());

        Ok(())
    }
}
