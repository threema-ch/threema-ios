import Foundation
import ThreemaEssentials

extension ConversationEntity {
    @objc(ConversationCategory) public enum Category: Int {
        case `default`, `private`
    }

    @objc(ConversationVisibility) public enum Visibility: Int {
        case `default`, archived, pinned
    }

    @objc public var isGroup: Bool {
        groupID != nil
    }

    public var unwrappedMembers: Set<ContactEntity> {
        members ?? Set<ContactEntity>()
    }

    public var participants: Set<ContactEntity> {
        if isGroup {
            if let members {
                members
            }
            else {
                Set<ContactEntity>()
            }
        }
        else {
            if let contact {
                Set<ContactEntity>([contact])
            }
            else {
                Set<ContactEntity>()
            }
        }
    }

    /// Checks whether self is the group conversation with given groupID and creator
    /// - Parameters:
    ///   - groupID:
    ///   - creator:
    /// - Returns:
    public func isEqualTo(groupIdentity: GroupIdentity, myIdentity: String) -> Bool {

        guard isGroup else {
            return false
        }

        guard groupID == groupIdentity.id else {
            return false
        }

        if let id = contact?.identity, id != groupIdentity.creator.rawValue {
            return false
        }

        if contact == nil, myIdentity != groupIdentity.creator.rawValue {
            return false
        }

        return true
    }
}
