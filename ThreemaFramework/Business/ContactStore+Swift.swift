import CocoaLumberjackSwift
import Foundation
import PromiseKit
import ThreemaEssentials
import ThreemaProtocols

public protocol WorkFetcherContactAdderProtocol {
    func batchAddWorkContacts(batchAddContacts: [BatchAddWorkContact], lastFullSyncAt: UInt64?) async throws
}

// MARK: - ContactStore + WorkFetcherContactAdderProtocol

extension ContactStore: WorkFetcherContactAdderProtocol {

    @objc func entityManager() -> EntityManager {
        persistenceManager().entityManager
    }

    @objc func backgroundEntityManager() -> EntityManager {
        persistenceManager().backgroundEntityManager
    }

    private func persistenceManager() -> PersistenceManager {
        PersistenceManager(
            appGroupID: AppGroup.groupID(),
            userDefaults: AppGroup.userDefaults(),
            remoteSecretManager: RemoteSecretProvider.remoteSecretManager
        )
    }

    /// Add or update given contacts as work contact and do MD sync.
    ///
    /// - Parameters:
    ///   - batchAddContacts: Array of contacts for adding as work contact
    ///   - lastFullSyncAt: UTC date from the work server
    public func batchAddWorkContacts(batchAddContacts: [BatchAddWorkContact], lastFullSyncAt: UInt64?) async throws {
        let entityManager = backgroundEntityManager()
        let mediatorSyncableContacts = MediatorSyncableContacts(
            userSettings: UserSettings.shared(),
            pushSettingManager: PushSettingManager(
                userSettings: UserSettings.shared(),
                groupManager: GroupManager(entityManager: entityManager),
                entityManager: entityManager,
                markupParser: MarkupParser(),
                taskManager: TaskManager(),
                isWorkApp: true
            ),
            taskManager: TaskManager(),
            entityManager: entityManager
        )

        let featureMasks = try await FeatureMask.getFeatureMask(for: batchAddContacts.map(\.identity))

        let identities = await withCheckedContinuation { continuation in
            syncContactsQueue.async {
                entityManager.performAndWait {
                    var identities = [String]()
                    for batchAddContact in batchAddContacts {
                        guard let publicKey = batchAddContact.publicKey,
                              let featureMask = featureMasks[batchAddContact.identity] else {
                            continue
                        }

                        if let contactIdentity = self.addWorkContact(
                            with: batchAddContact.identity,
                            publicKey: publicKey,
                            firstname: batchAddContact.firstName,
                            lastname: batchAddContact.lastName,
                            csi: batchAddContact.csi,
                            jobTitle: batchAddContact.jobTitle,
                            department: batchAddContact.department,
                            featureMask: NSNumber(integerLiteral: featureMask),
                            acquaintanceLevel: .direct,
                            workAvailabilityStatus: batchAddContact.availabilityStatus,
                            entityManager: entityManager,
                            contactSyncer: mediatorSyncableContacts
                        ) {
                            identities.append(contactIdentity)
                        }
                    }
                    continuation.resume(returning: identities)
                }
            }
        }

        await entityManager.performSave {
            guard let allContacts = entityManager.entityFetcher.contactEntities() else {
                return
            }
            
            for contactEntity in allContacts {
                // Get all work verified contacts from DB and set those that have not been supplied in this sync
                // back to non-work
                let isWorkContact = identities.contains(contactEntity.identity)
                if contactEntity.isWorkContact != isWorkContact {
                    contactEntity.workContact = NSNumber(booleanLiteral: isWorkContact)
                    mediatorSyncableContacts.updateWorkVerificationLevel(
                        identity: contactEntity.identity,
                        value: contactEntity.workContact
                    )
                    
                    if !isWorkContact {
                        if contactEntity.contactVerificationLevel != .fullyVerified {
                            contactEntity.contactVerificationLevel = .unverified
                            mediatorSyncableContacts.updateVerificationLevel(
                                identity: contactEntity.identity,
                                value: contactEntity.contactVerificationLevel.rawValue as NSNumber
                            )
                        }
                        
                        if let status = contactEntity.workAvailabilityStatus {
                            entityManager.entityDestroyer.delete(workAvailabilityStatus: status)
                        }
                    }
                }
                
                // Set last work sync at is a work contact otherwise is nil
                let workLastFullSyncAt: Date? = isWorkContact ? lastFullSyncAt?.date : nil
                if contactEntity.workLastFullSyncAt != workLastFullSyncAt {
                    contactEntity.workLastFullSyncAt = workLastFullSyncAt
                    mediatorSyncableContacts.updateWorkLastFullSyncAt(
                        identity: contactEntity.identity,
                        workLastFullSyncAt: workLastFullSyncAt
                    )
                }
            }
        }

        try await mediatorSyncableContacts.syncAsSubTask()
    }
    
