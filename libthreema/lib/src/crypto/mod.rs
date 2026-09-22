//! Crypto extensions.
pub mod chunked;

/// Extensions for AEAD ciphers.
pub(crate) mod aead {
    use libthreema_dependencies::{
        crypto::{
            aead::{AeadInPlace, Error, Nonce, Payload, Result},
            cipher::Unsigned as _,
        },
        rand,
    };

    use crate::utils::bytes::InsertSlice as _;

    // TODO(LIB-31): Use `ByteWriter`?
    pub(crate) trait AeadRandomNonceAhead: AeadInPlace {
        /// Encrypt the given buffer containing a plaintext message in-place, place a random nonce ahead and
        /// return the used nonce.
        ///
        /// The buffer must have sufficient capacity to store the random nonce ahead of the ciphertext
        /// message, which will always be larger than the original plaintext. The exact size needed is
        /// cipher-dependent, but generally includes the size of an authentication tag.
        ///
        /// Returns an error if the buffer has insufficient capacity to store the resulting ciphertext
        /// message.
        fn encrypt_in_place_random_nonce_ahead(
            &self,
            associated_data: &[u8],
            buffer: &mut Vec<u8>,
        ) -> Result<Nonce<Self>> {
            let nonce = Self::generate_nonce(rand::thread_rng());
            self.encrypt_in_place(&nonce, associated_data, buffer)?;
            buffer.insert_at(0, &nonce);
            Ok(nonce)
        }

        /// Decrypt the message with the random nonce ahead in-place, returning the nonce or an error in the
        /// event the provided authentication tag does not match the given ciphertext.
        ///
        /// The buffer will be truncated to the original plaintext message upon success.
        fn decrypt_in_place_random_nonce_ahead(
            &self,
            associated_data: &[u8],
            buffer: &mut Vec<u8>,
        ) -> Result<Nonce<Self>> {
            if buffer.len() < Self::NonceSize::to_usize() {
                return Err(Error);
            }
            let nonce = Nonce::<Self>::from(buffer.drain(..Self::NonceSize::to_usize()).collect());
            self.decrypt_in_place(&nonce, associated_data, buffer)?;
            Ok(nonce)
        }

        /// Encrypt the given plaintext payload and a random nonce ahead, and return the used nonce along the
        /// resulting ciphertext as a vector of bytes.
        ///
        /// The [`Payload`] type can be used to provide Additional Associated Data (AAD) along with the
        /// message: this is an optional bytestring which is not encrypted, but *is* authenticated along with
        /// the message. Failure to pass the same AAD that was used during encryption will cause decryption to
        /// fail, which is useful if you would like to "bind" the ciphertext to some other identifier, like a
        /// digital signature key or other identifier.
        ///
        /// If you don't care about AAD and just want to encrypt a plaintext message, `&[u8]` will
        /// automatically be coerced into a `Payload`:
        ///
        /// ```nobuild
        /// let plaintext = b"Top secret message, handle with care";
        /// let ciphertext = cipher.encrypt_random_nonce_ahead(plaintext);
        /// ```
        fn encrypt_random_nonce_ahead<'message, 'aad, TPlaintext: Into<Payload<'message, 'aad>>>(
            &self,
            plaintext: TPlaintext,
        ) -> Result<(Nonce<Self>, Vec<u8>)> {
            let payload: Payload<'message, 'aad> = plaintext.into();
            let mut buffer = payload.msg.to_vec();
            let nonce = self.encrypt_in_place_random_nonce_ahead(payload.aad, &mut buffer)?;
            Ok((nonce, buffer))
        }

        /// Decrypt the given ciphertext slice with the random nonce ahead, and return the resulting nonce
        /// along the plaintext as a vector of bytes.
        ///
        /// See notes on [`Aead::encrypt()`] about allowable message payloads and Associated Additional Data
        /// (AAD).
        ///
        /// If you have no AAD, you can call this as follows:
        ///
        /// ```nobuild
        /// let ciphertext = b"...";
        /// let plaintext = cipher.decrypt_random_nonce_ahead(ciphertext)?;
        /// ```
        #[cfg(test)]
        fn decrypt_random_nonce_ahead<'message, 'aad, TCiphertext: Into<Payload<'message, 'aad>>>(
            &self,
            ciphertext: TCiphertext,
        ) -> Result<(Nonce<Self>, Vec<u8>)> {
            let payload: Payload<'message, 'aad> = ciphertext.into();
            let mut buffer = payload.msg.to_vec();
            let nonce = self.decrypt_in_place_random_nonce_ahead(payload.aad, &mut buffer)?;
            Ok((nonce, buffer))
        }
    }

