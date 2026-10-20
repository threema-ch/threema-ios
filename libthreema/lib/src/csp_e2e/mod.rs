//! Implementation of the end-to-end encryption layer of the _Chat Server Protocol_.
use core::{cell::RefCell, fmt};
use std::{
    collections::HashMap,
    rc::Rc,
    sync::{Arc, PoisonError},
};

use educe::Educe;
use libthreema_macros::Name;
use tracing::debug;

use crate::{
    common::{
        ClientInfo, D2xDeviceId, ThreemaId,
        config::{Config, Flavor},
        keys::{ClientKey, DeviceGroupKey},
    },
    csp::payload::MessageWithMetadataBox,
    csp_e2e::{
        contacts::lookup::ContactLookupCache, message::task::incoming::IncomingMessageTask,
        transaction::manager::TransactionManager,
    },
    https::endpoint::HttpsEndpointError,
    model::{
        contact::ContactProvider, conversation::ConversationProvider, group::GroupProvider,
        settings::SettingsProvider,
    },
    provider::{NonceProvider, ProviderError, ShortcutProvider},
    utils::{
        debug::Name as _,
        sequence_numbers::{SequenceNumberOverflow, SequenceNumberU32, SequenceNumberValue},
        serde::string,
    },
};

pub mod contacts;
pub mod identity;
pub mod message;
pub mod reflect;
pub mod transaction;

/// Cause of an internal error.
#[derive(Clone, Debug, thiserror::Error)]
pub enum CspE2eProtocolInternalErrorCause {
    /// Exhausted the available sequence numbers (e.g. for `ReflectId`s). Should never happen.
    #[error("Sequence number overflow happened")]
    SequenceNumberOverflow(#[from] SequenceNumberOverflow),

    /// Unable to encrypt a message or a struct.
    #[error("Encrypting '{name}' failed")]
    EncryptionFailed {
        /// Name of the message or struct.
        name: &'static str,
    },

    /// An internal error occurred when starting or committing a transaction.
    #[error("Transaction management failed: {0}")]
    TransactionManagementFailed(String),

    /// Unable to obtain a lock.
    #[error("Obtaining a lock failed")]
    LockPoisoned,

    /// Another kind of error occurred.
    #[error("{0}")]
    Other(String),
}
impl<T: Into<String>> From<T> for CspE2eProtocolInternalErrorCause {
    fn from(message: T) -> Self {
        Self::Other(message.into())
    }
}

/// An error occurred while running the end-to-end encryption layer of the _Chat Server Protocol_.
///
/// TODO(LIB-16): Clarify recoverability and what to do when encountering an error. so far, the idea is that
/// an error means unrecoverable and that the CSP or CSP/D2M connection needs to be restarted. a new instance
/// of the protocol can then be created with linear/exponential backoff.
#[derive(Clone, Debug, thiserror::Error)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Error), uniffi(flat_error))]
#[cfg_attr(
    feature = "wasm",
    derive(tsify::Tsify, serde::Serialize),
    serde(
        tag = "type",
        content = "details",
        rename_all = "kebab-case",
        rename_all_fields = "camelCase"
    ),
    tsify(into_wasm_abi)
)]
pub enum CspE2eProtocolError {
    /// A contract violation occurred.
    #[error("Contract violation: {0}")]
    ContractViolation(String),

    /// A foreign function considered infallible returned an error.
    #[cfg(any(test, feature = "uniffi", feature = "cli"))]
    #[error("Infallible function failed in foreign code: {0}")]
    ForeignFunctionFailed(String),

