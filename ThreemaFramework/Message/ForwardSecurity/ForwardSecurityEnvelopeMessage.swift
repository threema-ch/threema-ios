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

@objc class ForwardSecurityEnvelopeMessage: AbstractMessage {
    let data: ForwardSecurityData
    var encapAllowSendingProfile = false
    
    @objc init(data: ForwardSecurityData) {
        self.data = data
        super.init()
        self.flags = NSNumber(integerLiteral: 0)
    }
    
    required init?(coder: NSCoder) {
        do {
            self.data = try ForwardSecurityData
                .fromProtobuf(rawProtobufMessage: coder.decodeObject(forKey: "data") as! Data)
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
            coder.encode(try data.toProtobuf(), forKey: "data")
        }
        catch {
            NSException(name: NSExceptionName("EncodeFailedException"), reason: "Error: \(error)").raise()
            abort()
        }
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
}