    impl<TAlgorithm: AeadInPlace> AeadRandomNonceAhead for TAlgorithm {}

    #[cfg(test)]
    mod tests {
        use assert_matches::assert_matches;
        use libthreema_dependencies::{
            crypto::{
                chacha20::{ChaCha20Poly1305, XChaCha20Poly1305},
                cipher::{KeyInit as _, Unsigned as _},
                salsa20::XSalsa20Poly1305,
            },
            rand,
        };
        use rstest::rstest;

        use crate::crypto::aead::AeadRandomNonceAhead;

        #[rstest]
        #[case(XSalsa20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(XChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(ChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        fn encrypt_nonce_in_place_ahead<TCipher: AeadRandomNonceAhead>(
            #[case] cipher: TCipher,
        ) -> anyhow::Result<()> {
            let mut buffer = vec![1_u8; 300];
            let data_length = buffer.len();
            let nonce = cipher
                .encrypt_in_place_random_nonce_ahead(b"", &mut buffer)?
                .to_vec();

            let nonce_length = TCipher::NonceSize::to_usize();

            assert_eq!(nonce, buffer.get(0..nonce_length).unwrap());

            assert_eq!(
                buffer.len(),
                nonce_length + data_length + TCipher::TagSize::to_usize()
            );

            Ok(())
        }

        #[rstest]
        #[case(XSalsa20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(XChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(ChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        fn encrypt_nonce_ahead<TCipher: AeadRandomNonceAhead>(#[case] cipher: TCipher) -> anyhow::Result<()> {
            let data = vec![1_u8; 300];
            let (nonce, encrypted_data) = cipher.encrypt_random_nonce_ahead(data.as_slice())?;

            let nonce_length = TCipher::NonceSize::to_usize();

            assert_eq!(nonce.to_vec(), encrypted_data.get(0..nonce_length).unwrap());

            assert_eq!(
                encrypted_data.len(),
                nonce_length + data.len() + TCipher::TagSize::to_usize()
            );

