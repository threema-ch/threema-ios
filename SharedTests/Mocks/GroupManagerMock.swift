//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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
import ThreemaFramework

class GroupManagerMock: NSObject, GroupManagerProtocol {

    var getConversationReturns: ConversationEntity?
    var getGroupReturns = [Group]()

    private let myIdentityStore: MyIdentityStoreProtocol

    init(_ myIdentityStore: MyIdentityStoreProtocol = MyIdentityStoreMock()) {
        self.myIdentityStore = myIdentityStore
    }

    struct SyncCall {
        let group: Group
        let receivers: Set<String>?
    }

    private(set) var syncCalls = [SyncCall]()
    
    var sendSyncRequestCalls = [GroupIdentity]()
    var periodicSyncIfNeededCalls = [Group]()
    
    struct LeaveCall {
        let groupIdentity: GroupIdentity
        let receivers: [String]?
    }

    private(set) var leaveCalls = [LeaveCall]()
    private(set) var leaveDBCalls = [GroupIdentity]()
    
    struct DissolveCall {
        let groupID: Data
        let receivers: Set<String>?
    }

    private(set) var dissolveCalls = [DissolveCall]()
    
    struct EmptyMemberListCall {
        let groupID: Data
        let receivers: Set<ThreemaIdentity>?
    }

    private(set) var emptyMemberListCalls = [EmptyMemberListCall]()
    
    // MARK: - Protocol implementation

    func setName(groupID: Data, creator: String, name: String?, systemMessageDate: Date, send: Bool) async throws {
        // no-op
    }
    
    func setName(group: Group, name: String?, systemMessageDate: Date, send: Bool) async throws {
        // no-op
    }
    
    func setPhoto(groupID: Data, creator: String, imageData: Data, sentDate: Date, send: Bool) async throws {
        // no-op
    }
    
    func setPhoto(group: Group, imageData: Data, sentDate: Date, send: Bool) async throws {
        // no-op
    }
    
    func deletePhoto(groupID: Data, creator: String, sentDate: Date, send: Bool) async throws {
        // no-op
    }

    func sync(
        group: Group,
        to members: Set<String>?,
        withoutCreateMessage: Bool
    ) async throws {
        syncCalls.append(SyncCall(group: group, receivers: members))
    }

    func createOrUpdate(
        for groupIdentity: GroupIdentity,
        members: Set<String>,
        systemMessageDate: Date
    ) async throws -> (Group, Set<String>?) {
        throw GroupManager.GroupError.notCreator
    }

    func createOrUpdateObjc(
        groupID: Data,
        creator: String,
        members: Set<String>,
        systemMessageDate: Date
    ) async throws -> (Group, Set<String>?) {
        throw GroupManager.GroupError.notCreator
    }

    func createOrUpdateDB(
        for groupIdentity: GroupIdentity,
        members: Set<String>,
        systemMessageDate: Date?,
        sourceCaller: SourceCaller
    ) async throws -> Group? {
        nil
    }

    func createOrUpdateDBObjc(
        groupID: Data,
        creator: String,
        members: Set<String>,
        systemMessageDate: Date?,
        sourceCaller: SourceCaller
    ) async throws {
        try await createOrUpdateDB(
            for: GroupIdentity(id: groupID, creator: ThreemaIdentity(creator)),
            members: members,
            systemMessageDate: systemMessageDate,
            sourceCaller: sourceCaller
        )
    }

    func deletePhotoObjc(
        groupID: Data,
        creator: String,
        sentDate: Date,
        send: Bool
    ) async throws {
        // no-op
    }
    
    func getConversation(for groupIdentity: GroupIdentity) -> ConversationEntity? {
        getConversationReturns
    }

    func getGroup(_ groupID: Data, creator: String) -> Group? {
        if creator == myIdentityStore.identity {
            return getGroupReturns.first(where: { $0.groupIdentity.id == groupID })
        }

        return getGroupReturns
            .first(where: { $0.groupIdentity.id == groupID && $0.groupIdentity.creator.string == creator })
    }
    
    func getGroup(conversation: ConversationEntity) -> Group? {
        guard let groupID = conversation.groupID else {
            return nil
        }

        return getGroup(groupID, creator: conversation.contact?.identity ?? myIdentityStore.identity)
    }
    
    func getAllActiveGroups() async -> [Group] {
        getGroupReturns.filter(\.isSelfMember)
    }

    func leave(groupID: Data, creator: String, toMembers: [String]?, systemMessageDate: Date) {
        leaveCalls.append(LeaveCall(
            groupIdentity: GroupIdentity(id: groupID, creator: ThreemaIdentity(creator)),
            receivers: toMembers
        ))
    }

    func leaveDB(groupID: Data, creator: String, member: String, systemMessageDate: Date) {
        leaveDBCalls.append(GroupIdentity(id: groupID, creator: ThreemaIdentity(creator)))
    }

    func dissolve(groupID: Data, to identities: Set<String>?) {
        dissolveCalls.append(DissolveCall(groupID: groupID, receivers: identities))
    }

    func sendEmptyMemberList(groupIdentity: GroupIdentity, to identities: Set<ThreemaIdentity>) {
        emptyMemberListCalls.append(EmptyMemberListCall(groupID: groupIdentity.id, receivers: identities))
    }

    func setNameObjc(
        groupID: Data,
        creator: String,
        name: String?,
        systemMessageDate: Date,
        send: Bool
    ) async throws {
        // no-op
    }

    func setNameObjc(
        group: Group,
        name: String?,
        systemMessageDate: Date,
        send: Bool
    ) async throws {
        // no-op
    }

    func setPhotoObjc(
        groupID: Data,
        creator: String,
        imageData: Data,
        sentDate: Date,
        send: Bool
    ) async throws {
        // no-op
    }
    
    func syncObjc(
        group: Group,
        to members: Set<String>?,
        withoutCreateMessage: Bool
    ) async throws {
        try await sync(
            group: group,
            to: members,
            withoutCreateMessage: withoutCreateMessage
        )
    }
    
    func sendSyncRequest(groupID: Data, creator: String, force: Bool) {
        sendSyncRequestCalls.append(GroupIdentity(id: groupID, creator: ThreemaIdentity(creator)))
    }
    
    func periodicSyncIfNeeded(for group: Group) {
        periodicSyncIfNeededCalls.append(group)
    }
}
