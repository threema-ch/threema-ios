//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2026-2025 Threema GmbH
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

import CoreData

// MARK: - Composing Predicates

extension NSPredicate {
    public static func or(_ predicates: NSPredicate?...) -> NSPredicate {
        NSCompoundPredicate(type: .or, subpredicates: predicates.compactMap { $0 })
    }

    public static func or(_ predicates: [NSPredicate?]) -> NSPredicate {
        NSCompoundPredicate(type: .or, subpredicates: predicates.compactMap { $0 })
    }

    public static func and(_ predicates: NSPredicate?...) -> NSPredicate {
        NSCompoundPredicate(type: .and, subpredicates: predicates.compactMap { $0 })
    }

    public static func and(_ predicates: [NSPredicate?]) -> NSPredicate {
        NSCompoundPredicate(type: .and, subpredicates: predicates.compactMap { $0 })
    }

    public static func not(_ predicate: NSPredicate) -> NSPredicate {
        NSCompoundPredicate(type: .not, subpredicates: [predicate])
    }
}

// MARK: - ConversationEntity Predicates

extension NSPredicate {
    static var conversationIsArchived: NSPredicate {
        NSPredicate(
            format: "%K == %d",
            #keyPath(ConversationEntity.visibility),
            ConversationEntity.Visibility.archived.rawValue
        )
    }

    static var conversationIsDistributionList: NSPredicate {
        NSPredicate(
            format: "%K != nil",
            #keyPath(ConversationEntity.distributionList)
        )
    }

    static var conversationIsGroup: NSPredicate {
        NSPredicate(
            format: "%K != nil",
            #keyPath(ConversationEntity.groupID)
        )
    }

    static var conversationIsPrivate: NSPredicate {
        NSPredicate(
            format: "%K == %d",
            #keyPath(ConversationEntity.category),
            ConversationEntity.Category.private.rawValue
        )
    }

    static var conversationIsTyping: NSPredicate {
        NSPredicate(
            format: "%K == %@",
            #keyPath(ConversationEntity.typing),
            NSNumber(value: true)
        )
    }

    static func conversationTypingIsStale(timeoutDate: Date) -> NSPredicate {
        NSPredicate(
            format: "%K < %@",
            #keyPath(ConversationEntity.lastTypingStart),
            timeoutDate as NSDate
        )
    }

    static var conversationHasLastUpdate: NSPredicate {
        NSPredicate(
            format: "%K != nil",
            #keyPath(ConversationEntity.lastUpdate)
        )
    }

    static func conversationWithFirstName(_ firstName: String) -> NSPredicate {
        .and(
            .not(.conversationIsGroup),
            NSPredicate(
                format: "%K contains[c] %@",
                #keyPath(ConversationEntity.contact.firstName),
                firstName
            )
        )
    }

    static func conversationWithGroupName(_ name: String) -> NSPredicate {
        .and(
            .conversationIsGroup,
            NSPredicate(
                format: "%K contains[c] %@",
                #keyPath(ConversationEntity.groupName),
                name
            )
        )
    }

    static func conversationWithLastName(_ lastName: String) -> NSPredicate {
        .and(
            .not(.conversationIsGroup),
            NSPredicate(
                format: "%K contains[c] %@",
                #keyPath(ConversationEntity.contact.lastName),
                lastName
            )
        )
    }

    static func conversationWithNickName(_ nickName: String) -> NSPredicate {
        .and(
            .not(.conversationIsGroup),
            NSPredicate(
                format: "%K contains[c] %@",
                #keyPath(ConversationEntity.contact.publicNickname),
                nickName
            )
        )
    }

    static func conversationWithContactIdentity(_ identity: String) -> NSPredicate {
        .and(
            .not(.conversationIsGroup),
            NSPredicate(
                format: "%K == %@",
                #keyPath(ConversationEntity.contact.identity),
                identity
            )
        )
    }

    static func conversationContainsContactIdentity(identity: String) -> NSPredicate {
        .and(
            .not(.conversationIsGroup),
            NSPredicate(
                format: "%K contains[c] %@",
                #keyPath(ConversationEntity.contact.identity),
                identity
            )
        )
    }

    static func conversationWithDistributionListID(_ id: Int) -> NSPredicate {
        NSPredicate(
            format: "%K == %@",
            #keyPath(ConversationEntity.distributionList.distributionListID),
            id as NSNumber
        )
    }

    static func conversationHasMember(_ member: ContactEntity) -> NSPredicate {
        NSPredicate(
            format: "%@ IN members",
            member
        )
    }

    static func conversationGroup(identity: String, id: Data, myIdentity: String?) -> NSPredicate {
        if identity != myIdentity {
            .and(
                legacyConversationWithGroupID(id),
                NSPredicate(
                    format: "%K == %@",
                    #keyPath(ConversationEntity.contact.identity),
                    identity
                )
            )
        }
        else {
            .and(
                legacyConversationWithGroupID(id),
                NSPredicate(
                    format: "%K == nil",
                    #keyPath(ConversationEntity.contact)
                )
            )
        }
    }

