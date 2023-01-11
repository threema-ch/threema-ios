//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

@objc class ForwardSecurityData: NSObject {
    let sessionID: DHSessionID
    
    init(sessionID: DHSessionID) {
        self.sessionID = sessionID
    }
    
    @objc static func fromProtobuf(rawProtobufMessage: Data) throws -> ForwardSecurityData {
        let protobufMessage = try CspE2eFs_ForwardSecurityEnvelope(serializedData: rawProtobufMessage)
        let sessionID = try DHSessionID(value: protobufMessage.sessionID)
        
        switch protobufMessage.content! {
        case let .init_p(initv):
            return try ForwardSecurityDataInit(sessionID: sessionID, ephemeralPublicKey: initv.ephemeralPublicKey)
        case let .accept(accept):
            return try ForwardSecurityDataAccept(sessionID: sessionID, ephemeralPublicKey: accept.ephemeralPublicKey)
        case let .reject(reject):
            return try ForwardSecurityDataReject(
                sessionID: sessionID,
                rejectedMessageID: withUnsafeBytes(of: reject.rejectedMessageID) { Data($0) },
                cause: reject.cause
            )
        case let .message(message):
            return ForwardSecurityDataMessage(
                sessionID: sessionID,
                type: message.dhType,
                counter: message.counter,
                message: message.message
            )
        case .terminate:
            return ForwardSecurityDataTerminate(sessionID: sessionID)
        }
    }
    
    func toProtobuf() throws -> Data {
        fatalError("Subclasses need to implement the `toProtobuf()` method")
    }
}
