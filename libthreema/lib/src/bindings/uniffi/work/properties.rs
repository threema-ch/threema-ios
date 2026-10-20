//! Bindings for the _Work Properties_.
use std::sync::Mutex;

use crate::{
    bindings::uniffi::{
        ConversionError,
        common::{ThreemaId, config::WorkServerBaseUrl, keys::ClientKey},
        https::HttpsResult,
    },
    common::{ClientInfo, config::WorkContext},
    https::HttpsRequest,
    work::properties::{self, WorkPropertiesUpdateError},
};

/// Binding version of [`properties::WorkPropertiesUpdateContext`].
#[derive(uniffi::Record)]
#[expect(missing_docs, reason = "Binding version")]
pub struct WorkPropertiesUpdateContext {
    pub client_info: ClientInfo,
    pub work_server_base_url: WorkServerBaseUrl,
    pub work_context: WorkContext,
    pub user_identity: ThreemaId,
    pub client_key: ClientKey,
}
impl TryFrom<WorkPropertiesUpdateContext> for properties::WorkPropertiesUpdateContext {
    type Error = ConversionError;

    fn try_from(context: WorkPropertiesUpdateContext) -> Result<Self, Self::Error> {
        Ok(Self {
            client_info: context.client_info,
            work_server_url: context.work_server_base_url.try_into()?,
            work_context: context.work_context,
            user_identity: context.user_identity.try_into()?,
            client_key: context.client_key.try_into()?,
        })
    }
}

/// Binding version of [`properties::WorkPropertiesUpdateLoop`].
#[derive(uniffi::Enum)]
#[expect(missing_docs, reason = "Binding version")]
pub enum WorkPropertiesUpdateLoop {
    Instruction(HttpsRequest),
    Done,
}
impl From<properties::WorkPropertiesUpdateLoop> for WorkPropertiesUpdateLoop {
    fn from(update_loop: properties::WorkPropertiesUpdateLoop) -> Self {
        match update_loop {
            properties::WorkPropertiesUpdateLoop::Instruction(
                properties::WorkPropertiesUpdateInstruction { request },
            ) => Self::Instruction(request),

            properties::WorkPropertiesUpdateLoop::Done(()) => Self::Done,
        }
    }
}

/// Binding version of [`properties::WorkPropertiesUpdateTask`].
#[derive(uniffi::Object)]
pub struct WorkPropertiesUpdateTask(Mutex<properties::WorkPropertiesUpdateTask>);

#[uniffi::export]
impl WorkPropertiesUpdateTask {
    /// Binding version of [`properties::WorkPropertiesUpdateTask::new`].
    ///
    /// # Errors
    ///
    /// Returns a [`WorkPropertiesUpdateError::ConversionError`] if `context` contains invalid
    /// parameters.
    #[uniffi::constructor]
    pub fn new(
        context: WorkPropertiesUpdateContext,
        work_properties: properties::WorkProperties,
    ) -> Result<Self, WorkPropertiesUpdateError> {
        Ok(Self(Mutex::new(properties::WorkPropertiesUpdateTask::new(
            context.try_into()?,
            work_properties,
        ))))
    }

    /// Binding version of [`properties::WorkPropertiesUpdateTask::poll`].
    #[expect(clippy::missing_errors_doc, reason = "Binding version")]
    pub fn poll(&self) -> Result<WorkPropertiesUpdateLoop, WorkPropertiesUpdateError> {
        self.0.lock()?.poll().map(WorkPropertiesUpdateLoop::from)
    }

    /// Binding version of [`properties::WorkPropertiesUpdateTask::response`].
    #[expect(clippy::missing_errors_doc, reason = "Binding version")]
    pub fn response(&self, response: HttpsResult) -> Result<(), WorkPropertiesUpdateError> {
        self.0.lock()?.response(response.into())
    }
}
