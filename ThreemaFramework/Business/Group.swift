//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

public struct GroupIdentity {
    let id: Data
    let creator: String
}

/// Business representation of a Threema group
public class Group: NSObject {

    /// A member in a group
    public enum Member: CustomStringConvertible, Equatable {
        case me
        case contact(Contact)
        case unknown
        
        public var shortDisplayName: String {
            switch self {
            case .me:
                return BundleUtil.localizedString(forKey: "me")
            case let .contact(contact):
                return contact.shortDisplayName
            case .unknown:
                return BundleUtil.localizedString(forKey: "(unknown)")
            }
        }
        
        // CustomStringConvertible
        public var description: String {
            switch self {
            case .me:
                return BundleUtil.localizedString(forKey: "me")
            case let .contact(contact):
                return contact.displayName
            case .unknown:
                return BundleUtil.localizedString(forKey: "(unknown)")
            }
        }
    }
    
    /// Creator of a group (same as `Member`)
    public typealias Creator = Member
    
    private let myIdentityStore: MyIdentityStoreProtocol

    // Tokens for entity subscriptions, will be removed when is deallocated
    private var subscriptionTokens = [EntityObserver.SubscriptionToken]()

    private var conversationGroupMyIdentity: String?

    /// It's `nil` if i am creator of the group
    private var conversationContact: Contact?

    init(
        myIdentityStore: MyIdentityStoreProtocol,
        groupEntity: GroupEntity,
        conversation: Conversation,
        lastSyncRequest: Date?
    ) {
        if let conversationContact = conversation.contact {
            assert(conversationContact.identity == groupEntity.groupCreator)
        }
        else {
            assert(groupEntity.groupCreator == nil)
        }

        self.myIdentityStore = myIdentityStore
        self.conversation = conversation
        self.conversationGroupMyIdentity = conversation.groupMyIdentity
        self.conversationContact = conversation.contact
        self.groupIdentity = GroupIdentity(
            id: groupEntity.groupID,
            creator: groupEntity.groupCreator ?? myIdentityStore.identity
        )
        self.state = GroupState(rawValue: groupEntity.state.intValue)!
        self.name = conversation.groupName
        self.photo = conversation.groupImage
        self.members = conversation.members
        self.lastSyncRequest = lastSyncRequest
        self.lastMessageDate = conversation.lastMessage?.date
        self.conversationCategory = conversation.conversationCategory
        self.conversationVisibility = conversation.conversationVisibility
        self.lastPeriodicSync = groupEntity.lastPeriodicSync

        super.init()

        // Subscribe group entity for DB updates or deletion
        subscriptionTokens.append(
            EntityObserver.shared.subscribe(
                managedObject: groupEntity
            ) { [weak self] managedObject, reason in
                switch reason {
                case .deleted:
                    self?.willBeDeleted = true
                case .updated:
                    guard let groupEntity = managedObject as? GroupEntity else {
                        return
                    }
                    self?.state = GroupState(rawValue: groupEntity.state.intValue)!
                    self?.lastPeriodicSync = groupEntity.lastPeriodicSync
                }
            }
        )

        // Subscribe conversation entity for DB updates or deletion
        subscriptionTokens.append(
            EntityObserver.shared.subscribe(
                managedObject: conversation
            ) { [weak self] managedObject, reason in
                switch reason {
                case .deleted:
                    self?.willBeDeleted = true
                case .updated:
                    guard let conversation = managedObject as? Conversation else {
                        return
                    }
                    self?.conversationGroupMyIdentity = conversation.groupMyIdentity
                    self?.conversationContact = conversation.contact
                    self?.name = conversation.groupName
                    self?.photo = conversation.groupImage
                    self?.members = conversation.members
                    self?.lastMessageDate = conversation.lastMessage?.date
                    self?.conversationCategory = conversation.conversationCategory
                    self?.conversationVisibility = conversation.conversationVisibility
                }
            }
        )
    }

    /// Public group properties and func

    @available(*, deprecated, message: "Do not use anymore, load CoreData conversation separated")
    @objc public let conversation: Conversation

    /// This will be set to `true` when a group is in the process to be deleted.
    ///
    /// This can be used to detect deletion in KVO-observers
    public private(set) dynamic var willBeDeleted = false

    public let groupIdentity: GroupIdentity
    @objc public private(set) dynamic var state: GroupState
    @objc public private(set) dynamic var members: Set<Contact>
    public private(set) var lastSyncRequest: Date?
    public private(set) var lastMessageDate: Date?

    @objc func isMember(identity: String) -> Bool {
        allMemberIdentities.contains(identity)
    }

    /// Returns true, if me is group creator and group is active/editable.
    @objc public var isOwnGroup: Bool {
        isSelfCreator && state == .active
    }

