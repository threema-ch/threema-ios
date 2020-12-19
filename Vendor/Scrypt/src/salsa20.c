#include <string.h>
#include <stdio.h>

#include "salsa20.h"

/* http://cr.yp.to/snuffle/spec.pdf */
static uint32_t scrypt_salsa20_rotl(uint32_t n, int s) {
  return (n << s) | (n >> (32 - s));
}


void scrypt_salsa20_quarterround(const uint32_t* y, uint32_t* z) {
  /*
   * If y = (y0, y1, y2, y3) then quarterround(y) = (z0, z1, z2, z3) where
   *
   *     z1 = y1 ⊕ ((y0 + y3) <<< 7),
   *     z2 = y2 ⊕ ((z1 + y0) <<< 9),
   *     z3 = y3 ⊕ ((z2 + z1) <<< 13),
   *     z0 = y0 ⊕ ((z3 + z2) <<< 18).
   */
  z[1] = y[1] ^ scrypt_salsa20_rotl(y[0] + y[3], 7);
  z[2] = y[2] ^ scrypt_salsa20_rotl(z[1] + y[0], 9);
  z[3] = y[3] ^ scrypt_salsa20_rotl(z[2] + z[1], 13);
  z[0] = y[0] ^ scrypt_salsa20_rotl(z[3] + z[2], 18);
}


void scrypt_salsa20_rowround(const uint32_t* y, uint32_t* z) {
  /*
   * If y = (y0, y1, y2, y3, . . . , y15) then
   * rowround(y) = (z0, z1, z2, z3, . . . , z15) where
   *
   *     (z0, z1, z2, z3) = quarterround(y0, y1, y2, y3),
   *     (z5, z6, z7, z4) = quarterround(y5, y6, y7, y4),
   *     (z10, z11, z8, z9) = quarterround(y10, y11, y8, y9),
   *     (z15, z12, z13, z14) = quarterround(y15, y12, y13, y14).
   */

  uint32_t s0[4] = { y[0], y[1], y[2], y[3] };
  uint32_t s1[4] = { y[5], y[6], y[7], y[4] };
  uint32_t s2[4] = { y[10], y[11], y[8], y[9] };
  uint32_t s3[4] = { y[15], y[12], y[13], y[14] };
  uint32_t t[4];

  scrypt_salsa20_quarterround(s0, t);
  z[0] = t[0];
  z[1] = t[1];
  z[2] = t[2];
  z[3] = t[3];

  scrypt_salsa20_quarterround(s1, t);
  z[5] = t[0];
  z[6] = t[1];
  z[7] = t[2];
  z[4] = t[3];

  scrypt_salsa20_quarterround(s2, t);
  z[10] = t[0];
  z[11] = t[1];
  z[8] = t[2];
  z[9] = t[3];

  scrypt_salsa20_quarterround(s3, t);
  z[15] = t[0];
  z[12] = t[1];
  z[13] = t[2];
  z[14] = t[3];
}


void scrypt_salsa20_columnround(const uint32_t* x, uint32_t* y) {
  /*
   * If x = (x0, x1, x2, x3, . . . , x15) then
   * columnround(x) = (y0, y1, y2, y3, . . . , y15) where
   *
   *     (y0, y4, y8, y12) = quarterround(x0, x4, x8, x12),
   *     (y5, y9, y13, y1) = quarterround(x5, x9, x13, x1),
   *     (y10, y14, y2, y6) = quarterround(x10, x14, x2, x6),
   *     (y15, y3, y7, y11) = quarterround(x15, x3, x7, x11).
   */

  uint32_t s0[4] = { x[0], x[4], x[8], x[12] };
  uint32_t s1[4] = { x[5], x[9], x[13], x[1] };
  uint32_t s2[4] = { x[10], x[14], x[2], x[6] };
  uint32_t s3[4] = { x[15], x[3], x[7], x[11] };
  uint32_t t[4];

  scrypt_salsa20_quarterround(s0, t);
  y[0] = t[0];
  y[4] = t[1];
  y[8] = t[2];
  y[12] = t[3];

  scrypt_salsa20_quarterround(s1, t);
  y[5] = t[0];
  y[9] = t[1];
  y[13] = t[2];
  y[1] = t[3];

  scrypt_salsa20_quarterround(s2, t);
  y[10] = t[0];
  y[14] = t[1];
  y[2] = t[2];
  y[6] = t[3];

  scrypt_salsa20_quarterround(s3, t);
  y[15] = t[0];
  y[3] = t[1];
  y[7] = t[2];
  y[11] = t[3];
}


void scrypt_salsa20_doubleround(const uint32_t* x, uint32_t* y) {
  /*
   * A double round is a column round followed by a row round:
   * doubleround(x) = rowround(columnround(x)).
   */
  scrypt_salsa20_columnround(x, y);
  scrypt_salsa20_rowround(y, y);
}


static uint32_t scrypt_salsa20_littleendian(const uint8_t* b) {
  /*
   * If b = (b0, b1, b2, b3) then littleendian(b) =
   * b0 + 2^8 * b1 + 2^16 * b2 + 2^24 * b3.
   */
  return (uint32_t) b[0] |
         ((uint32_t) b[1] << 8) |
         ((uint32_t) b[2] << 16) |
         ((uint32_t) b[3] << 24);
}


static void scrypt_salsa20_littleendian_inv(uint32_t x, uint8_t* y) {
  y[0] = x;
  y[1] = x >> 8;
  y[2] = x >> 16;
  y[3] = x >> 24;
}


void scrypt_salsa20(const uint8_t* input, int rounds, uint8_t* output) {
  /*
   * In short: Salsa20(x) = x + doubleround^10(x), where each 4-byte sequence is
   * viewed as a word in little-endian form.
   *
   * In detail: Starting from x = (x[0], x[1], . . . , x[63]), define
   * x0 = littleendian(x[0], x[1], x[2], x[3]),
   * x1 = littleendian(x[4], x[5], x[6], x[7]),
   * x2 = littleendian(x[8], x[9], x[10], x[11]),
   * ...
   * x15 = littleendian(x[60], x[61], x[62], x[63]).
   *
   * Define (z0, z1, . . . , z15) = doubleround10(x0, x1, . . . , x15).
   *
   * Then Salsa20(x) is the concatenation of
   * littleendian^−1(z0 + x0),
   * littleendian^−1(z1 + x1),
   * littleendian^−1(z2 + x2),
   * ...
   * littleendian^−1(z15 + x15).
   */

  int i;
  int j;

  uint32_t x[16];
  uint32_t z[16];

  for (i = 0; i < (int) (kSalsa20BlockSize / sizeof(*x)); i++)
    x[i] = scrypt_salsa20_littleendian(&input[i * sizeof(*x)]);

  memcpy(z, x, sizeof(x));

  for (j = 0; j < rounds; j++)
    scrypt_salsa20_doubleround(z, z);

  for (i = 0; i < (int) (kSalsa20BlockSize / sizeof(*x)); i++)
    scrypt_salsa20_littleendian_inv(x[i] + z[i], &output[i * sizeof(*x)]);
}
