#include <stdlib.h>
#include <string.h>

#include "scrypt.h"
#include "../include/scrypt.h"
#include "pbkdf2.h"
#include "salsa20.h"


static int kScryptSalsaRounds = 4;
static int kScryptPBKDF2Rounds = 1;
static int kScryptBlockMultiplier = 128;

static void scrypt_xor(const uint8_t* a,
                       const uint8_t* b,
                       size_t size,
                       uint8_t* out) {
  size_t i;

  for (i = 0; i < size; i++)
    out[i] = a[i] ^ b[i];
}

void scrypt_block_mix(const uint8_t* b, unsigned int r, uint8_t* output) {
  /*
   * Algorithm scryptBlockMix
   *
   * Parameters:
   *          r       Block size parameter.
   *
   * Input:
   *          B[0], ..., B[2 * r - 1]
   *                 Input vector of 2 * r 64-octet blocks.
   *
   * Output:
   *          B'[0], ..., B'[2 * r - 1]
   *                  Output vector of 2 * r 64-octet blocks.
   *
   * Steps:
   *
   *   1. X = B[2 * r - 1]
   *
   *   2. for i = 0 to 2 * r - 1 do
   *        T = X xor B[i]
   *        X = Salsa (T)
   *        Y[i] = X
   *      end for
   *
   *   3. B' = (Y[0], Y[2], ..., Y[2 * r - 2],
   *            Y[1], Y[3], ..., Y[2 * r - 1])
   */

  uint8_t x[kSalsa20BlockSize];
  unsigned int i;

  /* Step 1 */
  memcpy(x, &b[(2 * r - 1) * kSalsa20BlockSize], sizeof(x));

  /* Step 2 */
  for (i = 0; i < 2 * r; i++) {
    uint8_t t[sizeof(x)];

    scrypt_xor(x, &b[i * kSalsa20BlockSize], kSalsa20BlockSize, t);
    scrypt_salsa20(t, kScryptSalsaRounds, x);

    /* Step 3 */
    if (i % 2 == 0)
      memcpy(&output[(i / 2) * kSalsa20BlockSize], x, sizeof(x));
    else
      memcpy(&output[(r + (i / 2)) * kSalsa20BlockSize], x, sizeof(x));
  }
}


static uint64_t scrypt_integerify(scrypt_state_t* state, const uint8_t* x) {
  const uint8_t* p;
  uint64_t res;

  p = &x[state->block_size - kSalsa20BlockSize];
  res = (uint64_t) p[0] + ((uint64_t) p[1] << 8) +
        ((uint64_t) p[2] << 16) + ((uint64_t) p[3] << 24) +
        ((uint64_t) p[4] << 32) + ((uint64_t) p[5] << 40) +
        ((uint64_t) p[6] << 48) + ((uint64_t) p[7] << 56);

  return res;
}


void scrypt_ro_mix(scrypt_state_t* state, const uint8_t* b, uint8_t* output) {
  /*
   * Algorithm scryptROMix
   *
   *   Input:
   *            r       Block size parameter.
   *            B       Input octet vector of length 128 * r octets.
   *            N       CPU/Memory cost parameter, must be larger than 1,
   *                    a power of 2 and less than 2^(128 * r / 8).
   *
   *   Output:
   *            B'      Output octet vector of length 128 * r octets.
   *
   *   Steps:
   *
   *     1. X = B
   *
   *     2. for i = 0 to N - 1 do
   *          V[i] = X
   *          X = scryptBlockMix (X)
   *        end for
   *
   *     3. for i = 0 to N - 1 do
   *          j = Integerify (X) mod N
   *                 where Integerify (B[0] ... B[2 * r - 1]) is defined
   *                 as the result of interpreting B[2 * r - 1] as a
   *                 little-endian integer.
   *          T = X xor V[j]
   *          X = scryptBlockMix (T)
   *        end for
   *
   *     4. B' = X
   */

  uint8_t* x;
  uint8_t* v;
  uint8_t* t;
  unsigned int i;

  x = state->x;
  v = state->v;
  t = state->t;

  /* Step 1 */
  memcpy(x, b, state->block_size);

  /* Step 2 */
  for (i = 0; i < state->n; i++) {
    uint8_t* s;

    memcpy(&v[state->block_size * i], x, state->block_size);
    scrypt_block_mix(x, state->r, t);

    s = t;
    t = x;
    x = s;
  }

  /* Step 3 */
  for (i = 0; i < state->n; i++) {
    int j;

    j = scrypt_integerify(state, x) % state->n;
    scrypt_xor(x, &v[j * state->block_size], state->block_size, t);
    scrypt_block_mix(t, state->r, x);
  }

  /* Step 4 */
  memcpy(output, x, state->block_size);
}


