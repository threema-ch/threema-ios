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
    @objc func batchAddWorkContacts(batchAddContacts: [BatchAddWorkContact]) {
        let mediatorSyncableContacts = MediatorSyncableContacts()
        firstly { () -> Promise<EntityManager> in
            let entityManager = EntityManager(withChildContextForBackgroundProcess: true)
            return Promise { seal in seal.fulfill(entityManager) }
        }
        .then { entityManager -> Promise<[String]> in
            var identities = [String]()
            return entityManager.performAndWaitSave {
                for batchAddContact in batchAddContacts {
                    guard let publicKey = batchAddContact.publicKey else {
                        continue
                    }

                    if let contact = self.addWorkContact(
                        with: batchAddContact.identity,
                        publicKey: publicKey,
                        firstname: batchAddContact.firstName,
                        lastname: batchAddContact.lastName,
                        acquaintanceLevel: .direct,
                        entityManager: entityManager,
                        contactSyncer: mediatorSyncableContacts
                    ) {
                        identities.append(contact.identity)
                    }
                }
                return Promise { seal in seal.fulfill(identities) }
            }
        }
        .then { identities -> Promise<Void> in
            Promise { seal in
                self.updateFeatureMasks(forIdentities: identities, contactSyncer: mediatorSyncableContacts) {
                    seal.fulfill_()
                } onError: { error in
                    seal.reject(error)
                }
            }
        }
        .then { _ -> Promise<Void> in
            mediatorSyncableContacts.sync()
        }
        .catch { error in
            DDLogError("Sync contacts failed: \(error)")
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
