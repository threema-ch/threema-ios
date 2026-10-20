import libthreemaSwift
import ThreemaEssentials

enum GroupProviderError: Error {
    case loadGroupEntitiesFailed
    case loadUIImageFailed
}

final class GroupProvider: libthreemaSwift.GroupProvider {
    private let userIdentity: ThreemaIdentity
    private nonisolated(unsafe) let pushSettingManager: any PushSettingManagerProtocol
    private nonisolated(unsafe) let entityManager: EntityManager

    init(
        userIdentity: ThreemaIdentity,
        pushSettingManager: any PushSettingManagerProtocol,
        entityManager: EntityManager
    ) {
        self.userIdentity = userIdentity
        self.pushSettingManager = pushSettingManager
        self.entityManager = entityManager
    }

    func isPartOfAnyGroup(
        identity: LibthreemaThreemaID,
        filter: libthreemaSwift.GroupMembershipFilter
    ) throws -> Bool {
        // 1. If identity is the user’s Threema ID, return ProviderError::InvalidParameter.
        try userIdentity.throwIsEqual(to: identity)

        // 2. Return whether identity is part¹ of a group matching filter (see GroupMembershipFilter for more details).
        return switch filter {
        case .any:
            entityManager.performAndWait {
                self.entityManager.entityFetcher.allGroupEntities()?.count ?? 0 > 0
            }
        case .onlyActive:
            entityManager.performAndWait {
                self.entityManager.entityFetcher.activeGroupEntities()?.count ?? 0 > 0
            }
        }
    }
    