            Ok(())
        }

        #[rstest]
        #[case(XSalsa20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(XChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(ChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        fn decrypt_nonce_ahead_nonce_fail_too_small<TCipher: AeadRandomNonceAhead>(#[case] cipher: TCipher) {
            let mut buffer = vec![1_u8; 3];

            assert!(
                cipher
                    .decrypt_in_place_random_nonce_ahead(b"", &mut buffer)
                    .is_err()
            );
        }

        #[rstest]
        #[case(XSalsa20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(XChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(ChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        fn decrypt_in_place_nonce_ahead_fail_tag<TCipher: AeadRandomNonceAhead>(#[case] cipher: TCipher) {
            let mut buffer = vec![1_u8; 128];
            let error = cipher.decrypt_in_place_random_nonce_ahead(b"", &mut buffer);
            assert_matches!(error, Err(_));

            let buffer = &[1_u8; 128];
            assert!(cipher.decrypt_random_nonce_ahead(buffer.as_slice()).is_err());
        }

        #[rstest]
        #[case(XSalsa20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(XChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(ChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        fn decrypt_in_place_nonce_ahead_valid<TCipher: AeadRandomNonceAhead>(
            #[case] cipher: TCipher,
        ) -> anyhow::Result<()> {
            let mut buffer = vec![1_u8; 300];
            let decrypted_data = buffer.clone();
            let nonce = cipher
                .encrypt_in_place_random_nonce_ahead(b"", &mut buffer)?
                .to_vec();

            let decryption_nonce = cipher
                .decrypt_in_place_random_nonce_ahead(b"", &mut buffer)?
                .to_vec();

            let nonce_length = TCipher::NonceSize::to_usize();

            assert_eq!(nonce, decryption_nonce);
            assert_eq!(decryption_nonce.len(), nonce_length);
            assert_eq!(buffer, decrypted_data);

            Ok(())
        }

        #[rstest]
        #[case(XSalsa20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(XChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(ChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        fn decrypt_nonce_ahead_valid<TCipher: AeadRandomNonceAhead>(
            #[case] cipher: TCipher,
        ) -> anyhow::Result<()> {
            let mut buffer = vec![1_u8; 300];
            let original_data = buffer.clone();
            let nonce = cipher
                .encrypt_in_place_random_nonce_ahead(b"", &mut buffer)?
                .to_vec();

            let (decryption_nonce, decrypted_data) = cipher.decrypt_random_nonce_ahead(buffer.as_slice())?;

            let nonce_length = TCipher::NonceSize::to_usize();

            assert_eq!(nonce, decryption_nonce.to_vec());
            assert_eq!(decryption_nonce.len(), nonce_length);
            assert_eq!(original_data, decrypted_data);

            Ok(())
        }

        #[rstest]
        #[case(XSalsa20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(XChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(ChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        fn check_nonce_randomness_in_place<TCipher: AeadRandomNonceAhead>(
            #[case] cipher: TCipher,
        ) -> anyhow::Result<()> {
            let mut first_buffer = vec![1_u8; 300];
            let mut second_buffer = first_buffer.clone();
            let first_nonce = cipher
                .encrypt_in_place_random_nonce_ahead(b"", &mut first_buffer)?
                .to_vec();

            let second_nonce = cipher
                .encrypt_in_place_random_nonce_ahead(b"", &mut second_buffer)?
                .to_vec();

            assert_ne!(first_nonce, second_nonce);
            assert_ne!(first_buffer, second_buffer);

            Ok(())
        }

        #[rstest]
        #[case(XSalsa20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(XChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(ChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        fn check_nonce_randomness<TCipher: AeadRandomNonceAhead>(
            #[case] cipher: TCipher,
        ) -> anyhow::Result<()> {
            let data = vec![1_u8; 300];
            let (first_nonce, first_encrypted_data) = cipher.encrypt_random_nonce_ahead(data.as_slice())?;

            let (second_nonce, second_encrypted_data) = cipher.encrypt_random_nonce_ahead(data.as_slice())?;

            assert_ne!(first_nonce, second_nonce);
            assert_ne!(first_encrypted_data, second_encrypted_data);

            Ok(())
        }

        #[rstest]
        #[case(XSalsa20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(XChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(ChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        fn nonce_ahead_encryption_compatibility<TCipher: AeadRandomNonceAhead>(
            #[case] cipher: TCipher,
        ) -> anyhow::Result<()> {
            let mut buffer = vec![1_u8; 12];
            let data = buffer.clone();
            let nonce = cipher.encrypt_in_place_random_nonce_ahead(b"", &mut buffer)?;

            let mut buffer = buffer.get(TCipher::NonceSize::to_usize()..).unwrap().to_vec();
            cipher.decrypt_in_place(&nonce, b"", &mut buffer)?;

            assert_eq!(data, buffer);

            Ok(())
        }

        #[rstest]
        #[case(XSalsa20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(XChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        #[case(ChaCha20Poly1305::new_from_slice(&[1; 32]).unwrap())]
        fn nonce_ahead_decryption_compatibility<TCipher: AeadRandomNonceAhead>(
            #[case] cipher: TCipher,
        ) -> anyhow::Result<()> {
            let mut buffer = vec![1_u8; 300];
            let nonce = TCipher::generate_nonce(rand::thread_rng());
            let data = buffer.clone();
            cipher.encrypt_in_place(&nonce, b"", &mut buffer)?;

            let mut ciphertext = nonce.clone().as_slice().to_vec();
            ciphertext.extend(buffer);

            let extracted_nonce = cipher.decrypt_in_place_random_nonce_ahead(b"", &mut ciphertext)?;

            assert_eq!(data, ciphertext);
            assert_eq!(extracted_nonce, nonce);

            Ok(())
        }
    }
}
