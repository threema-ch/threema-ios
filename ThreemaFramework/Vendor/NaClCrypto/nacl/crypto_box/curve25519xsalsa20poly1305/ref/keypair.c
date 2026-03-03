#include "crypto_scalarmult_curve25519.h"
#include "crypto_box.h"
#include "randombytes.h"

int crypto_box_curve25519xsalsa20poly1305_ref_keypair(
  unsigned char *pk,
  unsigned char *sk
)
{
  randombytes(sk,32);
  return crypto_scalarmult_curve25519_base(pk,sk);
}
