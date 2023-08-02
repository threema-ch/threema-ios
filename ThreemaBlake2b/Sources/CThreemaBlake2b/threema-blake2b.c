//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

#include "threema-blake2b.h"

int blake2b_init_universal(
    blake2b_state* const S,
    size_t const digest_length,
    uint8_t const* const key,
    size_t const key_length,
    uint8_t const* const salt,
    size_t const salt_length,
    uint8_t const* const personal,
    size_t const personal_length
) {
    // Check parameters
    if (digest_length != 32 && digest_length != 64) {
        return -1;
    }
    if (key && key_length != 32 && key_length != 64) {
        return -1;
    }
    if (!key && key_length != 0) {
        return -1;
    }
    if (salt && salt_length > BLAKE2B_SALTBYTES) {
        return -1;
    }
    if (!salt && salt_length != 0) {
        return -1;
    }
    if (personal && personal_length > BLAKE2B_PERSONALBYTES) {
        return -1;
    }
    if (!personal && personal_length != 0) {
        return -1;
    }

    // Set parameters
    blake2b_param P[1];
    P->digest_length = (uint8_t) digest_length;
    P->key_length = (uint8_t) key_length;
    P->fanout = 1;
    P->depth = 1;
    store32(&P->leaf_length, 0);
    store32(&P->node_offset, 0);
    store32(&P->xof_length,  0);
    P->node_depth = 0;
    P->inner_length = 0;
    memset(P->reserved, 0, sizeof(P->reserved));
    memset(P->salt, 0, sizeof(P->salt));
    memset(P->personal, 0, sizeof(P->personal));
    if (salt) {
        memcpy(P->salt, salt, salt_length);
    }
    if (personal) {
        memcpy(P->personal, personal, personal_length);
    }

    // Initialise parameters
    if (blake2b_init_param(S, P) < 0) {
        return -1;
    }

    // From the spec (2.9): "When keyed (that is, when the field key length is
    // non-zero), BLAKE2 sets the first data block to the key padded with
    // zeros."
    if (key) {
        uint8_t block[BLAKE2B_BLOCKBYTES];
        memset(block, 0, BLAKE2B_BLOCKBYTES);
        memcpy(block, key, key_length);
        if (blake2b_update(S, block, BLAKE2B_BLOCKBYTES) != 0) {
            return -1;
        }
        secure_zero_memory(block, BLAKE2B_BLOCKBYTES); // Burn the key from stack
    }

    return 0;
}
