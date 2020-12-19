#ifndef SRC_PBKDF2_H_
#define SRC_PBKDF2_H_

#include <stdint.h>
#include <stdlib.h>

void scrypt_pbkdf2_sha256(const uint8_t* password,
                          size_t password_len,
                          const uint8_t* salt,
                          size_t salt_len,
                          unsigned int c,
                          uint8_t* out,
                          size_t out_len);

#endif  /* SRC_PBKDF2_H_ */
