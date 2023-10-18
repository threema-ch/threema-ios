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

import CocoaLumberjackSwift
import Foundation
import ThreemaBlake2b

struct GroupCallKeys: Sendable {
    
    // MARK: - Keys

    /// Group Call Key, only used for key derivation
    private let gck: Data
    /// Group Call Key Hash
    let gckh: Data
    /// Group Call Handshake Key
    let gchk: Data
    /// Group Call State Key
    let gcsk: Data

    // MARK: - Private Properties
    
    private let threemaBlake2b: ThreemaBlake2b
    
    // MARK: - Lifecycle
    
    /// Create new set of group call keys
    /// - Parameter gck: Group Call Key used for derivation
    /// - Throws: `GroupCallError.keyDerivationError` if any derivation fails
    init(gck: Data) throws {
        self.gck = gck
        
        do {
            let threemaBlake2bLocal = try ThreemaBlake2b(personal: ProtocolDefines.personal)
            
            self.gckh = try GroupCallKeys.gckh(gck: gck, threemaBlake2b: threemaBlake2bLocal)
            self.gchk = try GroupCallKeys.gchk(gck: gck, threemaBlake2b: threemaBlake2bLocal)
            self.gcsk = try GroupCallKeys.gcsk(gck: gck, threemaBlake2b: threemaBlake2bLocal)
            
            self.threemaBlake2b = threemaBlake2bLocal
        }
        catch {
            DDLogError("[GroupCall]: Unable to initialize group call keys: \(error)")
            throw GroupCallError.keyDerivationError
        }
    }
}

// MARK: - Key Derivation

extension GroupCallKeys {
    /// Derive Group Call Normal Handshake Authentication Key (GCNHAK)
    /// - Parameter sharedSecret: Shared secret used for derivation
    /// - Returns: Derived GCNHAK
    /// - Throws: `GroupCallError.keyDerivationError` if derivation fails
    func deriveGCNHAK(from sharedSecret: Data) throws -> Data {
        do {
            return try threemaBlake2b.deriveKey(
                from: sharedSecret,
                with: "nha",
                input: gckh,
                derivedKeyLength: .b32
            )
        }
        catch {
            DDLogError("[GroupCall]: Unable to derive GCNHAK: \(error)")
            throw GroupCallError.keyDerivationError
        }
    }
}

// MARK: - Helper functions

extension GroupCallKeys {
    /// Derive call ID from inputs
    /// - Parameter inputs: Inputs to derive key from
    /// - Returns: Derived call ID
    /// - Throws: `GroupCallError.keyDerivationError` if derivation fails
    static func deriveCallID(from inputs: [Data]) throws -> Data {
        let saltData = Data("i".utf8)
        let personalData = Data(ProtocolDefines.personal.utf8)
        
        do {
            return try ThreemaBlake2b.hash(inputs, salt: saltData, personal: personalData, hashLength: .b32)
        }
        catch {
            DDLogError("[GroupCall]: Unable to derive call id: \(error)")
            throw GroupCallError.keyDerivationError
        }
    }
    
    /// Derive ratchet iteration of PCMK (PCMK')
    /// - Parameter pcmk: PCMK to derive ratchet iteration from
    /// - Returns: Derived PCMK'
    /// - Throws: `GroupCallError.keyDerivationError` if derivation fails
    static func deriveNextPCMK(from pcmk: Data) throws -> Data {
        do {
            return try ThreemaBlake2b.deriveKey(
                from: pcmk,
                with: "m'",
                personal: ProtocolDefines.personal,
                derivedKeyLength: .b32
            )
        }
        catch {
            DDLogError("[GroupCall]: Unable to derive PCMK: \(error)")
            throw GroupCallError.keyDerivationError
        }
    }
}

// MARK: - Private helper functions

// Note: These don't throw a `GroupCallError`, but `ThreemaBlake2b.Error`s directly

extension GroupCallKeys {
    fileprivate static func gckh(gck: Data, threemaBlake2b: ThreemaBlake2b) throws -> Data {
        try threemaBlake2b.deriveKey(from: gck, with: "#", derivedKeyLength: .b32)
    }

    fileprivate static func gchk(gck: Data, threemaBlake2b: ThreemaBlake2b) throws -> Data {
        try threemaBlake2b.deriveKey(from: gck, with: "h", derivedKeyLength: .b32)
    }
    
    fileprivate static func gcsk(gck: Data, threemaBlake2b: ThreemaBlake2b) throws -> Data {
        try threemaBlake2b.deriveKey(from: gck, with: "s", derivedKeyLength: .b32)
    }
}
