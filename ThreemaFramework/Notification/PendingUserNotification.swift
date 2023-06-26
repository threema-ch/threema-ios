//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import Intents

// Consist of sender identity (`ThreemaIdentity`) and the ID of the message
typealias PendingUserNotificationKey = String

public class PendingUserNotification: NSObject, NSCoding {
    
    let key: PendingUserNotificationKey
    var threemaPushNotification: ThreemaPushNotification?
    public internal(set) var abstractMessage: AbstractMessage?
    public internal(set) var baseMessage: BaseMessage? {
        didSet {
            baseMessageID = baseMessage?.id
        }
    }
    
    internal var baseMessageID: Data?
    public internal(set) var isPendingGroup = false
    public internal(set) var stage: UserNotificationStage = .initial
    var fireDate: Date?
    
    enum Keys {
        static let key = "key"
        static let threemaPushNotification = "threemaPushNotification"
        static let abstractMessage = "abstractMessage"
        static let baseMessageID = "baseMessageId"
        static let isPendingGroup = "isPendingGroup"
        static let stage = "stage"
        static let fireDate = "fireDate"
    }
    
    public init(key: String) {
        self.key = key
    }
    
    public required init?(coder: NSCoder) {
        guard let dKey = coder.decodeObject(forKey: "key") as? String else {
            return nil
        }
        self.key = dKey
        self.threemaPushNotification = coder.decodeObject(
            of: [ThreemaPushNotification.self],
            forKey: Keys.threemaPushNotification
        ) as? ThreemaPushNotification
        self.abstractMessage = try? coder.decodeTopLevelObject(
            of: [AbstractMessage.self],
            forKey: Keys.abstractMessage
        ) as? AbstractMessage
        self.baseMessageID = coder.decodeObject(forKey: Keys.baseMessageID) as? Data
        if let stageRawValue = coder.decodeObject(forKey: Keys.stage) as? String {
            self.stage = UserNotificationStage(rawValue: stageRawValue) ?? .initial
        }
        self.fireDate = coder.decodeObject(forKey: Keys.fireDate) as? Date
        self.isPendingGroup = coder.decodeBool(forKey: Keys.isPendingGroup)
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(key, forKey: Keys.key)
        coder.encode(threemaPushNotification, forKey: Keys.threemaPushNotification)
        coder.encode(abstractMessage, forKey: Keys.abstractMessage)
        coder.encode(baseMessageID, forKey: Keys.baseMessageID)
        coder.encode(stage.rawValue, forKey: Keys.stage)
        coder.encode(fireDate, forKey: Keys.fireDate)
        coder.encode(isPendingGroup, forKey: Keys.isPendingGroup)
    }
    
    public var isGroupMessage: Bool? {
        // `flagGroupMessage` is deprecated. If it is missing we don't know whether it is a group message or not
        // We thus do not use it for determining whether this is a group message or not
        if let msg = baseMessage {
            return msg.isGroupMessage
        }
        else if let msg = abstractMessage {
            return msg.flagGroupMessage()
        }
        else if let push = threemaPushNotification {
            return push.command == .newGroupMessage
        }
        else {
            return nil
        }
    }
    
    public var messageID: String? {
        if let id = baseMessage?.id {
            return id.hexString
        }
        else if let id = abstractMessage?.messageID {
            return id.hexString
        }
        else if let id = threemaPushNotification?.messageID {
            return id
        }
        else {
            return nil
        }
    }
    
    public var senderIdentity: String? {
        if let threemaPushNotification {
            return threemaPushNotification.from
        }
        if let abstractMessage,
           let from = abstractMessage.fromIdentity {
            return from
        }
        if let baseMessage {
            return baseMessage.sender?.identity
        }
        
        return nil
    }
}

extension PendingUserNotification {
    
    var interaction: INInteraction? {
        guard let senderIdentity,
              stage == .final else {
            return nil
        }

        let businessInjector = BusinessInjector()
        let intentCreator = IntentCreator(
            userSettings: businessInjector.userSettings,
            entityManager: businessInjector.backgroundEntityManager
        )

        // Differentiate between groups and 1-1 conversation
        if let abstractMessage = abstractMessage as? AbstractGroupMessage {
            return intentCreator.inSendMessageIntentInteraction(
                for: abstractMessage.groupID,
                creatorID: abstractMessage.groupCreator,
                contactID: senderIdentity,
                direction: .incoming
            )
        }
        else {
            return intentCreator.inSendMessageIntentInteraction(for: senderIdentity, direction: .incoming)
        }
    }
}

extension PendingUserNotificationKey {
    static func key(for threemaPush: ThreemaPushNotification) -> PendingUserNotificationKey? {
        threemaPush.from + threemaPush.messageID
    }

    static func key(for abstractMessage: AbstractMessage) -> PendingUserNotificationKey? {
        key(identity: abstractMessage.fromIdentity, messageID: abstractMessage.messageID)
    }

    static func key(for boxedMessage: BoxedMessage) -> PendingUserNotificationKey? {
        key(identity: boxedMessage.fromIdentity, messageID: boxedMessage.messageID)
    }

    static func key(identity: ThreemaIdentity?, messageID: Data?) -> PendingUserNotificationKey? {
        guard let identity, identity.isValid, let messageID else {
            return nil
        }

        return identity + messageID.hexString
    }
}
