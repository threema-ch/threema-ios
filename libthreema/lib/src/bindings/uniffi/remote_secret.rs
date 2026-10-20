//! Bindings for the _Remote Secret_.
pub mod setup {
    //! Bindings for the remote secret setup.
    use crate::{
        bindings::uniffi::{
            ConversionError,
            common::{ThreemaId, config::WorkServerBaseUrl, keys::ClientKey},
        },
        common::{ClientInfo, config::WorkContext},
        remote_secret::setup,
    };

    /// Binding version of [`setup::RemoteSecretSetupContext`].
    #[derive(uniffi::Record)]
    #[expect(missing_docs, reason = "Binding version")]
    pub struct RemoteSecretSetupContext {
        pub client_info: ClientInfo,
        pub work_server_base_url: WorkServerBaseUrl,
        pub work_context: WorkContext,
        pub user_identity: ThreemaId,
        pub client_key: ClientKey,
    }
    impl TryFrom<RemoteSecretSetupContext> for setup::RemoteSecretSetupContext {
        type Error = ConversionError;

        fn try_from(context: RemoteSecretSetupContext) -> Result<Self, Self::Error> {
            Ok(Self {
                client_info: context.client_info,
                work_server_url: context.work_server_base_url.try_into()?,
                work_context: context.work_context,
                user_identity: context.user_identity.try_into()?,
                client_key: context.client_key.try_into()?,
            })
        }
    }

    pub mod create {
        //! Bindings for the remote secret creation.
        use std::sync::Mutex;

        use crate::{
            bindings::uniffi::{
                ConversionError,
                common::{ThreemaId, keys::RemoteSecretHash},
                https::HttpsResult,
            },
            common,
            https::HttpsRequest,
            remote_secret::setup::{self, RemoteSecretSetupError, create},
        };

        /// Derive the Remote Secret Hash tied to an identity (RSHID).
        ///
        /// # Errors
        ///
        /// Returns a [`RemoteSecretSetupError::ConversionError`] if the inputs violate a contract.
        #[uniffi::export]
        pub fn derive_remote_secret_hash_for_identity(
            remote_secret_hash: RemoteSecretHash,
            user_identity: ThreemaId,
        ) -> Result<Vec<u8>, ConversionError> {
            Ok(common::keys::RemoteSecretHash::try_from(remote_secret_hash)?
                .derive_for_identity(user_identity.try_into()?)
                .0
                .to_vec())
        }

        /// Binding version of [`create::RemoteSecretCreateResult`].
        #[derive(uniffi::Record)]
        #[expect(clippy::struct_field_names, reason = "Names as defined in protocol")]
        pub struct RemoteSecretCreateResult {
            /// Established remote secret (32 bytes).
            pub remote_secret: Vec<u8>,

            /// Assigned remote secret authentication token (32 bytes).
            pub remote_secret_authentication_token: Vec<u8>,

            /// The hash derived from the `remote_secret` (32 bytes).
            pub remote_secret_hash: Vec<u8>,
        }
        impl From<create::RemoteSecretCreateResult> for RemoteSecretCreateResult {
            fn from(result: create::RemoteSecretCreateResult) -> Self {
                Self {
                    remote_secret: result.remote_secret.0.to_vec(),
                    remote_secret_authentication_token: result.remote_secret_authentication_token.0.to_vec(),
                    remote_secret_hash: result.remote_secret.derive_hash().0.to_vec(),
                }
            }
        }

        /// Binding version of [`create::RemoteSecretCreateLoop`].
        #[derive(uniffi::Enum)]
        pub enum RemoteSecretCreateLoop {
            #[expect(missing_docs, reason = "Binding version")]
            Instruction(HttpsRequest),

            #[expect(missing_docs, reason = "Binding version")]
            Done(RemoteSecretCreateResult),
        }
        impl From<create::RemoteSecretCreateLoop> for RemoteSecretCreateLoop {
            fn from(create_loop: create::RemoteSecretCreateLoop) -> Self {
                match create_loop {
                    create::RemoteSecretCreateLoop::Instruction(setup::RemoteSecretSetupInstruction {
                        request,
                    }) => Self::Instruction(request),

                    create::RemoteSecretCreateLoop::Done(result) => Self::Done(result.into()),
                }
            }
        }

        /// Binding version of [`create::RemoteSecretCreateTask`].
        #[derive(uniffi::Object)]
        pub struct RemoteSecretCreateTask(Mutex<create::RemoteSecretCreateTask>);

