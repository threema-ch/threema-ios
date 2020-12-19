#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "sha256.h"
#include "common.h"


/* See: https://tools.ietf.org/html/rfc6234#section-5.1 */
static uint32_t scrypt_sha256_k[] = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};


static uint32_t scrypt_sha256_h[] = {
  0x6a09e667,
  0xbb67ae85,
  0x3c6ef372,
  0xa54ff53a,
  0x510e527f,
  0x9b05688c,
  0x1f83d9ab,
  0x5be0cd19
};


/* CH( x, y, z) = (x AND y) XOR ( (NOT x) AND z) */
static uint32_t scrypt_sha256_ch(uint32_t x, uint32_t y, uint32_t z) {
  return (x & y) ^ ((~x) & z);
}


/* MAJ( x, y, z) = (x AND y) XOR (x AND z) XOR (y AND z) */
static uint32_t scrypt_sha256_maj(uint32_t x, uint32_t y, uint32_t z) {
  return (x & y) ^ (x & z) ^ (y & z);
}


static uint32_t scrypt_sha256_rotr(uint32_t n, int s) {
  return (n << (32 - s)) | (n >> s);
}


/* BSIG0(x) = ROTR^2(x) XOR ROTR^13(x) XOR ROTR^22(x) */
static uint32_t scrypt_sha256_bsig0(uint32_t x) {
  return scrypt_sha256_rotr(x, 2) ^
         scrypt_sha256_rotr(x, 13) ^
         scrypt_sha256_rotr(x, 22);
}


/* BSIG1(x) = ROTR^6(x) XOR ROTR^11(x) XOR ROTR^25(x) */
static uint32_t scrypt_sha256_bsig1(uint32_t x) {
  return scrypt_sha256_rotr(x, 6) ^
         scrypt_sha256_rotr(x, 11) ^
         scrypt_sha256_rotr(x, 25);
}


/* SSIG0(x) = ROTR^7(x) XOR ROTR^18(x) XOR SHR^3(x) */
static uint32_t scrypt_sha256_ssig0(uint32_t x) {
  return scrypt_sha256_rotr(x, 7) ^
         scrypt_sha256_rotr(x, 18) ^
         (x >> 3);
}


/* SSIG1(x) = ROTR^17(x) XOR ROTR^19(x) XOR SHR^10(x) */
static uint32_t scrypt_sha256_ssig1(uint32_t x) {
  return scrypt_sha256_rotr(x, 17) ^
         scrypt_sha256_rotr(x, 19) ^
         (x >> 10);
}


void scrypt_sha256_init(scrypt_sha256_t* sha256) {
  memcpy(sha256->h, scrypt_sha256_h, sizeof(scrypt_sha256_h));
  sha256->length = 0;
}


static void scrypt_sha256_fill_block(const uint8_t* input,
                                     uint32_t* output,
                                     size_t n) {
  size_t i;

  for (i = 0; i < n; i++) {
    output[i] = ((uint32_t) input[i * 4] << 24) |
                ((uint32_t) input[i * 4 + 1] << 16) |
                ((uint32_t) input[i * 4 + 2] << 8) |
                (uint32_t) input[i * 4 + 3];
  }
}


static void scrypt_sha256_process_block(scrypt_sha256_t* sha256,
                                        const uint32_t* block) {
  /*
   *    1. Prepare the message schedule W:
   *         For t = 0 to 15
   *             Wt = M(i)t
   *         For t = 16 to 63
   *             Wt = SSIG1(W(t-2)) + W(t-7) + SSIG0(w(t-15)) + W(t-16)
   *
   */
  uint32_t w[64];
  size_t t;
  uint32_t a;
  uint32_t b;
  uint32_t c;
  uint32_t d;
  uint32_t e;
  uint32_t f;
  uint32_t g;
  uint32_t h;

  memcpy(w, block, sizeof(*w) * 16);
  for (t = 16; t < 64; t++) {
    w[t] = scrypt_sha256_ssig1(w[t - 2]) +
           w[t - 7] +
           scrypt_sha256_ssig0(w[t - 15]) +
           w[t - 16];
  }

  /*
   *    2. Initialize the working variables:
   *         a = H(i-1)0
   *         b = H(i-1)1
   *         c = H(i-1)2
   *         d = H(i-1)3
   *         e = H(i-1)4
   *         f = H(i-1)5
   *         g = H(i-1)6
   *         h = H(i-1)7
   */
  a = sha256->h[0];
  b = sha256->h[1];
  c = sha256->h[2];
  d = sha256->h[3];
  e = sha256->h[4];
  f = sha256->h[5];
  g = sha256->h[6];
  h = sha256->h[7];

  /*
   *    3. Perform the main hash computation:
   *       For t = 0 to 63
   *          T1 = h + BSIG1(e) + CH(e,f,g) + Kt + Wt
   *          T2 = BSIG0(a) + MAJ(a,b,c)
   *          h = g
   *          g = f
   *          f = e
   *          e = d + T1
   *          d = c
   *          c = b
   *          b = a
   *          a = T1 + T2
   */
  for (t = 0; t < 64; t++) {
    uint32_t t1;
    uint32_t t2;

    t1 = h +
         scrypt_sha256_bsig1(e) +
         scrypt_sha256_ch(e, f, g) +
         scrypt_sha256_k[t] +
         w[t];
    t2 = scrypt_sha256_bsig0(a) + scrypt_sha256_maj(a, b, c);
    h = g;
    g = f;
    f = e;
    e = d + t1;
    d = c;
    c = b;
    b = a;
    a = t1 + t2;
  }

  /*
   *    4. Compute the intermediate hash value H(i)
   *       H(i)0 = a + H(i-1)0
   *       H(i)1 = b + H(i-1)1
   *       H(i)2 = c + H(i-1)2
   *       H(i)3 = d + H(i-1)3
   *       H(i)4 = e + H(i-1)4
   *       H(i)5 = f + H(i-1)5
   *       H(i)6 = g + H(i-1)6
   *       H(i)7 = h + H(i-1)7
   */
  sha256->h[0] += a;
  sha256->h[1] += b;
  sha256->h[2] += c;
  sha256->h[3] += d;
  sha256->h[4] += e;
  sha256->h[5] += f;
  sha256->h[6] += g;
  sha256->h[7] += h;
}


