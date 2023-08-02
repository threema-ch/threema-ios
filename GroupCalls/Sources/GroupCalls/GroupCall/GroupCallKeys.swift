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
@preconcurrency import WebRTC

struct GroupCallKeys: Sendable {
    // MARK: - Internal Properties

    /// Group Call Key, only used for key derivation
    let gck: Data
    /// Group Call Handshake Key
    let gchk: Data
    ///  Group Call State Key
    let gcsk: Data
    /// Group Call Key Hash
    let gckh: Data

    // MARK: - Private Properties
    
    private let dependencies: Dependencies
    
    // MARK: - Lifecycle
    
    init(gck: Data, dependencies: Dependencies) throws {
        self.dependencies = dependencies
        self.gck = gck
        self.gchk = try GroupCallKeys.gchk(gck: gck, dependencies: dependencies)
        self.gcsk = try GroupCallKeys.gcsk(gck: gck, dependencies: dependencies)
        self.gckh = try GroupCallKeys.gckh(gck: gck, dependencies: dependencies)
    }
}

// MARK: - GroupCallKeys.GrupCallKeyError

extension GroupCallKeys {
    enum GrupCallKeyError: Error {
        case FatalError
        case EncodingError
    }
}

// MARK: - Key Derivation

extension GroupCallKeys {
    func deriveGCNHAK(from sharedSecret: Data) throws -> Data {
        let salt = try GroupCallKeys.encodeAndPad("nha")
        let personal = try GroupCallKeys.encodeAndPad(ProtocolDefines.GC_PERSONAL)
        
        return try ThreemaBlake2b(personal: personal).deriveKey(
            from: sharedSecret,
            with: salt,
            input: gckh,
            derivedKeyLength: .b32
        )
    }
}

// MARK: - Helper Functions

extension GroupCallKeys {
    static func deriveCallID(from inputs: [Data], dependencies: Dependencies) throws -> Data {
        let salt = try encodeAndPad("i")
        let personal = try encodeAndPad(ProtocolDefines.GC_PERSONAL)
        
        var inputData = Data()
        
        for input in inputs {
            inputData.append(input)
        }
        
        return try ThreemaBlake2b(personal: personal).hash(inputData, salt: salt, hashLength: .b32)
    }
    
    static func derivePCMK(from key: Data, dependencies: Dependencies) throws -> Data {
        try derive(key: key, salt: "m'", dependencies: dependencies)
    }
}

extension GroupCallKeys {
    fileprivate static func gchk(gck: Data, dependencies: Dependencies) throws -> Data {
        try derive(key: gck, salt: "h", dependencies: dependencies)
    }
    
    fileprivate static func gcsk(gck: Data, dependencies: Dependencies) throws -> Data {
        try derive(key: gck, salt: "s", dependencies: dependencies)
    }
    
    fileprivate static func gckh(gck: Data, dependencies: Dependencies) throws -> Data {
        try derive(key: gck, salt: "#", dependencies: dependencies)
    }
    
    private static func derive(key: Data, salt: String, dependencies: Dependencies) throws -> Data {
        let salt = try encodeAndPad(salt)
        let personal = try encodeAndPad(ProtocolDefines.GC_PERSONAL)
        
        return try ThreemaBlake2b(personal: personal).deriveKey(
            from: key,
            with: salt,
            derivedKeyLength: .b32
        )
    }
}

extension GroupCallKeys {
    fileprivate static func encodeAndPad(_ string: String) throws -> Data {
        guard var value = string.data(using: .utf8) else {
            assertionFailure()
            throw GrupCallKeyError.FatalError
        }
        
        guard value.count <= 16 else {
            assertionFailure()
            throw GrupCallKeyError.FatalError
        }
        
        value.append(Data(repeating: 0x00, count: 16 - value.count))
        
        return value
    }
}
