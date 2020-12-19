#include "crypto_scalarmult.h"

static const unsigned char basepoint[32] = {9};

int crypto_scalarmult_curve25519_donna_base(unsigned char *q,const unsigned char *n)
{
  return crypto_scalarmult_curve25519_donna(q, n, basepoint);
}
