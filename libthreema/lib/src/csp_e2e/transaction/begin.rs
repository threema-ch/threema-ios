//! Task for beginning a transaction.
use core::mem;

use libthreema_macros::{DebugVariantNames, Name, VariantNames};
use prost::Message as _;
use tracing::{debug, info, warn};

use super::commit::{CommitTransactionResponse, CommitTransactionSubtask};
use crate::{
    common::{D2xDeviceId, keys::DeviceGroupTransactionScopeCipher, task::TaskLoop},
    crypto::aead::AeadRandomNonceAhead as _,
    csp_e2e::{CspE2eProtocolError, D2xContext},
    protobuf,
    utils::{debug::Name as _, time::Duration},
};

/// Instruction for beginning a transaction. See each variant's steps.
pub enum BeginTransactionInstruction {
    /// 1. Await a `TransactionEnded` message.
    /// 2. Poll again.
    TransactionRejected,

    /// 1. Send the `message` (`BeginTransaction`).
    /// 2. Let `response` be the result of selectively awaiting a `BeginTransactionAck` or
    ///    `TransactionRejected` message.
    /// 3. Provide the `response` to the associated task as a
    ///    [`BeginTransactionResponse::BeginTransactionReply`] and poll again.
    BeginTransaction {
        /// The D2M `BeginTransaction` message.
        message: protobuf::d2m::BeginTransaction,
    },

    /// 1. Send the `message` (`CommitTransaction`).
    /// 2. Let `response` be the result of selectively awaiting a `CommitTransactionAck`.
    /// 3. Provide the `response` to the associated task as a
    ///    [`BeginTransactionResponse::AbortTransactionResponse`] and poll again.
    AbortTransaction {
        /// The D2M `CommitTransaction` message.
        message: protobuf::d2m::CommitTransaction,
    },
}

/// Possible replies to a `BeginTransaction` message.
pub enum BeginTransactionReply {
    /// The transaction has been acknowledged and is now in progress.
    BeginTransactionAck(protobuf::d2m::BeginTransactionAck),

    /// The transaction has been rejected and needs to be retried.
    TransactionRejected(protobuf::d2m::TransactionRejected),
}

/// Possible response for an [`BeginTransactionInstruction`].
pub enum BeginTransactionResponse {
    /// Possible responses to a `BeginTransaction` message.
    BeginTransactionReply(BeginTransactionReply),

    /// Possible response to a `CommitTransaction` message (due to a graceful abort).
    AbortTransactionResponse(protobuf::d2m::CommitTransactionAck),
}

pub(crate) enum BeginTransactionResult {
    /// The transaction is now in progress (and consequently needs to be committed after the
    /// desired task has been fulfilled, or alternatively abandoned).
    TransactionInProgress,

    /// The transaction has been aborted by the precondition. If the transaction was in
    /// progress, it has since been committed.
    TransactionAborted,
}

pub(crate) type BeginTransactionLoop = TaskLoop<BeginTransactionInstruction, BeginTransactionResult>;

/// Decide whether the transaction is still required or whether it can be aborted.
pub(crate) enum PreconditionVerdict {
    /// Continue the transaction.
    Continue,

    /// Abort the transaction.
    ///
    /// Use this when the transaction has become obsolete. Do not use this for errors!
    Abort,
}

/// Precondition function to check if a transaction is still necessary.
///
/// Errors are propagated back to the task.
pub(crate) type PreconditionFn = Box<dyn Fn() -> Result<PreconditionVerdict, CspE2eProtocolError>>;

/// The transaction is either being initiated for the first time or it was rejected, so we need
/// to re-initiate it.
struct InitOrTransactionRejectedState {
    precondition: PreconditionFn,
    scope: protobuf::d2d::transaction_scope::Scope,
    time_to_live: Option<Duration>,
}

/// A `BeginTransaction` is being sent and we're waiting for the response.
struct BeginTransactionState {
    precondition: PreconditionFn,
    scope: protobuf::d2d::transaction_scope::Scope,
    time_to_live: Option<Duration>,
    reply: Option<BeginTransactionReply>,
}

/// The transaction is in progress but the precondition indicated that the transaction should be
/// aborted (i.e. committed without any further action).
struct AbortTransactionState {
    commit_transaction_task: CommitTransactionSubtask,
}

