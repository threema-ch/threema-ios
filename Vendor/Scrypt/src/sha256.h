#ifndef SRC_SHA256_H_
#define SRC_SHA256_H_

#include <stdint.h>
#include <stdlib.h>

typedef struct scrypt_sha256_s scrypt_sha256_t;

static const int kSha256DigestSize = 32;
static const int kSha256BlockSize = 64;

struct scrypt_sha256_s {
  /* kSha256DigestSize / 4 */
  uint32_t h[8];

  /* kSha256BlockSize */
  uint8_t buffer[64];
  uint64_t length;
};

void scrypt_sha256_init(scrypt_sha256_t* sha256);
void scrypt_sha256_update(scrypt_sha256_t* sha256,
                          const uint8_t* data,
                          size_t size);
void scrypt_sha256_digest(scrypt_sha256_t* sha256, uint8_t* out);

#endif  /* SRC_SHA256_H_ */
