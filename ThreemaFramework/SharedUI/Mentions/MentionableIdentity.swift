import CocoaLumberjackSwift
import Foundation
import ThreemaMacros

public final class MentionableIdentity: Hashable {
    enum ContactKind: Hashable {
        case all
        case contact(String)
    }
    
    var contactKind: ContactKind
    var entityFetcher: EntityFetcher
    
    lazy var corpus: String = {
        switch contactKind {
        case .all:
            return #localize("all").lowercased()
        case let ContactKind.contact(identity):
            guard let contact = entityFetcher.contactEntity(for: identity) else {
                DDLogError("Created MentionableIdentity for a contact that doesn't exist")
                return ""
            }
            return "\(contact.displayName.lowercased()) \((contact.publicNickname ?? "").lowercased())"
        }
    }()
    
    lazy var displayName: String = {
        switch contactKind {
        case .all:
            return #localize("all")
        case let ContactKind.contact(identity):
            guard let contact = entityFetcher.contactEntity(for: identity) else {
                DDLogError("Created MentionableIdentity for a contact that doesn't exist")
                return ""
            }
            return "\(contact.displayName)"
        }
    }()
    
    // swiftformat:disable:next redundantClosure
    lazy var identity: String = {
        switch contactKind {
        case .all:
            ""
        case let ContactKind.contact(identity):
            identity
        }
    }()
    
    // swiftformat:disable:next redundantClosure
    public lazy var mentionIdentity: String = {
        switch contactKind {
        case .all:
            "@@@@@@@@"
        case let ContactKind.contact(identity):
            identity
        }
    }()
    
    public init(
        identity: String? = nil,
        entityFetcher: EntityFetcher = BusinessInjector.ui.entityManager.entityFetcher
    ) {
        if let identity {
            self.contactKind = .contact(identity)
        }
        else {
            self.contactKind = .all
        }
        self.entityFetcher = entityFetcher
    }
    
    public static func == (lhs: MentionableIdentity, rhs: MentionableIdentity) -> Bool {
        lhs.contactKind == rhs.contactKind
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(contactKind)
    }
}
