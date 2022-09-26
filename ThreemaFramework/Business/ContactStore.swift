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

import CocoaLumberjackSwift
import Foundation

extension ContactStore {
    @objc func batchAddWorkContacts(batchAddContacts: [BatchAddWorkContact]) {
        let mediatorSyncableContacts = MediatorSyncableContacts()

        let entityManager = EntityManager(withChildContextForBackgroundProcess: true)
        entityManager.performSyncBlockAndSafe {
            for batchAddContact in batchAddContacts {
                ContactStore.shared().batchAddWorkContact(
                    with: batchAddContact.identity,
                    publicKey: batchAddContact.publicKey,
                    firstname: batchAddContact.firstName,
                    lastname: batchAddContact.lastName,
                    shouldUpdateFeatureMask: false,
                    contactSyncer: mediatorSyncableContacts
                )
            }
        }

        mediatorSyncableContacts.sync()
            .catch { error in
                DDLogError("Sync contacts failed: \(error)")
            }
        
        ContactStore.shared().updateFeatureMasks(for: batchAddContacts.map(\.identity))
    }
}
