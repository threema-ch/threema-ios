use libthreema_dependencies::crypto::{
    aead::AeadInPlace as _,
    cipher::KeyInit as _,
    digest::{self, Mac as _},
    salsa20, x25519,
};
use libthreema_macros::concat_fixed_bytes;
use tracing::{debug, info};

use crate::{
    common::{
        Nonce,
        keys::{ClientKey, PublicKey},
    },
    csp::{
        ClientCookie, ClientSequenceNumber, Cookie, CspProtocolContext, CspProtocolError,
        CspProtocolInternalErrorCause, ServerCookie, ServerSequenceNumber, TemporaryClientKey,
        TemporaryServerKey,
        payload::{
            IncomingPayload, OutgoingPayload,
            handshake::{Extensions, LoginAck, LoginData, ServerChallengeResponse},
        },
    },
    utils::{debug::Name as _, sequence_numbers::SequenceNumberValue},
};

/// Concatenate a cookie and a sequence number to create a nonce.
///
/// Note: The sequence number is not incremented within this function!
#[inline]
#[expect(clippy::needless_pass_by_value, reason = "Prevent sequence number re-use")]
fn create_nonce(cookie: Cookie, sequence_number: SequenceNumberValue<u64>) -> Nonce {
    Nonce(concat_fixed_bytes!(cookie.0, sequence_number.0.to_le_bytes()))
}

/// Decrypt an incoming `server-challenge-response`.
///
/// Try all permanent server keys of `context`, and returns an error if none of them could be used
/// to decrypt the `server-challenge-response`.
pub(super) fn decrypt_server_challenge_response(
    context: &CspProtocolContext,
    temporary_client_key: &TemporaryClientKey,
    server_cookie: &ServerCookie,
    server_sequence_number: &mut ServerSequenceNumber,
    mut server_challenge_response_box: Vec<u8>,
) -> Result<(PublicKey, Vec<u8>), CspProtocolError> {
    // Compute the nonce once. Secure because we use different public keys for the same nonce.
    let nonce = create_nonce(server_cookie.0, server_sequence_number.0.get_and_increment()?);

    // Try to decrypt the server challenge response with all available permanent server keys.
    for permanent_server_key in &context.permanent_server_keys {
        let cipher = salsa20::XSalsa20Poly1305::new(
            temporary_client_key
                .0
                .diffie_hellman_hsalsa20(&permanent_server_key.0)
                .ok_or(CspProtocolError::ContractViolation(
                    "Non-contributory permanent public server key",
                ))?
                .as_bytes()
                .into(),
        );
        match cipher.decrypt_in_place((&nonce).into(), &[], &mut server_challenge_response_box) {
            Ok(()) => {
                debug!(?permanent_server_key, "Selected permanent server key");
                return Ok((*permanent_server_key, server_challenge_response_box));
            },
            Err(_) => {
                info!(mismatching_permanent_server_key = ?permanent_server_key,
                    "Decrypting server-challenge-response with server public key failed. \
                     Trying next one (if any)."
                );
            },
        }
    }

    // None of the permanent server keys was able to decrypt the challenge response.
    Err(CspProtocolError::DecryptionFailed {
        name: ServerChallengeResponse::NAME,
    })
}

struct VouchCipher {
    temporary_server_key: TemporaryServerKey,
    temporary_client_key_public: x25519::PublicKey,
}
impl VouchCipher {
    fn vouch_session(
        &self,
        client_key: &ClientKey,
        permanent_server_key: &PublicKey,
        server_cookie: &ServerCookie,
    ) -> Option<[u8; digest::MAC_256_LENGTH]> {
        // Obtain the CSP authentication secret (aka _vouch key_)
        let vouch_key =
            client_key.derive_csp_authentication_key(permanent_server_key, &self.temporary_server_key.0)?;

        // Compute the vouch from the vouch key and server_cookie || temporary_client_key_public
        Some(
            vouch_key
                .0
                .chain_update(server_cookie.0.0)
                .chain_update(self.temporary_client_key_public.as_bytes())
                .finalize()
                .into_bytes()
                .into(),
        )
    }
}

pub(super) struct SessionCipher {
    client_cookie: ClientCookie,
    client_sequence_number: ClientSequenceNumber,
    server_cookie: ServerCookie,
    server_sequence_number: ServerSequenceNumber,
    cipher: salsa20::XSalsa20Poly1305,
}
impl SessionCipher {
    /// Encrypt outgoing data in-place.
    fn encrypt(&mut self, name: &'static str, mut data: Vec<u8>) -> Result<Vec<u8>, CspProtocolError> {
        let nonce = create_nonce(
            self.client_cookie.0,
            self.client_sequence_number.0.get_and_increment()?,
        );
        self.cipher
            .encrypt_in_place((&nonce).into(), &[], &mut data)
            .map_err(|_| {
                CspProtocolError::InternalError(CspProtocolInternalErrorCause::EncryptionFailed { name })
            })?;
        Ok(data)
    }

