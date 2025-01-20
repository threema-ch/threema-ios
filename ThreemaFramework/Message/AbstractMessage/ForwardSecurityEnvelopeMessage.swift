//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaEssentials
import ThreemaProtocols

@objc class ForwardSecurityEnvelopeMessage: AbstractMessage {
    let data: ForwardSecurityData
    var encapAllowSendingProfile = false
    
    @objc init(data: ForwardSecurityData) {
        self.data = data
        super.init()
        self.flags = NSNumber(integerLiteral: 0)
    }
    
    override func type() -> UInt8 {
        UInt8(MSGTYPE_FORWARD_SECURITY)
    }
    
    override func body() -> Data? {
        try? data.toProtobuf()
    }
    
    override func isContentValid() -> Bool {
        true
    }
    
    override func flagShouldPush() -> Bool {
        (flags.int32Value & MESSAGE_FLAG_SEND_PUSH) != 0
    }
    
    override func flagDontQueue() -> Bool {
        (flags.int32Value & MESSAGE_FLAG_DONT_QUEUE) != 0
    }
    
    override func flagDontAck() -> Bool {
        (flags.int32Value & MESSAGE_FLAG_DONT_ACK) != 0
    }
    
    override func flagImmediateDeliveryRequired() -> Bool {
        (flags.int32Value & MESSAGE_FLAG_IMMEDIATE_DELIVERY) != 0
    }
    
    override func allowSendingProfile() -> Bool {
        encapAllowSendingProfile
    }
    
    override public func minimumRequiredForwardSecurityVersion() -> ObjcCspE2eFs_Version {
        // Do not allow encapsulating forward security envelope messages
        ObjcCspE2eFs_Version.unspecified
    }

    // MARK: NSSecureCoding

    private enum CodingKeys: String, CodingKey {
        case data
    }

    private enum CodingError: Error {
        case decodeObjectFailed // , serializedDataFailed
    }

    required init?(coder: NSCoder) {
        do {
            guard let rawData = coder.decodeObject(of: NSData.self, forKey: CodingKeys.data.rawValue) else {
                throw CodingError.decodeObjectFailed
            }

            self.data = try ForwardSecurityData.fromProtobuf(rawProtobufMessage: Data(rawData))
            super.init(coder: coder)
        }
        catch {
            NSException(name: NSExceptionName("DecodeFailedException"), reason: "Error: \(error)").raise()
            abort()
        }
    }

    override func encode(with coder: NSCoder) {
        do {
            super.encode(with: coder)
            try coder.encode(NSData(data: data.toProtobuf()), forKey: CodingKeys.data.rawValue)
        }
        catch {
            NSException(name: NSExceptionName("EncodeFailedException"), reason: "Error: \(error)").raise()
            abort()
        }
    }

    override static var supportsSecureCoding: Bool {
        true
    }
    
    // MARK: Logging description
    
    override var loggingDescription: String {
        var groupIdentity: GroupIdentity?
        if let reject = data as? ForwardSecurityDataReject, let rejectGroupIdentity = reject.groupIdentity {
            groupIdentity = rejectGroupIdentity
        }
        else if let message = data as? ForwardSecurityDataMessage, let messageGroupIdentity = message.groupIdentity {
            groupIdentity = messageGroupIdentity
        }
        
        if let groupIdentity {
            return "(type: \(Common_CspE2eMessageType.forwardSecurityEnvelope); id: \(messageID.hexString); groupIdentity: \(groupIdentity))"
        }
        else {
            return "(type: \(Common_CspE2eMessageType.forwardSecurityEnvelope); id: \(messageID.hexString))"
        }
    }
}
