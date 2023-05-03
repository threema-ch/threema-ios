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
import PromiseKit
import ThreemaFramework

class GroupManagerMock: NSObject, GroupManagerProtocol {

    var getConversationReturns: Conversation?
    var getGroupReturns: Group?

    var unknownGroupCalls = [Data: String]()
    var sendSyncRequestCalls = [Data: String]()
    var periodicSyncIfNeededCalls = [Group]()

    func setName(groupID: Data, creator: String, name: String?, systemMessageDate: Date, send: Bool) -> Promise<Void> {
        Promise()
    }
    
    func setName(group: Group, name: String?, systemMessageDate: Date, send: Bool) -> Promise<Void> {
        Promise()
    }
    
    func setPhoto(groupID: Data, creator: String, imageData: Data, sentDate: Date, send: Bool) -> Promise<Void> {
        Promise()
    }
    
    func setPhoto(group: Group, imageData: Data, sentDate: Date, send: Bool) -> Promise<Void> {
        Promise()
    }
    
    func deletePhoto(groupID: Data, creator: String, sentDate: Date, send: Bool) -> Promise<Void> {
        Promise()
    }

    func sync(
        group: Group,
        to members: Set<String>?,
        withoutCreateMessage: Bool
    ) -> Promise<Void> {
        Promise()
    }

    func createOrUpdate(
        groupID: Data,
        creator: String,
        members: Set<String>,
        systemMessageDate: Date
    ) -> Promise<(Group, Set<String>?)> {
        unknownGroupCalls.removeValue(forKey: groupID)
        return Promise(error: GroupManager.GroupError.notCreator)
    }

    func createOrUpdateObjc(
        groupID: Data,
        creator: String,
        members: Set<String>,
        systemMessageDate: Date,
        completionHandler: @escaping (Group, Set<String>?) -> Void,
        errorHandler: @escaping (Error?) -> Void
    ) {
        unknownGroupCalls.removeValue(forKey: groupID)
    }

    @discardableResult func createOrUpdateDB(
        groupID: Data,
        creator: String,
        members: Set<String>,
        systemMessageDate: Date?,
        sourceCaller: SourceCaller
    ) -> Promise<Group?> {
        Promise { $0.fulfill(nil) }
    }

    @discardableResult func createOrUpdateDBObjc(
        groupID: Data,
        creator: String,
        members: Set<String>,
        systemMessageDate: Date?,
        sourceCaller: SourceCaller
    ) -> AnyPromise {
        AnyPromise(createOrUpdateDBObjc(
            groupID: groupID,
            creator: creator,
            members: members,
            systemMessageDate: systemMessageDate,
            sourceCaller: sourceCaller
        ))
    }

    func deletePhotoObjc(groupID: Data, creator: String, sentDate: Date, send: Bool) -> AnyPromise {
        AnyPromise()
    }
    
    func getConversation(for groupIdentity: GroupIdentity) -> Conversation? {
        getConversationReturns
    }

    func getGroup(_ groupID: Data, creator: String) -> Group? {
        getGroupReturns
    }
    
    func getGroup(conversation: Conversation) -> Group? {
        getGroupReturns
    }

    func leave(groupID: Data, creator: String, toMembers: [String]?, systemMessageDate: Date) {
        // Do nothing
    }

    func leaveDB(groupID: Data, creator: String, member: String, systemMessageDate: Date) {
        // Do nothing
    }

    func dissolve(groupID: Data, to identities: Set<String>?) {
        // no-op
    }

    func unknownGroup(groupID: Data, creator: String) {
        unknownGroupCalls[groupID] = creator
    }

    @discardableResult func setNameObjc(
        groupID: Data,
        creator: String,
        name: String?,
        systemMessageDate: Date,
        send: Bool
    ) -> AnyPromise {
        AnyPromise()
    }

    @discardableResult func setNameObjc(
        group: Group,
        name: String?,
        systemMessageDate: Date,
        send: Bool
    ) -> AnyPromise {
        AnyPromise()
    }

    @discardableResult func setPhotoObjc(
        groupID: Data,
        creator: String,
        imageData: Data,
        sentDate: Date,
        send: Bool
    ) -> AnyPromise {
        AnyPromise()
    }
    
    func syncObjc(group: Group, to members: Set<String>?, withoutCreateMessage: Bool) -> AnyPromise {
        AnyPromise()
    }
    
    func sendSyncRequest(groupID: Data, creator: String, force: Bool) {
        sendSyncRequestCalls[groupID] = creator
    }
    
    func periodicSyncIfNeeded(for group: Group) {
        periodicSyncIfNeededCalls.append(group)
    }
}
