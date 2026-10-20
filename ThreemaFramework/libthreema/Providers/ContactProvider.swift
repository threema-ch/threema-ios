import Foundation
import libthreemaSwift
import ThreemaEssentials

enum ContactProviderError: Error {
    case loadUIImageFailed
}

final class ContactProvider: libthreemaSwift.ContactProvider {
    private let userIdentity: ThreemaIdentity
    private nonisolated(unsafe) let userSettings: any UserSettingsProtocol
    private nonisolated(unsafe) let contactStore: any ContactStoreProtocol
    private nonisolated(unsafe) let pushSettingManager: any PushSettingManagerProtocol
    private nonisolated(unsafe) let entityManager: EntityManager

    init(
        userIdentity: ThreemaIdentity,
        userSettings: any UserSettingsProtocol,
        contactStore: any ContactStoreProtocol,
        pushSettingManager: any PushSettingManagerProtocol,
        entityManager: EntityManager
    ) {
        self.userIdentity = userIdentity
        self.userSettings = userSettings
        self.contactStore = contactStore
        self.pushSettingManager = pushSettingManager
        self.entityManager = entityManager
    }

    func isExplicitlyBlocked(identity: LibthreemaThreemaID) throws -> Bool {
        // 1. If identity is called with the user’s Threema ID, return ProviderError::InvalidParameter.
        try userIdentity.throwIsEqual(to: identity)

        // 2. Return whether identity is present in the list of explicitly blocked identities.
        return userSettings.blacklist?.contains(identity) ?? false
    }

    func has(identity: LibthreemaThreemaID) throws -> Bool {
        // 1. If identity is the user’s Threema ID, return ProviderError::InvalidParameter.
        try userIdentity.throwIsEqual(to: identity)

        // 2. Return whether a contact for identity exists.¹
        return entityManager.performAndWait {
            self.entityManager.entityFetcher.contactEntity(for: identity) != nil
        }
    }

    func countExisting(identities: [LibthreemaThreemaID]) throws -> UInt32 {
        // 1. If any identity of identities is the user’s Threema ID, return ProviderError::InvalidParameter.
        try userIdentity.throwIsContaining(identities: identities)

        // 2. Return the amount of identities a contact exists for.¹
        return try entityManager.performAndWait {
            let count = try self.entityManager.entityFetcher
                .countExisting(of: identities.map { ThreemaIdentity(libthreemaThreemaID: $0) })
            return UInt32(count)
        }
    }

    func getIdentities() throws -> Set<LibthreemaThreemaID> {
        // Return the Threema IDs of all the user’s contacts.
        entityManager.performAndWait {
            Set(self.entityManager.entityFetcher.contactIdentities().compactMap { LibthreemaThreemaID($0) })
        }
    }

    func get(identity: LibthreemaThreemaID) throws -> LibthreemaContact? {
        // 1. If identity is the user’s Threema ID, return ProviderError::InvalidParameter.
        try userIdentity.throwIsEqual(to: identity)

        // 2. Return the contact stored for identity, if any.¹
        return try entityManager.performAndWait {
            guard let contactEntity = self.entityManager.entityFetcher.contactEntity(for: identity) else {
                return nil
            }
            let conversationEntity = self.entityManager.entityFetcher.conversationEntity(for: identity)

            return try LibthreemaContact(
                contactEntity: contactEntity,
                conversationEntity: conversationEntity,
                userSettings: self.userSettings,
                pushSettingManager: self.pushSettingManager
            )
        }
    }

    func add(contacts: [LibthreemaContact]) throws {
        // 1. If any identity of contacts is the user’s Threema ID, return ProviderError::InvalidParameter.
        try userIdentity.throwIsContaining(contacts: contacts)

        // 2. If any contact for contacts exists, return ProviderError::InvalidState.¹
        let contactIdentities = entityManager.entityFetcher.contactIdentities()

        guard !contacts.map(\.identity).contains(where: {
            contactIdentities.contains($0)
        }) else {
            throw ProviderError.ContractViolation("Some contacts are already existing")
        }

        do {
            // 3. Add each contact of contacts.
            try entityManager.performAndWait {
                for contact in contacts {
                    try self.add(contact: contact)
                }
            }

            try entityManager.save()
        }
        catch {
            entityManager.rollback()
            throw error
        }
    }

