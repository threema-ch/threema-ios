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

import CocoaLumberjackSwift
import Foundation
import ThreemaProtocols

extension MessageDecoder {
    static func decode(
        encapsulated: Data,
        with outer: AbstractMessage,
        for appliedVersion: CspE2eFs_Version
    ) throws -> AbstractMessage? {
        guard encapsulated.count < Int32.max else {
            DDLogError("Message size is too large.")
            return nil
        }
        
        guard let msg = MessageDecoder.decodeRawBody(encapsulated, realDataLength: Int32(encapsulated.count)) else {
            DDLogError("Could not decode message")
            return nil
        }
        
        if msg is ForwardSecurityEnvelopeMessage {
            /// This is additionally checked in MessageProcessor just
            /// under the `Don't allow double encapsulated forward security messages`
            /// comment.
            throw BadMessageError.unexpectedGroupMessageEncapsulated
        }
        
        switch appliedVersion {
        case .unspecified, .v10, .v11:
            // Technically, typing-indicator and delivery-receipts are not allowed for V1.0 but they don't do any harm,
            // so we'll let this slide through for simplicity.
            
            // Disallow encapsulation of group messages for V1.X
            if msg is AbstractGroupMessage {
                throw BadMessageError.unexpectedGroupMessageEncapsulated
            }
        case .v12:
            // Starting with V1.2 we also support group messages
            break
        case .UNRECOGNIZED:
            DDLogError("Unhandled FS version when decapsulating: \(appliedVersion)")
            throw BadMessageError.invalidFSVersion
        }
        
        // Copy header fields from outer message
        msg.fromIdentity = outer.fromIdentity
        msg.toIdentity = outer.toIdentity
        msg.messageID = outer.messageID
        msg.delivered = outer.delivered
        msg.date = outer.date
        msg.deliveryDate = outer.deliveryDate
        msg.userAck = outer.userAck
        msg.sendUserAck = outer.sendUserAck
        msg.nonce = outer.nonce
        msg.flags = outer.flags
        msg.receivedAfterInitialQueueSend = outer.receivedAfterInitialQueueSend
        msg.pushFromName = outer.pushFromName
        
        // Fix group message creator
        // For group control messages the creator is normally not included in the message itself. Thus we fix this here.
        // This should be in sync with the other place with the comment "Fix group message creator"
        if let groupMsg = msg as? AbstractGroupMessage {
            if groupMsg is GroupCreateMessage ||
                groupMsg is GroupRenameMessage ||
                groupMsg is GroupSetPhotoMessage ||
                groupMsg is GroupDeletePhotoMessage {
                groupMsg.groupCreator = outer.fromIdentity
            }
            else if groupMsg is GroupRequestSyncMessage {
                groupMsg.groupCreator = outer.toIdentity
            }
        
            // Validation
            assert(groupMsg.groupID != nil)
            assert(groupMsg.groupCreator != nil)
        }
        
        return msg
    }
}
