//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
import PromiseKit
import ThreemaEssentials

extension ContactStore {

    /// Add or update given contacts as work contact and do MD sync.
    ///
    /// - Parameter batchAddContacts: Array of contacts for adding as work contact
    @objc func batchAddWorkContacts(batchAddContacts: [BatchAddWorkContact]) async throws {
        let entityManager = EntityManager(withChildContextForBackgroundProcess: true)
        let mediatorSyncableContacts = MediatorSyncableContacts(
            UserSettings.shared(),
            PushSettingManager(
                UserSettings.shared(),
                GroupManager(entityManager: entityManager),
                entityManager,
                TaskManager(),
                true
            ),
            TaskManager(),
            entityManager
        )

        let featureMasks = try await FeatureMask.getFeatureMask(for: batchAddContacts.map(\.identity))

        let identities = await entityManager.perform {
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
                    entityManager: entityManager,
                    contactSyncer: mediatorSyncableContacts
                ) {
                    identities.append(contactIdentity)
                }
            }
            return identities
        }

        // Get all work verified contacts from DB and set those that have not been supplied in this sync back to
        // non-work
        await entityManager.performSave {
            if let allContacts = entityManager.entityFetcher.allContacts() as? [ContactEntity] {
                for contactEntity in allContacts {
                    let isWorkContact = identities.contains(contactEntity.identity)
                    if contactEntity.isWorkContact != isWorkContact {
                        contactEntity.workContact = NSNumber(booleanLiteral: isWorkContact)
                        mediatorSyncableContacts.updateWorkVerificationLevel(
                            identity: contactEntity.identity,
                            value: contactEntity.workContact
                        )

                        if !isWorkContact,
                           contactEntity.contactVerificationLevel != .fullyVerified {
                            contactEntity.contactVerificationLevel = .unverified
                            mediatorSyncableContacts.updateVerificationLevel(
                                identity: contactEntity.identity,
                                value: contactEntity.contactVerificationLevel.rawValue as NSNumber
                            )
                        }
                    }
                }
            }
        }

        try await mediatorSyncableContacts.sync().async()
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
    ///   - entityManager: EntityManager (default is BusinessInjector.ui.entityManager)
    /// - Returns: Business Object of Contact
    public func updateAcquaintanceLevelToDirect(
        for identity: ThreemaIdentity,
        entityManager: EntityManager = BusinessInjector.ui.entityManager
    ) -> Contact? {
        entityManager.performAndWait {
            guard let contactEntity = entityManager.entityFetcher.contact(for: identity.string) else {
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

            return Contact(contactEntity: contactEntity)
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
}