    func get(identity: LibthreemaGroupIdentity) throws -> libthreemaSwift.Group? {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func getIdentities() throws -> Set<LibthreemaGroupIdentity> {
        try entityManager.performAndWait {
            guard let groupEntities = self.entityManager.entityFetcher.allGroupEntities() else {
                throw GroupProviderError.loadGroupEntitiesFailed
            }

            return try Set(groupEntities.map {
                try LibthreemaGroupIdentity(
                    // swiftformat:disable:next acronyms
                    groupId: $0.groupID.littleEndian(),
                    creatorIdentity: LibthreemaThreemaID($0.groupCreator ?? self.userIdentity.rawValue)
                )
            })
        }
    }
    
    func getWithProfilePicture(identity: LibthreemaGroupIdentity) throws -> libthreemaSwift.GroupWithProfilePicture? {
        try entityManager.performAndWait {
            guard let groupEntity = self.entityManager.entityFetcher.groupEntity(
                for: GroupIdentity(libthreemaGroupIdentity: identity),
                myIdentity: self.userIdentity.rawValue
            ) else {
                return nil
            }

            let conversationEntity = self.entityManager.entityFetcher.conversationEntity(
                for: GroupIdentity(libthreemaGroupIdentity: identity),
                myIdentity: self.userIdentity.rawValue
            )

            let libthreemaGroup = try LibthreemaGroup(
                groupEntity: groupEntity,
                conversationEntity: conversationEntity,
                userIdentity: self.userIdentity,
                pushSettingManager: self.pushSettingManager
            )

            let profilePicture: ProfilePicture? =
                if let imageData = conversationEntity?.groupImage?.data {
                    ProfilePicture(mediaType: .jpeg, data: imageData)
                }
                else {
                    nil
                }

            return libthreemaSwift.GroupWithProfilePicture(
                group: libthreemaGroup,
                profilePicture: profilePicture
            )
        }
    }
    
    func has(identity: LibthreemaGroupIdentity) throws -> Bool {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func addWithProfilePicture(groups: [libthreemaSwift.GroupWithProfilePicture]) throws {
        do {
            try entityManager.performAndWaitSave {
                // 1. For each group of groups:
                for groupWithProfilePicture in groups {
                    let group = groupWithProfilePicture.group
                    let groupIdentity = GroupIdentity(libthreemaGroupIdentity: group.identity)

                    // 1. If a group with group identity group.identity already exists, return
                    // ProviderError::InvalidState.¹
                    guard self.entityManager.entityFetcher.groupEntity(
                        for: groupIdentity,
                        myIdentity: self.userIdentity.rawValue
                    ) == nil else {
                        throw ProviderError.ContractViolation("Group already exists")
                    }

                    var creator: ContactEntity?

                    // 2. If the group.creator is neither the user, nor a known contact², return
                    // ProviderError::InvalidState.
                    if group.identity.creatorIdentity != self.userIdentity.rawValue {
                        guard let contactEntity = self.entityManager.entityFetcher.contactEntity(
                            for: group.identity.creatorIdentity
                        ) else {
                            throw ProviderError.ContractViolation("Unknown group creator")
                        }

                        creator = contactEntity
                    }

                    // 3. For each member of group.members:
                    //  1. If member is the user’s identity, return ProviderError::InvalidState.
                    //  2. If member is not a known contact², return ProviderError::InvalidState.
                    let allContactIdentities = self.entityManager.entityFetcher.contactIdentities()
                    guard group.members.allSatisfy(
                        { $0 != self.userIdentity.rawValue && allContactIdentities.contains($0) }
                    ) else {
                        throw ProviderError.ContractViolation("Not all members known contacts")
                    }

                    // 2. For each group of groups:
                    //   1. Add group to the application storage.
                    try self.insert(
                        group: group,
                        profilePicture: groupWithProfilePicture.profilePicture,
                        creator: creator
                    )
                }
            }
        }
        catch {
            entityManager.rollback()
            throw error
        }
    }
    
    func setProfilePicture(identity: libthreemaSwift.GroupIdentity, profilePicture: libthreemaSwift.ProfilePicture?) throws {
        do {
            try entityManager.performAndWaitSave {
                let groupIdentity = GroupIdentity(libthreemaGroupIdentity: identity)

                // 1. Look up the group associated to identity and let group be the result.¹
                // 2. If group is not defined, return ProviderError::InvalidState.
                guard self.entityManager.entityFetcher.groupEntity(
                    for: groupIdentity,
                    myIdentity: self.userIdentity.rawValue
                ) != nil else {
                    throw ProviderError.ContractViolation("Group not found")
                }

                guard let conversationEntity = self.entityManager.entityFetcher.conversationEntity(
                    for: groupIdentity,
                    myIdentity: self.userIdentity.rawValue
                ) else {
                    throw ProviderError.ContractViolation("Conversation for group not found")
                }

                // 3. Set the profile picture associated to group to profile_picture.²
                if let imageData = profilePicture?.data {
                    conversationEntity.groupImage = try self.imageDataEntity(for: imageData)
                }
                else {
                    conversationEntity.groupImage = nil
                }

                conversationEntity.groupImageSetDate = .now
            }
        }
        catch {
            entityManager.rollback()
            throw error
        }
    }

    func update(updates: [libthreemaSwift.GroupUpdate]) throws {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    // MARK: Private functions

    /// Insert the group into the database.
    /// - Parameters:
    ///   - group: Group definition
    ///   - profilePicture: Profile picture of the group
    ///   - creator: Contact of the group creator, if is nil the creator is the user itself
    private func insert(group: LibthreemaGroup, profilePicture: ProfilePicture?, creator: ContactEntity?) throws {
        let groupEntity = self.entityManager.entityCreator.groupEntity(
            // swiftformat:disable:next acronyms
            groupID: group.identity.groupId.littleEndianData,
            state: NSNumber(
                integerLiteral: GroupEntity.GroupState(libthreemaUserState: group.userState).rawValue
            )
        )
        let conversationEntity = self.entityManager.entityCreator.conversationEntity()
        conversationEntity.groupID = groupEntity.groupID
        conversationEntity.groupMyIdentity = self.userIdentity.rawValue

        if let creator {
            groupEntity.groupCreator = creator.identity
            conversationEntity.contact = creator
        }

        for member in group.members {
            guard let contactEntity = self.entityManager.entityFetcher.contactEntity(for: member) else {
                throw ProviderError.ContractViolation("Contact for member \(member) not found")
            }

            conversationEntity.members?.insert(contactEntity)
        }

        conversationEntity.groupName = group.name
        if let lastUpdateAt = group.lastUpdateAt {
            conversationEntity.lastUpdate = lastUpdateAt.date
        }

        conversationEntity.category = ConversationEntity.Category(group.conversationCategory)?.rawValue as? NSNumber ?? NSNumber(
            integerLiteral: ConversationEntity.Category.default.rawValue
        )

        conversationEntity.visibility = ConversationEntity.Visibility(group.conversationVisibility)?.rawValue as? NSNumber ?? NSNumber(
            integerLiteral: ConversationEntity.Visibility.default.rawValue
        )

        if let imageData = profilePicture?.data {
            conversationEntity.groupImage = try self.imageDataEntity(for: imageData)
            conversationEntity.groupImageSetDate = .now
        }
    }

    private func imageDataEntity(for imageData: Data) throws -> ImageDataEntity {
        guard let image = UIImage(data: imageData) else {
            throw GroupProviderError.loadUIImageFailed
        }

        return entityManager.entityCreator.imageDataEntity(
            data: imageData,
            size: image.size
        )
    }
}

extension ThreemaEssentials.GroupIdentity {
    init(identity: LibthreemaGroupIdentity) throws {
        try self.init(
            // swiftformat:disable:next acronyms
            id: identity.groupId.littleEndianData,
            creator: ThreemaIdentity(identity: identity.creatorIdentity)
        )
    }
}

extension libthreemaSwift.UserState {
    init(groupState: GroupEntity.GroupState) {
        self =
            switch groupState {
            case .forcedLeft: .kicked
            case .left: .left
            case .active, .requestedSync: .member
            }
    }
}

extension GroupEntity.GroupState {
    init(libthreemaUserState: libthreemaSwift.UserState) {
        self =
            switch libthreemaUserState {
            case .kicked: .forcedLeft
            case .left: .left
            case .member: .active
            }
    }
}