void scrypt(scrypt_state_t* state,
            const uint8_t* passphrase,
            size_t passphase_len,
            const uint8_t* salt,
            size_t salt_len,
            uint8_t* out,
            size_t out_len) {
  /*
   *   Algorithm scrypt
   *
   *   Input:
   *            P       Passphrase, an octet string.
   *            S       Salt, an octet string.
   *            N       CPU/Memory cost parameter, must be larger than 1,
   *                    a power of 2 and less than 2^(128 * r / 8).
   *            r       Block size parameter.
   *            p       Parallelization parameter, a positive integer
   *                    less than or equal to ((2^32-1) * hLen) / MFLen
   *                    where hLen is 32 and MFlen is 128 * r.
   *            dkLen   Intended output length in octets of the derived
   *                    key; a positive integer less than or equal to
   *                    (2^32 - 1) * hLen where hLen is 32.
   *
   *   Output:
   *            DK      Derived key, of length dkLen octets.
   *
   *   Steps:
   *
   *     1. B[0] || B[1] || ... || B[p - 1] =
   *          PBKDF2-HMAC-SHA256 (P, S, 1, p * 128 * r)
   *
   *     2. for i = 0 to p - 1 do
   *          B[i] = scryptROMix (r, B[i], N)
   *        end for
   *
   *     3. DK = PBKDF2-HMAC-SHA256 (P, B[0] || B[1] || ... || B[p - 1],
   *                                 1, dkLen)
   */

  unsigned int i;

  /* Step 1 */
  scrypt_pbkdf2_sha256(passphrase,
                       passphase_len,
                       salt,
                       salt_len,
                       kScryptPBKDF2Rounds,
                       state->b,
                       state->p * state->block_size);

  /* Step 2 */
  for (i = 0; i < state->p; i++) {
    uint8_t* b;

    b = &state->b[state->block_size * i];
    scrypt_ro_mix(state, b, b);
  }

  /* Step 3 */
  scrypt_pbkdf2_sha256(passphrase,
                       passphase_len,
                       state->b,
                       state->p * state->block_size,
                       kScryptPBKDF2Rounds,
                       out,
                       out_len);
}


int scrypt_state_init(scrypt_state_t* state) {
  state->block_size = kScryptBlockMultiplier * state->r;

  state->b = malloc(state->p * state->block_size);
  if (state->b == NULL)
    goto failed_alloc_b;

  state->x = malloc(state->block_size);
  if (state->x == NULL)
    goto failed_alloc_x;

  state->v = malloc(state->block_size * state->n);
  if (state->v == NULL)
    goto failed_alloc_v;

  state->t = malloc(state->block_size);
  if (state->t == NULL)
    goto failed_alloc_t;

  return 0;

failed_alloc_t:
  free(state->v);
  state->v = NULL;

failed_alloc_v:
  free(state->x);
  state->x = NULL;

failed_alloc_x:
  free(state->b);
  state->b = NULL;

failed_alloc_b:
  return -1;
}


void scrypt_state_destroy(scrypt_state_t* state) {
  free(state->v);
  free(state->x);
  free(state->t);
  memset(state, 0, sizeof(*state));
}
