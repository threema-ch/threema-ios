//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

#pragma once

#include "blake2.h"
#include "blake2-impl.h"
#include <stdint.h>
#include <string.h>

/// Initialize  BLAKE2b state
///
/// - Parameters:
///   - S: State of current run. Must be provided
///   - digest_length: Must be 32 or 64
///   - key: Must be `NULL` or contain exactly `key_length` bytes
///   - key_length: Must be 0, 32 or 64
///   - salt: Must be `NULL` or contain exactly `salt_length` bytes
///   - salt_length: Must be 0 or ≤ `BLAKE2B_SALTBYTES`
///   - personal: Must be `NULL` or contain exactly `personal_length` bytes
///   - personal_length: Must be 0 or ≤ `BLAKE2B_PERSONALBYTES`
int blake2b_init_universal(
    blake2b_state* const S,
    size_t const digest_length,
    uint8_t const* const key,
    size_t const key_length,
    uint8_t const* const salt,
    size_t const salt_length,
    uint8_t const* const personal,
    size_t const personal_length
);
