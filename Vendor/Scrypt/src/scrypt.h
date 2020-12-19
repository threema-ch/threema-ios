#ifndef SRC_SCRYPT_H_
#define SRC_SCRYPT_H_

#include <stdint.h>

#include "../include/scrypt.h"

/* Just for testing */
void scrypt_block_mix(const uint8_t* b, unsigned int r, uint8_t* output);
//void scrypt_ro_mix(scrypt_state_t* state, const uint8_t* b, uint8_t* output);

#endif  /* SRC_SCRYPT_H_ */
