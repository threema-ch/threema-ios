//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

#ifndef THREEMA_KDF_H
#define THREEMA_KDF_H

#include "blake2.h"
#include "blake2-impl.h"

#define THREEMA_KDF_KEYBYTES 32
#define THREEMA_KDF_SUBKEYBYTES 32
#define THREEMA_KDF_MAC_LENGTH 32

/**
 * BLAKE2b function with key, salt and personalization.
 *
 * Notes:
 *
 * - `key` must be 32..64 bytes long
 * - `salt` must be of size BLAKE2B_SALTBYTES
 * - `personal` must be of size BLAKE2B_PERSONALBYTES
 * - `out` must be 32 bytes long
 */
int blake2b_key_salt_personal(
    const uint8_t* key,
    const int      key_length,
    const uint8_t* salt,
    const uint8_t* personal,
    uint8_t*       out
);

/**
 * Helper function for using BLAKE2b as a MAC.
 *
 * Notes:
 * - `key` must be 32 bytes long
 * - `out` must be 32 bytes long
 */
int blake2b_mac(
    const uint8_t *key,
    const uint8_t *input,
    size_t input_len,
    uint8_t *out
);

/**
 * Helper function for using BLAKE2b as a simple hash with variable output length (up to 64 bytes).
 */
int blake2b_hash(
    const uint8_t *input,
    size_t input_len,
    uint8_t *output,
    size_t output_len
);

/**
 * BLAKE2b self test, copied from `main()` see in file `blake2b-ref.c`.
 */
int blake2b_self_test(void);

#endif // THREEMA_KDF_H