        #[uniffi::export]
        impl RemoteSecretCreateTask {
            /// Binding version of [`create::RemoteSecretCreateTask::new`].
            ///
            /// # Errors
            ///
            /// Returns a [`RemoteSecretSetupError::ConversionError`] if `context` contains invalid
            /// parameters.
            #[uniffi::constructor]
            pub fn new(context: super::RemoteSecretSetupContext) -> Result<Self, RemoteSecretSetupError> {
                Ok(Self(Mutex::new(create::RemoteSecretCreateTask::new(
                    context.try_into()?,
                ))))
            }

            /// Binding version of [`create::RemoteSecretCreateTask::poll`].
            #[expect(clippy::missing_errors_doc, reason = "Binding version")]
            pub fn poll(&self) -> Result<RemoteSecretCreateLoop, RemoteSecretSetupError> {
                self.0.lock()?.poll().map(RemoteSecretCreateLoop::from)
            }

            /// Binding version of [`create::RemoteSecretCreateTask::response`].
            #[expect(clippy::missing_errors_doc, reason = "Binding version")]
            pub fn response(&self, response: HttpsResult) -> Result<(), RemoteSecretSetupError> {
                self.0.lock()?.response(response.into())
            }
        }
    }

    pub mod delete {
        //! Bindings for the remote secret deletion.
        use std::sync::Mutex;

        use crate::{
            bindings::uniffi::{common::keys::RemoteSecretAuthenticationToken, https::HttpsResult},
            https::HttpsRequest,
            remote_secret::setup::{self, RemoteSecretSetupError, delete},
        };

        /// Binding version of [`delete::RemoteSecretDeleteLoop`].
        #[derive(uniffi::Enum)]
        pub enum RemoteSecretDeleteLoop {
            #[expect(missing_docs, reason = "Binding version")]
            Instruction(HttpsRequest),

            #[expect(missing_docs, reason = "Binding version")]
            Done,
        }
        impl From<delete::RemoteSecretDeleteLoop> for RemoteSecretDeleteLoop {
            fn from(delete_loop: delete::RemoteSecretDeleteLoop) -> Self {
                match delete_loop {
                    delete::RemoteSecretDeleteLoop::Instruction(setup::RemoteSecretSetupInstruction {
                        request,
                    }) => Self::Instruction(request),

                    delete::RemoteSecretDeleteLoop::Done(()) => Self::Done,
                }
            }
        }

        /// Binding version of [`delete::RemoteSecretDeleteTask`].
        #[derive(uniffi::Object)]
        pub struct RemoteSecretDeleteTask(Mutex<delete::RemoteSecretDeleteTask>);

        #[uniffi::export]
        impl RemoteSecretDeleteTask {
            /// Binding version of [`delete::RemoteSecretDeleteTask::new`].
            ///
            /// # Errors
            ///
            /// Returns a [`RemoteSecretSetupError::ConversionError`] if `context` contains invalid
            /// parameters or if the `remote_secret_authentication_token` is not exactly 32 bytes.
            #[uniffi::constructor]
            pub fn new(
                context: super::RemoteSecretSetupContext,
                remote_secret_authentication_token: RemoteSecretAuthenticationToken,
            ) -> Result<Self, RemoteSecretSetupError> {
                Ok(Self(Mutex::new(delete::RemoteSecretDeleteTask::new(
                    context.try_into()?,
                    remote_secret_authentication_token.try_into()?,
                ))))
            }

            /// Binding version of [`delete::RemoteSecretDeleteTask::poll`].
            #[expect(clippy::missing_errors_doc, reason = "Binding version")]
            pub fn poll(&self) -> Result<RemoteSecretDeleteLoop, RemoteSecretSetupError> {
                self.0.lock()?.poll().map(RemoteSecretDeleteLoop::from)
            }

            /// Binding version of [`delete::RemoteSecretDeleteTask::response`].
            #[expect(clippy::missing_errors_doc, reason = "Binding version")]
            pub fn response(&self, response: HttpsResult) -> Result<(), RemoteSecretSetupError> {
                self.0.lock()?.response(response.into())
            }
        }
    }
}

pub mod monitor {
    //! Bindings for the remote secret monitoring.
    use core::time::Duration;
    use std::sync::Mutex;

    use crate::{
        bindings::uniffi::{
            common::{
                ThreemaId,
                config::WorkServerBaseUrl,
                keys::{RemoteSecretAuthenticationToken, RemoteSecretHash, RemoteSecretHashForIdentity},
            },
            https::HttpsResult,
        },
        common::ClientInfo,
        https::HttpsRequest,
        remote_secret::monitor::{self, RemoteSecretMonitorError},
    };

