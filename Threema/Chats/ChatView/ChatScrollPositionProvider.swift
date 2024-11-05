//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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

/// Information stored by `ChatScrollPositionProvider` implementations
struct ChatScrollPositionInfo: Codable {
    /// Offset of measured message bubble from the top
    let offsetFromTop: CGFloat
    /// Managed object ID URL of the message we calculated the offset from the top
    let messageObjectIDURL: URL
    /// Date of the message for fast fetching of messages around this message
    let messageDate: Date
}

// MARK: - Equatable

extension ChatScrollPositionInfo: Equatable { }

/// Mange scroll position information for conversations
protocol ChatScrollPositionProvider {
    /// Save current scroll position
    /// - Parameters:
    ///   - scrollPosition: Scroll position information to be stored
    ///   - conversation: ConversationEntity the scroll position is stored for
    func save(_ scrollPosition: ChatScrollPositionInfo, for conversation: ConversationEntity)
    
    /// Remove saved scroll position if there is any
    /// - Parameter conversation: ConversationEntity to remove scroll position for
    func removeSavedPosition(for conversation: ConversationEntity)
    
    /// Get scroll position information for a conversation
    /// - Parameter conversation: ConversationEntity to get scroll position for
    /// - Returns: Scroll position information if there is any for the provided conversation
    func chatScrollPosition(for conversation: ConversationEntity) -> ChatScrollPositionInfo?
}

/// Store chat scroll position in app group user defaults
class ChatScrollPosition: NSObject, ChatScrollPositionProvider {
    
    static let shared = ChatScrollPosition()
    
    private let appGroupUserDefaultsKey = "ChatScrollPositions"
    
    private var savedScrollPositions: [String: Data] {
        get {
            // Get most recent data from app group user defaults
            guard let currentPositions = AppGroup.userDefaults().dictionary(
                forKey: appGroupUserDefaultsKey
            ) as? [String: Data] else {
                return [:]
            }
            
            return currentPositions
        }
        
        set {
            // Store newest information in app group user defaults
            AppGroup.userDefaults().setValue(newValue, forKey: appGroupUserDefaultsKey)
        }
    }
    
    private lazy var decoder = JSONDecoder()
    private lazy var encoder = JSONEncoder()
    
    // MARK: - ChatScrollPositionProvider
    
    // This always works, but might not store the position if encoding of the data fails
    func save(_ scrollPosition: ChatScrollPositionInfo, for conversation: ConversationEntity) {
        do {
            let encodedData = try encoder.encode(scrollPosition)
            savedScrollPositions[identifier(for: conversation)] = encodedData
        }
        catch {
            DDLogWarn("Unable to encode scroll position info: \(error)")
        }
    }
    
    @objc func removeSavedPosition(for conversation: ConversationEntity) {
        savedScrollPositions.removeValue(forKey: identifier(for: conversation))
    }
    
    // This will always work but return `nil` if no info exists or there was an error
    func chatScrollPosition(for conversation: ConversationEntity) -> ChatScrollPositionInfo? {
        guard let encodedData = savedScrollPositions[identifier(for: conversation)] else {
            return nil
        }
        
        do {
            let scrollPositionInfo = try decoder.decode(ChatScrollPositionInfo.self, from: encodedData)
            return scrollPositionInfo
        }
        catch {
            DDLogWarn("Unable to decode scroll position info: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Helper
    
    private func identifier(for conversation: ConversationEntity) -> String {
        // We need a string to allow storing it in user defaults
        conversation.objectID.uriRepresentation().absoluteString
    }
    
    // MARK: - Objective-C support
    
    @available(*, deprecated, renamed: "shared", message: "Only use for Objective-C access")
    @objc class func _sharedObjC() -> ChatScrollPosition {
        // TODO: Remove `NSObject` inheritance when this Objective-C dependency can be removed
        shared
    }
}
