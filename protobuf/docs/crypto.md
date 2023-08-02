# Crypto Guidelines

## Checklist

- [ ] Never use a root key directly, always derive subkeys for each different
      use case.
- [ ] Use different keys for each direction and role, making it possible to use
      a _ratcheting_ approach and making nonce re-use impossible without the use
      of a nonce _cookie_.
- [ ] To authenticate, send a random challenge (at least 16 bytes) to be
      repeated by the remote party. This is required by both sides, resulting in
      a three-way handshake.
- [ ] Authentication challenges must mitigate replay attacks, i.e. a different
      (key, nonce) combination for challenge and response. Generally, it is
      recommended to use separate keys for each direction.
- [ ] Always establish an ephemeral secret during authentication. This ensures
      that any later compromise of key material used for authentication does not
      compromise data exchanged by the ephemeral secret after the handshake.
- [ ] If possible, use mutual contribution of sntrup761 encrypted key material.
      This requires a three-way handshake. Fall back to unilateral contribution
      of sntrup761 key material if a two-way handshake is unavoidable. This
      prevents _capture now, decrypt later_ attacks.
- [ ] Do not exchange sensitive information during authentication, even if it is
      encrypted. The key material used during authentication could become
      compromised, putting sensitive data at risk.
- [ ] When deriving ephemeral secrets, mix in the key material used for
      authentication. This provides some level of PQS if the authentication key
      material was PQS.
- [ ] If the ephemeral secret is stored for a certain amount of time, derive a
      root key from it prior to deriving any subkeys. This ensures that any key
      material required to derive the root key does not need to be present to
      derive subkeys.
- [ ] Use ChaCha20 or XChaCha20 instead of XSalsa20. If there can be nonce
      collisions and the nonce needs to be random, use XChaCha20 over ChaCha20.
      However, protocols with random nonces should generally be avoided because
      they require storage of nonces to prevent replay attacks for the lifetime
      of the keys used.
- [ ] For long-lived sessions, use a _ratcheting_ approach to derive new keys
      with each message (see the Forward Security Subprotocol or the Group Calls
      Protocol) and thereby mitigate replay attacks.

## Shared Secret Derivation

The `X25519HSalsa20` function is the one from NaCl, i.e. `crypto_box_beforenm`,
which multiplies the secret key by the public key on the curve and then hashes
the resulting point with HSalsa20.

## Client Key (`CK`) Payload Confusion

The Client Key is the most valuable key of a Threema client. If it has been
compromised once, the Threema ID is to be considered permanently compromised.

In the past, `CK` has been used for multiple different use cases in the NaCl
`Box` model: aside from E2EE message encryption to other users, it was also used
for chat server and directory server authentication. This can lead to something
we call _payload confusion_: If an attacker controls the plaintext encrypted by
the victim for use case A, the attacker can convey that encrypted data to use
case B if not prevented.

All use cases that make use of `CK` for purposes other than E2EE message
encryption to other users **must** first use BLAKE2b as a KDF to derive a new 32
byte key from the shared secret calculated using `X25519HSalsa20` with
_salt_/_personalization_ values unique to the particular use case to avoid any
clashes. The derived key can then be used for encryption purposes with the
symmetric `crypto_secretbox` model of NaCl, or for authentication purposes e.g.
by using BLAKE2b as a MAC.

All use cases and their _personal_/_salt_ input combinations should be listed
below. Other input parameters do not need to be explained as long as they are
clear in the use cases context.

**All future usages of `CK` are forbidden to use any other form than this.**

### Chat Server Protocol Authentication:

    S = X25519HSalsa20(CK.secret, SK.public)
    VouchKey = BLAKE2b(key=S, salt='v', personal='3ma-csp')
    vouch = BLAKE2b(out-length=32, key=VouchKey, input=<SCK><TCK.public>)

### Directory Server Authentication:

    S = X25519HSalsa20(CK.secret, DirectoryServerChallengeKey)
    ResponseKey = BLAKE2b(key=S, salt='dir', personal='3ma-csp')
    response = BLAKE2b(out-length=32, key=ResponseKey, input=token)

### Message Metadata Encryption:

Note: This is only relevant for usage outside of `csp-e2e-fs.Encapsulated`.

    S = X25519HSalsa20(<sender.CK>.secret, <receiver.CK>.public)
    MMK = BLAKE2b(key=S, salt='mm', personal='3ma-csp')

### Group/Conference Call `AuthEnvelope` Encryption

    S = X25519HSalsa20(<sender.CK>.secret, <receiver.CK>.public)
    GCNHAK = BLAKE2b(key=S, salt='gcnha', personal='3ma-call', input=GCKH)

### Forward Security

Initiator:

    local-2DHK = BLAKE2b(
      key=BLAKE2b(
        out-length=64,
        input=
             X25519HSalsa20(<local.CK>.secret, <remote.CK>.public)
          || X25519HSalsa20(<local.FSSK>.secret, <remote.CK>.public)
      ),
      salt='ke-2dh-<local-threema-id>',
      personal='3ma-e2e',
    )

    local-4DHK = BLAKE2b(
      key=BLAKE2b(
        out-length=64,
        input=
             X25519HSalsa20(<local.CK>.secret, <remote.CK>.public)
          || X25519HSalsa20(<local.FSSK>.secret, <remote.CK>.public)
          || X25519HSalsa20(<local.CK>.secret, <remote.FSSK>.public)
          || X25519HSalsa20(<local.FSSK>.secret, <remote.FSSK>.public)
      ),
      salt='ke-4dh-<local-threema-id>',
      personal='3ma-e2e',
    )

    remote-4DHK = BLAKE2b(
      key=BLAKE2b(
        out-length=64,
        input=
             X25519HSalsa20(<local.CK>.secret, <remote.CK>.public)
          || X25519HSalsa20(<local.FSSK>.secret, <remote.CK>.public)
          || X25519HSalsa20(<local.CK>.secret, <remote.FSSK>.public)
          || X25519HSalsa20(<local.FSSK>.secret, <remote.FSSK>.public)
      ),
      salt='ke-4dh-<remote-threema-id>',
      personal='3ma-e2e',
    )

Responder:

    remote-2DHK = BLAKE2b(
      key=BLAKE2b(
        out-length=64,
        input=
             X25519HSalsa20(<local.CK>.secret, <remote.CK>.public)
          || X25519HSalsa20(<local.CK>.secret, <remote.FSSK>.public)
      ),
      salt='ke-2dh-<remote-threema-id>',
      personal='3ma-e2e',
    )

    local-4DHK = BLAKE2b(
      key=BLAKE2b(
        out-length=64,
        input=
             X25519HSalsa20(<local.CK>.secret, <remote.CK>.public)
          || X25519HSalsa20(<local.CK>.secret, <remote.FSSK>.public)
          || X25519HSalsa20(<local.FSSK>.secret, <remote.CK>.public)
          || X25519HSalsa20(<local.FSSK>.secret, <remote.FSSK>.public)
      ),
      salt='ke-4dh-<local-threema-id>',
      personal='3ma-e2e',
    )

    remote-4DHK = BLAKE2b(
      key=BLAKE2b(
        out-length=64,
        input=
             X25519HSalsa20(<local.CK>.secret, <remote.CK>.public)
          || X25519HSalsa20(<local.CK>.secret, <remote.FSSK>.public)
          || X25519HSalsa20(<local.FSSK>.secret, <remote.CK>.public)
          || X25519HSalsa20(<local.FSSK>.secret, <remote.FSSK>.public)
      ),
      salt='ke-4dh-<remote-threema-id>',
      personal='3ma-e2e',
    )
