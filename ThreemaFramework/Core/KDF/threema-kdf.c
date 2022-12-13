//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#include "threema-kdf.h"
#include "blake2.h"
#include "blake2-impl.h"
#include "blake2-kat.h"

// Implementation based on `blake2b_init_key` and `blake2b`.
int blake2b_key_salt_personal(
    const uint8_t* key,
    const uint8_t* salt,
    const uint8_t* personal,
    uint8_t*       out
) {
    // Verify parameters
    if (!key || !salt || !personal || !out) {
        return -1;
    }

    // State
    blake2b_state S[1];

    // Parameters
    // Everything except for `salt` and `personal` is set like in `blake2b_init_key`.
    blake2b_param P[1];
    P->digest_length = (uint8_t) THREEMA_KDF_SUBKEYBYTES;
    P->key_length    = (uint8_t) THREEMA_KDF_KEYBYTES;
    P->fanout        = 1;
    P->depth         = 1;
    store32(&P->leaf_length, 0);
    store32(&P->node_offset, 0);
    store32(&P->xof_length,  0);
    P->node_depth    = 0;
    P->inner_length  = 0;
    if (sizeof(P->salt) != BLAKE2B_SALTBYTES) {
        return -1;
    }
    if (sizeof(P->personal) != BLAKE2B_PERSONALBYTES) {
        return -1;
    }
    memset(P->reserved, 0,        sizeof(P->reserved));
    memcpy(P->salt,     salt,     sizeof(P->salt));
    memcpy(P->personal, personal, sizeof(P->personal));

    // Init
    if (blake2b_init_param(S, P) < 0) {
        return -1;
    }

    // From the spec (2.9): "When keyed (that is, when the field key length is
    // non-zero), BLAKE2 sets the first data block to the key padded with
    // zeros."
    {
        uint8_t block[BLAKE2B_BLOCKBYTES];
        memset(block, 0, BLAKE2B_BLOCKBYTES);
        memcpy(block, key, THREEMA_KDF_KEYBYTES);
        blake2b_update(S, block, BLAKE2B_BLOCKBYTES);
        secure_zero_memory(block, BLAKE2B_BLOCKBYTES); // Burn the key from stack
    }

    if (blake2b_final(S, out, THREEMA_KDF_SUBKEYBYTES) < 0) {
        return -1;
    }
    return 0;
}

int blake2b_mac(
    const uint8_t *key,
    const uint8_t *input,
    size_t input_len,
    uint8_t *out
) {
    blake2b_state S[1];
    if (blake2b_init_key(S, THREEMA_KDF_MAC_LENGTH, key, THREEMA_KDF_SUBKEYBYTES) < 0) {
        return -1;
    }
    blake2b_update(S, input, input_len);
    if (blake2b_final(S, out, THREEMA_KDF_MAC_LENGTH) < 0) {
        return -1;
    }
    return 0;
}

int blake2b_hash(
    const uint8_t *input,
    size_t input_len,
    uint8_t *out
) {
    return blake2b(out, 32, input, input_len, NULL, 0);
}

int blake2b_self_test() {
    uint8_t key[BLAKE2B_KEYBYTES];
    uint8_t buf[BLAKE2_KAT_LENGTH];
    size_t i, step;

    for( i = 0; i < BLAKE2B_KEYBYTES; ++i )
      key[i] = ( uint8_t )i;

    for( i = 0; i < BLAKE2_KAT_LENGTH; ++i )
      buf[i] = ( uint8_t )i;

    /* Test simple API */
    for( i = 0; i < BLAKE2_KAT_LENGTH; ++i )
    {
      uint8_t hash[BLAKE2B_OUTBYTES];
      blake2b( hash, BLAKE2B_OUTBYTES, buf, i, key, BLAKE2B_KEYBYTES );

      if( 0 != memcmp( hash, blake2b_keyed_kat[i], BLAKE2B_OUTBYTES ) )
      {
        goto fail;
      }
    }

    /* Test streaming API */
    for(step = 1; step < BLAKE2B_BLOCKBYTES; ++step) {
      for (i = 0; i < BLAKE2_KAT_LENGTH; ++i) {
        uint8_t hash[BLAKE2B_OUTBYTES];
        blake2b_state S;
        uint8_t * p = buf;
        size_t mlen = i;
        int err = 0;

        if( (err = blake2b_init_key(&S, BLAKE2B_OUTBYTES, key, BLAKE2B_KEYBYTES)) < 0 ) {
          goto fail;
        }

        while (mlen >= step) {
          if ( (err = blake2b_update(&S, p, step)) < 0 ) {
            goto fail;
          }
          mlen -= step;
          p += step;
        }
        if ( (err = blake2b_update(&S, p, mlen)) < 0) {
          goto fail;
        }
        if ( (err = blake2b_final(&S, hash, BLAKE2B_OUTBYTES)) < 0) {
          goto fail;
        }

        if (0 != memcmp(hash, blake2b_keyed_kat[i], BLAKE2B_OUTBYTES)) {
          goto fail;
        }
      }
    }

    return 0;
  fail:
    return -1;
}
