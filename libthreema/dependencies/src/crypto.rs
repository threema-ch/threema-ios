//! Higher-level wrappers around crypto libraries used and some commonly used abstractions used by Threema
//! protocols.

/// Minimal interface of a generic fixed-size array (used for some ciphers).
pub mod generic_array {
    pub use cipher::generic_array::GenericArray;
}

/// Type aliases for all constants.
pub mod consts {
    pub use cipher::consts::{U16, U24, U32, U64};
}

/// Minimal abstract interface for general ciphers.
pub mod cipher {
    pub use cipher::{KeyInit, KeyIvInit, StreamCipher, StreamCipherSeek, Unsigned};
}

/// Minimal abstract interface for hash digests.
pub mod digest {
    pub use digest::{Digest, FixedOutput, Mac, block_buffer::EagerBuffer};

    /// Generic 256 bit MAC length in bytes (d'uh).
    pub const MAC_256_LENGTH: usize = 32;
}

/// Minimal abstract interface for constant-time cryptographic implementations.
pub mod subtle {
    pub use subtle::{Choice, ConstantTimeEq};
}

/// Minimal abstract interface for AEAD ciphers.
pub mod aead {
    pub use aead::{Aead, AeadInPlace, Buffer, Error, Nonce, Payload, Result};
}

/// Argon2 for password-based key derivations.
pub mod argon2 {
    pub use argon2::{Algorithm::Argon2id, Argon2, Error, Params, Version};
}

/// BLAKE2b for hashing and key derivations.
pub mod blake2b {
    use blake2::Blake2bMac;

    /// Blake2b MAC with 256 bits output.
    pub type Blake2bMac256 = Blake2bMac<super::consts::U32>;

    /// Blake2b MAC with 512 bits output.
    pub type Blake2bMac512 = Blake2bMac<super::consts::U64>;
}

/// SHA2 and HMAC-SHA-2 for hashing (some of which is legacy).
pub mod sha2 {
    use hmac::Hmac;
    pub use sha2::Sha256;

    /// HMAC-SHA-2 with 256 bits output.
    pub type HmacSha256 = Hmac<Sha256>;
}

/// ChaCha20Poly1305 and XChaCha20Poly1305 ciphers.
pub mod chacha20 {
    pub use chacha20::XChaCha20;
    pub use chacha20poly1305::{ChaCha20Poly1305, Key, XChaCha20Poly1305};

    /// ChaCha20 and XChaCha20 key length in bytes.
    pub const KEY_LENGTH: usize = 32;

    /// ChaCha20 nonce length in bytes.
    pub const STANDARD_NONCE_LENGTH: usize = 12;

    /// XChaCha20 nonce length in bytes.
    pub const EXTENDED_NONCE_LENGTH: usize = 24;

    /// ChaCha20 and XChaCha20 tag length in bytes.
    pub const TAG_LENGTH: usize = 16;
}

/// XSalsa20Poly1305 cipher (legacy).
pub mod salsa20 {
    pub use crypto_secretbox::{Key, XSalsa20Poly1305};
    pub use salsa20::XSalsa20;

    /// Salsa20 and XSalsa20 key length in bytes.
    pub const KEY_LENGTH: usize = 32;

    /// XSalsa20 nonce length in bytes.
    pub const EXTENDED_NONCE_LENGTH: usize = 24;

    /// Salsa20 and XSalsa20 tag length in bytes.
    pub const TAG_LENGTH: usize = 16;
}

/// Poly1305 for hashing in combination with XSalsa20/XChaCha20. Should only be used for chunked crypto.
pub mod poly1305 {
    pub use poly1305::{Key, Tag};
    use poly1305::{Poly1305, universal_hash::UniversalHash as _};

    use super::cipher::KeyInit as _;

    /// Poly1305 as a MAC construction with an internal buffer handling incomplete blocks.
    ///
    /// WARNING: You should really know what you're doing when using this!
    pub struct ChunkedPoly1305 {
        hash: Poly1305,
        buffer: super::digest::EagerBuffer<super::consts::U16>,
    }
    impl ChunkedPoly1305 {
        /// Initialize chunked Poly1305 construction with the given key.
        #[inline]
        #[must_use]
        pub fn new(key: &Key) -> Self {
            Self {
                hash: Poly1305::new(key),
                buffer: super::digest::EagerBuffer::default(),
            }
        }

        /// Update with any full blocks and store any leftover bytes for later processing.
        #[inline]
        pub fn update(&mut self, chunk: &[u8]) {
            // Update the hash from fully constructed blocks and store any leftover bytes in the internal
            // buffer
            self.buffer.digest_blocks(chunk, |blocks| {
                self.hash.update(blocks);
            });
        }
    }

