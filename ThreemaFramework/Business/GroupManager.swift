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
import ThreemaEssentials

public final class GroupManager: NSObject, GroupManagerProtocol {
    
    public enum GroupError: Error {
        case creatorIsBlocked(groupIdentity: GroupIdentity)
        case creatorNotFound
        case membersMissing
        case groupConversationNotFound
        case groupNotFound
        case decodingFailed
        case blobIDOrKeyMissing
        case photoUploadFailed
        case notCreator
        case contactForCreatorMissing
        case contactForMemberMissing
    }
    
    /// Used for error handling when fetching unknown contacts
    private enum FetchedContactOrError: Equatable {
        case added
        case revokedOrInvalid(String)
        case blocked(String)
        case localNotFound
        case error
    }

    private let myIdentityStore: MyIdentityStoreProtocol
    private let contactStore: ContactStoreProtocol
    private let taskManager: TaskManagerProtocol
    private let userSettings: UserSettingsProtocol
    private let entityManager: EntityManager
    private let groupPhotoSender: GroupPhotoSenderProtocol
    
    init(
        _ myIdentityStore: MyIdentityStoreProtocol,
        _ contactStore: ContactStoreProtocol,
        _ taskManager: TaskManagerProtocol,
        _ userSettings: UserSettingsProtocol,
        _ entityManager: EntityManager,
        _ groupPhotoSender: GroupPhotoSenderProtocol
    ) {
        self.myIdentityStore = myIdentityStore
        self.contactStore = contactStore
        self.taskManager = taskManager
        self.userSettings = userSettings
        self.entityManager = entityManager
        self.groupPhotoSender = groupPhotoSender
    }
    
    convenience init(entityManager: EntityManager, taskManager: TaskManagerProtocol = TaskManager()) {
        self.init(
            MyIdentityStore.shared(),
            ContactStore.shared(),
            taskManager,
            UserSettings.shared(),
            entityManager,
            GroupPhotoSender()
        )
    }

    @objc convenience init(entityManager: EntityManager, taskManagerObjc: TaskManager) {
        self.init(
            MyIdentityStore.shared(),
            ContactStore.shared(),
            taskManagerObjc,
            UserSettings.shared(),
            entityManager,
            GroupPhotoSender()
        )
    }
    
    // MARK: - Create or update
    
    /// Create or update group members and send group create messages to members, if I'm the creator.
    ///
    /// Also sends ballot messages to new members, if necessary.
    ///
    /// - Parameters:
    ///   - groupIdentity: Identity of the group
    ///   - members: Members (identity list) of the group
    ///   - systemMessageDate: Date for new system message(s)
    /// - Returns: Group and list of new members (identity)
    /// - Throws: ThreemaError, GroupError.notCreator, TaskManagerError
    public func createOrUpdate(
        for groupIdentity: GroupIdentity,
        members: Set<String>,
        systemMessageDate: Date
    ) async throws -> (Group, Set<String>?) {

        guard groupIdentity.creator.string.elementsEqual(myIdentityStore.identity) else {
            throw GroupError.notCreator
        }
        
        // Is oldMembers nil, means the group is new and there aren't old members
        var oldMembers: [String]?
        var removedMembers = [String]()

        // If group already exists get old and removed members
        entityManager.performAndWait {
            if let oldConversation = self.getConversation(for: groupIdentity) {
                oldMembers = oldConversation.members.map(\.identity)
                removedMembers = oldMembers!.filter { !members.contains($0) }
            }
        }

        guard let group = try await createOrUpdateDB(
            for: groupIdentity,
            members: members,
            systemMessageDate: systemMessageDate,
            sourceCaller: .local
        ) else {
            throw GroupError.groupNotFound
        }

        var newMembers: Set<String>?
        await entityManager.perform {
            if let oldMembers,
               let conversation = self.getConversation(for: GroupIdentity(
                   id: group.groupID,
                   creator: group.groupIdentity.creator
               )) {
                newMembers = Set(
                    conversation.members
                        .filter { !oldMembers.contains($0.identity) }
                        .map(\.identity)
                )
                if newMembers?.isEmpty == true {
                    newMembers = nil
                }
            }
        }

        if groupIdentity.creator.string.elementsEqual(myIdentityStore.identity) {
            // Send group create message to each active member
            let task = TaskDefinitionSendGroupCreateMessage(
                group: group,
                to: group.allActiveMemberIdentitiesWithoutCreator,
                removed: removedMembers,
                members: members
            )

            taskManager.add(taskDefinition: task)
        }

        return (group, newMembers)
    }

    /// Objective-c bridge
    @objc public func createOrUpdateObjc(
        groupID: Data,
        creator: String,
        members: Set<String>,
        systemMessageDate: Date
    ) async throws -> (Group, Set<String>?) {
        try await createOrUpdate(
            for: GroupIdentity(id: groupID, creator: ThreemaIdentity(creator)),
            members: members,
            systemMessageDate: systemMessageDate
        )
    }