    /// An internal error happened.
    #[cfg_attr(feature = "wasm", serde(serialize_with = "string::to_string::serialize"))]
    #[error("Internal error: {0}")]
    InternalError(#[from] CspE2eProtocolInternalErrorCause),

    /// A desync occurred.
    ///
    /// This may be the result of...
    ///
    /// - a protocol violation from the client using this state machine (e.g. adding a contact to storage
    ///   without using the appropriate task), or
    /// - misbehaviour of another device in the device group (e.g. updating a contact without an appropriate
    ///   transaction), or
    /// - the mediator server misbehaving (e.g. forwarding reflected messages from another device while a
    ///   transaction is ongoing), or
    /// - an implementation error of this protocol state machine.
    ///
    /// If multi-device is active, device group integrity may have been compromised and relinking against
    /// another device is advisable.
    #[error("Desync error: {0}")]
    DesyncError(String),

    /// A network error occurred while communicating with a server.
    #[error("Network error: {0}")]
    NetworkError(String),

    /// A server misbehaved in an operation considered infallible.
    #[error("Server error: {0}")]
    ServerError(String),

    /// Invalid credentials (should only be relevant for Work and OnPrem) reported by a server caused an
    /// operation to fail.
    ///
    /// When processing this variant, notify the user that the Work credentials are invalid and request new
    /// ones. A new CSP connection may be retried after the credentials have been validated.
    #[error("Invalid credentials")]
    InvalidCredentials,

    /// A rate limit of a server has been exceeded.
    ///
    /// When processing this variant, ensure that a new CSP connection attempt is delayed by at least 10s.
    #[error("Rate limit exceeded")]
    RateLimitExceeded,
}
impl From<SequenceNumberOverflow> for CspE2eProtocolError {
    fn from(error: SequenceNumberOverflow) -> Self {
        Self::InternalError(CspE2eProtocolInternalErrorCause::from(error))
    }
}
impl From<HttpsEndpointError> for CspE2eProtocolError {
    fn from(error: HttpsEndpointError) -> Self {
        match error {
            HttpsEndpointError::NetworkError(_) | HttpsEndpointError::ChallengeExpired => {
                Self::NetworkError(error.to_string())
            },
            HttpsEndpointError::RateLimitExceeded => Self::RateLimitExceeded,
            HttpsEndpointError::InvalidCredentials => Self::InvalidCredentials,
            HttpsEndpointError::Forbidden
            | HttpsEndpointError::NotFound
            | HttpsEndpointError::InvalidChallenge
            | HttpsEndpointError::InvalidChallengeResponse
            | HttpsEndpointError::UnexpectedStatus(_)
            | HttpsEndpointError::CustomPossiblyLocalizedError(_)
            | HttpsEndpointError::DecodingFailed(_) => Self::ServerError(error.to_string()),
        }
    }
}
impl From<ProviderError> for CspE2eProtocolError {
    fn from(error: ProviderError) -> Self {
        match error {
            ProviderError::ConversionError(message) => Self::InternalError(message.into()),
            ProviderError::ContractViolation(message) => Self::DesyncError(message),
            #[cfg(any(test, feature = "uniffi", feature = "cli"))]
            ProviderError::ForeignFunctionFailed(message) => Self::ForeignFunctionFailed(message),
        }
    }
}
impl<T> From<PoisonError<T>> for CspE2eProtocolError {
    fn from(_: PoisonError<T>) -> Self {
        Self::InternalError(CspE2eProtocolInternalErrorCause::LockPoisoned)
    }
}

/// CSP-specific context information.
pub struct CspE2eContext {
    /// The user's identity.
    pub user_identity: ThreemaId,

    /// Client key.
    pub client_key: ClientKey,

    /// Application flavour.
    pub flavor: Flavor,
}

/// Common providers for the CSP E2E protocol.
pub struct CspE2eProtocolProviders {
    /// CSP nonce storage.
    pub csp_e2e_nonce_provider: Rc<RefCell<dyn NonceProvider>>,

    /// See [`ShortcutProvider`].
    pub shortcut: Rc<RefCell<dyn ShortcutProvider>>,

    /// See [`SettingsProvider`].
    // TODO(LIB-188): WRONG! This needs to refer to the effective settings, not the user settings.
    pub settings: Rc<RefCell<dyn SettingsProvider>>,

    /// See [`ContactProvider`].
    pub contacts: Rc<RefCell<dyn ContactProvider>>,

    /// See [`GroupProvider`].
    pub groups: Rc<RefCell<dyn GroupProvider>>,

    /// See [`ConversationProvider`].
    pub conversations: Rc<RefCell<dyn ConversationProvider>>,
}

/// Initializer for a [`D2xContext`].
pub struct D2xContextInit {
    /// The device's (D2X) ID.
    pub device_id: D2xDeviceId,

    /// The device group key.
    pub device_group_key: DeviceGroupKey,

    /// D2D nonce storage.
    pub nonce_provider: Box<RefCell<dyn NonceProvider>>,
}

/// Initializer for a [`CspE2eProtocolContext`].
pub struct CspE2eProtocolContextInit {
    /// Client info.
    pub client_info: ClientInfo,

    /// Configuration used by the protocol.
    pub config: Arc<Config>,

    /// See [`CspE2eContext`].
    pub csp_e2e: CspE2eContext,

    /// Optional D2X context, only available if multi-device is enabled, see [`D2xContext`].
    pub d2x: Option<D2xContextInit>,

    /// Data providers.
    pub providers: CspE2eProtocolProviders,
}

/// Sequence number used for outgoing reflections.
struct ReflectSequenceNumber(SequenceNumberU32);

/// The current D2M role.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum D2mRole {
    /// Follower role (i.e. not yet _leader_).
    Follower,

    /// Leader role.
    Leader,
}

/// D2M/D2D-specific context information.
pub struct D2xContext {
    /// The device's (D2X) ID.
    device_id: D2xDeviceId,