    /// Decrypt incoming data in-place.
    fn decrypt(&mut self, name: &'static str, mut data: Vec<u8>) -> Result<Vec<u8>, CspProtocolError> {
        let nonce = create_nonce(
            self.server_cookie.0,
            self.server_sequence_number.0.get_and_increment()?,
        );
        self.cipher
            .decrypt_in_place((&nonce).into(), &[], &mut data)
            .map_err(|_| CspProtocolError::DecryptionFailed { name })?;
        Ok(data)
    }
}

pub(super) struct LoginBoxes {
    pub(super) login_data_box: Vec<u8>,
    pub(super) extensions_box: Vec<u8>,
}

pub(super) struct LoginCipher {
    vouch_cipher: VouchCipher,
    session_cipher: SessionCipher,
}
impl LoginCipher {
    /// Create the cipher needed to encrypt `login` contents.
    pub(super) fn new(
        temporary_client_key: &TemporaryClientKey,
        client_cookie: ClientCookie,
        client_sequence_number: ClientSequenceNumber,
        server_cookie: ServerCookie,
        server_sequence_number: ServerSequenceNumber,
        temporary_server_key: TemporaryServerKey,
    ) -> Option<Self> {
        let temporary_client_key_public = x25519::PublicKey::from(&temporary_client_key.0);
        let session_key = temporary_client_key
            .0
            .diffie_hellman_hsalsa20(&temporary_server_key.0.0)?;
        let session_cipher = SessionCipher {
            client_cookie,
            client_sequence_number,
            server_cookie,
            server_sequence_number,
            cipher: salsa20::XSalsa20Poly1305::new(session_key.as_bytes().into()),
        };
        let vouch_cipher = VouchCipher {
            temporary_server_key,
            temporary_client_key_public,
        };
        Some(Self {
            vouch_cipher,
            session_cipher,
        })
    }

    /// Dissolve the cipher, returning the wrapped [`SessionCipher`].
    pub(super) fn dissolve(self) -> SessionCipher {
        self.session_cipher
    }

    /// Create a vouch MAC for use in the `login`.
    #[inline]
    pub(super) fn vouch_session(
        &self,
        client_key: &ClientKey,
        permanent_server_key: &PublicKey,
    ) -> Option<[u8; digest::MAC_256_LENGTH]> {
        self.vouch_cipher.vouch_session(
            client_key,
            permanent_server_key,
            &self.session_cipher.server_cookie,
        )
    }

    /// Encrypt data of the `login` message in-place.
    #[inline]
    pub(super) fn encrypt_login(
        &mut self,
        login_data: Vec<u8>,
        extensions: Vec<u8>,
    ) -> Result<LoginBoxes, CspProtocolError> {
        let login_data_box = self.session_cipher.encrypt(LoginData::NAME, login_data)?;
        let extensions_box = self.session_cipher.encrypt(Extensions::NAME, extensions)?;
        Ok(LoginBoxes {
            login_data_box,
            extensions_box,
        })
    }
}

pub(super) struct LoginAckCipher {
    session_cipher: SessionCipher,
}
impl LoginAckCipher {
    /// Create the cipher needed to decrypt `login-ack` contents.
    pub(super) fn new(session_cipher: SessionCipher) -> Self {
        Self { session_cipher }
    }

    /// Dissolve the cipher, returning the wrapped [`SessionCipher`].
    pub(super) fn dissolve(self) -> SessionCipher {
        self.session_cipher
    }

    /// Decrypt data of the `login-ack` message in-place.
    pub(super) fn decrypt(&mut self, login_ack_box: Vec<u8>) -> Result<Vec<u8>, CspProtocolError> {
        self.session_cipher.decrypt(LoginAck::NAME, login_ack_box)
    }
}

/// Cipher to encrypt/decrypt outgoing/incoming payloads.
pub(super) struct PayloadCipher(SessionCipher);
impl PayloadCipher {
    /// Create the cipher needed to encrypt/decrypt payloads.
    pub(super) fn new(session_cipher: SessionCipher) -> Self {
        Self(session_cipher)
    }

    /// Encrypt an outgoing payload in-place.
    #[inline]
    pub(super) fn encrypt_payload(&mut self, payload: Vec<u8>) -> Result<Vec<u8>, CspProtocolError> {
        self.0.encrypt(OutgoingPayload::NAME, payload)
    }

    /// Decrypt an incoming payload in-place.
    #[inline]
    pub(super) fn decrypt_payload(&mut self, payload: Vec<u8>) -> Result<Vec<u8>, CspProtocolError> {
        self.0.decrypt(IncomingPayload::NAME, payload)
    }
}

#[cfg(test)]
mod tests {
    use assert_matches::assert_matches;
    use derive_builder::Builder;
    use libthreema_dependencies::crypto::{aead::Aead as _, cipher::KeyInit as _, salsa20, x25519};
    use rstest::rstest;

    use crate::{
        common::keys::PublicKey,
        csp::{
            Cookie, CspProtocolError, SequenceNumberU64, ServerChallengeResponse, ServerCookie,
            ServerSequenceNumber, TemporaryClientKey, cipher::create_nonce,
            decrypt_server_challenge_response, tests::ContextBuilder,
        },
        utils::{debug::Name as _, sequence_numbers::SequenceNumberValue},
    };