    /// Binding version of [`monitor::RemoteSecretVerifier`].
    #[derive(uniffi::Enum)]
    #[expect(missing_docs, reason = "Binding version")]
    pub enum RemoteSecretVerifier {
        RemoteSecretHash(RemoteSecretHash),
        RemoteSecretHashForIdentity {
            user_identity: ThreemaId,
            remote_secret_hash_for_identity: RemoteSecretHashForIdentity,
        },
    }
    impl TryFrom<RemoteSecretVerifier> for monitor::RemoteSecretVerifier {
        type Error = RemoteSecretMonitorError;

        fn try_from(verifier: RemoteSecretVerifier) -> Result<Self, Self::Error> {
            Ok(match verifier {
                RemoteSecretVerifier::RemoteSecretHash(remote_secret_hash) => {
                    Self::RemoteSecretHash(remote_secret_hash.try_into()?)
                },
                RemoteSecretVerifier::RemoteSecretHashForIdentity {
                    user_identity,
                    remote_secret_hash_for_identity,
                } => Self::RemoteSecretHashForIdentity {
                    user_identity: user_identity.try_into()?,
                    remote_secret_hash_for_identity: remote_secret_hash_for_identity.try_into()?,
                },
            })
        }
    }

    /// Binding version of [`monitor::RemoteSecretMonitorInstruction`].
    #[derive(uniffi::Enum)]
    pub enum RemoteSecretMonitorInstruction {
        #[expect(missing_docs, reason = "Binding version")]
        Request(HttpsRequest),

        #[expect(missing_docs, reason = "Binding version")]
        Schedule {
            timeout: Duration,
            remote_secret: Option<Vec<u8>>,
        },
    }
    impl From<monitor::RemoteSecretMonitorInstruction> for RemoteSecretMonitorInstruction {
        fn from(instruction: monitor::RemoteSecretMonitorInstruction) -> Self {
            match instruction {
                monitor::RemoteSecretMonitorInstruction::Request(https_request) => {
                    Self::Request(https_request)
                },

                monitor::RemoteSecretMonitorInstruction::Schedule {
                    timeout,
                    remote_secret,
                } => Self::Schedule {
                    timeout,
                    remote_secret: remote_secret.map(|remote_secret| remote_secret.0.to_vec()),
                },
            }
        }
    }

    /// Binding version of [`monitor::RemoteSecretMonitorProtocol`].
    #[derive(uniffi::Object)]
    pub struct RemoteSecretMonitorProtocol(Mutex<monitor::RemoteSecretMonitorProtocol>);

    #[uniffi::export]
    impl RemoteSecretMonitorProtocol {
        /// Binding version of [`monitor::RemoteSecretMonitorProtocol::new`].
        ///
        /// # Errors
        ///
        /// Returns a [`RemoteSecretMonitorError::ConversionError`] if any of the inputs violates a contract.
        #[uniffi::constructor]
        pub fn new(
            client_info: ClientInfo,
            work_server_base_url: WorkServerBaseUrl,
            remote_secret_authentication_token: RemoteSecretAuthenticationToken,
            remote_secret_verifier: RemoteSecretVerifier,
        ) -> Result<Self, RemoteSecretMonitorError> {
            Ok(Self(Mutex::new(monitor::RemoteSecretMonitorProtocol::new(
                monitor::RemoteSecretMonitorContext {
                    client_info,
                    work_server_url: work_server_base_url.try_into()?,
                    remote_secret_authentication_token: remote_secret_authentication_token.try_into()?,
                    remote_secret_verifier: remote_secret_verifier.try_into()?,
                },
            ))))
        }

        /// Binding version of [`monitor::RemoteSecretMonitorProtocol::poll`].
        #[expect(clippy::missing_errors_doc, reason = "Binding version")]
        pub fn poll(&self) -> Result<RemoteSecretMonitorInstruction, RemoteSecretMonitorError> {
            self.0.lock()?.poll().map(RemoteSecretMonitorInstruction::from)
        }

        /// Binding version of [`monitor::RemoteSecretMonitorProtocol::response`].
        #[expect(clippy::missing_errors_doc, reason = "Binding version")]
        pub fn response(&self, response: HttpsResult) -> Result<(), RemoteSecretMonitorError> {
            self.0.lock()?.response(response.into())
        }
    }
}

pub mod wonky_field_encryption {
    //! Wonk field encryption utilities for iOS.
    use std::sync::Arc;

    use libthreema_dependencies::{
        crypto::chacha20,
        rand::{self, Rng as _},
    };

    use crate::{
        bindings::uniffi::{
            ConversionError,
            common::keys::RemoteSecret,
            crypto::{ChunkedXChaCha20Poly1305Decryptor, ChunkedXChaCha20Poly1305Encryptor, CryptoError},
        },
        common::{self, keys::WonkyFieldCipherKey},
    };