    /// The device group key.
    device_group_key: DeviceGroupKey,

    /// D2D nonce storage.
    nonce_provider: Box<RefCell<dyn NonceProvider>>,

    /// Sequence number used for outgoing reflections.
    reflect_id: ReflectSequenceNumber,

    /// The current D2M role.
    role: D2mRole,

    /// The transaction manager.
    transaction_manager: TransactionManager,
}
impl From<D2xContextInit> for D2xContext {
    fn from(init: D2xContextInit) -> Self {
        let transaction_manager = TransactionManager::new(init.device_group_key.transaction_scope_key());
        Self {
            device_id: init.device_id,
            device_group_key: init.device_group_key,
            nonce_provider: init.nonce_provider,
            reflect_id: ReflectSequenceNumber(SequenceNumberU32::new(0)),
            role: D2mRole::Follower,
            transaction_manager,
        }
    }
}

/// CSP E2EE protocol context.
pub struct CspE2eProtocolContext {
    /// Client info.
    client_info: ClientInfo,

    /// Configuration used by the protocol.
    config: Arc<Config>,

    /// See [`CspE2eContext`].
    csp_e2e: CspE2eContext,

    /// Optional D2X context, only available if multi-device is enabled, see [`D2xContext`].
    d2x: Option<D2xContext>,

    /// Providers.
    providers: CspE2eProtocolProviders,

    /// See [`ContactLookupCache`].
    contact_lookup_cache: ContactLookupCache,
}
impl From<CspE2eProtocolContextInit> for CspE2eProtocolContext {
    fn from(init: CspE2eProtocolContextInit) -> Self {
        Self {
            client_info: init.client_info,
            config: init.config,
            csp_e2e: init.csp_e2e,
            d2x: init.d2x.map(From::from),
            providers: init.providers,
            contact_lookup_cache: ContactLookupCache::new(HashMap::new()),
        }
    }
}

/// A D2M reflect ID.
#[derive(Clone, Copy, Eq, Hash, PartialEq, Name)]
pub struct ReflectId(pub u32);
impl fmt::Debug for ReflectId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}({:016x})", Self::NAME, self.0.to_be())
    }
}
impl From<SequenceNumberValue<u32>> for ReflectId {
    fn from(value: SequenceNumberValue<u32>) -> Self {
        Self(value.0)
    }
}

/// The Chat Server E2EE Protocol state machine.
///
/// TODO(LIB-16):
/// - How to use.
/// - Protocol must be recreated whenever a reconnection happens.
/// - Add linear/exponential backoff when retrying a connection.
/// - ...
#[derive(Educe)]
#[educe(Debug)]
pub struct CspE2eProtocol {
    #[educe(Debug(ignore))]
    context: CspE2eProtocolContext,
}
impl CspE2eProtocol {
    /// Initiate a new CSP E2EE protocol.
    #[must_use]
    #[tracing::instrument(skip_all)]
    pub fn new(context: CspE2eProtocolContextInit) -> Self {
        debug!("Creating CSP E2EE protocol");

        // Create initial state
        Self {
            context: CspE2eProtocolContext::from(context),
        }
    }

    /// Borrow current [`CspE2eProtocolContext`] state.
    #[inline]
    pub fn context(&mut self) -> &mut CspE2eProtocolContext {
        &mut self.context
    }

    /// TODO(LIB-16): How to use.
    ///
    /// # Errors
    ///
    /// TODO(LIB-16): Describe errors.
    #[tracing::instrument(skip_all, fields(?d2m_state))]
    pub fn update_d2m_state(&mut self, d2m_state: D2mRole) -> Result<(), CspE2eProtocolError> {
        let Some(d2m_context) = &mut self.context.d2x else {
            return Err(CspE2eProtocolError::ContractViolation(
                "MD context not initialized".to_owned(),
            ));
        };
        if matches!(d2m_context.role, D2mRole::Leader) && matches!(d2m_state, D2mRole::Follower) {
            return Err(CspE2eProtocolError::ContractViolation(
                "Downgrading D2M state is not allowed".to_owned(),
            ));
        }
        debug!("Updating D2M state");
        d2m_context.role = d2m_state;
        Ok(())
    }

    /// TODO(LIB-16): How to use.
    ///
    /// # Errors
    ///
    /// TODO(LIB-16): Describe errors.
    #[expect(clippy::unused_self, reason = "TODO(LIB-16)")]
    #[must_use]
    #[tracing::instrument(skip_all, fields(?payload))]
    pub fn handle_incoming_message(&self, payload: MessageWithMetadataBox) -> IncomingMessageTask {
        // TODO(LIB-16): Check for leading state!
        debug!("Creating incoming message task");
        IncomingMessageTask::new(payload)
    }
}
