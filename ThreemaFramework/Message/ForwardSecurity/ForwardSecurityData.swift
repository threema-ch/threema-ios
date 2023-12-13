//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

import Foundation
import ThreemaProtocols

@objc class ForwardSecurityData: NSObject {
    let sessionID: DHSessionID
    
    init(sessionID: DHSessionID) {
        self.sessionID = sessionID
    }
    
    @objc static func fromProtobuf(rawProtobufMessage: Data) throws -> ForwardSecurityData {
        let protobufMessage = try CspE2eFs_Envelope(serializedData: rawProtobufMessage)
        let sessionID = try DHSessionID(value: protobufMessage.sessionID)
        
        switch protobufMessage.content! {
        case let .init_p(initv):
            return try ForwardSecurityDataInit(
                sessionID: sessionID,
                versionRange: initv.supportedVersion,
                ephemeralPublicKey: initv.fssk
            )
        case let .accept(accept):
            return try ForwardSecurityDataAccept(
                sessionID: sessionID,
                version: accept.supportedVersion,
                ephemeralPublicKey: accept.fssk
            )
        case let .reject(reject):
            return try ForwardSecurityDataReject(
                sessionID: sessionID,
                rejectedMessageID: withUnsafeBytes(of: reject.messageID) { Data($0) },
                cause: reject.cause
            )
        case let .encapsulated(message):
            let appliedVersion = CspE2eFs_Version(rawValue: Int(message.appliedVersion)) ??
                .UNRECOGNIZED(Int(message.appliedVersion))
            let offeredVersion = CspE2eFs_Version(rawValue: Int(message.offeredVersion)) ??
                .UNRECOGNIZED(Int(message.offeredVersion))
            
            return ForwardSecurityDataMessage(
                sessionID: sessionID,
                type: message.dhType,
                offeredVersion: offeredVersion,
                appliedVersion: appliedVersion,
                counter: message.counter,
                message: message.encryptedInner
            )
        case let .terminate(message):
            return ForwardSecurityDataTerminate(sessionID: sessionID, cause: message.cause)
        }
    }
    
    func toProtobuf() throws -> Data {
        fatalError("Subclasses need to implement the `toProtobuf()` method")
    }
}
