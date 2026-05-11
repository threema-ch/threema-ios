//! Bindings for the _Identity Create Task_.
use std::sync::{Arc, Mutex};

use crate::{
    bindings::uniffi::{
        config::{ConfigEnvironment, ConfigError},
        https::HttpsResult,
    },
    common::{
        ClientInfo,
        config::{self, Flavor},
    },
    csp_e2e::{CspE2eProtocolError, identity},
    https::HttpsRequest,
    utils::sync::MutexIgnorePoison as _,
};

/// Binding version [`identity::create::CreateIdentityContext`].
#[derive(uniffi::Record)]
pub struct CreateIdentityContext {
    #[expect(missing_docs, reason = "Binding version")]
    pub client_info: ClientInfo,

    /// The config environment.
    pub config_environment: ConfigEnvironment,

    #[expect(missing_docs, reason = "Binding version")]
    pub flavor: Flavor,
}
impl TryFrom<CreateIdentityContext> for identity::create::CreateIdentityContext {
    type Error = ConfigError;

    fn try_from(context: CreateIdentityContext) -> Result<Self, Self::Error> {
        let config = {
            let config_environment = config::ConfigEnvironment::try_from(context.config_environment)?;
            config::Config::from(config_environment)
        };

        Ok(Self {
            client_info: context.client_info,
            config: Arc::new(config),
            flavor: context.flavor,
        })
    }
}

/// Binding version [`identity::create::CreateIdentityResult`].
#[derive(uniffi::Record)]
pub struct CreateIdentityResult {
    #[expect(missing_docs, reason = "Binding version")]
    pub user_identity: String,

    #[expect(missing_docs, reason = "Binding version")]
    pub client_key: Vec<u8>,

    #[expect(missing_docs, reason = "Binding version")]
    pub server_group: u8,
}
impl From<identity::create::CreateIdentityResult> for CreateIdentityResult {
    fn from(result: identity::create::CreateIdentityResult) -> Self {
        Self {
            user_identity: result.identity.to_string(),
            client_key: result.client_key.as_bytes().as_ref().to_vec(),
            server_group: result.server_group.0,
        }
    }
}

/// Binding version of [`identity::create::CreateIdentityLoop`].
#[derive(uniffi::Enum)]
pub enum CreateIdentityLoop {
    #[expect(missing_docs, reason = "Binding version")]
    Instruction(HttpsRequest),

    #[expect(missing_docs, reason = "Binding version")]
    Done(CreateIdentityResult),
}
impl From<identity::create::CreateIdentityLoop> for CreateIdentityLoop {
    fn from(create_loop: identity::create::CreateIdentityLoop) -> Self {
        match create_loop {
            identity::create::CreateIdentityLoop::Instruction(
                identity::create::CreateIdentityInstruction { request },
            ) => Self::Instruction(request),
            identity::create::CreateIdentityLoop::Done(result) => Self::Done(result.into()),
        }
    }
}

/// Binding version of a [`identity::create::CreateIdentityTask::poll`] result.
#[derive(uniffi::Enum)]
pub enum CreateIdentityPollResult {
    #[expect(missing_docs, reason = "Binding version")]
    CreateLoop(CreateIdentityLoop),

    #[expect(missing_docs, reason = "Binding version")]
    Error(CspE2eProtocolError),
}
impl From<Result<identity::create::CreateIdentityLoop, CspE2eProtocolError>> for CreateIdentityPollResult {
    fn from(result: Result<identity::create::CreateIdentityLoop, CspE2eProtocolError>) -> Self {
        match result {
            Ok(create_loop) => Self::CreateLoop(create_loop.into()),
            Err(error) => Self::Error(error),
        }
    }
}

/// Binding version of [`identity::create::CreateIdentityTask`].
#[derive(uniffi::Object)]
pub struct CreateIdentityTask(Mutex<identity::create::CreateIdentityTask>);

#[uniffi::export]
impl CreateIdentityTask {
    /// Binding version of [`identity::create::CreateIdentityTask::new`].
    ///
    /// # Errors
    ///
    /// Returns a [`CspE2eProtocolError::Foreign`] if `context` contains invalid parameters.
    #[uniffi::constructor]
    pub fn new(context: CreateIdentityContext) -> Result<Self, ConfigError> {
        Ok(Self(Mutex::new(identity::create::CreateIdentityTask::new(
            context.try_into()?,
        ))))
    }

    /// Binding version of [`identity::create::CreateIdentityTask::poll`].
    pub fn poll(&self) -> CreateIdentityPollResult {
        self.0.lock_ignore_poison().poll().into()
    }

    /// Binding version of [`identity::create::CreateIdentityTask::response`].
    #[expect(clippy::missing_errors_doc, reason = "Binding version")]
    pub fn response(&self, response: HttpsResult) -> Result<(), CspE2eProtocolError> {
        self.0.lock_ignore_poison().response(response.into())
    }
}
