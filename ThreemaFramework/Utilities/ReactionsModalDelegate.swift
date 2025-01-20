//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

import Combine
import Foundation
import SwiftUI
import ThreemaMacros

public protocol ReactionsModalDelegate {
    var currentReactionsByCreatorPublisher: AnyPublisher<[ReactionsManager.ReactionInfo], Never> { get }
    func send(_ reaction: EmojiVariant?)
}

public struct ReactionEntry: Identifiable, Hashable, Equatable {
    public let id = UUID()
    public let reaction: String
    public var userReactionEntries: [UserReactionEntry]
    
    public var reactedByMe: Bool {
        userReactionEntries.map(\.isMe).contains(true)
    }
    
    public var displayValue: String {
        guard let emoji = EmojiVariant(rawValue: reaction), emoji.base.isAvailable else {
            return "�"
        }
        return emoji.rawValue
    }
    
    public init(reaction: String, userReactionEntries: [UserReactionEntry]) {
        self.reaction = reaction
        self.userReactionEntries = userReactionEntries
    }
}

public struct UserReactionEntry: Identifiable, Hashable, Equatable {
    public let id = UUID()
    public let sortDate: Date
    
    private(set) var user: Contact?
    
    public var name: String {
        user?.displayName ?? #localize("me")
    }
    
    public var profileImage: Image {
        if let user {
            Image(uiImage: user.profilePicture)
        }
        else {
            Image(uiImage: MyIdentityStore.shared().resolvedProfilePicture)
        }
    }
    
    public var isMe: Bool {
        user == nil
    }
    
    public init(user: Contact?, sortDate: Date) {
        self.user = user
        self.sortDate = sortDate
    }
}
