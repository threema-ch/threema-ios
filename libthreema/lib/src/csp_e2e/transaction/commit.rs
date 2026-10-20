//! Task for committing an established transaction.
//!
//! Note: The only way to abort an established transaction is to disconnect and reconnect.
use libthreema_macros::Name;

use super::manager::TransactionManager;
use crate::{
    csp_e2e::{
        CspE2eProtocolError, D2xContext, ReflectId,
        reflect::{ReflectInstruction, ReflectPayload, ReflectResponse, ReflectSubtask},
    },
    protobuf,
    utils::debug::Name as _,
};

/// 1. Let `reflect-ids` be the list of all reflect IDs of `reflect_messages` that do not have the _ephemeral_
///    flag.
/// 2. Reflect each message of `reflect_messages` with the provided flags and ID as a `reflect` message.
/// 3. Send the `commit_transaction_message` (`CommitTransaction`).
/// 4. Let `acknowledged_reflect_ids` the collection of all `reflect-ack` messages while selectively awaiting
///    a `CommitTransactionAck`.
/// 5. Provide `acknowledged_reflect_ids` and the `CommitTransactionAck` to the associated task as a
///    [`CommitTransactionResponse`] and poll again.
#[derive(Debug)]
pub struct CommitTransactionInstruction {
    /// Messages to be reflected.
    pub reflect_messages: Vec<ReflectPayload>,

    /// The D2M `CommitTransaction` message.
    pub commit_transaction_message: protobuf::d2m::CommitTransaction,
}

/// Possible response for an [`CommitTransactionInstruction`].
pub struct CommitTransactionResponse {
    /// Acknowledgements for reflected messages.
    pub acknowledged_reflect_ids: Vec<ReflectId>,

    /// The transaction has been committed successfully.
    pub commit_transaction_ack: protobuf::d2m::CommitTransactionAck,
}

/// Subtask for committing a transaction and waiting until it has been committed.
#[derive(Debug, Name)]
pub(crate) struct CommitTransactionSubtask {
    reflect_task: ReflectSubtask,
    expected_transaction_scope: protobuf::d2d::transaction_scope::Scope,
    commit_transaction_ack: Option<protobuf::d2m::CommitTransactionAck>,
}
impl CommitTransactionSubtask {
    pub(crate) fn new(
        context: &mut D2xContext,
        reflect_messages: Vec<ReflectPayload>,
        expected_transaction_scope: protobuf::d2d::transaction_scope::Scope,
    ) -> Result<(Self, CommitTransactionInstruction), CspE2eProtocolError> {
        // Commit transaction only makes sense if a transaction is already running.
        context
            .transaction_manager
            .ensure_transaction_running(expected_transaction_scope)?;

        let (reflect_task, ReflectInstruction { reflect_messages }) = ReflectSubtask::new(reflect_messages);
        Ok((
            Self {
                reflect_task,
                expected_transaction_scope,
                commit_transaction_ack: None,
            },
            CommitTransactionInstruction {
                reflect_messages,
                commit_transaction_message: protobuf::d2m::CommitTransaction {},
            },
        ))
    }

    #[tracing::instrument(skip_all, fields(?self))]
    pub(crate) fn poll(
        self,
        transaction_manager: &mut TransactionManager,
    ) -> Result<(), CspE2eProtocolError> {
        // Ensure that we have received a commit transaction ack and unregister the transaction.
        if self.commit_transaction_ack.is_none() {
            return Err(CspE2eProtocolError::ContractViolation(format!(
                "Commit transaction ack was not provided for '{}' state",
                Self::NAME,
            )));
        }
        transaction_manager.unregister(self.expected_transaction_scope)?;

        // Advance the reflect task.
        self.reflect_task.poll()
    }

    #[tracing::instrument(skip_all, fields(?self))]
    pub(crate) fn response(&mut self, response: CommitTransactionResponse) {
        self.commit_transaction_ack = Some(response.commit_transaction_ack);
        self.reflect_task.response(ReflectResponse {
            acknowledged_reflect_ids: response.acknowledged_reflect_ids,
        });
    }
}

#[cfg(test)]
mod tests {
    use assert_matches::assert_matches;

    use super::*;
    use crate::csp_e2e::{CspE2eProtocolInternalErrorCause, transaction::tests::d2x_context};

    #[test]
    fn new_valid_without_reflect_ids() -> anyhow::Result<()> {
        let mut context = d2x_context();
        let _ = context
            .transaction_manager
            .register(protobuf::d2d::transaction_scope::Scope::ContactSync);
        let (_, instruction) = CommitTransactionSubtask::new(
            &mut context,
            vec![],
            protobuf::d2d::transaction_scope::Scope::ContactSync,
        )?;

        assert_eq!(instruction.reflect_messages.len(), 0);

        Ok(())
    }

    #[test]
    fn new_no_running_transaction() {
        let mut context = d2x_context();
        assert_matches!(context.transaction_manager.running_transaction(), None);

        let error = CommitTransactionSubtask::new(
            &mut context,
            vec![],
            protobuf::d2d::transaction_scope::Scope::ContactSync,
        );
        assert_matches!(
            error,
            Err(CspE2eProtocolError::InternalError(
                CspE2eProtocolInternalErrorCause::TransactionManagementFailed(_)
            ))
        );
    }

    #[test]
    fn poll_commit_running_transaction() -> anyhow::Result<()> {
        let mut context = d2x_context();
        let _ = context
            .transaction_manager
            .register(protobuf::d2d::transaction_scope::Scope::ContactSync);
        context
            .transaction_manager
            .ensure_transaction_running(protobuf::d2d::transaction_scope::Scope::ContactSync)?;

        let (mut state, _) = CommitTransactionSubtask::new(
            &mut context,
            vec![],
            protobuf::d2d::transaction_scope::Scope::ContactSync,
        )?;

        state.response(CommitTransactionResponse {
            acknowledged_reflect_ids: vec![],
            commit_transaction_ack: protobuf::d2m::CommitTransactionAck {},
        });

        state.poll(&mut context.transaction_manager)?;

        assert_matches!(context.transaction_manager.running_transaction(), None);

        Ok(())
    }
}
