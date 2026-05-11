//! Bindings for the _Identity Create Task_.
use std::sync::Arc;

use ::serde::Deserialize;
use js_sys::Error;
use serde::Serialize;
use serde_bytes::ByteBuf;
use tsify::Tsify;
use wasm_bindgen::prelude::wasm_bindgen;

use crate::{
    bindings::wasm::{
        config::ConfigEnvironment,
        https::{HttpsRequest, HttpsResult},
    },
    common::{
        ClientInfo,
        config::{self, Flavor},
    },
    csp_e2e::{CspE2eProtocolError, identity},
};

/// Binding version of [`identity::create::CreateIdentityContext`].
#[derive(Tsify, Deserialize)]
#[serde(rename_all = "camelCase")]
#[tsify(from_wasm_abi)]
pub struct CreateIdentityContext {
    #[expect(missing_docs, reason = "Binding version")]
    pub client_info: ClientInfo,

    /// The config environment.
    pub config_environment: ConfigEnvironment,

    #[expect(missing_docs, reason = "Binding version")]
    pub flavor: Flavor,
}
impl TryFrom<CreateIdentityContext> for identity::create::CreateIdentityContext {
    type Error = Error;

    fn try_from(context: CreateIdentityContext) -> Result<Self, Self::Error> {
        let config = {
            let config_environment: config::ConfigEnvironment =
                config::ConfigEnvironment::try_from(context.config_environment)?;
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
#[derive(Tsify, Serialize)]
#[serde(rename_all = "camelCase")]
#[tsify(into_wasm_abi)]
pub struct CreateIdentityResult {
    #[expect(missing_docs, reason = "Binding version")]
    pub user_identity: String,

    #[expect(missing_docs, reason = "Binding version")]
    pub client_key: ByteBuf,

    #[expect(missing_docs, reason = "Binding version")]
    pub server_group: u8,
}
impl From<identity::create::CreateIdentityResult> for CreateIdentityResult {
    fn from(result: identity::create::CreateIdentityResult) -> Self {
        Self {
            user_identity: result.identity.to_string(),
            client_key: ByteBuf::from(result.client_key.as_bytes()),
            server_group: result.server_group.0,
        }
    }
}

/// Binding version of [`identity::create::CreateIdentityLoop`].
#[derive(Tsify, Serialize)]
#[serde(
    tag = "type",
    content = "value",
    rename_all = "kebab-case",
    rename_all_fields = "camelCase"
)]
#[tsify(into_wasm_abi)]
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
            ) => Self::Instruction(request.into()),
            identity::create::CreateIdentityLoop::Done(result) => CreateIdentityLoop::Done(result.into()),
        }
    }
}

/// Binding version of a [`identity::create::CreateIdentityTask::poll`] result.
#[derive(Tsify, Serialize)]
#[serde(
    tag = "type",
    content = "value",
    rename_all = "kebab-case",
    rename_all_fields = "camelCase"
)]
#[tsify(into_wasm_abi)]
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
#[wasm_bindgen]
pub struct CreateIdentityTask(identity::create::CreateIdentityTask);

#[wasm_bindgen]
impl CreateIdentityTask {
    /// Binding version of [`identity::create::CreateIdentityTask::new`].
    ///
    /// # Errors
    ///
    /// Returns an error if `context` contains invalid parameters.
    pub fn new(context: CreateIdentityContext) -> Result<Self, Error> {
        Ok(Self(identity::create::CreateIdentityTask::new(
            context.try_into()?,
        )))
    }

    /// Binding version of [`identity::create::CreateIdentityTask::poll`].
    pub fn poll(&mut self) -> CreateIdentityPollResult {
        self.0.poll().into()
    }

    /// Binding version of [`identity::create::CreateIdentityTask::response`].
    pub fn response(&mut self, response: HttpsResult) -> Option<CspE2eProtocolError> {
        self.0.response(response.into()).err()
    }
}
