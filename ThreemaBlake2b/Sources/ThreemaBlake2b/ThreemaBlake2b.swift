//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

@_implementationOnly import CThreemaBlake2b
// @_implementationOnly is needed such that we don't need to expose `CThreemaBlake2b` to module clients
// https://forums.swift.org/t/issue-with-third-party-dependencies-inside-a-xcframework-through-spm/41977/3
import Foundation

/// Threema BLAKE2b Swift bindings
///
/// There are function to derive a new key and to hash. They allow for various inputs using `Data` or `String`s.
/// If BLAKE2b is called more than once with the same personal a struct instance can be created.
public struct ThreemaBlake2b: Sendable {
    
    public enum Error: Swift.Error {
        case wrongKeySize
        case inputEmpty
        case saltEmpty
        case saltTooLong
        case personalEmpty
        case personalTooLong
        case failedToInitialize
        case failedToAppendInput
        case failedToFinalize
    }
    
    /// Digest length in bytes
    public enum DigestLength: Int {
        case b32 = 32
        case b64 = 64
    }
    
    // MARK: Private properties
    
    private let personal: Data
    
    // MARK: - Lifecycle
    
    /// Create new instance that uses the provided personal
    /// - Parameter personal: Personal UTF-8 string to use in all calls of this instance
    /// - Throws:`ThreemaBlake2b.Error.personalTooLong`
    public init(personal: String) throws {
        try self.init(personal: Data(personal.utf8))
    }
    
    /// Create new instance that uses the provided personal
    /// - Parameter personal: Personal to use in all calls of this instance
    /// - Throws: `ThreemaBlake2b.Error.personalTooLong`
    public init(personal: Data) throws {
        guard personal.count <= BLAKE2B_PERSONALBYTES.rawValue else {
            throw Error.personalTooLong
        }
        
        self.personal = personal
    }
    
    // MARK: - Key derivation
    
    /// Derive a new key from the provided key
    ///
    /// This uses the `personal` provided to the initializer.
    ///
    /// - Parameters:
    ///   - key: Key used for derivation
    ///   - salt: Salt as UTF-8 string used for derivation
    ///   - input: Optional input used for derivation
    ///   - derivedKeyLength: Length of new key
    /// - Returns: Key of size `derivedKeyLength`
    /// - Throws: `ThreemaBlake2b.Error`
    public func deriveKey(
        from key: Data,
        with salt: String,
        input: Data...,
        derivedKeyLength: DigestLength
    ) throws -> Data {
        try ThreemaBlake2b.deriveKey(
            from: key,
            with: Data(salt.utf8),
            personal: personal,
            input: input,
            derivedKeyLength: derivedKeyLength
        )
    }
    
    /// Derive a new key from the provided key
    ///
    /// This uses the `personal` provided to the initializer.
    ///
    /// - Parameters:
    ///   - key: Key used for derivation
    ///   - salt: Salt used for derivation
    ///   - input: Optional input used for derivation
    ///   - derivedKeyLength: Length of new key
    /// - Returns: Key of size `derivedKeyLength`
    /// - Throws: `ThreemaBlake2b.Error`
    public func deriveKey(
        from key: Data,
        with salt: Data,
        input: Data...,
        derivedKeyLength: DigestLength
    ) throws -> Data {
        try ThreemaBlake2b.deriveKey(
            from: key,
            with: salt,
            personal: personal,
            input: input,
            derivedKeyLength: derivedKeyLength
        )
    }
    
    /// Derive a new key from the provided key
    ///
    /// - Parameters:
    ///   - key: Key used for derivation
    ///   - salt: Salt as UTF-8 string used for derivation
    ///   - personal: Personal as UTF-8 string used for derivation
    ///   - input: Optional input used for derivation
    ///   - derivedKeyLength: Length of new key
    /// - Returns: Key of size `derivedKeyLength`
    /// - Throws: `ThreemaBlake2b.Error`
    public static func deriveKey(
        from key: Data,
        with salt: String,
        personal: String,
        input: Data...,
        derivedKeyLength: DigestLength
    ) throws -> Data {
        try deriveKey(
            from: key,
            with: Data(salt.utf8),
            personal: Data(personal.utf8),
            input: input,
            derivedKeyLength: derivedKeyLength
        )
    }
    