    /// Update the state of the contact to active and sync it with multi device if activated
    /// - Parameter contactEntity: The entity of the contact
    /// - Parameter entityManager: The EntityManager of the contactEntity
    @objc func updateStateToActive(for contactEntity: ContactEntity, entityManager: EntityManager) {
        let mediatorSyncableContacts = MediatorSyncableContacts()
        entityManager.performAndWaitSave {
            contactEntity.contactState = .active
            mediatorSyncableContacts.updateState(
                identity: contactEntity.identity,
                value: contactEntity.contactState.rawValue as NSNumber
            )
        }
        mediatorSyncableContacts.syncAsync()
    }
    
    @objc func workAvailabilityStatusChanged(
        current: WorkAvailabilityStatusEntity,
        new: WorkAvailabilityStatus
    ) -> Bool {
        if current.value.intValue != new.category.rawValue {
            return true
        }
       
        // Current might be nil, and new an empty string, which is the same
        let newText: String? = new.text?.trimmingCharacters(in: .whitespacesAndNewlines) == "" ? nil : new.text
        if current.text != newText {
            return true
        }
       
        return false
    }
}

extension ContactStoreProtocol {
    public func update(
        readReceipt: ContactEntity.ReadReceipt,
        for contactEntity: ContactEntity,
        entityManager: EntityManager
    ) {
        let mediatorSyncableContacts = MediatorSyncableContacts()
        entityManager.performAndWaitSave {
            contactEntity.readReceipt = readReceipt
            mediatorSyncableContacts.updateReadReceipt(identity: contactEntity.identity, value: readReceipt)
        }
        mediatorSyncableContacts.syncAsync()
    }

    public func update(
        typingIndicator: ContactEntity.TypingIndicator,
        for contactEntity: ContactEntity,
        entityManager: EntityManager
    ) {
        let mediatorSyncableContacts = MediatorSyncableContacts()
        entityManager.performAndWaitSave {
            contactEntity.typingIndicator = typingIndicator
            mediatorSyncableContacts.updateTypingIndicator(identity: contactEntity.identity, value: typingIndicator)
        }
        mediatorSyncableContacts.syncAsync()
    }
        
    /// Update the acquaintance level of the contact to direct and sync it with multi device if activated
    /// - Parameters:
    ///   - identity: Identity of the contact
    ///   - entityManager: EntityManager
    /// - Returns: Business Object of Contact
    public func updateAcquaintanceLevelToDirect(
        for identity: ThreemaIdentity,
        entityManager: EntityManager
    ) -> (contact: Contact, entity: ContactEntity)? {
        entityManager.performAndWait {
            guard let contactEntity = entityManager.entityFetcher.contactEntity(for: identity.rawValue) else {
                return nil
            }

            if contactEntity.isHidden {
                let mediatorSyncableContacts = MediatorSyncableContacts()
                entityManager.performAndWaitSave {
                    contactEntity.isHidden = false
                    mediatorSyncableContacts.updateAcquaintanceLevel(
                        identity: contactEntity.identity,
                        value: NSNumber(integerLiteral: ContactAcquaintanceLevel.direct.rawValue)
                    )
                }
                mediatorSyncableContacts.syncAsync()
            }

            return (Contact(contactEntity: contactEntity), contactEntity)
        }
    }
        
    /// Async version of `updateStatus(forAllContactsIgnoreInterval:onCompletion:onError:)`
    func updateStatusForAllContacts(ignoreInterval: Bool) async throws {
        try await withCheckedThrowingContinuation { continuation in
            updateStatus(forAllContactsIgnoreInterval: ignoreInterval) {
                continuation.resume()
            } onError: { error in
                continuation.resume(throwing: error)
            }
        }
    }
    
    func resetImportStatusForAllContacts(entityManager: EntityManager) async {
        await entityManager.performSave {
            entityManager.entityFetcher.contactEntities()?.forEach { $0.contactImportStatus = .initial }
        }
    }
}