#[derive(DebugVariantNames, VariantNames)]
enum State {
    Error(CspE2eProtocolError),
    InitOrTransactionRejected(InitOrTransactionRejectedState),
    BeginTransaction(BeginTransactionState),
    AbortTransaction(AbortTransactionState),
    Done,
}
impl State {
    fn poll_init_or_transaction_rejected(
        context: &mut D2xContext,
        state: InitOrTransactionRejectedState,
    ) -> Result<(Self, BeginTransactionLoop), CspE2eProtocolError> {
        // The transaction is either being started for the first time or another transaction
        // ended, so we can retry. Before we do so, run the precondition.
        match (state.precondition)()? {
            PreconditionVerdict::Continue => {},
            PreconditionVerdict::Abort => {
                info!("Skipping transaction due to precondition abort");
                return Ok((
                    Self::Done,
                    BeginTransactionLoop::Done(BeginTransactionResult::TransactionAborted),
                ));
            },
        }

        // The precondition was fulfilled, register the transaction.
        let encrypted_scope = context.transaction_manager.register(state.scope)?;

        // Begin the transaction
        info!("Beginning transaction");
        Ok((
            Self::BeginTransaction(BeginTransactionState {
                precondition: state.precondition,
                scope: state.scope,
                time_to_live: state.time_to_live,
                reply: None,
            }),
            BeginTransactionLoop::Instruction(BeginTransactionInstruction::BeginTransaction {
                message: protobuf::d2m::BeginTransaction {
                    encrypted_scope,
                    ttl: state.time_to_live.map_or(0, |duration| {
                        u32::try_from(duration.as_secs()).unwrap_or(u32::MAX)
                    }),
                },
            }),
        ))
    }

    fn poll_begin_transaction(
        context: &mut D2xContext,
        state: BeginTransactionState,
    ) -> Result<(Self, BeginTransactionLoop), CspE2eProtocolError> {
        // Ensure the caller provided the reply
        let Some(reply) = state.reply else {
            return Err(CspE2eProtocolError::ContractViolation(format!(
                "BeginTransactionAck/TransactionRejected reply was not provided for '{}' state",
                Self::BEGIN_TRANSACTION,
            )));
        };

        // Process the reply
        Ok(match reply {
            // The transaction is now in progress
            BeginTransactionReply::BeginTransactionAck(..) => {
                // Run the precondition again...
                match (state.precondition)()? {
                    // Transaction still necessary, continue
                    PreconditionVerdict::Continue => {
                        info!("Transaction acknowledged, now in progress");
                        (
                            Self::Done,
                            BeginTransactionLoop::Done(BeginTransactionResult::TransactionInProgress),
                        )
                    },

                    // Transaction is obsolete now, so abort it by committing immediately
                    PreconditionVerdict::Abort => {
                        info!("Committing obsolete transaction due to precondition abort");
                        let (commit_transaction_task, commit_transaction_instruction) =
                            CommitTransactionSubtask::new(context, vec![], state.scope)?;
                        (
                            Self::AbortTransaction(AbortTransactionState {
                                commit_transaction_task,
                            }),
                            BeginTransactionLoop::Instruction(
                                BeginTransactionInstruction::AbortTransaction {
                                    message: commit_transaction_instruction.commit_transaction_message,
                                },
                            ),
                        )
                    },
                }
            },

            // The transaction was rejected due to another transaction being in progress
            BeginTransactionReply::TransactionRejected(transaction_rejected) => {
                fn decrypt_and_decode_transaction_scope(
                    transaction_scope_key: &DeviceGroupTransactionScopeCipher,
                    mut scope: Vec<u8>,
                ) -> Option<protobuf::d2d::transaction_scope::Scope> {
                    // Decrypt scope
                    if transaction_scope_key
                        .0
                        .decrypt_in_place_random_nonce_ahead(b"", &mut scope)
                        .is_err()
                    {
                        warn!("Ignoring scope that could not be decrypted in TransactionRejected message");
                        return None;
                    }

                    // Decode scope
                    let scope = match protobuf::d2d::TransactionScope::decode(scope.as_ref()) {
                        Ok(scope) => scope,
                        Err(error) => {
                            warn!(decode_error = ?error,
                                "Ignoring scope message that could not be decoded in \
                                 TransactionRejected message");
                            return None;
                        },
                    };
                    match protobuf::d2d::transaction_scope::Scope::try_from(scope.scope) {
                        Ok(scope) => Some(scope),
                        Err(error) => {
                            warn!(decode_error = ?error,
                                "Ignoring scope enum value that could not be decoded in \
                                 TransactionRejected message");
                            None
                        },
                    }
                }

                // Try to decrypt and decode the scope, unregister the transaction and go back to the initial
                // state.
                let other_device_id = D2xDeviceId(transaction_rejected.device_id);
                let other_scope = decrypt_and_decode_transaction_scope(
                    &context.device_group_key.transaction_scope_key(),
                    transaction_rejected.encrypted_scope,
                );
                context.transaction_manager.unregister(state.scope)?;
                info!(
                    ?other_device_id,
                    ?other_scope,
                    "Transaction rejected due to another transaction being in progress"
                );
                (
                    Self::InitOrTransactionRejected(InitOrTransactionRejectedState {
                        precondition: state.precondition,
                        scope: state.scope,
                        time_to_live: state.time_to_live,
                    }),
                    BeginTransactionLoop::Instruction(BeginTransactionInstruction::TransactionRejected),
                )
            },
        })
    }

