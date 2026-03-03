#ifndef crypto_scalarmult_curve25519_H
#define crypto_scalarmult_curve25519_H

#define crypto_scalarmult_curve25519_donna_BYTES 32
#define crypto_scalarmult_curve25519_donna_SCALARBYTES 32
#ifdef __cplusplus
#include <string>
extern std::string crypto_scalarmult_curve25519_donna(const std::string &,const std::string &);
extern std::string crypto_scalarmult_curve25519_donna_base(const std::string &);
extern "C" {
#endif
extern int crypto_scalarmult_curve25519_donna(unsigned char *,const unsigned char *,const unsigned char *);
extern int crypto_scalarmult_curve25519_donna_base(unsigned char *,const unsigned char *);
#ifdef __cplusplus
}
#endif

#define crypto_scalarmult_curve25519 crypto_scalarmult_curve25519_donna
#define crypto_scalarmult_curve25519_base crypto_scalarmult_curve25519_donna_base
#define crypto_scalarmult_curve25519_BYTES crypto_scalarmult_curve25519_donna_BYTES
#define crypto_scalarmult_curve25519_SCALARBYTES crypto_scalarmult_curve25519_donna_SCALARBYTES
#define crypto_scalarmult_curve25519_IMPLEMENTATION "crypto_scalarmult/curve25519/ref"
#ifndef crypto_scalarmult_curve25519_donna_VERSION
#define crypto_scalarmult_curve25519_donna_VERSION "-"
#endif
#define crypto_scalarmult_curve25519_VERSION crypto_scalarmult_curve25519_donna_VERSION

#endif