    #[derive(Builder)]
    #[builder(pattern = "owned")]
    struct ServerChallengeResponseTestContext {
        #[builder(default = "x25519::StaticSecret::from([1; x25519::KEY_LENGTH])")]
        temporary_server_key: x25519::StaticSecret,

        #[builder(default = "TemporaryClientKey(x25519::StaticSecret::from([2; x25519::KEY_LENGTH]))")]
        temporary_client_key: TemporaryClientKey,

        #[builder(default = "ServerCookie(Cookie([1; Cookie::LENGTH]))")]
        server_cookie: ServerCookie,

        #[builder(default = "1")]
        server_sequence_number: u64,

        #[builder(default = b"so ein quatsch".to_vec())]
        server_challenge_response: Vec<u8>,
    }
    impl ServerChallengeResponseTestContext {
        fn temporary_server_key_public(&self) -> PublicKey {
            PublicKey(x25519::PublicKey::from(&self.temporary_server_key))
        }

        fn server_sequence_number(&self) -> ServerSequenceNumber {
            ServerSequenceNumber(SequenceNumberU64::new(self.server_sequence_number))
        }

        fn create_server_challenge_response(&self) -> Vec<u8> {
            let cipher = salsa20::XSalsa20Poly1305::new(
                self.temporary_server_key
                    .diffie_hellman_hsalsa20(&x25519::PublicKey::from(&self.temporary_client_key.0))
                    .unwrap()
                    .as_bytes()
                    .into(),
            );
            let nonce = create_nonce(
                self.server_cookie.0,
                SequenceNumberValue(self.server_sequence_number),
            );
            cipher
                .encrypt((&nonce).into(), self.server_challenge_response.as_slice())
                .unwrap()
        }
    }

    #[rstest]
    #[case(vec![PublicKey::from([1; PublicKey::LENGTH])])]
    #[case(vec![PublicKey::from([1; PublicKey::LENGTH]), PublicKey::from([2; PublicKey::LENGTH])])]
    fn server_challenge_response_invalid_mismatching_permanent_server_keys(
        #[case] permanent_server_keys: Vec<PublicKey>,
    ) {
        let server_challenge_response_context = ServerChallengeResponseTestContextBuilder::default()
            .build()
            .unwrap();
        let csp_context = ContextBuilder::default()
            .with_permanent_server_keys(permanent_server_keys)
            .build();

        // Decrypting the challenge response should fail after trying all of them.
        let result = decrypt_server_challenge_response(
            &csp_context,
            &server_challenge_response_context.temporary_client_key,
            &server_challenge_response_context.server_cookie,
            &mut server_challenge_response_context.server_sequence_number(),
            server_challenge_response_context.create_server_challenge_response(),
        );
        assert_matches!(
            result,
            Err(CspProtocolError::DecryptionFailed {
                name: ServerChallengeResponse::NAME,
            })
        );
    }

    #[rstest]
    #[case(vec![PublicKey::from([0; PublicKey::LENGTH])])]
    #[case(vec![PublicKey::from([1; PublicKey::LENGTH]), PublicKey::from([0; PublicKey::LENGTH])])]
    fn server_challenge_response_invalid_non_contributory_permanent_server_key(
        #[case] permanent_server_keys: Vec<PublicKey>,
    ) {
        let server_challenge_response_context = ServerChallengeResponseTestContextBuilder::default()
            .build()
            .unwrap();
        let csp_context = ContextBuilder::default()
            .with_permanent_server_keys(permanent_server_keys)
            .build();

        // Decrypting the challenge response should fail because the key is non-contributory.
        let result = decrypt_server_challenge_response(
            &csp_context,
            &server_challenge_response_context.temporary_client_key,
            &server_challenge_response_context.server_cookie,
            &mut server_challenge_response_context.server_sequence_number(),
            server_challenge_response_context.create_server_challenge_response(),
        );
        assert_eq!(
            result,
            Err(CspProtocolError::ContractViolation(
                "Non-contributory permanent public server key"
            ))
        );
    }

    #[test]
    fn server_challenge_response_valid() {
        let server_challenge_response_context = ServerChallengeResponseTestContextBuilder::default()
            .build()
            .unwrap();
        let csp_context = ContextBuilder::default()
            .with_permanent_server_keys(vec![
                server_challenge_response_context.temporary_server_key_public(),
            ])
            .build();

        // Decrypting the challenge response should be successful.
        let (selected_permanent_server_key, server_challenge_response) = decrypt_server_challenge_response(
            &csp_context,
            &server_challenge_response_context.temporary_client_key,
            &server_challenge_response_context.server_cookie,
            &mut server_challenge_response_context.server_sequence_number(),
            server_challenge_response_context.create_server_challenge_response(),
        )
        .unwrap();
        assert_eq!(
            selected_permanent_server_key,
            server_challenge_response_context.temporary_server_key_public()
        );
        assert_eq!(
            server_challenge_response,
            server_challenge_response_context.server_challenge_response
        );
    }
}
