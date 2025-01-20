//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

public class UserNotificationContent {
    private let pendingUserNotification: PendingUserNotification
    
    init(_ pendingUserNotification: PendingUserNotification) {
        self.pendingUserNotification = pendingUserNotification
    }
    
    var stage: UserNotificationStage {
        pendingUserNotification.stage
    }
    
    public var messageID: String! {
        pendingUserNotification.messageID
    }
    
    public var senderID: String! {
        pendingUserNotification.senderIdentity
    }
    
    public var isGroupMessage: Bool! {
        pendingUserNotification.isGroupMessage
    }
    
    var fromName: String?
    var title: String?
    var body: String?
    var attachmentName: String?
    var attachmentURL: URL?
    
    var cmd: String! {
        var commandValue: ThreemaPushNotification.Command?
        
        if let baseMsg = pendingUserNotification.baseMessage {
            commandValue = baseMsg.isGroupMessage ? .newGroupMessage : .newMessage
        }
        else if let abstractMsg = pendingUserNotification.abstractMessage {
            commandValue = abstractMsg.flagGroupMessage() ? ThreemaPushNotification.Command
                .newGroupMessage : ThreemaPushNotification.Command.newMessage
        }
        else if let command = pendingUserNotification.threemaPushNotification?.command {
            commandValue = command
        }
        
        return commandValue?.rawValue
    }
    
    var categoryIdentifier: String {
        (pendingUserNotification.isGroupMessage ?? false) ? "GROUP" : "SINGLE"
    }
    
    var groupID: String?
    var groupCreator: String?
    
    var userInfo: [String: [String: String]] {
        if isGroupMessage {
            if let groupID, let groupCreator {
                [
                    "threema": [
                        "cmd": cmd,
                        "from": senderID,
                        "messageId": messageID,
                        "groupId": groupID,
                        "groupCreator": groupCreator,
                    ],
                ]
            }
            else {
                // This can happen if base message was never set
                [
                    "threema": [
                        "cmd": cmd,
                        "from": senderID,
                        "messageId": messageID,
                    ],
                ]
            }
        }
        else {
            ["threema": ["cmd": cmd, "from": senderID, "messageId": messageID]]
        }
    }
    
    public func isGroupCallStartMessage() -> Bool {
        if let abstractMessage = pendingUserNotification.abstractMessage,
           abstractMessage.isKind(of: GroupCallStartMessage.self) {
            return true
        }
        return false
    }
}
