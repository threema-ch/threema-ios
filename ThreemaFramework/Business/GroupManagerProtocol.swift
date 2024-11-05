//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import ThreemaEssentials

/// Receivers of control message for group changes
public enum GroupManagerProtocolReceivers {
    /// All members
    case all
    /// A selected set of members
    case members([ThreemaIdentity])
}

public protocol GroupManagerProtocol: GroupManagerProtocolObjc {
    func createOrUpdate(
        for groupIdentity: GroupIdentity,
        members: Set<String>,
        systemMessageDate: Date
    ) async throws -> (Group, Set<String>?)
    @discardableResult func createOrUpdateDB(
        for groupIdentity: GroupIdentity,
        members: Set<String>,
        systemMessageDate: Date?,
        sourceCaller: SourceCaller
    ) async throws -> Group?
    func getConversation(for groupIdentity: GroupIdentity) -> ConversationEntity?
    func getAllActiveGroups() async -> [Group]
    func setName(groupID: Data, creator: String, name: String?, systemMessageDate: Date, send: Bool) async throws
    func setName(group: Group, name: String?, systemMessageDate: Date, send: Bool) async throws
    func setPhoto(groupID: Data, creator: String, imageData: Data, sentDate: Date, send: Bool) async throws
    func setPhoto(group: Group, imageData: Data, sentDate: Date, send: Bool) async throws
    func deletePhoto(groupID: Data, creator: String, sentDate: Date, send: Bool) async throws
    func sync(group: Group, to identities: Set<String>?, withoutCreateMessage: Bool) async throws
    func sendEmptyMemberList(groupIdentity: GroupIdentity, to identities: Set<ThreemaIdentity>)
}

// Define "default" arguments for certain protocol methods
extension GroupManagerProtocol {
    public func setName(groupID: Data, creator: String, name: String?, systemMessageDate: Date) async throws {
        try await setName(
            groupID: groupID,
            creator: creator,
            name: name,
            systemMessageDate: systemMessageDate,
            send: true
        )
    }
    
    public func setName(group: Group, name: String?) async throws {
        try await setName(group: group, name: name, systemMessageDate: Date(), send: true)
    }
    
    public func setPhoto(groupID: Data, creator: String, imageData: Data, sentDate: Date) async throws {
        try await setPhoto(groupID: groupID, creator: creator, imageData: imageData, sentDate: sentDate, send: true)
    }
    
    public func setPhoto(group: Group, imageData: Data, sentDate: Date) async throws {
        try await setPhoto(group: group, imageData: imageData, sentDate: sentDate, send: true)
    }
    
    public func deletePhoto(groupID: Data, creator: String, sentDate: Date) async throws {
        try await deletePhoto(groupID: groupID, creator: creator, sentDate: sentDate, send: true)
    }
    
    public func sync(group: Group) async throws {
        try await sync(group: group, to: nil, withoutCreateMessage: false)
    }
}

// Convenience functions for GroupIdentity type
extension GroupManagerProtocol {
    public func group(for groupIdentity: GroupIdentity) -> Group? {
        getGroup(groupIdentity.id, creator: groupIdentity.creator.string)
    }
    
    public func leave(groupWith groupIdentity: GroupIdentity, inform receivers: GroupManagerProtocolReceivers) {
        let members: [String]? =
            switch receivers {
            case .all:
                nil
            case let .members(list):
                list.map(\.string)
            }
        
        leave(groupIdentity: groupIdentity, toMembers: members)
    }
    
    public func sendSyncRequest(for groupIdentity: GroupIdentity) {
        sendSyncRequest(groupID: groupIdentity.id, creator: groupIdentity.creator.string)
    }
}

@objc public protocol GroupManagerProtocolObjc {
    func createOrUpdateObjc(
        groupID: Data,
        creator: String,
        members: Set<String>,
        systemMessageDate: Date
    ) async throws -> (Group, Set<String>?)
    func createOrUpdateDBObjc(
        groupID: Data,
        creator: String,
        members: Set<String>,
        systemMessageDate: Date?,
        sourceCaller: SourceCaller
    ) async throws
    func deletePhotoObjc(
        groupID: Data,
        creator: String,
        sentDate: Date,
        send: Bool
    ) async throws
    func getGroup(_ groupID: Data, creator: String) -> Group?
    func getGroup(conversation: ConversationEntity) -> Group?
    func leave(groupID: Data, creator: String, toMembers: [String]?, systemMessageDate: Date)
    func leaveDB(groupID: Data, creator: String, member: String, systemMessageDate: Date)
    func dissolve(groupID: Data, to identities: Set<String>?)
    func setNameObjc(
        groupID: Data,
        creator: String,
        name: String?,
        systemMessageDate: Date,
        send: Bool
    ) async throws
    func setNameObjc(
        group: Group,
        name: String?,
        systemMessageDate: Date,
        send: Bool
    ) async throws
    func setPhotoObjc(
        groupID: Data,
        creator: String,
        imageData: Data,
        sentDate: Date,
        send: Bool
    ) async throws
    func syncObjc(
        group: Group,
        to identities: Set<String>?,
        withoutCreateMessage: Bool
    ) async throws
    func sendSyncRequest(groupID: Data, creator: String, force: Bool)
    func periodicSyncIfNeeded(for group: Group)
}

// Define "default" arguments for certain protocol methods
extension GroupManagerProtocolObjc {
    public func createOrUpdateObjc(
        groupID: Data,
        creator: String,
        members: Set<String>
    ) async throws -> (Group, Set<String>?) {
        try await createOrUpdateObjc(
            groupID: groupID,
            creator: creator,
            members: members,
            systemMessageDate: Date()
        )
    }
    
    public func leave(groupIdentity: GroupIdentity, toMembers: [String]?) {
        leave(
            groupID: groupIdentity.id,
            creator: groupIdentity.creator.string,
            toMembers: toMembers,
            systemMessageDate: Date()
        )
    }

    public func dissolve(groupID: Data, to identities: Set<String>?) {
        dissolve(groupID: groupID, to: identities)
    }
    
    public func sendSyncRequest(groupID: Data, creator: String) {
        sendSyncRequest(groupID: groupID, creator: creator, force: false)
    }
}
