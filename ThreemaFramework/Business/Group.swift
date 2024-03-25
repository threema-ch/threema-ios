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

import CocoaLumberjackSwift
import Foundation
import GroupCalls
import Intents
import ThreemaEssentials
import ThreemaProtocols

/// Business representation of a Threema group
public class Group: NSObject {
    
    // These strings are used as static properties for performance reasons
    private static let meString = BundleUtil.localizedString(forKey: "me")
    private static let unknownString = BundleUtil.localizedString(forKey: "(unknown)")
    private static let oneMemberTitleString = BundleUtil.localizedString(forKey: "group_one_member_title")
    private static let multipleMemberTitleString = BundleUtil.localizedString(forKey: "group_multiple_members_title")
    private static let maxGroupMembers = BundleUtil.object(forInfoDictionaryKey: "ThreemaMaxGroupMembers") as? Int ?? 0

    /// A member in a group
    public enum Member: CustomStringConvertible, Equatable {
        case me(String)
        case contact(Contact)
        case unknown
        
        public var shortDisplayName: String {
            switch self {
            case .me:
                return meString
            case let .contact(contact):
                return contact.shortDisplayName
            case .unknown:
                return unknownString
            }
        }
        
        // CustomStringConvertible
        public var description: String {
            switch self {
            case .me:
                return meString
            case let .contact(contact):
                return contact.displayName
            case .unknown:
                return unknownString
            }
        }

        public var identity: String? {
            switch self {
            case let .contact(contact): return contact.identity.string
            case let .me(identity): return identity
            default: return nil
            }
        }
    }
    
    /// Creator of a group (same as `Member`)
    public typealias Creator = Member
    
    private let myIdentityStore: MyIdentityStoreProtocol
    private let userSettings: UserSettingsProtocol

    // Tokens for entity subscriptions, will be removed when is deallocated
    private var subscriptionTokens = [EntityObserver.SubscriptionToken]()

    private var conversationGroupMyIdentity: String?

    /// It's `nil` if i am creator of the group
    private var conversationContact: Contact?