    /// Create or update group members in DB.
    /// - Parameters:
    ///   - groupIdentity: Identity of the group
    ///   - members: Members (identity list) of the group
    ///   - systemMessageDate: Date for new system message(s), if `nil` no message is posted
    ///   - sourceCaller: Delete member (is hidden contact) only is not `SourceCaller.sync`
    /// - Returns: Created or updated group or is Nil when group is deleted
    /// - Throws: GroupError.contactForCreatorMissing, GroupError.contactForMemberMissing
    @discardableResult
    public func createOrUpdateDB(
        for groupIdentity: GroupIdentity,
        members: Set<String>,
        systemMessageDate: Date?,
        sourceCaller: SourceCaller
    ) async throws -> Group? {
        if !groupIdentity.creator.string.elementsEqual(myIdentityStore.identity) {
            // Record a pseudo sync request so we won't trigger another one if we process
            // messages in this new group while we are still processing the group create
            recordSendSyncRequest(groupIdentity)
        }

        // Am I the creator? Then Conversation.contact and GroupEntity.groupCreator have to be `nil`.
        var creatorContact: ContactEntity?
        if !groupIdentity.creator.string.elementsEqual(myIdentityStore.identity) {

            // If the creator blocked and group not found, then send leave messages to sender and all provided members
            if userSettings.blacklist.contains(groupIdentity.creator.string),
               getGroup(groupIdentity.id, creator: groupIdentity.creator.string) == nil {
                if members.contains(myIdentityStore.identity) {
                    var toMembers = [String](members)
                    if !toMembers.contains(groupIdentity.creator.string) {
                        toMembers.append(groupIdentity.creator.string)
                    }

                    leave(groupIdentity: groupIdentity, toMembers: toMembers)
                }

                DDLogWarn(
                    "Group (\(groupIdentity)) not created, because creator is blocked, i sent group leave messages to its members"
                )
                throw GroupError.creatorIsBlocked(groupIdentity: groupIdentity)
            }

            creatorContact = entityManager.entityFetcher.contact(for: groupIdentity.creator.string)
            guard creatorContact != nil else {
                throw GroupError.contactForCreatorMissing
            }
        }

        // Adjust group members and group state
        var allMembers = Set<String>(members)
        if !allMembers.contains(groupIdentity.creator.string) {
            allMembers.insert(groupIdentity.creator.string)
        }

        if allMembers.contains(myIdentityStore.identity) {
            // I'm member of this group
            var groupNewCreated = false

            // First fetch all contacts
            var identitiesToFetch = [String]()
            entityManager.performAndWait {
                for member in members.filter({ $0 != self.myIdentityStore.identity }) {
                    if self.entityManager.entityFetcher.contact(for: member) == nil {
                        identitiesToFetch.append(member)
                    }
                }
            }
            
            let fetchedIdentities = try await fetchContacts(for: identitiesToFetch)

            return try await entityManager.performSave {
                let conversation: Conversation
                if let existingConversation = self.entityManager.entityFetcher.conversation(
                    for: groupIdentity.id,
                    creator: groupIdentity.creator.string
                ) {
                    conversation = existingConversation
                }
                else {
                    conversation = self.entityManager.entityCreator.conversation()
                    conversation.groupID = groupIdentity.id
                    conversation.contact = creatorContact
                    conversation.groupMyIdentity = self.myIdentityStore.identity
                }

                let groupEntity: GroupEntity
                if let existingGroup = self.entityManager.entityFetcher.groupEntity(for: conversation) {
                    groupEntity = existingGroup
                }
                else {
                    groupEntity = self.entityManager.entityCreator.groupEntity()
                    groupEntity.groupID = groupIdentity.id
                    groupEntity.groupCreator = creatorContact != nil ? groupIdentity.creator.string : nil
                    groupEntity.state = NSNumber(value: GroupState.active.rawValue)
                    groupNewCreated = true
                }
                groupEntity.lastPeriodicSync = Date()

                let currentMembers: [String] = conversation.members.map(\.identity)

                // I am member of this group, set group state active
                if groupEntity.state != NSNumber(value: GroupState.active.rawValue) {
                    groupEntity.state = NSNumber(value: GroupState.active.rawValue)

                    if let systemMessageDate {
                        self.postSystemMessage(
                            in: conversation,
                            type: kSystemMessageGroupSelfAdded,
                            arg: nil,
                            date: systemMessageDate
                        )
                    }
                }

                // My ID should be set on active group conversation (could be an old ID e.g. after restored a
                // backup)
                if let groupMyIdentity = conversation.groupMyIdentity,
                   !groupMyIdentity.elementsEqual(self.myIdentityStore.identity) {
                    conversation.groupMyIdentity = self.myIdentityStore.identity
                }

                // Remove deleted members
                for memberIdentity in currentMembers {
                    guard !allMembers.contains(memberIdentity) else {
                        continue
                    }

                    if let memberContact = self.entityManager.entityFetcher.contact(for: memberIdentity) {
                        conversation.removeMembersObject(memberContact)

                        if let systemMessageDate {
                            self.postSystemMessage(
                                in: conversation,
                                member: memberContact,
                                type: kSystemMessageGroupMemberForcedLeave,
                                date: systemMessageDate
                            )
                        }

                        if sourceCaller != .sync, !memberContact.isContactHidden {
                            self.contactStore.markContactAsDeleted(
                                identity: memberIdentity,
                                entityManagerObject: self.entityManager
                            )
                        }
                    }
                }

                // Add new members
                for memberIdentity in allMembers {
                    guard !currentMembers.contains(memberIdentity),
                          !memberIdentity.elementsEqual(self.myIdentityStore.identity) else {
                        continue
                    }

                    guard let contact = self.entityManager.entityFetcher.contact(for: memberIdentity) else {
                        let isIdentityRevoked = fetchedIdentities.contains { contactState in
                            if case .revokedOrInvalid(memberIdentity) = contactState {
                                return true
                            }
                            else if case .blocked(memberIdentity) = contactState {
                                return true
                            }
                            return false
                        }
                        if isIdentityRevoked {
                            // Do nothing because the contact never existed or was revoked or blocked
                            DDLogVerbose("Skip invalid, revoked or blocked contact")
                            continue
                        }
                        else {
                            throw GroupError.contactForMemberMissing
                        }
                    }

                    conversation.addMembersObject(contact)

                    if let systemMessageDate {
                        self.postSystemMessage(
                            in: conversation,
                            member: contact,
                            type: kSystemMessageGroupMemberAdd,
                            date: systemMessageDate
                        )
                    }
                }

                if groupIdentity.creator.string.elementsEqual(self.myIdentityStore.identity) {
                    // Check is note group or not anymore
                    if allMembers.count == 1, allMembers.contains(self.myIdentityStore.identity) {
                        self.postSystemMessage(
                            in: conversation,
                            type: kSystemMessageStartNoteGroupInfo,
                            arg: nil,
                            date: Date()
                        )
                    }
                    else if !groupNewCreated, allMembers.count > 1, currentMembers.isEmpty {
                        self.postSystemMessage(
                            in: conversation,
                            type: kSystemMessageEndNoteGroupInfo,
                            arg: nil,
                            date: Date()
                        )
                    }
                }

                let lastSyncRequestSince = Date(timeIntervalSinceNow: TimeInterval(-kGroupSyncRequestInterval))
                let lastSyncRequest = self.entityManager.entityFetcher.lastGroupSyncRequest(
                    for: groupIdentity.id,
                    groupCreator: groupIdentity.creator.string,
                    since: lastSyncRequestSince
                )

                let group = Group(
                    myIdentityStore: self.myIdentityStore,
                    userSettings: self.userSettings,
                    groupEntity: groupEntity,
                    conversation: conversation,
                    lastSyncRequest: lastSyncRequest?.lastSyncRequest
                )

                self.refreshRejectedMessages(in: group)

                return group
            }
        }
        else {
            if !groupIdentity.creator.string.elementsEqual(myIdentityStore.identity) {
                // I'm not member or creator of the group
                return await entityManager.performSave {
                    if let groupEntity = self.entityManager.entityFetcher.groupEntity(
                        for: groupIdentity.id,
                        with: groupIdentity.creator.string
                    ) {
                        var addSystemMessage = false

                        if groupEntity.state != NSNumber(value: GroupState.forcedLeft.rawValue) {
                            groupEntity.state = NSNumber(value: GroupState.forcedLeft.rawValue)
                            addSystemMessage = true
                        }

                        if let conversation = self.entityManager.entityFetcher.conversation(
                            for: groupIdentity.id,
                            creator: groupIdentity.creator.string
                        ) {
                            if addSystemMessage, let systemMessageDate {
                                self.postSystemMessage(
                                    in: conversation,
                                    type: kSystemMessageGroupSelfRemoved,
                                    arg: nil,
                                    date: systemMessageDate
                                )
                            }

                            let lastSyncRequestSince =
                                Date(timeIntervalSinceNow: TimeInterval(-kGroupSyncRequestInterval))
                            let lastSyncRequest = self.entityManager.entityFetcher.lastGroupSyncRequest(
                                for: groupIdentity.id,
                                groupCreator: groupIdentity.creator.string,
                                since: lastSyncRequestSince
                            )
                            
                            let group = Group(
                                myIdentityStore: self.myIdentityStore,
                                userSettings: self.userSettings,
                                groupEntity: groupEntity,
                                conversation: conversation,
                                lastSyncRequest: lastSyncRequest?.lastSyncRequest
                            )
                            
                            self.refreshRejectedMessages(in: group)
                            
                            return group
                        }
                        else {
                            DDLogWarn("Conversation entity for \(groupIdentity) not found")
                        }
                    }
                    else {
                        DDLogWarn("Group entity for \(groupIdentity) not found")
                    }

                    return nil
                }
            }
            else {
                DDLogNotice("I'm creator of the group \(groupIdentity) but not member")
            }

            return nil
        }
    }

