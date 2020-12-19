#ifndef INCLUDE_SCRYPT_H_
#define INCLUDE_SCRYPT_H_
#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>  /* uint8_t */
#include <stdlib.h>  /* size_t */

typedef struct scrypt_state_s scrypt_state_t;

struct scrypt_state_s {
  unsigned int r;
  unsigned int n;
  unsigned int p;

  size_t block_size;

  /* scrypt params */
  uint8_t* b;

  /* ro_mix params */
  uint8_t* x;
  uint8_t* v;
  uint8_t* t;
};

int scrypt_state_init(scrypt_state_t* state);
void scrypt_state_destroy(scrypt_state_t* state);

void scrypt(scrypt_state_t* state,
            const uint8_t* passphrase,
            size_t passphase_len,
            const uint8_t* salt,
            size_t salt_len,
            uint8_t* out,
            size_t out_len);

#ifdef __cplusplus
}
#endif
#endif  /* INCLUDE_SCRYPT_H_ */