    /// Chunked Poly1305 hashing for use with XChaCha20.
    ///
    /// WARNING: You should really know what you're doing when using this!
    pub trait ChunkedPoly1305XChaCha20 {
        /// Zero-pad a _pending_ block.
        ///
        /// If no bytes are in the internal buffer, the block is not considered _pending_. In other words,
        /// this prevents a full block of just zero-padding.
        fn zeropad_pending_block(&mut self);

        /// Hand out the resulting tag.
        ///
        /// WARNING: This disregards any pending blocks. The caller must ensure that all pending blocks have
        /// been written.
        fn finalize_complete_block(self) -> Tag;
    }
    impl ChunkedPoly1305XChaCha20 for ChunkedPoly1305 {
        #[inline]
        fn zeropad_pending_block(&mut self) {
            if self.buffer.get_pos() == 0 {
                return;
            }
            self.hash.update(&[*self.buffer.pad_with_zeros()]);
        }

        #[inline]
        fn finalize_complete_block(self) -> Tag {
            self.hash.finalize()
        }
    }

    /// Chunked Poly1305 hashing for use with XSalsa20.
    ///
    /// WARNING: You should really know what you're doing when using this!
    pub trait ChunkedPoly1305XSalsa20 {
        /// Hand out the hash unpadded (yet still hashing the remaining bytes).
        fn finalize_unpadded(self) -> Tag;
    }
    impl ChunkedPoly1305XSalsa20 for ChunkedPoly1305 {
        #[inline]
        fn finalize_unpadded(self) -> Tag {
            self.hash.compute_unpadded(self.buffer.get_data())
        }
    }
}

/// Deprecated stuff that only exists for the sake of backwards compatibility.
pub mod deprecated {
    /// PBKDF2 password-based key derivations.
    ///
    /// WARNING: Do not use for anything but the legacy scheme of the ID backup!
    pub mod pbkdf2 {
        pub use pbkdf2::pbkdf2_hmac_array;
    }

    /// Salsa20 without Poly1305 MAC.
    ///
    /// WARNING: Do not use for anything but the legacy scheme of the ID backup!
    pub mod salsa20 {
        pub use salsa20::XSalsa20;
    }

    /// Scrypt for password-based key derivations.
    ///
    /// WARNING: Do not use for anything but legacy support!
    pub mod scrypt {
        pub use scrypt::{Params, scrypt};
    }
}

/// Ed25519-related keys and signatures.
pub mod ed25519 {
    pub use ed25519_dalek::{PUBLIC_KEY_LENGTH, SIGNATURE_LENGTH, Signature, VerifyingKey};
}

/// X25519-related derivation and keys, including the intermediate X25519HSalsa20 hash on top of a montgomery
/// point as used by many Threema protocols to derive further keys from.
pub mod x25519 {
    use aead::consts::U10;
    use rand;
    use salsa20::hsalsa;
    pub use x25519_dalek::PublicKey;
    use x25519_dalek::{SharedSecret, StaticSecret as UnsafeStaticSecret};
    use zeroize::ZeroizeOnDrop;

    use super::generic_array::GenericArray;

    /// X25519 secret and public key length.
    pub const KEY_LENGTH: usize = 32;

    /// A uniformly distributed [`SharedSecret`], compatible with classic NaCl shared secret
    /// derivation.
    #[derive(ZeroizeOnDrop)]
    pub struct SharedSecretHSalsa20([u8; Self::LENGTH]);
    impl SharedSecretHSalsa20 {
        /// Byte length of the shared secret.
        pub const LENGTH: usize = KEY_LENGTH;

