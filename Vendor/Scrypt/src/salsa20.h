#ifndef SRC_SALSA20_H_
#define SRC_SALSA20_H_

#include <stdint.h>

static const int kSalsa20BlockSize = 64;

void scrypt_salsa20(const uint8_t* input, int rounds, uint8_t* output);

/* Just for testing */
void scrypt_salsa20_quarterround(const uint32_t* y, uint32_t* z);
void scrypt_salsa20_rowround(const uint32_t* y, uint32_t* z);
void scrypt_salsa20_columnround(const uint32_t* x, uint32_t* y);
void scrypt_salsa20_doubleround(const uint32_t* x, uint32_t* y);

#endif  /* SRC_SALSA20_H_ */