    fn poll_abort_transaction(
        context: &mut D2xContext,
        state: AbortTransactionState,
    ) -> Result<(Self, BeginTransactionLoop), CspE2eProtocolError> {
        state
            .commit_transaction_task
            .poll(&mut context.transaction_manager)?;
        Ok((
            Self::Done,
            BeginTransactionLoop::Done(BeginTransactionResult::TransactionAborted),
        ))
    }
}

/// Subtask for beginning a transaction and looping until it has been established or aborted.
#[derive(Debug, Name)]
pub(crate) struct BeginTransactionSubtask {
    state: State,
}
impl BeginTransactionSubtask {
    pub(crate) fn new(
        precondition: PreconditionFn,
        scope: protobuf::d2d::transaction_scope::Scope,
        time_to_live: Option<Duration>,
    ) -> Self {
        Self {
            state: State::InitOrTransactionRejected(InitOrTransactionRejectedState {
                precondition,
                scope,
                time_to_live,
            }),
        }
    }

    #[tracing::instrument(skip_all, fields(?self))]
    pub(crate) fn poll(
        &mut self,
        context: &mut D2xContext,
    ) -> Result<BeginTransactionLoop, CspE2eProtocolError> {
        let result = match mem::replace(
            &mut self.state,
            State::Error(CspE2eProtocolError::ContractViolation(format!(
                "{} in a transitional state",
                Self::NAME
            ))),
        ) {
            State::Error(error) => Err(error),
            State::InitOrTransactionRejected(state) => {
                State::poll_init_or_transaction_rejected(context, state)
            },
            State::BeginTransaction(state) => State::poll_begin_transaction(context, state),
            State::AbortTransaction(state) => State::poll_abort_transaction(context, state),
            State::Done => Err(CspE2eProtocolError::ContractViolation(format!(
                "{} already done",
                Self::NAME
            ))),
        };
        match result {
            Ok((state, instruction)) => {
                self.state = state;
                debug!(state = ?self.state, "Changed state");
                Ok(instruction)
            },
            Err(error) => {
                self.state = State::Error(error.clone());
                debug!(state = ?self.state, "Changed state to error");
                Err(error)
            },
        }
    }

