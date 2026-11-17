import Foundation

public final class UserNotificationContent {
    /// Key of the reacted message's ID in the `threema` dictionary of a notification about a reaction
    public static let reactedMessageIDKey = "reactedMessageId"

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
        var threemaInfo: [String: String] = ["cmd": cmd, "from": senderID, "messageId": messageID]

        // Group ID and creator can be missing if base message was never set
        if isGroupMessage, let groupID, let groupCreator {
            threemaInfo["groupId"] = groupID
            threemaInfo["groupCreator"] = groupCreator
        }

        if isReactionMessage(), let reactedMessageID = pendingUserNotification.baseMessage?.id.hexString {
            threemaInfo[UserNotificationContent.reactedMessageIDKey] = reactedMessageID
        }

        return ["threema": threemaInfo]
    }
    
    public func isGroupCallStartMessage() -> Bool {
        if let abstractMessage = pendingUserNotification.abstractMessage,
           abstractMessage.isKind(of: GroupCallStartMessage.self) {
            return true
        }
        return false
    }

    /// Is this the notification about a reaction to a message?
    public func isReactionMessage() -> Bool {
        pendingUserNotification.abstractMessage is ReactionMessage
            || pendingUserNotification.abstractMessage is GroupReactionMessage
    }
}
