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
    public let canBeRemoved: Bool
    
    public var reactedByMe: Bool {
        userReactionEntries.map(\.isMe).contains(true)
    }
    
    public var displayValue: String {
        guard let emoji = EmojiVariant(rawValue: reaction), emoji.base.isAvailable else {
            return "�"
        }
        return emoji.rawValue
    }
    
    public init(reaction: String, userReactionEntries: [UserReactionEntry], canBeRemoved: Bool) {
        self.reaction = reaction
        self.userReactionEntries = userReactionEntries
        self.canBeRemoved = canBeRemoved
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
