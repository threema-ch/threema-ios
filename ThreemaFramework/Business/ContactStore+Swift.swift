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

import CocoaLumberjackSwift
import Foundation
import PromiseKit

extension ContactStore {

    /// Add or update given contacts as work contact and do MD sync.
    ///
    /// - Parameter batchAddContacts: Array of contacts for adding as work contact
    @objc func batchAddWorkContacts(batchAddContacts: [BatchAddWorkContact]) async throws {
        let entityManager = EntityManager(withChildContextForBackgroundProcess: true)
        let mediatorSyncableContacts = MediatorSyncableContacts(
            UserSettings.shared(),
            PushSettingManager(UserSettings.shared(), GroupManager(entityManager: entityManager), entityManager, true),
            TaskManager(),
            entityManager
        )

        let identities = await entityManager.perform {
            var identities = [String]()
            for batchAddContact in batchAddContacts {
                guard let publicKey = batchAddContact.publicKey else {
                    continue
                }

                if let contactIdentity = self.addWorkContact(
                    with: batchAddContact.identity,
                    publicKey: publicKey,
                    firstname: batchAddContact.firstName,
                    lastname: batchAddContact.lastName,
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
                    if contactEntity.workContact.boolValue != isWorkContact {
                        contactEntity.workContact = NSNumber(booleanLiteral: isWorkContact)
                        mediatorSyncableContacts.updateWorkVerificationLevel(
                            identity: contactEntity.identity,
                            value: contactEntity.workContact
                        )

                        if !isWorkContact, contactEntity.verificationLevel.intValue != kVerificationLevelFullyVerified {
                            contactEntity.verificationLevel = NSNumber(integerLiteral: kVerificationLevelUnverified)
                            mediatorSyncableContacts.updateVerificationLevel(
                                identity: contactEntity.identity,
                                value: contactEntity.verificationLevel
                            )
                        }
                    }
                }
            }
        }

        try await withCheckedThrowingContinuation { continuation in
            self.updateFeatureMasks(forIdentities: identities, contactSyncer: mediatorSyncableContacts) {
                continuation.resume()
            } onError: { error in
                continuation.resume(throwing: error)
            }
        }

        try await withCheckedThrowingContinuation { continuation in
            mediatorSyncableContacts.sync()
                .done(on: .global()) {
                    continuation.resume()
                }
                .catch { error in
                    continuation.resume(throwing: error)
                }
        }
    }
    
    /// Update the state of the contact to active and sync it with multi device if activated
    /// - Parameter contactEntity: The entity of the contact
    /// - Parameter entityManager: The EntityManager of the contactEntity
    @objc func updateStateToActive(for contactEntity: ContactEntity, entityManager: EntityManager) {
        let mediatorSyncableContacts = MediatorSyncableContacts()
        entityManager.performAndWaitSave {
            contactEntity.state = NSNumber(value: kStateActive)
            mediatorSyncableContacts.updateState(identity: contactEntity.identity, value: contactEntity.state)
        }
        mediatorSyncableContacts.syncAsync()
    }
}

extension ContactStoreProtocol {
    public func update(
        readReceipt: ReadReceipt,
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
        typingIndicator: TypingIndicator,
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
}
