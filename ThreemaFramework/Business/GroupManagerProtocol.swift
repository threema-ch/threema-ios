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
import PromiseKit
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
    ) -> Promise<(Group, Set<String>?)>
    @discardableResult func createOrUpdateDB(
        for groupIdentity: GroupIdentity,
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
extension GroupManagerProtocol {
    public func setName(groupID: Data, creator: String, name: String?, systemMessageDate: Date) -> Promise<Void> {
        setName(groupID: groupID, creator: creator, name: name, systemMessageDate: systemMessageDate, send: true)
    }
    
    public func setName(group: Group, name: String?) -> Promise<Void> {
        setName(group: group, name: name, systemMessageDate: Date(), send: true)
    }
    
    public func setPhoto(groupID: Data, creator: String, imageData: Data, sentDate: Date) -> Promise<Void> {
        setPhoto(groupID: groupID, creator: creator, imageData: imageData, sentDate: sentDate, send: true)
    }
    
    public func setPhoto(group: Group, imageData: Data, sentDate: Date) -> Promise<Void> {
        setPhoto(group: group, imageData: imageData, sentDate: sentDate, send: true)
    }
    
    public func deletePhoto(groupID: Data, creator: String, sentDate: Date) -> Promise<Void> {
        deletePhoto(groupID: groupID, creator: creator, sentDate: sentDate, send: true)
    }
    
    public func sync(group: Group) -> Promise<Void> {
        sync(group: group, to: nil, withoutCreateMessage: false)
    }
}

// Convenience functions for GroupIdentity type
extension GroupManagerProtocol {
    public func group(for groupIdentity: GroupIdentity) -> Group? {
        getGroup(groupIdentity.id, creator: groupIdentity.creator.string)
    }
    
    public func leave(groupWith groupIdentity: GroupIdentity, inform receivers: GroupManagerProtocolReceivers) {
        let members: [String]?
        switch receivers {
        case .all:
            members = nil
        case let .members(list):
            members = list.map(\.string)
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
        systemMessageDate: Date,
        completionHandler: @escaping (Group, Set<String>?) -> Void,
        errorHandler: @escaping (Error?) -> Void
    )
    func createOrUpdateDBObjc(
        groupID: Data,
        creator: String,
        members: Set<String>,
        systemMessageDate: Date?,
        sourceCaller: SourceCaller,
        completionHandler: @escaping (Error?) -> Void
    )
    func deletePhotoObjc(
        groupID: Data,
        creator: String,
        sentDate: Date,
        send: Bool,
        completionHandler: @escaping (Error?) -> Void
    )
    func getGroup(_ groupID: Data, creator: String) -> Group?
    func getGroup(conversation: Conversation) -> Group?
    func leave(groupID: Data, creator: String, toMembers: [String]?, systemMessageDate: Date)
    func leaveDB(groupID: Data, creator: String, member: String, systemMessageDate: Date)
    func dissolve(groupID: Data, to identities: Set<String>?)
    func unknownGroup(groupID: Data, creator: String)
    func setNameObjc(
        groupID: Data,
        creator: String,
        name: String?,
        systemMessageDate: Date,
        send: Bool,
        completionHandler: @escaping (Error?) -> Void
    )
    func setNameObjc(
        group: Group,
        name: String?,
        systemMessageDate: Date,
        send: Bool,
        completionHandler: @escaping (Error?) -> Void
    )
    func setPhotoObjc(
        groupID: Data,
        creator: String,
        imageData: Data,
        sentDate: Date,
        send: Bool,
        completionHandler: @escaping (Error?) -> Void
    )
    func syncObjc(
        group: Group,
        to identities: Set<String>?,
        withoutCreateMessage: Bool,
        completionHandler: @escaping (Error?) -> Void
    )
    func sendSyncRequest(groupID: Data, creator: String, force: Bool)
    func periodicSyncIfNeeded(for group: Group)
}

// Define "default" arguments for certain protocol methods
extension GroupManagerProtocolObjc {
    public func createOrUpdateObjc(
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
