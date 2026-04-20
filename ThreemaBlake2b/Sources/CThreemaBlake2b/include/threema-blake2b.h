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
