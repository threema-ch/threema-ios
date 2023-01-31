//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

/// Errors for `ThreemaPushNotification` parsing
enum ThreemaPushNotificationError: Error, Equatable {
    case unknownCommand(String)
    case keyNotFoundOrTypeMissmatch(ThreemaPushNotificationDictionary)
}

/// Represents the payload in a push notifcation keyed with "threema"
public class ThreemaPushNotification: NSObject {
    
    /// A command that is part of of the push notification payload
    public enum Command: String, Codable {
        /// A new message in a chat with a single person
        case newMessage = "newmsg"
        /// A new message in a group chat
        case newGroupMessage = "newgroupmsg"
        
        /// Creates a new instance depending on the string
        /// - Parameter string: String representing a command
        /// - Throws: `ThreemaPushNotificationError` if command string is unknown
        init(from string: String) throws {
            switch string {
            case ThreemaPushNotificationDictionary.Command.newMessage.rawValue:
                self = .newMessage
            case ThreemaPushNotificationDictionary.Command.newGroupMessage.rawValue:
                self = .newGroupMessage
            default:
                throw ThreemaPushNotificationError.unknownCommand(string)
            }
        }
    }
    
    public let command: Command
    
    /// Message sender
    ///
    /// Needed to open the correct chat
    public let from: String
    
    public let messageID: String
    
    /// Indicates if the push notification is related to an incoming voip call
    public let voip: Bool?
    
    /// Parse an incoming push payload dictionary
    /// - Parameter dictionary: Dictionary to parse
    /// - Throws: `ThreemaPushNotificationError` if a required key is missing or a value cannot be parsed
    public init(from dictionary: [String: Any]) throws {
        
        let commandString = try ThreemaPushNotification.decode(String.self, forKey: .commandKey, in: dictionary)
        self.command = try Command(from: commandString)
        
        self.from = try ThreemaPushNotification.decode(String.self, forKey: .fromKey, in: dictionary)
        self.messageID = try ThreemaPushNotification.decode(String.self, forKey: .messageIDKey, in: dictionary)
        
        // For backwards compatiblity the voip key is also a string,
        // but in the future it could be a bool
        if let voipString = try? ThreemaPushNotification.decode(String.self, forKey: .voipKey, in: dictionary) {
            if voipString == ThreemaPushNotificationDictionary.Bool.true.rawValue {
                self.voip = true
            }
            else if voipString == ThreemaPushNotificationDictionary.Bool.false.rawValue {
                self.voip = false
            }
            else {
                self.voip = nil
            }
        }
        else {
            self.voip = try? ThreemaPushNotification.decode(Bool.self, forKey: .voipKey, in: dictionary)
        }
    }
    
    private static func decode<T>(
        _ type: T.Type,
        forKey key: ThreemaPushNotificationDictionary,
        in dictionary: [String: Any]
    ) throws -> T {
        
        if let decodedValue = dictionary[key.rawValue] as? T {
            return decodedValue
        }
        else {
            throw ThreemaPushNotificationError.keyNotFoundOrTypeMissmatch(key)
        }
    }
    
    /// Initializer for `NSCoding`
    /// - Parameter coder: Coder to decode from
    public required init?(coder: NSCoder) {
        guard let commandString = coder
            .decodeObject(forKey: ThreemaPushNotificationDictionary.commandKey.rawValue) as? String,
            let command = Command(rawValue: commandString) else {
            return nil
        }
        self.command = command
        
        guard let from = coder.decodeObject(forKey: ThreemaPushNotificationDictionary.fromKey.rawValue) as? String
        else {
            return nil
        }
        self.from = from
        
        guard let messageID = coder.decodeObject(forKey: ThreemaPushNotificationDictionary.messageIDKey.rawValue)
            as? String else {
            return nil
        }
        self.messageID = messageID
        
        self.voip = coder.decodeObject(forKey: ThreemaPushNotificationDictionary.voipKey.rawValue) as? Bool
    }
}

// MARK: - NSCoding

extension ThreemaPushNotification: NSCoding {

    // We still need to use NSCoding (instead of Codable), because there are dependencies
    // used in `PendingMessage` that are in Obj-C.
    // When we can remove this, `ThreemaPushNotification` can become a struct.
    
    public func encode(with coder: NSCoder) {
        coder.encode(command.rawValue, forKey: ThreemaPushNotificationDictionary.commandKey.rawValue)
        coder.encode(from, forKey: ThreemaPushNotificationDictionary.fromKey.rawValue)
        coder.encode(messageID, forKey: ThreemaPushNotificationDictionary.messageIDKey.rawValue)
        coder.encode(voip, forKey: ThreemaPushNotificationDictionary.voipKey.rawValue)
    }
}
