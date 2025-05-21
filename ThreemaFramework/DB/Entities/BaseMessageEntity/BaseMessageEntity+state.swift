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

extension BaseMessageEntity {
    
    /// State of this message
    public enum State {
        // Common
        case read

        // Outgoing
        case sending
        case sent
        case delivered
        case failed
        
        // Incoming
        case received
    }
    
    /// Current state of this message
    ///
    /// This only considers acks and the state bools and doesn't differentiate between single chats, gateway ids and
    /// groups
    public var messageState: State {
        if isOwnMessage {
            ownMessageState
        }
        else {
            otherMessageState
        }
    }

    /// Is reacting to this message allowed?
    public var supportsReaction: Bool {
        // We do not allow reaction to messages that are deleted, or to our own messages that were not sent successfully
       
        guard deletedAt == nil else {
            return false
        }
        
        if isOwnMessage, messageState == .failed || messageState == .sending {
            return false
        }
        
        return true
    }
    
    @objc public var showRetryAndCancelButton: Bool {
        messageState == .failed
    }

    /// Message can only be edited if it was sent no more than 6 hours ago
    public var wasSentMoreThanSixHoursAgo: Bool {
        guard let sixHoursAgo = Calendar.current.date(byAdding: .hour, value: -6, to: .now)
        else {
            return true
        }
        return date < sixHoursAgo
    }

    /// Is editing of this message allowed?
    public var supportsEditing: Bool {
        guard ThreemaEnvironment.deleteEditMessage else {
            return false
        }
        
        let isNoteGroup = {
            guard conversation.isGroup else {
                return false
            }
            
            let businessInjector = BusinessInjector(forBackgroundProcess: true)
            
            guard let group = businessInjector.groupManager.getGroup(conversation: conversation),
                  group.isNoteGroup else {
                return false
            }
            
            return true
        }()
        
        return isOwnMessage &&
            (!wasSentMoreThanSixHoursAgo || isNoteGroup) &&
            messageState != .sending &&
            messageState != .failed &&
            (FeatureMask.check(message: self, for: .editMessageSupport).isSupported || isNoteGroup)
    }
        
    public var typeSupportsRemoteDeletion: Bool {
        self is AudioMessageEntity ||
            self is FileMessageEntity ||
            self is ImageMessageEntity ||
            self is VideoMessageEntity ||
            self is LocationMessageEntity ||
            self is TextMessageEntity
    }
    
    /// Is remote deletion of this message allowed?
    public var supportsRemoteDeletion: Bool {
        guard ThreemaEnvironment.deleteEditMessage else {
            return false
        }
        
        return isOwnMessage &&
            typeSupportsRemoteDeletion &&
            deletedAt == nil &&
            !wasSentMoreThanSixHoursAgo &&
            messageState != .sending &&
            messageState != .failed &&
            FeatureMask.check(message: self, for: .deleteMessageSupport).isSupported
    }
    
    /// Is there a pending (blob) download for this message?
    public var hasPendingDownload: Bool {
        guard let blobDataMessage = self as? BlobData else {
            return false
        }

        return blobDataMessage.blobDisplayState == .remote
    }
    
    /// Is this a message in a distribution list?
    public var isDistributionListMessage: Bool {
        if let distributedMessages {
            return !distributedMessages.isEmpty
        }
        return false
    }

    // MARK: - Private helper
    
    private var ownMessageState: State {
        if let sendFailed, sendFailed.boolValue {
            .failed
        }
        else if read.boolValue {
            .read
        }
        else if delivered.boolValue {
            .delivered
        }
        else if sent.boolValue {
            .sent
        }
        else {
            .sending
        }
    }
    
    private var otherMessageState: State {
        if read.boolValue {
            return .read
        }
        
        return .received
    }
}
