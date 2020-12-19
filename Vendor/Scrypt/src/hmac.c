#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "hmac.h"
#include "common.h"
#include "sha256.h"


/* See https://tools.ietf.org/html/rfc2104#section-2 */

void scrypt_hmac_init(scrypt_hmac_t* hmac, const uint8_t* key, size_t key_len) {
  /*
   *                ipad = the byte 0x36 repeated B times
   *                opad = the byte 0x5C repeated B times.
   *
   *   To compute HMAC over the data `text' we perform
   *
   *                    H(K XOR opad, H(K XOR ipad, text))
   *
   *   Namely,
   *
   *    (1) append zeros to the end of K to create a B byte string
   *        (e.g., if K is of length 20 bytes and B=64, then K will be
   *         appended with 44 zero bytes 0x00)
   *    (2) XOR (bitwise exclusive-OR) the B byte string computed in step
   *        (1) with ipad
   *    (3) append the stream of data 'text' to the B byte string resulting
   *        from step (2)
   *    (4) apply H to the stream generated in step (3)
   *    (5) XOR (bitwise exclusive-OR) the B byte string computed in
   *        step (1) with opad
   *    (6) append the H result from step (4) to the B byte string
   *        resulting from step (5)
   *    (7) apply H to the stream generated in step (6) and output
   *        the result
   */

  uint8_t block[kSha256BlockSize];
  size_t to_copy;
  int i;


  /* Hash the key to fit it into the block */
  if (key_len > kSha256BlockSize) {
    scrypt_sha256_t tmp;
    scrypt_sha256_init(&tmp);
    scrypt_sha256_update(&tmp, key, key_len);
    scrypt_sha256_digest(&tmp, block);

    return scrypt_hmac_init(hmac, block, kSha256DigestSize);
  }

  scrypt_sha256_init(&hmac->outer);
  scrypt_sha256_init(&hmac->inner);

  /* Pad the key */
  to_copy = MIN(key_len, ARRAY_SIZE(block));
  memcpy(block, key, to_copy);
  memset(block + to_copy, 0, ARRAY_SIZE(block) - to_copy);

  for (i = 0; i < kSha256BlockSize; i++)
    block[i] ^= 0x36;
  scrypt_sha256_update(&hmac->inner, block, kSha256BlockSize);

  /* NOTE: a ^ b ^ b ^ c = a ^ c */
  for (i = 0; i < kSha256BlockSize; i++)
    block[i] ^= 0x36 ^ 0x5c;
  scrypt_sha256_update(&hmac->outer, block, kSha256BlockSize);
}


void scrypt_hmac_update(scrypt_hmac_t* hmac, const uint8_t* data, size_t size) {
  scrypt_sha256_update(&hmac->inner, data, size);
}


void scrypt_hmac_digest(scrypt_hmac_t* hmac, uint8_t* out) {
  uint8_t digest[kSha256DigestSize];

  scrypt_sha256_digest(&hmac->inner, digest);
  scrypt_sha256_update(&hmac->outer, digest, sizeof(digest));
  scrypt_sha256_digest(&hmac->outer, out);
}