    /// Objective-C bridge
    public func createOrUpdateDBObjc(
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
    
    /// Individually fetches the contacts with the listed identities from the database or requests them individually
    /// from the directory server. This function will ignore the block unknown setting, because it should add all
    /// contacts to member list.
    /// Use `fetchContacts` to fetch multiple contacts
    /// - Parameter identities: identities to fetch from the database or directory server
    /// - Returns: The fetched contact or an error
    private func fetchContacts(for identities: [String]) async throws -> [FetchedContactOrError] {
        let prefetchedIdentities = try await prefetchIdentities(for: identities)

        return await withTaskGroup(
            of: FetchedContactOrError.self,
            returning: [FetchedContactOrError].self
        ) { taskGroup in
            for identity in prefetchedIdentities {
                taskGroup.addTask {
                    await withCheckedContinuation { continuation in
                        self.contactStore.fetchPublicKey(
                            for: identity,
                            acquaintanceLevel: .groupOrDeleted,
                            entityManager: self.entityManager,
                            ignoreBlockUnknown: true,
                            onCompletion: { _ in
                                guard self.entityManager.entityFetcher.contact(for: identity) != nil else {
                                    continuation.resume(returning: .localNotFound)
                                    return
                                }
                                continuation.resume(returning: .added)
                            }
                        ) { error in
                            DDLogError("Error fetch public key")
                            if let nsError = error as? NSError, nsError.domain == NSURLErrorDomain,
                               nsError.code == 404 {
                                continuation.resume(returning: .revokedOrInvalid(identity))
                            }
                            else if let nsError = error as? NSError,
                                    nsError.code == ThreemaProtocolError.blockUnknownContact.rawValue {
                                continuation.resume(returning: .blocked(identity))
                            }
                            else {
                                continuation.resume(returning: .error)
                            }
                        }
                    }
                }
            }

            var fetchedResults = [FetchedContactOrError]()
            for await fetchedResult in taskGroup {
                fetchedResults.append(fetchedResult)
            }
            return fetchedResults
        }
    }

    private func prefetchIdentities(for identities: [String]) async throws -> Set<String> {
        try await withCheckedThrowingContinuation { continuation in
            self.contactStore.prefetchIdentityInfo(Set(identities)) {
                continuation.resume(returning: Set(identities))
            } onError: { error in
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Set name
    
    public func setName(
        groupID: Data,
        creator: String,
        name: String?,
        systemMessageDate: Date,
        send: Bool
    ) async throws {
        guard let grp = getGroup(groupID, creator: creator) else {
            throw GroupError.groupNotFound
        }
        return try await setName(group: grp, name: name, systemMessageDate: systemMessageDate, send: send)
    }
    
    /// Update group name in DB. If I'm the creator send group rename message (`GroupRenameMessage`) to members.
    ///
    /// - Parameters:
    ///   - group: Group to update name
    ///   - name: New name of the group
    ///   - systemMessageDate: Date for new system message
    ///   - send: Send group rename messages if I'm the creator?
    public func setName(
        group: Group,
        name: String?,
        systemMessageDate: Date,
        send: Bool
    ) async throws {
        guard group.name != name else {
            // Name didn't change
            return
        }
        
        await entityManager.performSave {
            guard let conversation = self.entityManager.entityFetcher.conversation(
                for: group.groupID,
                creator: group.groupCreatorIdentity
            ) else {
                return
            }

            conversation.groupName = name

            self.postSystemMessage(
                in: conversation,
                type: kSystemMessageRenameGroup,
                arg: name?.data(using: .utf8),
                date: systemMessageDate
            )
        }
        
        if send, group.isOwnGroup {
            let task = createGroupRenameTask(for: group, to: group.allActiveMemberIdentitiesWithoutCreator)
            try await add(task: task)
        }
    }
    
    /// Objective-C bridge
    public func setNameObjc(
        groupID: Data,
        creator: String,
        name: String?,
        systemMessageDate: Date,
        send: Bool
    ) async throws {
        try await setName(groupID: groupID, creator: creator, name: name, systemMessageDate: systemMessageDate)
    }
    
    /// Objective-C bridge
    public func setNameObjc(
        group: Group,
        name: String?,
        systemMessageDate: Date,
        send: Bool
    ) async throws {
        try await setName(group: group, name: name, systemMessageDate: systemMessageDate, send: send)
    }
    
    // MARK: - Set photo
    
    public func setPhoto(
        groupID: Data,
        creator: String,
        imageData: Data,
        sentDate: Date,
        send: Bool
    ) async throws {
        guard let grp = getGroup(groupID, creator: creator) else {
            throw GroupError.groupNotFound
        }
        return try await setPhoto(group: grp, imageData: imageData, sentDate: sentDate, send: send)
    }
    
    /// Update group photo and upload photo and send group set photo message (`GroupSetPhotoMessage`) to members, if I'm
    /// the creator.
    ///
    /// - Parameters:
    ///   - group: Group to update photo
    ///   - imageData: Photo raw image data, supporting UIImage
    ///   - sentDate: Sent date of set photo message
    ///   - send: If `True` and I'm the creator: upload photo and send group set photo messages
    /// - Throws: GroupError.groupConversationNotFound, GroupError.decodingFailed
    ///           GroupError.notCreator, GroupError.photoUploadFailed, GroupError.blobIDOrKeyMissing
    public func setPhoto(
        group: Group,
        imageData: Data,
        sentDate: Date,
        send: Bool
    ) async throws {

        let (conversationObjectID, conversationGroupImageSetDate, conversationGroupImageData) = await entityManager
            .perform {
                let conversation = self.entityManager.entityFetcher.conversation(
                    for: group.groupID,
                    creator: group.groupCreatorIdentity
                )
                return (conversation?.objectID, conversation?.groupImageSetDate, conversation?.groupImage?.data)
            }

        guard let conversationObjectID else {
            throw GroupError.groupConversationNotFound
        }

        var imageDataSend: Data?
        
        // Check if this message is older than the last set date. This ensures that we're using
        // the latest image in case multiple images arrive for the same conversation in short succession.
        // Must do the check here (main thread) to avoid race condition.
        if let imageSetDate = conversationGroupImageSetDate,
           imageSetDate.compare(sentDate) == .orderedDescending {
            
            DDLogInfo("Ignoring older group set photo message")
            imageDataSend = conversationGroupImageData
        }
        else if let image = UIImage(data: imageData) {
            do {
                try entityManager.performAndWaitSave {
                    guard let conversation = self.entityManager.entityFetcher
                        .existingObject(with: conversationObjectID) as? Conversation else {
                        throw GroupError.groupConversationNotFound
                    }

                    var dbImage: ImageData? = conversation.groupImage
                    if dbImage == nil {
                        dbImage = self.entityManager.entityCreator.imageData()
                    }

                    guard dbImage?.data != imageData else {
                        return
                    }

                    dbImage?.data = imageData
                    dbImage?.width = NSNumber(floatLiteral: Double(image.size.width))
                    dbImage?.height = NSNumber(floatLiteral: Double(image.size.height))

                    conversation.groupImageSetDate = sentDate
                    conversation.groupImage = dbImage

                    self.postSystemMessage(
                        in: conversation,
                        type: kSystemMessageGroupProfilePictureChanged,
                        arg: nil,
                        date: Date()
                    )
                }
            }
            catch {
                throw error
            }

            imageDataSend = imageData
        }
        else {
            throw GroupError.decodingFailed
        }
        
        if send, group.isOwnGroup,
           let imageDataSend {
            try await sendPhoto(
                to: group,
                imageData: imageDataSend,
                toMembers: group.allActiveMemberIdentitiesWithoutCreator
            )
        }
    }
    
    /// Objective-C bridge
    public func setPhotoObjc(
        groupID: Data,
        creator: String,
        imageData: Data,
        sentDate: Date,
        send: Bool
    ) async throws {
        try await setPhoto(groupID: groupID, creator: creator, imageData: imageData, sentDate: sentDate, send: send)
    }
    
    // MARK: - Delete photo
    
    /// Delete group photo and send group delete photo message (`GroupDeletePhotoMessage`) to members, if I'm the
    /// creator.
    ///
    /// - Parameters:
    ///   - groupID: ID (8 bytes) of the group, unique with creator
    ///   - creator: Creator (identity) of the group, unique with ID
    ///   - sentDate: Sent date of delete photo message
    ///   - send: True send group delete photo message if I'm the creator
    ///  - Throws: GroupError.groupNotFound, GroupError.groupConversationNotFound
    public func deletePhoto(
        groupID: Data,
        creator: String,
        sentDate: Date,
        send: Bool
    ) async throws {
        guard let grp = getGroup(groupID, creator: creator) else {
            throw GroupError.groupNotFound
        }

        try await entityManager.performSave {
            guard let conversation = self.entityManager.entityFetcher.conversation(
                for: grp.groupID,
                creator: grp.groupCreatorIdentity
            ) else {
                throw GroupError.groupConversationNotFound
            }
            conversation.groupImageSetDate = sentDate
            
            if let groupImage = conversation.groupImage {
                self.entityManager.entityDestroyer.delete(imageData: groupImage)
                conversation.groupImage = nil
                
                self.postSystemMessage(
                    in: conversation,
                    type: kSystemMessageGroupProfilePictureChanged,
                    arg: nil,
                    date: Date.now
                )
            }
        }

        if send, grp.isOwnGroup {
            let task = createDeletePhotoTask(for: grp, to: grp.allActiveMemberIdentitiesWithoutCreator)
            try await add(task: task)
        }
    }
    
    /// Objective-C bridge
    public func deletePhotoObjc(
        groupID: Data,
        creator: String,
        sentDate: Date,
        send: Bool
    ) async throws {
        try await deletePhoto(groupID: groupID, creator: creator, sentDate: sentDate, send: send)
    }
    
    // MARK: - Leave
    
    /// Send group leave and leave the group, admin of the group may not allowed to leave the group.
    ///
    /// - Parameters:
    ///   - groupID: ID (8 bytes) of the group, unique with creator
    ///   - creator: Creator (identity) of the group, unique with ID
    ///   - toMembers: Receivers of the group leave message, if nil send to all members of existing group
    ///   - systemMessageDate: Date for new system message
    @objc public func leave(groupID: Data, creator: String, toMembers: [String]?, systemMessageDate: Date) {
        guard creator != myIdentityStore.identity else {
            DDLogWarn("Group creator can't leave the group")
            return
        }

        // Send leave group message even I'm left the group already or the group not exists
        var currentMembers = [String]()
        var hiddenContacts = [String]()
        entityManager.performAndWait {
            if let conversation = self
                .getConversation(for: GroupIdentity(id: groupID, creator: ThreemaIdentity(creator))) {
                currentMembers = conversation.members.map(\.identity)
                hiddenContacts = conversation.members.filter(\.isContactHidden).map(\.identity)
            }
        }

        var sendToMembers = toMembers ?? currentMembers
        if sendToMembers.isEmpty {
            // Add Me as receiver to reflect group leave message
            sendToMembers.append(myIdentityStore.identity)
        }

        let task = TaskDefinitionSendGroupLeaveMessage(sendContactProfilePicture: false)
        task.groupID = groupID
        task.groupCreatorIdentity = creator
        task.fromMember = myIdentityStore.identity
        task.toMembers = sendToMembers
        task.hiddenContacts = hiddenContacts
        taskManager.add(taskDefinition: task)

        if let group = getGroup(groupID, creator: creator) {
            guard group.state != .left, group.state != .forcedLeft else {
                DDLogWarn("I can't left the group, I'm not member of this group anymore")
                return
            }
        }

        leaveDB(
            groupID: groupID,
            creator: creator,
            member: myIdentityStore.identity,
            systemMessageDate: systemMessageDate
        )
    }
    
    /// Remove member from group in DB.
    ///
    /// - Parameters:
    ///   - groupID: ID (8 bytes) of the group, unique with creator
    ///   - creator: Creator (identity) of the group, unique with ID
    ///   - member: Member who left the group
    ///   - systemMessageDate: Date for new system message
    public func leaveDB(groupID: Data, creator: String, member: String, systemMessageDate: Date) {
        entityManager.performAndWait {
            guard let grp = self.getGroup(groupID, creator: creator) else {
                DDLogWarn("Group not found")
                return
            }
            guard let groupEntity = self.entityManager.entityFetcher.groupEntity(
                for: groupID,
                with: creator != self.myIdentityStore.identity ? creator : nil
            )
            else {
                DDLogWarn("Group entity not found")
                return
            }
            guard let conversation = self
                .getConversation(for: GroupIdentity(id: groupID, creator: ThreemaIdentity(creator))) else {
                DDLogWarn("Conversation not found")
                return
            }

            DDLogInfo("Member \(member) left the group \(grp.groupID.hexString) \(creator)")

            if let contact = conversation.members.first(where: { contact -> Bool in
                contact.identity.elementsEqual(member)
            }) {
                self.entityManager.performAndWaitSave {
                    conversation.removeMembersObject(contact)
                }

                self.postSystemMessage(
                    in: conversation,
                    member: contact,
                    type: kSystemMessageGroupMemberLeave,
                    date: systemMessageDate
                )

                if creator.elementsEqual(self.myIdentityStore.identity),
                   grp.isNoteGroup {
                    self.postSystemMessage(
                        in: conversation,
                        type: kSystemMessageStartNoteGroupInfo,
                        arg: nil,
                        date: Date()
                    )
                }
                else if creator == member, !grp.isNoteGroup {
                    self.postSystemMessage(
                        in: conversation,
                        type: kSystemMessageGroupCreatorLeft,
                        arg: nil,
                        date: Date()
                    )
                }
            }
            else if member.elementsEqual(self.myIdentityStore.identity), !grp.didLeave {
                self.entityManager.performAndWaitSave {
                    groupEntity.state = NSNumber(value: GroupState.left.rawValue)
                    if !(conversation.groupMyIdentity?.elementsEqual(self.myIdentityStore.identity) ?? false) {
                        conversation.groupMyIdentity = self.myIdentityStore.identity
                    }
                }

                self.postSystemMessage(
                    in: conversation,
                    type: kSystemMessageGroupSelfLeft,
                    arg: nil,
                    date: systemMessageDate
                )
            }
            
            self.refreshRejectedMessages(in: grp)
        }
    }

    /// Send empty member list to every group member to dissolve the group and i left the group.
    ///
    /// - Parameters:
    ///   - groupID: Group ID to suspend (I'm the group creator)
    ///   - identities: Identities to send dissolve to, if `nil` all group members get the dissolve message
    @objc public func dissolve(
        groupID: Data,
        to identities: Set<String>?
    ) {
        entityManager.performAndWait {
            if let group = self.getGroup(groupID, creator: self.myIdentityStore.identity) {
                guard group.isSelfCreator else {
                    return
                }

                // Add task to kick all active members (and reflect left group), and left the group
                let task = TaskDefinitionGroupDissolve(group: group)
                if let identities {
                    task.toMembers = Array(identities)
                }
                else {
                    task.toMembers = group.allActiveMemberIdentitiesWithoutCreator
                }

                self.taskManager.add(taskDefinition: task)

                if group.state == .active {
                    // I leave the group
                    self.leaveDB(
                        groupID: group.groupID,
                        creator: group.groupCreatorIdentity,
                        member: group.groupCreatorIdentity,
                        systemMessageDate: Date()
                    )
                }
            }
            else {
                // Group not found (means conversation was deleted), kick identities except me if I'm group creator and
                // has left the group
                guard let groupEntity = self.entityManager.entityFetcher.groupEntity(
                    for: groupID,
                    with: nil
                ),
                    groupEntity.didLeave(),
                    let identities
                else {
                    return
                }

                let removeMembers = identities.filter { $0 != self.myIdentityStore.identity }
                if !removeMembers.isEmpty {
                    self.taskManager.add(
                        taskDefinition: TaskDefinitionSendGroupCreateMessage(
                            groupID: groupID,
                            groupCreatorIdentity: self.myIdentityStore.identity,
                            groupName: nil,
                            allGroupMembers: nil,
                            isNoteGroup: nil,
                            to: [],
                            removed: Array(removeMembers),
                            members: Set<String>(),
                            sendContactProfilePicture: false
                        )
                    )
                }
            }
        }
    }
       
    /// Send empty member list to the receivers, if I'm the group creator
    ///
    /// - Parameters:
    ///   - groupID: Group Identity
    ///   - identities: Identities to send empty member list to
    public func sendEmptyMemberList(
        groupIdentity: GroupIdentity,
        to identities: Set<ThreemaIdentity>
    ) {
        guard let group = getGroup(groupIdentity.id, creator: groupIdentity.creator.string),
              group.isSelfCreator else {
            let errorMessage =
                "Could not send empty member list because the group does not exist or I am not the creator of the group (id: \(groupIdentity.id.hexString), creator: \(groupIdentity.creator.string))"
            assertionFailure(errorMessage)
            DDLogError(errorMessage)
            return
        }
        
        taskManager.add(
            taskDefinition: TaskDefinitionSendGroupCreateMessage(
                groupID: groupIdentity.id,
                groupCreatorIdentity: groupIdentity.creator.string,
                groupName: nil,
                allGroupMembers: nil,
                isNoteGroup: nil,
                to: Array(identities.map(\.string)),
                removed: nil,
                members: Set<String>(),
                sendContactProfilePicture: false
            )
        )
    }
    
    // MARK: - Sync
    
    /// Sync group information to identities.
    ///
    /// Send group create, rename and set photo message to each identity that is a member. Send a group create to
    /// non-members with an empty
    /// members list.
    ///
    /// - Parameters:
    ///   - group: Group to sync
    ///   - identities: Identities to send sync to, if `nil` all group members get the sync messages
    ///   - withoutCreateMessage: Should the create message also be sent to group members?
    ///                             (This is useful to send all group information to recently added members.)
    public func sync(
        group: Group,
        to identities: Set<String>?,
        withoutCreateMessage: Bool
    ) async throws {
        // Ensure that we are the creator
        guard group.isOwnGroup else {
            throw GroupError.notCreator
        }
        
        guard let identities else {
            // Sync to all members
            try await sync(
                group: group,
                to: group.allActiveMemberIdentitiesWithoutCreator,
                withoutCreateMessage: withoutCreateMessage
            )
            return
        }
        
        // If we have a list of receivers filter between members and non-members.
        var activeMembers = [String]()
        var removedMembers = [String]()
        for identity in identities {
            if group.allMemberIdentities.contains(identity) {
                activeMembers.append(identity)
            }
            else {
                removedMembers.append(identity)
            }
        }
        
        try await sync(group: group, to: activeMembers, withoutCreateMessage: withoutCreateMessage)
        try await syncToRemovedMembers(group: group, to: removedMembers)
    }
    
    public func syncObjc(
        group: Group,
        to identities: Set<String>?,
        withoutCreateMessage: Bool
    ) async throws {
        try await sync(group: group, to: identities, withoutCreateMessage: withoutCreateMessage)
    }
    
    /// Send sync request for this group, is not already requested in the last 7 days (see `kGroupSyncRequestInterval`).
    ///
    /// - Parameters:
    ///   - groupID: ID 8 Bytes
    ///   - creator: Creator of group
    ///   - force: If the minimum time interval should be ignored
    @objc public func sendSyncRequest(groupID: Data, creator: String, force: Bool) {
        
        let lastSyncRequestSince = Date(timeIntervalSinceNow: TimeInterval(-kGroupSyncRequestInterval))
        guard entityManager.entityFetcher.lastGroupSyncRequest(
            for: groupID,
            groupCreator: creator,
            since: lastSyncRequestSince
        ) == nil || force else {
            DDLogInfo(
                "Sync for Group ID \(groupID.hexString) (creator \(creator)) already requested in the last \(kGroupSyncRequestInterval) s."
            )
            return
        }
        
        DDLogWarn("Group ID \(groupID.hexString) (creator \(creator)) not found. Requesting sync from creator.")
        
        // Fetch creator first, contact could be missing
        contactStore.fetchPublicKey(
            for: creator,
            acquaintanceLevel: .groupOrDeleted,
            entityManager: entityManager,
            ignoreBlockUnknown: false,
            onCompletion: { _ in
                if self.entityManager.entityFetcher.contact(for: creator) != nil {
                    self.recordSendSyncRequest(GroupIdentity(id: groupID, creator: ThreemaIdentity(creator)))
                    self.sendGroupSyncRequest(groupID, creator)
                }
                else {
                    DDLogError("Could not send group request sync, because of missing group creator \(creator) contact")
                }
            }
        ) { error in
            if let error = error as? NSError {
                DDLogError("Could not fetch public key for \(creator); Error: \(error.description) \(error.code) ")
            }
            else {
                DDLogError("Could not fetch public key for \(creator)")
            }
        }
    }
    
    /// Start periodic group sync if needed
    ///
    /// Sync tasks are guaranteed to be enqueued when this function returns, except of a potential set photo message
    ///
    /// - Parameter group: Group conversation to sync
    @objc public func periodicSyncIfNeeded(for group: Group) {
        // Check if we are the creator
        guard group.isOwnGroup else {
            return
        }
        
        // Check if sync is needed
        if let lastPeriodicSync = group.lastPeriodicSync {
            let timeSinceLastSync = lastPeriodicSync.timeIntervalSinceNow
            if timeSinceLastSync > TimeInterval(-kGroupPeriodicSyncInterval) {
                // Last sync is shorter than `kGroupPeriodicSyncInterval` in the past
                return
            }
        }

        let toMembers = group.allActiveMemberIdentitiesWithoutCreator
        
        // Do these step synchronously to ensure they are enqueued before a potential outgoing
        // message leading to this call.
        // We don't care if the task execution fails eventually as the likelihood is low.
                
        guard let conversation =
            getConversation(for: GroupIdentity(id: group.groupID, creator: group.groupIdentity.creator))
        else {
            DDLogWarn("Coversation not found")
            return
        }

        // 5. Send a group-setup message with the current group members, ...
        let createTask = createGroupCreateSyncTask(for: group, conversation: conversation, to: toMembers)
        taskManager.add(taskDefinition: createTask)

        // ...followed by a group-name message to the sender.
        let sendNameTask = createGroupRenameTask(for: group, to: toMembers)
        taskManager.add(taskDefinition: sendNameTask)

        // 7. If the group has no profile picture, send a `delete-profile-picture` group control message to the sender.
        if group.old_ProfilePicture == nil {
            let deletePhotoTask = createDeletePhotoTask(for: group, to: toMembers)
            taskManager.add(taskDefinition: deletePhotoTask)
        }
                
        entityManager.performAndWaitSave {
            if let groupEntity = self.entityManager.entityFetcher.groupEntity(
                for: group.groupID,
                with: group.groupCreatorIdentity != self.myIdentityStore.identity ? group
                    .groupCreatorIdentity : nil
            ) {
                groupEntity.lastPeriodicSync = Date()
            }
        }
        
        // As sending a profile picture might take a while to upload we do it asynchronously and
        // don't guarantee it to be sent out before the a group message is sent
        
        // 6. If the group has a profile picture, send a `set-profile-picture` group control message to the sender.
        if let profilePicture = group.old_ProfilePicture {
            Task {
                do {
                    try await self.sendPhoto(to: group, imageData: profilePicture, toMembers: toMembers)
                }
                catch {
                    // Note: This might never be called if the task was persisted at some point in
                    // the meantime
                    DDLogError("Periodic group sync photo sending failed: \(error)")
                    // Reset last periodic sync date if photo sending failed
                    await self.entityManager.performSave {
                        if let groupEntity = self.entityManager.entityFetcher.groupEntity(
                            for: group.groupID,
                            with: group.groupCreatorIdentity != self.myIdentityStore.identity ? group
                                .groupCreatorIdentity : nil
                        ) {
                            groupEntity.lastPeriodicSync = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Get group / conversation

    public func getConversation(for groupIdentity: GroupIdentity) -> Conversation? {
        entityManager.entityFetcher.conversation(for: groupIdentity.id, creator: groupIdentity.creator.string)
    }

    /// Loads group, conversation and LastGroupSyncRequest from DB.
    ///
    /// - Parameters:
    ///   - groupID: ID 8 Bytes
    ///   - creator: Creator of group
    /// - Returns: The group or nil
    @objc public func getGroup(_ groupID: Data, creator: String) -> Group? {
        var group: Group?

        entityManager.performAndWait {
            guard let conversation = self.entityManager.entityFetcher.conversation(
                for: groupID,
                creator: creator
            ) else {
                return
            }
            guard let groupEntity = self.entityManager.entityFetcher.groupEntity(for: conversation) else {
                return
            }
            group = self.getGroup(groupEntity: groupEntity, conversation: conversation)
        }

        return group
    }
    
    /// Loads group for conversation.
    ///
    /// - Parameter conversation: Conversation for group
    /// - Returns: The group or nil
    @objc public func getGroup(conversation: Conversation) -> Group? {
        var group: Group?

        entityManager.performAndWait {
            guard let groupEntity = self.entityManager.entityFetcher.groupEntity(for: conversation) else {
                return
            }
            group = self.getGroup(groupEntity: groupEntity, conversation: conversation)
        }

        return group
    }
    
    public func getAllActiveGroups() async -> [Group] {
        await entityManager.perform {
            let allActiveGroupEntities = self.entityManager.entityFetcher.allActiveGroups()
            
            return allActiveGroupEntities.compactMap { groupEntity in
                // Because the entity fetcher for group conversations needs a creator identity we set them to our own
                // identity. If our ID changed in the meantime (e.g. through a restore were the data is restored, but a
                // new ID created) we will still fetch the correct group, that we're not really part of anymore, but
                // might be still marked as active...
                
                guard let creatorIdentity = groupEntity.groupCreator ?? self.myIdentityStore.identity else {
                    return nil
                }
            
                guard let conversation = self.entityManager.entityFetcher.conversation(
                    for: groupEntity.groupID,
                    creator: creatorIdentity
                ) else {
                    return nil
                }
                
                return self.getGroup(groupEntity: groupEntity, conversation: conversation)
            }
        }
    }

    private func getGroup(groupEntity: GroupEntity, conversation: Conversation) -> Group {
        let creator: String = groupEntity.groupCreator ?? myIdentityStore.identity

        let lastSyncRequestSince = Date(timeIntervalSinceNow: TimeInterval(-kGroupSyncRequestInterval))
        let lastSyncRequest = entityManager.entityFetcher.lastGroupSyncRequest(
            for: groupEntity.groupID,
            groupCreator: creator,
            since: lastSyncRequestSince
        )

        return Group(
            myIdentityStore: myIdentityStore,
            userSettings: userSettings,
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: lastSyncRequest?.lastSyncRequest
        )
    }
    
    /// Get all members of existing group except me. It will remove the hidden flag for all members.
    ///
    /// - Parameters:
    ///   - groupID: ID 8 Bytes
    ///   - creator: Creator of group
    /// - Returns: Members of the group
    @objc func getGroupMembersForClone(_ groupID: Data, creator: String) -> Set<ContactEntity>? {
        guard let conversation =
            getConversation(for: GroupIdentity(id: groupID, creator: ThreemaIdentity(creator))) else {
            DDLogError("Group conversation not found")
            return nil
        }
                
        // Mark all contacts as visible
        removeContactHiddenFlags(for: conversation)

        return conversation.members.filter { member -> Bool in
            !member.identity.elementsEqual(myIdentityStore.identity)
        }
    }
    
    // MARK: - Private functions
    
    private func postSystemMessage(in conversation: Conversation, member: ContactEntity, type: Int, date: Date) {
        postSystemMessage(in: conversation, type: type, arg: Data(member.displayName.utf8), date: date)
    }
    
    private func postSystemMessage(in conversation: Conversation, type: Int, arg: Data?, date: Date) {
        entityManager.performAndWaitSave {
            // Insert system message to document this change
            let sysMsg = self.entityManager.entityCreator.systemMessage(for: conversation)
            sysMsg?.type = NSNumber(integerLiteral: type)
            sysMsg?.arg = arg
            sysMsg?.remoteSentDate = date
            conversation.lastMessage = sysMsg
        }
    }
    
    // MARK: Sync
    
    private func sync(
        group: Group,
        to toMembers: [String],
        withoutCreateMessage: Bool
    ) async throws {
        /// Sync group if `toMembers` empty to reflect note groups if multi device activated.
        guard !(toMembers.isEmpty && !userSettings.enableMultiDevice) else {
            return
        }

        // Prepare sync tasks
    
        func runGroupCreateTask() async throws {
            guard !withoutCreateMessage else {
                return
            }
            
            guard let conversation =
                getConversation(for: GroupIdentity(id: group.groupID, creator: group.groupIdentity.creator))
            else {
                throw GroupError.groupConversationNotFound
            }

            // 5. Send a group-setup message with the current group members, ...
            let task = createGroupCreateSyncTask(for: group, conversation: conversation, to: toMembers)
            try await add(task: task)
        }
        
        // ...followed by a group-name message to the sender.
        func runGroupNameTask() async throws {
            let task = createGroupRenameTask(for: group, to: toMembers)
            try await add(task: task)
        }
        
        func runGroupPhotoTask() async throws {
            var profilePicture: Data?
            await entityManager.perform {
                profilePicture = group.old_ProfilePicture
            }

            guard let data = profilePicture else {
                // 7. If the group has no profile picture, send a `delete-profile-picture` group
                // control message to the sender.
                let task = createDeletePhotoTask(for: group, to: toMembers)
                try await add(task: task)
                return
            }
            
            // 6. If the group has a profile picture, send a `set-profile-picture` group control
            // message to the sender.
            try await sendPhoto(to: group, imageData: data, toMembers: toMembers)
        }
        
        try await runGroupCreateTask()
        try await runGroupNameTask()
        try await runGroupPhotoTask()
    }
    
    private func syncToRemovedMembers(
        group: Group,
        to removedMembers: [String]
    ) async throws {
        guard !removedMembers.isEmpty else {
            return
        }
        guard let conversation =
            getConversation(for: GroupIdentity(id: group.groupID, creator: group.groupIdentity.creator))
        else {
            return
        }
        
        let members = Set(conversation.members.map(\.identity))
        let emptyCreateTask = TaskDefinitionSendGroupCreateMessage(
            group: group,
            to: [],
            removed: removedMembers,
            members: members
        )
        
        try await add(task: emptyCreateTask)
    }
    
    private func sendPhoto(
        to group: Group,
        imageData: Data,
        toMembers: [String]
    ) async throws {
        guard group.isOwnGroup else {
            throw GroupError.notCreator
        }

        // Core Data concurrency problem, store group infos for reloading group
        let groupID = group.groupID
        let groupCreatorIdentity = group.groupCreatorIdentity
        
        let task: TaskDefinitionSendGroupSetPhotoMessage = try await withCheckedThrowingContinuation { continuation in
            groupPhotoSender.start(
                withImageData: imageData,
                isNoteGroup: group.isNoteGroup
            ) { blobID, encryptionKey in
                guard let blobID, let encryptionKey else {
                    continuation.resume(throwing: GroupError.blobIDOrKeyMissing)
                    return
                }

                guard let group = self.getGroup(groupID, creator: groupCreatorIdentity) else {
                    continuation.resume(throwing: GroupError.groupNotFound)
                    return
                }

                let task = TaskDefinitionSendGroupSetPhotoMessage(
                    group: group,
                    from: self.myIdentityStore.identity,
                    to: toMembers,
                    size: UInt32(imageData.count),
                    blobID: blobID,
                    encryptionKey: encryptionKey
                )

                continuation.resume(returning: task)
            } onError: { _ in
                continuation.resume(throwing: GroupError.photoUploadFailed)
            }
        }

        try await add(task: task)
    }
        
    private func createGroupCreateSyncTask(
        for group: Group,
        conversation: Conversation,
        to toMembers: [String]
    ) -> TaskDefinitionSendGroupCreateMessage {
        let members = entityManager.performAndWait {
            Set(conversation.members.map(\.identity))
        }
        
        return TaskDefinitionSendGroupCreateMessage(
            group: group,
            to: toMembers,
            members: members
        )
    }
    
    private func createGroupRenameTask(
        for group: Group,
        to toMembers: [String]
    ) -> TaskDefinitionSendGroupRenameMessage {
        TaskDefinitionSendGroupRenameMessage(
            group: group,
            from: myIdentityStore.identity,
            to: toMembers,
            newName: group.name
        )
    }
    
    private func createDeletePhotoTask(
        for group: Group,
        to toMembers: [String]
    ) -> TaskDefinitionSendGroupDeletePhotoMessage {
        TaskDefinitionSendGroupDeletePhotoMessage(
            group: group,
            from: myIdentityStore.identity,
            to: toMembers,
            sendContactProfilePicture: false
        )
    }
    
    private func add(task: TaskDefinitionProtocol) async throws {
        // swiftformat:disable:next all
        return try await withCheckedThrowingContinuation { continuation in
            taskManager.add(taskDefinition: task) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume()
            }
        }
    }
    
    private func recordSendSyncRequest(_ groupIdentity: GroupIdentity) {
        entityManager.performAndWaitSave {
            // Record this sync request
            let lastSyncRequest: LastGroupSyncRequest = self.entityManager.entityCreator.lastGroupSyncRequest()
            lastSyncRequest.groupID = groupIdentity.id
            lastSyncRequest.groupCreator = groupIdentity.creator.string
            lastSyncRequest.lastSyncRequest = Date()
        }
    }
    
    /// Caution: Use this only for testing!
    @objc public func deleteAllSyncRequestRecords() {
        if let entities = entityManager.entityFetcher.allLastGroupSyncRequests() {
            for entity in entities {
                if let entity = entity as? LastGroupSyncRequest {
                    entityManager.entityDestroyer.delete(lastGroupSyncRequest: entity)
                }
            }
        }
    }
    
    private func sendGroupSyncRequest(_ groupID: Data, _ creator: String) {
        let msg = GroupRequestSyncMessage()
        msg.groupID = groupID
        msg.groupCreator = creator
        msg.toIdentity = creator
        
        let task = TaskDefinitionSendAbstractMessage(message: msg)
        taskManager.add(taskDefinition: task)
    }
    
    private func removeContactHiddenFlags(for conversation: Conversation) {
        // Get all hidden contacts and mark them as visible
        let hiddenMembers = conversation.members.filter { member -> Bool in
            !member.identity.elementsEqual(myIdentityStore.identity)
                && member.isContactHidden
        }
        
        if !hiddenMembers.isEmpty {
            entityManager.performSyncBlockAndSafe {
                for member in hiddenMembers {
                    member.isContactHidden = false
                }
            }
        }
    }

    // MARK: Rejected Messages Refresh Steps

    /// Implementation of `Rejected Messages Refresh Steps`
    ///
    /// From the protocol documentation:
    /// > [...] run every time the group members are being updated
    ///
    /// - Parameter group: Group to run Rejected Messages Refresh Steps on
    private func refreshRejectedMessages(in group: Group) {
        // 2. If `group` is marked as _left_:
        if group.state == .left || group.state == .forcedLeft {
            resetAllRejectedMessages(in: group)
        }
        // 3. If `group` is not marked as _left_:
        else {
            updateAllRejectedMessages(in: group)
        }
    }
    
    /// Don't call this directly. Use `refreshRejectedMessages(in:)` instead
    private func resetAllRejectedMessages(in group: Group) {
        //    1. For each `message` of `group` that has a _re-send requested_ mark,
        //       remove the mark and the list of receivers requiring a re-send.
        entityManager.performAndWaitSave {
            let messageFetcher = MessageFetcher(for: group.conversation, with: self.entityManager)
            let allRejectedMessages = messageFetcher.rejectedGroupMessages()
            
            for rejectedMessage in allRejectedMessages {
                rejectedMessage.rejectedBy = Set()
                // We only reset `sendFailed` if the message was sent successfully before. As `sendFailed` might not
                // have been set because of rejections. In theory this should never happen as an unsent message should
                // never have been rejected.
                if rejectedMessage.sent?.boolValue ?? false {
                    rejectedMessage.sendFailed = false
                }
            }
        }
    }
    
    /// Don't call this directly. Use `refreshRejectedMessages(in:)` instead
    private func updateAllRejectedMessages(in group: Group) {
        
        entityManager.performAndWaitSave {
            //    1. Let `members` be the current list of members for `group`.
            let members = group.members.map(\.identity)
            
            //    2. For each `message` of `group` that has a _re-send requested_ mark:
            let messageFetcher = MessageFetcher(for: group.conversation, with: self.entityManager)
            let allRejectedMessages = messageFetcher.rejectedGroupMessages()
            for rejectedMessage in allRejectedMessages {
                self.updateRejectedMessage(rejectedMessage, with: members)
            }
        }
    }
    
    private func updateRejectedMessage(_ rejectedMessage: BaseMessage, with groupMembers: [ThreemaIdentity]) {
        
        //       1. Let `receivers` be the list of receivers requiring a re-send for
        //          `message`.
        
        guard let rejectedByContactsList = rejectedMessage.rejectedBy?.map({
            ThreemaIdentity($0.identity)
        }) else {
            return
        }
        let rejectedByContacts = Set(rejectedByContactsList)

        //       2. Remove all entries from `receivers` that are not present in
        //          `members`.
        
        let contactsToRemove = rejectedByContacts.subtracting(groupMembers)
        for contactToRemove in contactsToRemove {
            guard let contact = entityManager.entityFetcher.contact(for: contactToRemove.string) else {
                continue
            }
            rejectedMessage.removeRejectedBy(contact)
        }
        
        //       3. If `receivers` is now empty, remove the _re-send requested_ mark on
        //          `message`.
        
        // We only reset `sendFailed` if the message was sent successfully before. As `sendFailed` might not
        // have been set because of rejections. In theory this should never happen as an unsent message should
        // never have been rejected.
        if rejectedMessage.rejectedBy?.isEmpty ?? true, rejectedMessage.sent?.boolValue ?? false {
            rejectedMessage.sendFailed = false
        }
    }
}