    /// Returns true if me is group creator
    @objc public var isSelfCreator: Bool {
        (conversationGroupMyIdentity?.elementsEqual(myIdentityStore.identity) ?? false)
            && conversationContact == nil
    }

    /// Returns true, if I'm in the group
    @objc public var isSelfMember: Bool {
        isOwnGroup ||
            (
                (conversationGroupMyIdentity?.elementsEqual(myIdentityStore.identity) ?? false)
                    && state == .active
            )
    }
    
    /// Can I add new members
    public var canAddMembers: Bool {
        let maxGroupMembers: Int = BundleUtil.object(forInfoDictionaryKey: "ThreemaMaxGroupMembers") as? Int ?? 0
        
        return isOwnGroup && members.count < maxGroupMembers
    }
    
    public var canLeave: Bool {
        isSelfMember && !isOwnGroup
    }

    public var canDissolve: Bool {
        isOwnGroup
    }
    
    /// Has the creator left the group?
    public var didCreatorLeave: Bool {
        !isMember(identity: groupCreatorIdentity)
    }
    
    /// Only `true` if you left the group. `false` otherwise.
    /// This includes if you were removed from the group by the creator.
    ///
    /// Is that really what you want? Probably you're looking for `isSelfMember`.
    @objc public var didLeave: Bool {
        state == .left
    }

    var didForcedLeave: Bool {
        state == .forcedLeft
    }
    
    @objc public var didSyncRequst: Bool {
        lastSyncRequest != nil
    }
    
    @objc public var groupID: Data {
        groupIdentity.id
    }
    
    @objc public var groupCreatorIdentity: String {
        if let conversationContact = conversationContact {
            return conversationContact.identity
        }
        return myIdentityStore.identity
    }

    /// Creator of the group. It might not be part of the group anymore.
    public var creator: Creator {
        if conversationGroupMyIdentity?.elementsEqual(myIdentityStore.identity) ?? false,
           conversationContact == nil {
            return .me
        }
        else if let contact = conversationContact {
            return .contact(contact)
        }
        else {
            return .unknown
        }
    }
    
    /// Number of members including me
    public var numberOfMembers: Int {
        var membersCount = members.count
        
        if state == .active {
            membersCount += 1
        }
        
        return membersCount
    }
    
    public var membersTitleSummary: String {
        if numberOfMembers == 1 {
            return BundleUtil.localizedString(forKey: "group_one_member_title")
        }
        else {
            return String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "group_multiple_members_title"),
                numberOfMembers
            )
        }
    }
    
    public var localizedRelativeLastMessageDate: String {
        guard let lastMessageDate = lastMessageDate else {
            return ""
        }
            
        return DateFormatter.relativeMediumDate(for: lastMessageDate)
    }
    
    @objc public private(set) dynamic var name: String?
    
    @objc public private(set) dynamic var photo: ImageData?

    @objc public var isNoteGroup: Bool {
        allMemberIdentities.count == 1 && isSelfMember
    }

    @objc public private(set) var conversationCategory: ConversationCategory
    
    @objc public private(set) var conversationVisibility: ConversationVisibility
    
    /// A string with all members as comma separated list
    ///
    /// The order is the same as produces by `sortedMembers(userSettings:)`
    @objc public var membersList: String {
        sortedMembers()
            .map(\.shortDisplayName)
            .joined(separator: ", ")
    }
    
    /// Sorted list of group members
    ///
    /// The order is as follows: creator (always), me (if I'm in the group and not the creator), all other members sorted (w/o creator)
    ///
    /// - Parameter userSettings: Optional user settings for sorting order
    /// - Returns: Sorted group members list
    public func sortedMembers(
        userSettings: UserSettingsProtocol = UserSettings.shared()
    ) -> [Member] {
        var sortedMembers = [Member]()
        
        // Always add creator
        sortedMembers.append(creator)
        
        // Add me if I'm a member and not the creator
        if isSelfMember, !isOwnGroup {
            sortedMembers.append(.me)
        }
        
        // Add everybody else expect the creator
        sortedMembers.append(
            contentsOf: members.sorted(with: userSettings)
                .map(Member.contact)
                .filter { $0 != creator }
        )

        return sortedMembers
    }

    /// All group member identities including me
    public var allMemberIdentities: Set<String> {
        var identities = Set<String>()
        for member in members {
            identities.insert(member.identity)
        }
        
        if state == .active {
            identities.insert(myIdentityStore.identity)
        }
        
        return identities
    }
    
    /// All members that are active in this group
    ///
    /// This is useful to get all members that should receive a group message
    var allActiveMemberIdentitiesWithoutCreator: [String] {
        members
            .filter { $0.state != NSNumber(value: kStateInvalid) }
            .map(\.identity)
    }
    
    private(set) var lastPeriodicSync: Date?
}
