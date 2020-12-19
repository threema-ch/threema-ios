#include <string.h>

#include "scrypt.h"
#include "pbkdf2.h"
#include "hmac.h"
#include "common.h"

/* See: https://tools.ietf.org/html/rfc2898#section-5.2 */

void scrypt_pbkdf2_sha256(const uint8_t* password,
                          size_t password_len,
                          const uint8_t* salt,
                          size_t salt_len,
                          unsigned int c,
                          uint8_t* out,
                          size_t out_len) {
  /*
   * Terminology:
   *   P = password
   *   S = salt
   *   DK = out
   *   dkLen = out_len
   */

  /* 1. If dkLen > (2^32 - 1) * hLen, output "derived key too long" and stop. */
  /* (skip) */

  /* 2. Let l be the number of hLen-octet blocks in the derived key,
   *    rounding up, and let r be the number of octets in the last
   *    block:
   *
   *               l = CEIL (dkLen / hLen) ,
   *               r = dkLen - (l - 1) * hLen .
   *
   *    Here, CEIL (x) is the "ceiling" function, i.e. the smallest
   *    integer greater than, or equal to, x.
   */
  size_t i;
  size_t l;
  size_t r;

  l = (out_len + kSha256DigestSize - 1) / kSha256DigestSize;
  r = out_len - (l - 1) * kSha256DigestSize;

  /* 3. For each block of the derived key apply the function F defined
   *    below to the password P, the salt S, the iteration count c, and
   *    the block index to compute the block:
   *
   *               T_1 = F (P, S, c, 1) ,
   *               T_2 = F (P, S, c, 2) ,
   *               ...
   *               T_l = F (P, S, c, l) ,
   *
   *    where the function F is defined as the exclusive-or sum of the
   *    first c iterates of the underlying pseudorandom function PRF
   *    applied to the password P and the concatenation of the salt S
   *    and the block index i:
   *
   *               F (P, S, c, i) = U_1 \xor U_2 \xor ... \xor U_c
   *
   *    where
   *
   *               U_1 = PRF (P, S || INT (i)) ,
   *               U_2 = PRF (P, U_1) ,
   *               ...
   *               U_c = PRF (P, U_{c-1}) .
   *
   *    Here, INT (i) is a four-octet encoding of the integer i, most
   *    significant octet first.
   */
  for (i = 1; i <= l; i++) {
    unsigned int j;
    uint8_t t[kSha256DigestSize];
    uint8_t u[kSha256DigestSize];
    uint8_t ctr[4];
    scrypt_hmac_t hmac;

    ctr[0] = i >> 24;
    ctr[1] = i >> 16;
    ctr[2] = i >> 8;
    ctr[3] = i;

    /* U_1 = PRF (P, S || INT (i)) */
    scrypt_hmac_init(&hmac, password, password_len);
    scrypt_hmac_update(&hmac, salt, salt_len);
    scrypt_hmac_update(&hmac, ctr, sizeof(ctr));
    scrypt_hmac_digest(&hmac, u);
    memcpy(t, u, sizeof(u));

    for (j = 2; j <= c; j++) {
      size_t u_len;
      size_t k;

      u_len = sizeof(u);

      /* U_c = PRF (P, U_{c-1}) */
      scrypt_hmac_init(&hmac, password, password_len);
      scrypt_hmac_update(&hmac, u, u_len);
      scrypt_hmac_digest(&hmac, u);

      /* Xor Us */
      for (k = 0; k < kSha256DigestSize; k++)
        t[k] ^= u[k];
    }

    /* Copy out the results */
    memcpy(&out[(i - 1) * kSha256DigestSize],
           t,
           MIN(out_len - (i - 1) * kSha256DigestSize, kSha256DigestSize));
  }
}