    /// A wonky field encryptor context created by [`WonkyFieldCipher::encryptor`].
    #[derive(uniffi::Record)]
    pub struct WonkyFieldEncryptorContext {
        /// The nonce that must be prepended to the ciphertext.
        pub nonce: Vec<u8>,

        /// The chunked encryptor to encrypt the field.
        pub encryptor: Arc<ChunkedXChaCha20Poly1305Encryptor>,
    }

    /// Wonky field cipher for the wonky database field encryption.
    ///
    /// A word of warning: This should generally be avoided. We only need it since the Threema iOS app would
    /// require a large refactoring prior to being able to leverage an encrypted database (`SQLCipher`) like
    /// all other Threema apps. Ultimately, that is still our goal but until that is reached, we need this
    /// wonky field encryption implementation footgun thingy.
    ///
    /// See [`Self::encryptor()`] and [`Self::decryptor()`] for the encryption resp. decryption flows.
    #[derive(uniffi::Object)]
    pub struct WonkyFieldCipher {
        key: WonkyFieldCipherKey,
    }

    #[uniffi::export]
    impl WonkyFieldCipher {
        /// Create a new wonky field cipher.
        ///
        /// # Errors
        ///
        /// Returns [`ConversionError`] if `remote_secret` violates the contract defined in [`RemoteSecret`].
        #[uniffi::constructor]
        pub fn new(remote_secret: RemoteSecret) -> Result<Self, ConversionError> {
            Ok(Self {
                key: common::keys::RemoteSecret::try_from(remote_secret)?.wonky_field_cipher_key(),
            })
        }

        /// Generate a new random nonce and instantiate a new [`ChunkedXChaCha20Poly1305Encryptor`].
        ///
        /// The flow to encrypt a database field is as follows:
        ///
        /// 1. Call this function and let `nonce` and `encryptor` as defined in the resulting
        ///    [`WonkyFieldEncryptorContext`].
        /// 2. Let `data` be the database field serialized to bytes.
        /// 3. Let `encrypted_data` be the chunkwise encryption of `data` using the `encryptor`'s
        ///    [`ChunkedXChaCha20Poly1305Encryptor::encrypt()`] method.
        /// 4. Let `tag` be the result of calling the `encryptor`'s
        ///    [`ChunkedXChaCha20Poly1305Encryptor::finalize()`] method.
        /// 5. Compose the encrypted database field by concatenating `nonce`, `encrypted_data`, and `tag`,
        ///    i.e., `encrypted_database_field = nonce || encrypted_data || tag`.
        #[must_use]
        #[expect(clippy::missing_panics_doc, reason = "Panic will never happen")]
        pub fn encryptor(&self) -> WonkyFieldEncryptorContext {
            let nonce = {
                let mut nonce = [0; chacha20::EXTENDED_NONCE_LENGTH];
                rand::thread_rng().fill(&mut nonce);
                nonce
            };

            WonkyFieldEncryptorContext {
                nonce: nonce.to_vec(),
                encryptor: Arc::new(
                    ChunkedXChaCha20Poly1305Encryptor::new(&self.key.0, &nonce, &[])
                        .expect("'key' and 'nonce' should have correct size."),
                ),
            }
        }

        /// Instantiate a new [`ChunkedXChaCha20Poly1305Decryptor`] from the given `nonce`.
        ///
        /// The flow to decrypt an encrypted database field is as follows:
        ///
        /// 1. Parse the encrypted database field (stored as bytes) into `nonce || encrypted_data || tag`
        ///    where `nonce` is 24 bytes long, and `tag` is 16 bytes long.
        /// 2. Let `decryptor` be the result of calling this function with `nonce` as argument.
        /// 3. Let `data` be the chunkwise decryption of `encrypted_data` using the `decryptor`'s
        ///    [`ChunkedXChaCha20Poly1305Decryptor::decrypt()`] method.
        /// 4. Verify the `tag` by calling the `decryptor`'s
        ///    [`ChunkedXChaCha20Poly1305Decryptor::finalize_verify()`] method. Abort if this fails.
        /// 5. Deserialize `data` into the data type of the corresponding database field.
        ///
        /// # Errors
        ///
        /// Returns [`CryptoError::ConversionError`] if `nonce` is not exactly 24 bytes.
        pub fn decryptor(&self, nonce: &[u8]) -> Result<ChunkedXChaCha20Poly1305Decryptor, CryptoError> {
            ChunkedXChaCha20Poly1305Decryptor::new(&self.key.0, nonce, &[])
        }
    }
}
