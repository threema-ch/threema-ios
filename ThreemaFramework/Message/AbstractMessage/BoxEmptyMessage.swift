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

final class BoxEmptyMessage: AbstractMessage {
    override func type() -> UInt8 {
        UInt8(MSGTYPE_EMPTY)
    }
    
    // No flags
    
    override func flagShouldPush() -> Bool {
        false
    }
    
    override func flagDontQueue() -> Bool {
        false
    }
    
    override func flagDontAck() -> Bool {
        false
    }
    
    override func flagGroupMessage() -> Bool {
        false
    }
    
    override func flagImmediateDeliveryRequired() -> Bool {
        false
    }
    
    override func flagIsVoIP() -> Bool {
        false
    }
    
    override func body() -> Data? {
        // Doesn't contain any content
        Data()
    }
    
    override func canCreateConversation() -> Bool {
        false
    }
    
    override func canUnarchiveConversation() -> Bool {
        false
    }
    
    override func needsConversation() -> Bool {
        false
    }
    
    override func canShowUserNotification() -> Bool {
        false
    }
    
    override func minimumRequiredForwardSecurityVersion() -> ObjcCspE2eFs_Version {
        // This should always be sent as PFS message. Thus a system message will be posted if an empty message is
        // received without FS and a FS session exists with the sender.
        // Old clients will just drop this as unknown message.
        .V10
    }
    
    override func isContentValid() -> Bool {
        // Every content is valid
        true
    }
    
    // pushNotificationBody left out as this is not needed
    
    override func allowSendingProfile() -> Bool {
        false
    }
    
    // getMessageIDString is a general implementation so no override needed
    
    override func noDeliveryReceiptFlagSet() -> Bool {
        true
    }
    
    // `NSSecureCoding` is inherited from `AbstractMessage`
}