void scrypt_sha256_update(scrypt_sha256_t* sha256,
                          const uint8_t* data,
                          size_t size) {
  const uint8_t* p;
  size_t left;

  p = data;
  left = size;

  while (left != 0) {
    size_t off;
    size_t to_copy;
    uint32_t block[16];

    off = sha256->length % kSha256BlockSize;
    to_copy = MIN(left, kSha256BlockSize - off);

    /* Just bufferize to fill the block */
    memcpy(sha256->buffer + off, p, to_copy);
    sha256->length += to_copy;

    p += to_copy;
    left -= to_copy;

    /* Incomplete block - wait for more data */
    if (off + to_copy != kSha256BlockSize)
      break;

    scrypt_sha256_fill_block(sha256->buffer, block, ARRAY_SIZE(block));
    scrypt_sha256_process_block(sha256, block);
  }
}


static void scrypt_sha256_write_uint64_be(uint8_t* data,
                                          uint64_t value,
                                          size_t off) {
  data[off] = value >> 56;
  data[off + 1] = value >> 48;
  data[off + 2] = value >> 40;
  data[off + 3] = value >> 32;
  data[off + 4] = value >> 24;
  data[off + 5] = value >> 16;
  data[off + 6] = value >> 8;
  data[off + 7] = value;
}


void scrypt_sha256_digest(scrypt_sha256_t* sha256, uint8_t* out) {
  /* https://tools.ietf.org/html/rfc6234#section-4.1 */

  /*
   *   Suppose a message has length L < 2^64.  Before it is input to the
   *   hash function, the message is padded on the right as follows:
   *
   *   a. "1" is appended.  Example: if the original message is "01010000",
   *      this is padded to "010100001".
   *
   *   b. K "0"s are appended where K is the smallest, non-negative solution
   *      to the equation
   *
   *         ( L + 1 + K ) mod 512 = 448
   *
   *   c. Then append the 64-bit block that is L in binary representation.
   *      After appending this block, the length of the message will be a
   *      multiple of 512 bits.
   */

  size_t off;
  uint32_t block[16];
  size_t i;
  int has_overflow;

  /* NOTE: It is simple to calculate `k`, but having it is a bit useless, since
   * we know that this algorithm just wants to zero the rest of the block and to
   * put the 64bit length to the end */
  off = (sha256->length % kSha256BlockSize);

  /* (b) */
  memset(sha256->buffer + off, 0, kSha256BlockSize - off);

  /* If padding does not fit in a single block - append 0x80 and zeroes to the
   * current block and flush it.
   * Then fill the block with zeroes and append size to it, and flush it again
   */
  has_overflow = off + 9 > kSha256BlockSize;
  if (has_overflow) {
    /* (a) */
    sha256->buffer[off] |= 0x80;

    scrypt_sha256_fill_block(sha256->buffer, block, ARRAY_SIZE(block));
    scrypt_sha256_process_block(sha256, block);

    off = 0;
    memset(sha256->buffer, 0, kSha256BlockSize);
  }

  /* (c) */
  scrypt_sha256_write_uint64_be(sha256->buffer,
                                sha256->length * 8,
                                kSha256BlockSize - 8);

  /* (a) */
  if (!has_overflow)
    sha256->buffer[off] |= 0x80;

  scrypt_sha256_fill_block(sha256->buffer, block, ARRAY_SIZE(block));
  scrypt_sha256_process_block(sha256, block);

  for (i = 0; i < ARRAY_SIZE(sha256->h); i++) {
    out[i * 4] = sha256->h[i] >> 24;
    out[i * 4 + 1] = sha256->h[i] >> 16;
    out[i * 4 + 2] = sha256->h[i] >> 8;
    out[i * 4 + 3] = sha256->h[i];
  }
}
