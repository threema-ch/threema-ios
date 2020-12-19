#ifndef SRC_HMAC_H_
#define SRC_HMAC_H_

#include <stdint.h>
#include <stdlib.h>

#include "sha256.h"

typedef struct scrypt_hmac_s scrypt_hmac_t;

struct scrypt_hmac_s {
  scrypt_sha256_t outer;
  scrypt_sha256_t inner;
};

void scrypt_hmac_init(scrypt_hmac_t* hmac, const uint8_t* key, size_t key_len);
void scrypt_hmac_update(scrypt_hmac_t* hmac, const uint8_t* data, size_t size);
void scrypt_hmac_digest(scrypt_hmac_t* hmac, uint8_t* out);

#endif  /* SRC_HMAC_H_ */
