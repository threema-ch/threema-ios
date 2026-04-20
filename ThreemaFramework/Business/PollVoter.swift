import Foundation
import UIKit

public struct PollVoter: Identifiable, Hashable, Comparable {

    // MARK: - Public types

    public enum ProfilePictureSource: Hashable {
        case contact(ContactEntity)
        case me(any MyIdentityStoreProtocol)

        public static func == (lhs: ProfilePictureSource, rhs: ProfilePictureSource) -> Bool {
            switch (lhs, rhs) {
            case let (.contact(l), .contact(r)):
                l.objectID == r.objectID
            case (.me, .me):
                true
            default:
                false
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .contact(entity):
                hasher.combine(0)
                hasher.combine(entity.objectID)
            case .me:
                hasher.combine(1)
            }
        }
    }

    // MARK: - Public properties

    public let id = UUID()
    public let identity: String
    public let displayName: String

    // MARK: - Private properties

    private let source: ProfilePictureSource

    public var profilePicture: UIImage? {
        switch source {
        case let .contact(entity):
            Contact(contactEntity: entity).profilePicture
        case let .me(identityStore):
            identityStore.resolvedProfilePicture
        }
    }

    // MARK: - Lifecycle

    public init(identity: String, displayName: String, source: ProfilePictureSource) {
        self.identity = identity
        self.displayName = displayName
        self.source = source
    }

    // MARK: - Public static methods

    public static func < (lhs: PollVoter, rhs: PollVoter) -> Bool {
        lhs.identity < rhs.identity
    }
}