    #[tracing::instrument(skip_all, fields(?self))]
    pub(crate) fn response(&mut self, response: BeginTransactionResponse) -> Result<(), CspE2eProtocolError> {
        match response {
            BeginTransactionResponse::BeginTransactionReply(reply) => {
                let State::BeginTransaction(state) = &mut self.state else {
                    return Err(CspE2eProtocolError::ContractViolation(format!(
                        "Must be in '{}' state",
                        State::BEGIN_TRANSACTION
                    )));
                };
                let _ = state.reply.insert(reply);
                Ok(())
            },
            BeginTransactionResponse::AbortTransactionResponse(response) => {
                let State::AbortTransaction(state) = &mut self.state else {
                    return Err(CspE2eProtocolError::ContractViolation(format!(
                        "Must be in '{}' state",
                        State::ABORT_TRANSACTION
                    )));
                };
                state.commit_transaction_task.response(CommitTransactionResponse {
                    acknowledged_reflect_ids: vec![],
                    commit_transaction_ack: response,
                });
                Ok(())
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use assert_matches::assert_matches;
    use libthreema_dependencies::data_encoding::HEXLOWER_PERMISSIVE;

    use super::*;
    use crate::csp_e2e::transaction::tests::d2x_context;

    #[test]
    fn init_transaction_ack() -> anyhow::Result<()> {
        let mut context = d2x_context();
        // Make sure no transaction is currently running.
        assert_eq!(context.transaction_manager.running_transaction(), None);

        let state = InitOrTransactionRejectedState {
            precondition: Box::new(|| Ok(PreconditionVerdict::Continue)),
            scope: protobuf::d2d::transaction_scope::Scope::ContactSync,
            time_to_live: None,
        };

        let (state, instruction) = State::poll_init_or_transaction_rejected(&mut context, state)?;

        assert_matches!(state, State::BeginTransaction(_));
        assert_matches!(
            instruction,
            BeginTransactionLoop::Instruction(BeginTransactionInstruction::BeginTransaction { .. })
        );

        // Check that the transaction is registered.
        assert_matches!(context.transaction_manager.running_transaction(), Some(transaction)
            => assert_matches!(transaction, protobuf::d2d::transaction_scope::Scope::ContactSync));

        Ok(())
    }

    #[test]
    fn init_transaction_precondition_rejected() -> anyhow::Result<()> {
        let mut context = d2x_context();
        // Make sure no transaction is currently running.
        assert_eq!(context.transaction_manager.running_transaction(), None);

        let state = InitOrTransactionRejectedState {
            precondition: Box::new(|| Ok(PreconditionVerdict::Abort)),
            scope: protobuf::d2d::transaction_scope::Scope::ContactSync,
            time_to_live: None,
        };

        let (state, instruction) = State::poll_init_or_transaction_rejected(&mut context, state)?;
        assert_matches!(state, State::Done);
        assert_matches!(
            instruction,
            BeginTransactionLoop::Done(BeginTransactionResult::TransactionAborted)
        );

        assert_eq!(context.transaction_manager.running_transaction(), None);

        Ok(())
    }

    #[test]
    fn begin_transaction_rejected() -> anyhow::Result<()> {
        let mut context = d2x_context();
        // Register a transaction mocking what would have happened in the init state.
        let _ = context
            .transaction_manager
            .register(protobuf::d2d::transaction_scope::Scope::ContactSync)?;
        context
            .transaction_manager
            .ensure_transaction_running(protobuf::d2d::transaction_scope::Scope::ContactSync)?;

        let encrypted_group_sync_scope = HEXLOWER_PERMISSIVE.decode(
            "226440e3e7279f7d02ba7ffd876be495873748b1451728c97c49c23dea7d8671460ccd444cd82afc1001".as_bytes(),
        )?;
        let state = BeginTransactionState {
            precondition: Box::new(|| Ok(PreconditionVerdict::Continue)),
            scope: protobuf::d2d::transaction_scope::Scope::ContactSync,
            time_to_live: None,
            reply: Some(BeginTransactionReply::TransactionRejected(
                protobuf::d2m::TransactionRejected {
                    device_id: 0x02,
                    encrypted_scope: encrypted_group_sync_scope,
                },
            )),
        };
        let (state, instruction) = State::poll_begin_transaction(&mut context, state)?;
        assert_matches!(state, State::InitOrTransactionRejected(_));
        assert_matches!(
            instruction,
            BeginTransactionLoop::Instruction(BeginTransactionInstruction::TransactionRejected)
        );

        // Assert that the transaction was unregistered.
        assert_eq!(context.transaction_manager.running_transaction(), None);

        Ok(())
    }

    #[test]
    fn begin_transaction_precondition_rejected() -> anyhow::Result<()> {
        let mut context = d2x_context();
        // Register a transaction mocking what would have happened in the init state.
        let _ = context
            .transaction_manager
            .register(protobuf::d2d::transaction_scope::Scope::ContactSync)?;
        context
            .transaction_manager
            .ensure_transaction_running(protobuf::d2d::transaction_scope::Scope::ContactSync)?;

        let state = BeginTransactionState {
            precondition: Box::new(|| Ok(PreconditionVerdict::Abort)),
            scope: protobuf::d2d::transaction_scope::Scope::ContactSync,
            time_to_live: None,
            reply: Some(BeginTransactionReply::BeginTransactionAck(
                protobuf::d2m::BeginTransactionAck {},
            )),
        };
        let (state, instruction) = State::poll_begin_transaction(&mut context, state)?;
        assert_matches!(state, State::AbortTransaction(_));
        assert_matches!(
            instruction,
            BeginTransactionLoop::Instruction(BeginTransactionInstruction::AbortTransaction { .. })
        );

        // The transaction is still registered.
        assert_matches!(context.transaction_manager.running_transaction(), Some(transaction)
            => assert_eq!(transaction, protobuf::d2d::transaction_scope::Scope::ContactSync));

        Ok(())
    }

    #[test]
    fn abort_unregister_transaction() -> anyhow::Result<()> {
        let mut context = d2x_context();
        let _ = context
            .transaction_manager
            .register(protobuf::d2d::transaction_scope::Scope::ContactSync)?;
        context
            .transaction_manager
            .ensure_transaction_running(protobuf::d2d::transaction_scope::Scope::ContactSync)?;

        let (mut commit_transaction_task, _) = CommitTransactionSubtask::new(
            &mut context,
            vec![],
            protobuf::d2d::transaction_scope::Scope::ContactSync,
        )?;
        // Provide a response to the commit transaction task to advance its state.
        commit_transaction_task.response(CommitTransactionResponse {
            acknowledged_reflect_ids: vec![],
            commit_transaction_ack: protobuf::d2m::CommitTransactionAck {},
        });

        let state = AbortTransactionState {
            commit_transaction_task,
        };

        let (state, instruction) = State::poll_abort_transaction(&mut context, state)?;
        assert_matches!(state, State::Done);
        assert_matches!(
            instruction,
            BeginTransactionLoop::Done(BeginTransactionResult::TransactionAborted)
        );

        // The transaction should now be unregistered.
        assert_matches!(context.transaction_manager.running_transaction(), None);

        Ok(())
    }
}