    /// Derive a new key from the provided key
    ///
    /// - Parameters:
    ///   - key: Key used for derivation
    ///   - salt: Salt as UTF-8 string used for derivation
    ///   - personal: Personal used for derivation
    ///   - input: Optional input used for derivation
    ///   - derivedKeyLength: Length of new key
    /// - Returns: Key of size `derivedKeyLength`
    /// - Throws: `ThreemaBlake2b.Error`
    public static func deriveKey(
        from key: Data,
        with salt: String,
        personal: Data,
        input: Data...,
        derivedKeyLength: DigestLength
    ) throws -> Data {
        try deriveKey(
            from: key,
            with: Data(salt.utf8),
            personal: personal,
            input: input,
            derivedKeyLength: derivedKeyLength
        )
    }
    
    /// Derive a new key from the provided key
    ///
    /// - Parameters:
    ///   - key: Key used for derivation
    ///   - salt: Salt used for derivation
    ///   - personal: Personal used for derivation
    ///   - input: Optional input used for derivation
    ///   - derivedKeyLength: Length of new key
    /// - Returns: Key of size `derivedKeyLength`
    /// - Throws: `ThreemaBlake2b.Error`
    public static func deriveKey(
        from key: Data,
        with salt: Data,
        personal: Data,
        input: Data...,
        derivedKeyLength: DigestLength
    ) throws -> Data {
        try deriveKey(from: key, with: salt, personal: personal, input: input, derivedKeyLength: derivedKeyLength)
    }
    
    // MARK: Private key derivation
    
    // This is needed for validation and as variadic inputs appear as arrays and cannot be passed on to another
    // variadic input
    public static func deriveKey(
        from key: Data,
        with salt: Data,
        personal: Data,
        input: [Data],
        derivedKeyLength: DigestLength
    ) throws -> Data {
        // Key is required
        guard !key.isEmpty else {
            throw Error.wrongKeySize
        }
        
        return try blake2b(input, key: key, salt: salt, personal: personal, hashLength: derivedKeyLength)
    }
    
    // MARK: - Hashing
    
    /// Hash of the input data
    ///
    /// This uses the `personal` provided to the initializer.
    ///
    /// - Parameters:
    ///   - input: Input data to hash
    ///   - key: Optional key used for hashing
    ///   - salt: Salt as UTF-8 string used for hashing
    ///   - hashLength: Length of hash
    /// - Returns: Hash of length `hashLength`
    /// - Throws: `ThreemaBlake2b.Error`
    public func hash(_ input: Data..., key: Data? = nil, salt: String, hashLength: DigestLength) throws -> Data {
        try ThreemaBlake2b.hash(input, key: key, salt: Data(salt.utf8), personal: personal, hashLength: hashLength)
    }
    
    /// Hash of the input data
    ///
    /// This uses the `personal` provided to the initializer.
    ///
    /// - Parameters:
    ///   - input: Input data to hash
    ///   - key: Optional key used for hashing
    ///   - salt: Optional salt used for hashing
    ///   - hashLength: Length of hash
    /// - Returns: Hash of length `hashLength`
    /// - Throws: `ThreemaBlake2b.Error`
    public func hash(_ input: Data..., key: Data? = nil, salt: Data? = nil, hashLength: DigestLength) throws -> Data {
        try ThreemaBlake2b.hash(input, key: key, salt: salt, personal: personal, hashLength: hashLength)
    }
    
    /// Hash of the input data
    ///
    /// - Parameters:
    ///   - input: Input data to hash
    ///   - key: Optional key used for hashing
    ///   - salt: Salt as UTF-8 string used for hashing
    ///   - personal: Personal as UTF-8 string used for hashing
    ///   - hashLength: Length of hash
    /// - Returns: Hash of length `hashLength`
    /// - Throws: `ThreemaBlake2b.Error`
    public static func hash(
        _ input: Data...,
        key: Data? = nil,
        salt: String,
        personal: String,
        hashLength: DigestLength
    ) throws -> Data {
        try ThreemaBlake2b.hash(
            input,
            key: key,
            salt: Data(salt.utf8),
            personal: Data(personal.utf8),
            hashLength: hashLength
        )
    }
    
    /// Hash of the input data
    ///
    /// - Parameters:
    ///   - input: Input data to hash
    ///   - key: Optional key used for hashing
    ///   - salt: Optional salt used for hashing
    ///   - personal: Optional personal used for hashing
    ///   - hashLength: Length of hash
    /// - Returns: Hash of length `hashLength`
    /// - Throws: `ThreemaBlake2b.Error`
    public static func hash(
        _ input: Data...,
        key: Data? = nil,
        salt: Data? = nil,
        personal: Data? = nil,
        hashLength: DigestLength
    ) throws -> Data {
        try hash(input, key: key, salt: salt, personal: personal, hashLength: hashLength)
    }
    
