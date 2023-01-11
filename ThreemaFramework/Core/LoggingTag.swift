//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

enum LoggingTag: UInt8 {
    case none = 0x00

    case receiveIncomingMessageFromChat = 0x15
    case sendIncomingMessageAckToChat = 0x33
    case receiveIncomingMessageFromMediator = 0x78
    case sendIncomingMessageAckToMediator = 0x65
    case reflectIncomingMessageToMediator = 0x91
    case receiveIncomingMessageAckFromMediator = 0x24
    case reflectIncomingMessageUpdateToMediator = 0x31
    case receiveIncomingMessageUpdateAckFromMediator = 0x56

    case sendOutgoingMessageToChat = 0x82
    case receiveOutgoingMessageAckFromChat = 0x93
    case reflectOutgoingMessageToMediator = 0x03
    case receiveOutgoingMessageAckFromMediator = 0x55
    case reflectOutgoingMessageUpdateToMediator = 0x21
    case receiveOutgoingMessageUpdateAckFromMediator = 0x52

    case sendBeginTransactionToMediator = 0x34
    case receiveBeginTransactionAckFromMediator = 0x13
    case receiveTransactionRejectedFromMediator = 0x29
    case sendCommitTransactionToMediator = 0x61
    case receiveTransactionEndedFromMediator = 0x72

    var hexString: String {
        "[0x\(String(format: "%02hhx", rawValue))]"
    }
}