    func getWithProfilePictures(identity: LibthreemaThreemaID) throws -> ContactWithProfilePictures? {
        // 1. If identity is the user’s Threema ID, return ProviderError::InvalidParameter.
        try userIdentity.throwIsEqual(to: identity)

        // 2. Return the contact with its profile picture(s) stored for identity, if any.¹
        return try entityManager.performAndWait {
            guard let contactEntity = self.entityManager.entityFetcher.contactEntity(for: identity) else {
                return nil
            }

            let conversationEntity = self.entityManager.entityFetcher.conversationEntity(for: identity)

            let contactDefinedProfilePicture: ProfilePicture? =
                if let contactImage = contactEntity.contactImage {
                    ProfilePicture(mediaType: .jpeg, data: contactImage.data)
                }
                else {
                    nil
                }

            let userDefinedProfilePicture: ProfilePicture? =
                if let imageData = contactEntity.imageData {
                    ProfilePicture(mediaType: .jpeg, data: imageData)
                }
                else {
                    nil
                }

            return try ContactWithProfilePictures(
                contact: LibthreemaContact(
                    contactEntity: contactEntity,
                    conversationEntity: conversationEntity,
                    userSettings: self.userSettings,
                    pushSettingManager: self.pushSettingManager
                ),
                contactDefinedProfilePicture: contactDefinedProfilePicture,
                userDefinedProfilePicture: userDefinedProfilePicture
            )
        }
    }

    func addWithProfilePictures(contacts: [libthreemaSwift.ContactWithProfilePictures]) throws {
        // 1. If any identity of contacts is the user’s Threema ID, return ProviderError::InvalidParameter.
        try userIdentity.throwIsContaining(contacts: contacts.map(\.contact))

        // 2. If any contact for contacts exists, return ProviderError::InvalidState.¹
        let contactIdentities = entityManager.entityFetcher.contactIdentities()

        guard !contacts.map(\.contact).map(\.identity).contains(where: {
            contactIdentities.contains($0)
        }) else {
            throw ProviderError.ContractViolation("Some contacts are already existing")
        }

        do {
            try entityManager.performAndWait {
                // 3. Add each contact of contacts.
                for contact in contacts {
                    try self.add(
                        contact: contact.contact,
                        contactDefinedProfilePicture: contact.contactDefinedProfilePicture,
                        userDefinedProfilePicture: contact.userDefinedProfilePicture
                    )
                }
            }

            try entityManager.save()
        }
        catch {
            entityManager.rollback()
            throw error
        }
    }

    func update(updates contacts: [libthreemaSwift.ContactUpdate]) throws {
        // 1. If any identity of contacts is the user’s Threema ID, return ProviderError::InvalidParameter.
        try userIdentity.throwIsContaining(identities: contacts.map(\.identity))

        do {
            // 3. Update each contact of contacts.
            try entityManager.performAndWait {
                for contact in contacts {
                    // 2. If any contact for contacts does not exist, return ProviderError::InvalidState.¹
                    guard let contactEntity = self.entityManager.entityFetcher
                        .contactEntity(for: contact.identity) else {
                        throw ProviderError.ContractViolation("Contact \(contact.identity) not exists")
                    }

                    try contactEntity.update(with: contact, sortOrderFirstName: self.userSettings.sortOrderFirstName)

                    if let conversationEntity = self.entityManager.entityFetcher
                        .conversationEntity(for: contact.identity) {
                        try conversationEntity.update(with: contact)
                    }
                    else {
                        if contact.conversationCategory != .default || contact.conversationVisibility != .normal {
                            let conversationEntity = self.entityManager.entityCreator.conversationEntity()
                            conversationEntity.contact = contactEntity
                            try conversationEntity.update(with: contact)
                        }
                    }

                    if contact.identityType == .work {
                        // TODO: (IOS-6086) Backup Compatibility: Migrate `contactStore.addAsWork(...` setting into the DB
                        self.contactStore.addAsWork(identities: [contact.identity], contactSyncer: nil)
                    }

                    // TODO: (IOS-6087) Backup Compatibility: Migrate push setting into the DB
                    Task {
                        var pushSetting = self.pushSettingManager
                            .find(forContact: ThreemaIdentity(libthreemaThreemaID: contact.identity))
                        pushSetting.update(with: contact)
                        await self.pushSettingManager.save(pushSetting: pushSetting, sync: false)
                    }
                }
            }

            try entityManager.save()
        }
        catch {
            entityManager.rollback()
            throw error
        }
    }

