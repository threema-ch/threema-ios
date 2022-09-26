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

    blake2b_final(S, out, THREEMA_KDF_SUBKEYBYTES);
    return 0;
}
