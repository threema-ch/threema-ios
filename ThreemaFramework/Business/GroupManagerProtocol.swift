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

public protocol GroupManagerProtocol: GroupManagerProtocolObjc {
    func createOrUpdate(
        groupID: Data,
        creator: String,
        members: Set<String>,
        systemMessageDate: Date
    ) -> Promise<(Group, Set<String>?)>
    @discardableResult func createOrUpdateDB(
        groupID: Data,
        creator: String,
        members: Set<String>,
        systemMessageDate: Date?,
        sourceCaller: SourceCaller
    ) -> Promise<Group?>
    func getConversation(for groupIdentity: GroupIdentity) -> Conversation?
    func setName(groupID: Data, creator: String, name: String?, systemMessageDate: Date, send: Bool) -> Promise<Void>
    func setName(group: Group, name: String?, systemMessageDate: Date, send: Bool) -> Promise<Void>
    func setPhoto(groupID: Data, creator: String, imageData: Data, sentDate: Date, send: Bool) -> Promise<Void>
    func setPhoto(group: Group, imageData: Data, sentDate: Date, send: Bool) -> Promise<Void>
    func deletePhoto(groupID: Data, creator: String, sentDate: Date, send: Bool) -> Promise<Void>
    func sync(group: Group, to identities: Set<String>?, withoutCreateMessage: Bool)
        -> Promise<Void>
}

// Define "default" arguments for certains protocol methods
public extension GroupManagerProtocol {
    func setName(groupID: Data, creator: String, name: String?, systemMessageDate: Date) -> Promise<Void> {
        setName(groupID: groupID, creator: creator, name: name, systemMessageDate: systemMessageDate, send: true)
    }
    
    func setName(group: Group, name: String?) -> Promise<Void> {
        setName(group: group, name: name, systemMessageDate: Date(), send: true)
    }
    
    func setPhoto(groupID: Data, creator: String, imageData: Data, sentDate: Date) -> Promise<Void> {
        setPhoto(groupID: groupID, creator: creator, imageData: imageData, sentDate: sentDate, send: true)
    }
    
    func setPhoto(group: Group, imageData: Data, sentDate: Date) -> Promise<Void> {
        setPhoto(group: group, imageData: imageData, sentDate: sentDate, send: true)
    }
    
    func deletePhoto(groupID: Data, creator: String, sentDate: Date) -> Promise<Void> {
        deletePhoto(groupID: groupID, creator: creator, sentDate: sentDate, send: true)
    }
    
    func sync(group: Group) -> Promise<Void> {
        sync(group: group, to: nil, withoutCreateMessage: false)
    }
}

@objc public protocol GroupManagerProtocolObjc {
    func createOrUpdateObjc(
        groupID: Data,
        creator: String,
        members: Set<String>,
        systemMessageDate: Date,
        completionHandler: @escaping (Group, Set<String>?) -> Void,
        errorHandler: @escaping (Error?) -> Void
    )
    func createOrUpdateDBObjc(
        groupID: Data,
        creator: String,
        members: Set<String>,
        systemMessageDate: Date?,
        sourceCaller: SourceCaller
    ) -> AnyPromise
    func deletePhotoObjc(groupID: Data, creator: String, sentDate: Date, send: Bool) -> AnyPromise
    func getGroup(_ groupID: Data, creator: String) -> Group?
    func getGroup(conversation: Conversation) -> Group?
    func leave(groupID: Data, creator: String, toMembers: [String]?, systemMessageDate: Date)
    func leaveDB(groupID: Data, creator: String, member: String, systemMessageDate: Date)
    func dissolve(groupID: Data, to identities: Set<String>?)
    func unknownGroup(groupID: Data, creator: String)
    @discardableResult func setNameObjc(
        groupID: Data,
        creator: String,
        name: String?,
        systemMessageDate: Date,
        send: Bool
    ) -> AnyPromise
    @discardableResult func setNameObjc(group: Group, name: String?, systemMessageDate: Date, send: Bool)
        -> AnyPromise
    @discardableResult func setPhotoObjc(groupID: Data, creator: String, imageData: Data, sentDate: Date, send: Bool)
        -> AnyPromise
    func syncObjc(group: Group, to identities: Set<String>?, withoutCreateMessage: Bool) -> AnyPromise
    func sendSyncRequest(groupID: Data, creator: String)
    func periodicSyncIfNeeded(for group: Group)
}

// Define "default" arguments for certains protocol methods
public extension GroupManagerProtocolObjc {
    func createOrUpdateObjc(
        groupID: Data,
        creator: String,
        members: Set<String>,
        completionHandler: @escaping (Group, Set<String>?) -> Void,
        errorHandler: @escaping (Error?) -> Void
    ) {
        createOrUpdateObjc(
            groupID: groupID,
            creator: creator,
            members: members,
            systemMessageDate: Date(),
            completionHandler: completionHandler,
            errorHandler: errorHandler
        )
    }
    
    func leave(groupID: Data, creator: String, toMembers: [String]?) {
        leave(groupID: groupID, creator: creator, toMembers: toMembers, systemMessageDate: Date())
    }

    func dissolve(groupID: Data, to identities: Set<String>?) {
        dissolve(groupID: groupID, to: identities)
    }
}