    func setContactDefinedProfilePicture(
        identity: LibthreemaThreemaID,
        profilePicture: libthreemaSwift.ProfilePicture?
    ) throws {
        // 1. If identity is the user’s Threema ID, return ProviderError::InvalidParameter.
        try userIdentity.throwIsEqual(to: identity)

        try entityManager.performAndWait {
            do {
                // 2. Look up the contact associated to identity and let contact be the result.¹
                guard let contactEntity = self.entityManager.entityFetcher.contactEntity(for: identity) else {
                    // 3. If contact is not defined, return ProviderError::InvalidState.
                    throw ProviderError.ContractViolation("Contact not found for identity")
                }

                // 4. Set the contact-defined profile picture associated to contact to profile_picture.²
                if let profilePicture {
                    guard let image = UIImage(data: profilePicture.data) else {
                        throw ContactProviderError.loadUIImageFailed
                    }
                    let imageDataEntity = self.entityManager.entityCreator.imageDataEntity(
                        data: profilePicture.data,
                        size: image.size
                    )
                    contactEntity.contactImage = imageDataEntity
                }
                else {
                    if let imageDataEntity = contactEntity.contactImage {
                        // ²: None signals to remove the profile picture.
                        self.entityManager.entityDestroyer.delete(imageDataEntity: imageDataEntity)
                        contactEntity.contactImage = nil
                    }
                }

                try self.entityManager.save()
            }
            catch {
                self.entityManager.rollback()
                throw error
            }
        }
    }

    func setUserDefinedProfilePicture(
        identity: LibthreemaThreemaID,
        profilePicture: libthreemaSwift.ProfilePicture?
    ) throws {
        // 1. If identity is the user’s Threema ID, return ProviderError::InvalidParameter.
        try userIdentity.throwIsEqual(to: identity)

        try entityManager.performAndWait {
            do {
                // 2. Look up the contact associated to identity and let contact be the result.¹
                guard let contactEntity = self.entityManager.entityFetcher.contactEntity(for: identity) else {
                    // 3. If contact is not defined, return ProviderError::InvalidState.
                    throw ProviderError.ContractViolation("Contact not found for identity")
                }

                // 4. Set the user-defined profile picture associated to contact to profile_picture.²
                if let profilePicture {
                    contactEntity.imageData = profilePicture.data
                }
                else {
                    if contactEntity.imageData != nil {
                        contactEntity.imageData = nil
                    }
                }

                try self.entityManager.save()
            }
            catch {
                self.entityManager.rollback()
                throw error
            }
        }
    }

    // MARK: - Private functions

    private func add(
        contact: LibthreemaContact,
        contactDefinedProfilePicture: ProfilePicture? = nil,
        userDefinedProfilePicture: ProfilePicture? = nil
    ) throws {
        let contactEntity = self.entityManager.entityCreator.contactEntity(
            identity: contact.identity,
            publicKey: contact.publicKey,
            sortOrderFirstName: self.userSettings.sortOrderFirstName
        )

        try contactEntity.update(with: contact, sortOrderFirstName: self.userSettings.sortOrderFirstName)

        if contact.lastUpdateAt != nil ||
            contact.conversationCategory != .default ||
            contact.conversationVisibility != .normal {

            let conversationEntity = self.entityManager.entityCreator
                .conversationEntity(setLastUpdate: false)
            conversationEntity.contact = contactEntity
            try conversationEntity.update(with: contact)
        }

        // Update the work identities and the push setting
        if contact.identityType == .work {
            // TODO: (IOS-6086) Backup Compatibility: Migrate `contactStore.addAsWork(...` setting into the DB
            self.contactStore.addAsWork(identities: [contact.identity], contactSyncer: nil)
        }

        // TODO: (IOS-6087) Backup Compatibility: Migrate push setting into the DB
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            var pushSetting = self.pushSettingManager
                .find(forContact: ThreemaIdentity(libthreemaThreemaID: contact.identity))
            pushSetting.update(with: contact)
            await self.pushSettingManager.save(pushSetting: pushSetting, sync: false)

            semaphore.signal()
        }

        semaphore.wait()

        if let imageData = contactDefinedProfilePicture?.data {
            guard let image = UIImage(data: imageData) else {
                throw ContactProviderError.loadUIImageFailed
            }

            contactEntity.contactImage = entityManager.entityCreator.imageDataEntity(data: imageData, size: image.size)
        }

        if let imageData = userDefinedProfilePicture?.data {
            contactEntity.imageData = imageData
        }
    }
}