    // MARK: Private hash
    
    // This is needed for validation and as variadic inputs appear as arrays and cannot be passed on to another
    // variadic input
    public static func hash(
        _ input: [Data],
        key: Data? = nil,
        salt: Data? = nil,
        personal: Data? = nil,
        hashLength: DigestLength
    ) throws -> Data {
        guard !input.isEmpty else {
            throw Error.inputEmpty
        }
        
        return try blake2b(input, key: key, salt: salt, personal: personal, hashLength: hashLength)
    }
    
    // MARK: - BLAKE2b helper
    
    private static func blake2b(
        _ input: [Data],
        key: Data?,
        salt: Data?,
        personal: Data?,
        hashLength: DigestLength
    ) throws -> Data {
        // Key has to be either `nil` or 32 or 64 bytes
        guard key == nil || key?.count == 32 || key?.count == 64 else {
            throw Error.wrongKeySize
        }
        
        // Salt has to be `nil` or non-empty
        guard !(salt?.isEmpty ?? false) else {
            throw Error.saltEmpty
        }
        guard salt?.count ?? 0 <= BLAKE2B_SALTBYTES.rawValue else {
            throw Error.saltTooLong
        }
        
        // Personal has to be `nil` or non-empty
        guard !(personal?.isEmpty ?? false) else {
            throw Error.personalEmpty
        }
        guard personal?.count ?? 0 <= BLAKE2B_PERSONALBYTES.rawValue else {
            throw Error.personalTooLong
        }
        
        // Create and init state
        var state = blake2b_state()
        let result = key.withUnsafeBytes { keyBytes in
            salt.withUnsafeBytes { saltBytes in
                personal.withUnsafeBytes { personalBytes in
                    // `baseAddress` is not guaranteed to be `nil` if `count` is 0. Thus the workarounds below.
                    // (e.g. for `Data().withUnsafeBytes(_:)`)
                    blake2b_init_universal(
                        &state,
                        hashLength.rawValue,
                        keyBytes.isEmpty ? nil : keyBytes.baseAddress,
                        keyBytes.count,
                        saltBytes.isEmpty ? nil : saltBytes.baseAddress,
                        saltBytes.count,
                        personalBytes.isEmpty ? nil : personalBytes.baseAddress,
                        personalBytes.count
                    )
                }
            }
        }
        
        guard result == 0 else {
            throw Error.failedToInitialize
        }
        
        // Add input
        for dataInput in input {
            let result = dataInput.withUnsafeBytes { dataInputBytes in
                blake2b_update(&state, dataInputBytes.baseAddress, dataInputBytes.count)
            }
            
            guard result == 0 else {
                throw Error.failedToAppendInput
            }
        }
        
        // Finalize
        return try finalize(state: &state, digestLength: hashLength)
    }
        
    /// Finalize the computation and provide the digest
    ///
    /// - Parameters:
    ///   - state: State of current run
    ///   - digestLength: Desired length of digest
    /// - Returns: Digest of length `digestLength`
    private static func finalize(state: inout blake2b_state, digestLength: DigestLength) throws -> Data {
        var hash = Data(count: digestLength.rawValue)
        let result = hash.withUnsafeMutableBytes { hashBytes in
            blake2b_final(&state, hashBytes.baseAddress, hashBytes.count)
        }
        
        guard result == 0 else {
            throw Error.failedToFinalize
        }
        
        return hash
    }
}

extension Data? {
    /// Get bytes pointer from optional `Data`
    ///
    /// For non-`nil` `Data` it calls
    /// `Data.withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType`
    /// otherwise it creates an empty `UnsafeRawBufferPointer` and passes this to the closure.
    ///
    /// This is a workaround to allow pointer access on an optional `Data` instance.
    ///
    /// - Parameter body: Closure to be called with `UnsafeRawBufferPointer` to data or empty pointer
    /// - Returns: Value returned in closure
    fileprivate func withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows
        -> ResultType {
        switch self {
        case .none:
            let emptyUnsafeRawBufferPointer = UnsafeRawBufferPointer(start: nil, count: 0)
            return try body(emptyUnsafeRawBufferPointer)
        case let .some(wrapped):
            return try wrapped.withUnsafeBytes(body)
        }
    }
}