    static func legacyConversationWithGroupID(_ id: Data) -> NSPredicate {
        NSPredicate(
            format: "%K == %@",
            #keyPath(ConversationEntity.groupID),
            id as CVarArg
        )
    }
}

// MARK: - GroupEntity Predicates

extension NSPredicate {
    static var groupIsActive: NSPredicate {
        let keyPath = #keyPath(GroupEntity.state)
        return .not(
            .or(
                NSPredicate(
                    format: "%K == %ld",
                    keyPath,
                    GroupEntity.GroupState.left.rawValue
                ),
                NSPredicate(
                    format: "%K == %ld",
                    keyPath,
                    GroupEntity.GroupState.forcedLeft.rawValue
                )
            )
        )
    }

    static func groupWithID(_ id: Data) -> NSPredicate {
        NSPredicate(
            format: "%K == %@",
            #keyPath(GroupEntity.groupID),
            id as CVarArg
        )
    }

    static func groupWith(creator: String?, id: Data) -> NSPredicate {
        let withCreator =
            if let creator {
                NSPredicate(
                    format: "%K == %@",
                    #keyPath(GroupEntity.groupCreator),
                    creator
                )
            }
            else {
                NSPredicate(
                    format: "%K == nil",
                    #keyPath(GroupEntity.groupCreator)
                )
            }
        return .and(.groupWithID(id), withCreator)
    }
}

// MARK: - DistributionListEntity Predicates

extension NSPredicate {
    static var distributionListIsPrivate: NSPredicate {
        NSPredicate(
            format: "%K == %d",
            #keyPath(DistributionListEntity.conversation.category),
            ConversationEntity.Category.private.rawValue
        )
    }

    static func distributionListWithID(_ id: Int) -> NSPredicate {
        NSPredicate(
            format: "%K == %@",
            #keyPath(DistributionListEntity.distributionListID),
            id as NSNumber
        )
    }

    static func distributionListWithConversation(_ conversationEntity: ConversationEntity) -> NSPredicate {
        NSPredicate(
            format: "%K == %@",
            #keyPath(DistributionListEntity.conversation),
            conversationEntity
        )
    }

    static func distributionListWithName(_ name: String) -> NSPredicate {
        NSPredicate(
            format: "%K contains[c] %@",
            #keyPath(DistributionListEntity.name),
            name
        )
    }
}

// MARK: - ContactEntity Predicates

extension NSPredicate {
    enum PredicateFormat {
        case name
        case id
        case titleDepartmentCSI

        var format: String {
            switch self {
            case .name:
                "lastName contains[cd] %@ OR firstName contains[cd] %@ OR publicNickname contains[cd] %@"

            case .id:
                "identity contains[c] %@"

            case .titleDepartmentCSI:
                "csi contains[cd] %@ OR department contains[cd] %@ OR jobTitle contains[cd] %@"
            }
        }

        func arguments(for searchTerm: String) -> [String] {
            switch self {
            case .name, .titleDepartmentCSI:
                [searchTerm, searchTerm, searchTerm]
            case .id:
                [searchTerm]
            }
        }
    }
    
    static var contactIsGateway: NSPredicate {
        NSPredicate(
            format: "%K beginswith '*'",
            #keyPath(ContactEntity.identity)
        )
    }

    static var contactWithCustomReadReceipt: NSPredicate {
        NSPredicate(
            format: "%K != %ld",
            ContactEntity.ReadReceipt.keyPath,
            ContactEntity.ReadReceipt.default.rawValue
        )
    }

    static var contactWithCustomTypingIndicator: NSPredicate {
        NSPredicate(
            format: "%K != %ld",
            ContactEntity.TypingIndicator.keyPath,
            ContactEntity.TypingIndicator.default.rawValue
        )
    }

    static var contactIsActive: NSPredicate {
        contactWithState(.active)
    }

    static var contactIsVisible: NSPredicate {
        .or(
            NSPredicate(
                format: "%K == nil",
                ContactEntity.hiddenKeyPath
            ),
            NSPredicate(
                format: "%K == 0",
                ContactEntity.hiddenKeyPath
            )
        )
    }

    static func contactWithState(_ state: ContactEntity.ContactState) -> NSPredicate {
        NSPredicate(
            format: "%K == %d",
            ContactEntity.ContactState.keyPath,
            state.rawValue as CVarArg
        )
    }

    static func contactWithIdentity(_ identity: String) -> NSPredicate {
        NSPredicate(
            format: "%K == %@",
            #keyPath(ContactEntity.identity),
            identity
        )
    }

    static func predicate(from words: [String], for predicateFormat: PredicateFormat) -> [NSPredicate] {
        guard words.isEmpty == false else {
            return []
        }

        var predicates = [NSPredicate]()

        for word in words {
            guard !word.isEmpty else {
                continue
            }

            let predicate = NSPredicate(
                format: predicateFormat.format,
                argumentArray: predicateFormat.arguments(for: word)
            )

            predicates.append(predicate)
        }

        return predicates
    }

    static func contactWithNullFeatureMask(encrypted: Bool) -> NSPredicate {
        let featureMaskFieldName = ContactEntity.Field.name(for: .featureMask, encrypted: encrypted)
        return NSPredicate(format: "\(featureMaskFieldName) == nil")
    }
}