        /// Create a new `[SharedSecretHSalsa20]` from a [`SharedSecret`], consuming the input.
        #[expect(
            clippy::needless_pass_by_value,
            reason = "Consume the input so that it is dropped zeroized afterwards"
        )]
        #[must_use]
        fn new(shared_secret: SharedSecret) -> Self {
            Self(
                hsalsa::<U10>(
                    GenericArray::from_slice(shared_secret.as_bytes()),
                    &GenericArray::default(),
                )
                .into(),
            )
        }

        /// Convert this shared secret key to a byte array.
        #[inline]
        #[must_use]
        pub fn to_bytes(&self) -> [u8; Self::LENGTH] {
            self.0
        }

        /// View this shared secret key as a byte array.
        #[inline]
        #[must_use]
        pub fn as_bytes(&self) -> &[u8; Self::LENGTH] {
            &self.0
        }
    }

    /// A short-lived Diffie-Hellman secret key that can only be used to compute a single
    /// [`SharedSecretHSalsa20`].
    ///
    /// This type is identical to the [`StaticSecret`] type, except that the
    /// [`EphemeralSecret::diffie_hellman_hsalsa20`] method consumes and then wipes the secret key, and there
    /// are no serialization methods defined. This means that [`EphemeralSecret`]s can only be generated
    /// from fresh randomness where the compiler statically checks that the resulting secret is used at
    /// most once.
    #[derive(ZeroizeOnDrop)]
    pub struct EphemeralSecret(UnsafeStaticSecret);
    impl EphemeralSecret {
        /// Perform a Diffie-Hellman key agreement between `self` and `public_key` key to produce a
        /// [`SharedSecretHSalsa20`].
        ///
        /// [`None`] is returned if the result is from a non-contributory key and should be rejected.
        #[inline]
        #[must_use]
        pub fn diffie_hellman_hsalsa20(self, public_key: &PublicKey) -> Option<SharedSecretHSalsa20> {
            let shared_secret = self.0.diffie_hellman(public_key);
            if shared_secret.was_contributory() {
                Some(SharedSecretHSalsa20::new(shared_secret))
            } else {
                None
            }
        }

        /// Generate a new [`EphemeralSecret`].
        #[inline]
        #[must_use]
        pub fn random() -> Self {
            Self(UnsafeStaticSecret::random_from_rng(rand::thread_rng()))
        }
    }
    impl<'secret> From<&'secret EphemeralSecret> for PublicKey {
        fn from(secret: &'secret EphemeralSecret) -> Self {
            Self::from(&secret.0)
        }
    }

    /// A Diffie-Hellman secret key that can be used to compute multiple [`SharedSecretHSalsa20`]s.
    ///
    /// This type is identical to the [`EphemeralSecret`] type, except that the
    /// [`StaticSecret::diffie_hellman_hsalsa20`] method does not consume the secret key, and the type
    /// provides serialization methods to save and load key material.  This means that the secret may be
    /// used multiple times (but does not *have to be*).
    #[derive(ZeroizeOnDrop, Clone)]
    pub struct StaticSecret(UnsafeStaticSecret);
    impl StaticSecret {
        /// Perform a Diffie-Hellman key agreement between `self` and a `public_key` to produce a
        /// [`SharedSecretHSalsa20`].
        ///
        /// [`None`] is returned if the result is from a non-contributory key and should be rejected.
        #[inline]
        #[must_use]
        pub fn diffie_hellman_hsalsa20(&self, public_key: &PublicKey) -> Option<SharedSecretHSalsa20> {
            let shared_secret = self.0.diffie_hellman(public_key);
            if shared_secret.was_contributory() {
                Some(SharedSecretHSalsa20::new(shared_secret))
            } else {
                None
            }
        }

        /// View this key as a byte array.
        #[inline]
        #[must_use]
        pub fn as_bytes(&self) -> &[u8; KEY_LENGTH] {
            self.0.as_bytes()
        }

        /// Generate a new [`StaticSecret`].
        #[inline]
        #[must_use]
        pub fn random() -> Self {
            Self(UnsafeStaticSecret::random_from_rng(rand::thread_rng()))
        }
    }
    impl From<[u8; KEY_LENGTH]> for StaticSecret {
        fn from(bytes: [u8; KEY_LENGTH]) -> Self {
            Self(UnsafeStaticSecret::from(bytes))
        }
    }
    impl AsRef<[u8]> for StaticSecret {
        #[inline]
        fn as_ref(&self) -> &[u8] {
            self.as_bytes()
        }
    }
    impl<'secret> From<&'secret StaticSecret> for PublicKey {
        fn from(secret: &'secret StaticSecret) -> Self {
            Self::from(&secret.0)
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::crypto::x25519;

    #[test]
    fn static_secret_diffie_hellman_non_contributory() {
        let secret = x25519::StaticSecret::random();
        assert!(
            secret
                .diffie_hellman_hsalsa20(&x25519::PublicKey::from([0; x25519::KEY_LENGTH]))
                .is_none()
        );
    }

    #[test]
    fn ephemeral_diffie_hellman_non_contributory() {
        let secret = x25519::EphemeralSecret::random();
        assert!(
            secret
                .diffie_hellman_hsalsa20(&x25519::PublicKey::from([0; x25519::KEY_LENGTH]))
                .is_none()
        );
    }
}