    /// Initialize Group properties, subscribe GroupEntity and Conversation on EntityObserver for updates.
    /// Note: Group properties will be only refreshed if it's ContactEntity and Conversation object already saved in
    /// Core Data.
    ///
    /// - Parameters:
    ///   - myIdentityStore: MyIdentityStore
    ///   - userSettings: UserSettings
    ///   - groupEntity: Core Data object
    ///   - conversation: Core Data object
    ///   - lastSyncRequest: From Core Data object `LastGroupSyncRequest.lastSyncRequest` (TODO: should be Core Data
    /// itself and subscribe on EntityObserver too)
    init(
        myIdentityStore: MyIdentityStoreProtocol,
        userSettings: UserSettingsProtocol,
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
        self.userSettings = userSettings
        self.conversation = conversation
        self.conversationGroupMyIdentity = conversation.groupMyIdentity
        if let contactEntity = conversation.contact {
            self.conversationContact = Contact(contactEntity: contactEntity)
        }
        self.groupIdentity = GroupIdentity(
            id: groupEntity.groupID,
            creator: ThreemaIdentity(groupEntity.groupCreator ?? myIdentityStore.identity)
        )
        self.state = GroupState(rawValue: groupEntity.state.intValue)!
        self.name = conversation.groupName
        self.profilePicture = conversation.groupImage?.data
        self.lastSyncRequest = lastSyncRequest
        self.lastUpdate = conversation.lastUpdate
        self.lastMessageDate = conversation.lastMessage?.date
        self.conversationCategory = conversation.conversationCategory
        self.conversationVisibility = conversation.conversationVisibility
        self.lastPeriodicSync = groupEntity.lastPeriodicSync

        self.members = Set(conversation.members.map { Contact(contactEntity: $0) })

        super.init()

        self.sortedMembers = allSortedMembers()
        self.membersList = sortedMembers.map(\.shortDisplayName)
            .joined(separator: ", ")

        // Subscribe group entity for DB updates or deletion
        subscriptionTokens.append(
            EntityObserver.shared.subscribe(
                managedObject: groupEntity
            ) { [weak self] managedObject, reason in
                guard let groupEntity = managedObject as? GroupEntity else {
                    DDLogError("Wrong type, should be GroupEntity")
                    return
                }
                guard self?.groupIdentity == GroupIdentity(
                    id: groupEntity.groupID,
                    creator: ThreemaIdentity(groupEntity.groupCreator ?? myIdentityStore.identity)
                ) else {
                    DDLogError("Group identity mismatch")
                    return
                }

                switch reason {
                case .deleted:
                    if let deleted = self?.willBeDeleted, !deleted {
                        self?.willBeDeleted = true
                    }
                case .updated:
                    if let newState = GroupState(rawValue: groupEntity.state.intValue) {
                        if self?.state != newState {
                            self?.state = newState
                        }
                    }
                    else {
                        DDLogError("Unknown group state")
                    }
                    if self?.lastPeriodicSync != groupEntity.lastPeriodicSync {
                        self?.lastPeriodicSync = groupEntity.lastPeriodicSync
                    }
                }
            }
        )

        // Subscribe conversation entity for DB updates or deletion
        subscriptionTokens.append(
            EntityObserver.shared.subscribe(
                managedObject: conversation
            ) { [weak self] managedObject, reason in
                guard let conversation = managedObject as? Conversation else {
                    DDLogError("Wrong type, should be Conversation")
                    return
                }
                guard conversation.isGroup(), self?.groupID == conversation.groupID else {
                    DDLogError("Group ID mismatch")
                    return
                }

                switch reason {
                case .deleted:
                    if let deleted = self?.willBeDeleted, !deleted {
                        self?.willBeDeleted = true
                    }
                case .updated:
                    if self?.conversationGroupMyIdentity != conversation.groupMyIdentity {
                        self?.conversationGroupMyIdentity = conversation.groupMyIdentity
                    }
                    if let contactEntity = conversation.contact {
                        let newConversationContact = Contact(contactEntity: contactEntity)
                        if self?.conversationContact != newConversationContact {
                            self?.conversationContact = newConversationContact
                        }
                    }
                    else if self?.conversationContact != nil {
                        self?.conversationContact = nil
                    }
                    if self?.name != conversation.groupName {
                        self?.name = conversation.groupName
                    }
                    if self?.profilePicture != conversation.groupImage?.data {
                        self?.profilePicture = conversation.groupImage?.data
                    }
                    if self?.lastUpdate != conversation.lastUpdate {
                        self?.lastUpdate = conversation.lastUpdate
                    }
                    if self?.lastMessageDate != conversation.lastMessage?.date {
                        self?.lastMessageDate = conversation.lastMessage?.date
                    }
                    if self?.conversationCategory != conversation.conversationCategory {
                        self?.conversationCategory = conversation.conversationCategory
                    }
                    if self?.conversationVisibility != conversation.conversationVisibility {
                        self?.conversationVisibility = conversation.conversationVisibility
                    }

                    // Check has members composition changed
                    let newMembers = Set(conversation.members.map { Contact(contactEntity: $0) })

                    if let members = self?.members, !members.contactsEqual(to: newMembers) {
                        self?.members = newMembers
                        self?.sortedMembers = self?.allSortedMembers() ?? [Member]()
                        self?.membersList = self?.sortedMembers.map(\.shortDisplayName)
                            .joined(separator: ", ") ?? ""
                    }
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
    @objc public private(set) dynamic var willBeDeleted = false

    public let groupIdentity: GroupIdentity

    public var pushSetting: PushSetting {
        let pushSettingManager = PushSettingManager()
        return pushSettingManager.find(forGroup: groupIdentity)
    }

    @objc public private(set) dynamic var state: GroupState
    @objc public private(set) dynamic var members: Set<Contact>
    public private(set) var lastSyncRequest: Date?
    public private(set) var lastUpdate: Date?
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
        let maxGroupMembers: Int = Group.maxGroupMembers
        
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
        if let identity = conversationContact?.identity.string {
            return identity
        }
        return myIdentityStore.identity
    }

    /// Creator of the group. It might not be part of the group anymore.
    public var creator: Creator {
        if conversationGroupMyIdentity?.elementsEqual(myIdentityStore.identity) ?? false,
           conversationContact == nil {
            return .me(myIdentityStore.identity)
        }
        else if let contact = conversationContact {
            return .contact(contact)
        }
        else {
            return .unknown
        }
    }
    
    @objc public var groupCreatorNickname: String? {
        if let nickname = conversationContact?.publicNickname {
            return nickname
        }
        return myIdentityStore.pushFromName
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
            return Group.oneMemberTitleString
        }
        else {
            return String.localizedStringWithFormat(
                Group.multipleMemberTitleString,
                numberOfMembers
            )
        }
    }
    
    public var localizedRelativeLastMessageDate: String {
        guard let lastMessageDate else {
            return ""
        }

        return DateFormatter.relativeMediumDate(for: lastMessageDate)
    }
    
    @objc public private(set) dynamic var name: String?
        
    /// Profile picture of group if there is any
    @objc public private(set) dynamic var profilePicture: Data?
    
    @objc public var isNoteGroup: Bool {
        allMemberIdentities.count == 1 && isSelfMember
    }

    @objc public private(set) var conversationCategory: ConversationCategory
    
    @objc public private(set) var conversationVisibility: ConversationVisibility
    
    /// A string with all members as comma separated list
    ///
    /// The order is the same as produced by `sortedMembers`
    @objc public private(set) var membersList = ""
    
    /// Sorted list of group members
    public private(set) var sortedMembers = [Member]()

    /// All group member identities including me
    @objc public var allMemberIdentities: Set<String> {
        var identities = Set(members.map(\.identity.string))
        if state == .active {
            identities.insert(myIdentityStore.identity)
        }
        return identities
    }
    
    /// All members that are active in this group
    ///
    /// This is useful to get all members that should receive a group message
    var allActiveMemberIdentitiesWithoutCreator: [String] {
        var identities: [String]!
        identities = members
            .filter { $0.state != kStateInvalid }
            .map(\.identity.string)
        return identities
    }
    
    private(set) var lastPeriodicSync: Date?

    /// The order is as follows: creator (always), me (if I'm in the group and not the creator), all other members
    /// sorted (w/o creator)
    ///
    /// - Returns: Sorted group members list
    private func allSortedMembers() -> [Member] {
        var allSortedMembers = [Member]()
        
        // Always add creator
        allSortedMembers.append(creator)
        
        // Add me if I'm a member and not the creator
        if isSelfMember, !isOwnGroup {
            allSortedMembers.append(.me(myIdentityStore.identity))
        }
        
        // Add everybody else expect the creator
        allSortedMembers.append(
            contentsOf: members.sorted(with: userSettings)
                .map(Member.contact)
                .filter { $0.identity != creator.identity }
        )

        return allSortedMembers
    }
    
    /// Returns an array of `Contacts` containing the members of this group supporting a given
    /// `Common_CspFeatureMaskFlag`
    /// - Parameter mask: `Common_CspFeatureMaskFlag` to check for
    /// - Returns: `Contacts` supporting the `mask`
    public func membersSupporting(_ mask: ThreemaProtocols.Common_CspFeatureMaskFlag) -> [Contact] {
        var supportingMembers = [Contact]()
        for member in members {
            if FeatureMask.check(contact: member, for: mask) {
                supportingMembers.append(member)
            }
        }
        return supportingMembers
    }
    
    /// Checks if at least one member of the group supports the given mask
    /// - Parameter mask: `Common_CspFeatureMaskFlag` to check members for
    /// - Returns: `true` if at least one member supports the given `mask`, `false` otherwise
    public func hasAtLeastOneMemberSupporting(_ mask: ThreemaProtocols.Common_CspFeatureMaskFlag) -> Bool {
        !membersSupporting(mask).isEmpty
    }
    
    /// Checks if *all* member of the group support the given mask
    /// - Parameter mask: `Common_CspFeatureMaskFlag` to check members for
    /// - Returns: `true` all member supports the given `mask`, `false` otherwise
    public func allMembersSupport(_ mask: ThreemaProtocols.Common_CspFeatureMaskFlag) -> Bool {
        membersSupporting(mask).count == members.count
    }

    // MARK: Comparing function

    public func isEqual(to object: Any?) -> Bool {
        guard let object = object as? Group else {
            return false
        }

        return willBeDeleted == object.willBeDeleted &&
            groupIdentity == object.groupIdentity &&
            state == object.state &&
            lastPeriodicSync == object.lastPeriodicSync &&
            conversationGroupMyIdentity == object.conversationGroupMyIdentity &&
            conversationContact == object.conversationContact &&
            name == object.name &&
            profilePicture == object.profilePicture &&
            lastUpdate == object.lastUpdate &&
            lastMessageDate == object.lastMessageDate &&
            conversationCategory == object.conversationCategory &&
            conversationVisibility == object.conversationVisibility &&
            members.contactsEqual(to: object.members)
    }
}
