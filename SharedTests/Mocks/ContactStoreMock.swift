//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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
@testable import ThreemaFramework

class ContactStoreMock: NSObject, ContactStoreProtocol {
    private let callOnCompletion: Bool
    private var contact: ContactEntity?
    private let errorHandler: NSError?

    private(set) var numberOfSynchronizeAddressBookCalls = 0
    private(set) var numberOfUpdateStatusCalls = 0
    var deleteContactCalls = [String]()

    required init(callOnCompletion: Bool, _ contact: ContactEntity? = nil, errorHandler: NSError? = nil) {
        self.callOnCompletion = callOnCompletion
        self.contact = contact
        self.errorHandler = errorHandler
    }
    
    override convenience init() {
        self.init(callOnCompletion: false)
    }
    
    func contact(for identity: String?) -> ContactEntity? {
        contact?.identity == identity ? contact : nil
    }
    
    func prefetchIdentityInfo(_ identities: Set<String>, onCompletion: () -> Void, onError: (Error) -> Void) {
        if callOnCompletion {
            onCompletion()
        }
    }
    
    func fetchWorkIdentities(
        _ identities: [Any],
        onCompletion: @escaping ([Any]) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        if callOnCompletion {
            onCompletion([])
        }
    }
    
    func fetchPublicKey(
        for identity: String,
        acquaintanceLevel: ContactAcquaintanceLevel,
        onCompletion: @escaping (Data) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        if callOnCompletion {
            onCompletion(Data())
        }
    }

    func fetchPublicKey(
        for identity: String?,
        acquaintanceLevel: ContactAcquaintanceLevel,
        entityManager entityManagerObject: NSObject,
        ignoreBlockUnknown: Bool,
        onCompletion: @escaping (Data?) -> Void,
        onError: ((Error?) -> Void)? = nil
    ) {
        if let errorHandler, let onError {
            onError(errorHandler)
        }
        else if callOnCompletion {
            onCompletion(Data())
        }
    }

    func removeProfilePictureFlagForAllContacts() {
        // no-op
    }
    
    func removeProfilePictureRequest(_ identity: String) {
        // no-op
    }
    
    func synchronizeAddressBook(
        forceFullSync: Bool,
        ignoreMinimumInterval: Bool,
        onCompletion: ((Bool) -> Void)?,
        onError: ((Error?) -> Void)?
    ) {
        numberOfSynchronizeAddressBookCalls += 1
        
        if let errorHandler, let onError {
            onError(errorHandler)
        }
        else if callOnCompletion {
            onCompletion?(true)
        }
    }
    
    func updateFeatureMasks(
        forIdentities Identities: [String],
        onCompletion: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        if let errorHandler {
            onError(errorHandler)
        }
        else if callOnCompletion {
            onCompletion()
        }
    }
    
    func reflect(_ identity: String?) {
        // no-op
    }
    
    func reflectDeleteContact(_ identity: String?) {
        // no-op
    }
    
    func updateProfilePicture(
        _ identity: String?,
        imageData: Data,
        shouldReflect: Bool,
        blobID: Data?,
        encryptionKey: Data?,
        didFailWithError error: NSErrorPointer
    ) {
        // no-op
    }
    
    func deleteProfilePicture(_ identity: String?, shouldReflect: Bool) {
        // no-op
    }
    
    func removeProfilePictureFlag(for identity: String) {
        // no-op
    }

    func resetEntityManager() {
        // no-op
    }
    
    func addContact(
        with identity: String,
        verificationLevel: Int32,
        onCompletion: @escaping (ContactEntity?, Bool) -> Void,
        onError: ((Error) -> Void)? = nil
    ) {
        // no-op
    }

    func addAsWork(identities: NSOrderedSet, contactSyncer mediatorSyncableContacts: MediatorSyncableContacts?) {
        // no-op
    }

    func updateContact(withIdentity identity: String, avatar: Data?, firstName: String?, lastName: String?) {
        // no-op
    }
    
    func updateStatus(
        forAllContactsIgnoreInterval ignoreInterval: Bool,
        onCompletion: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        numberOfUpdateStatusCalls += 1
        
        if let errorHandler {
            onError(errorHandler)
        }
        else {
            onCompletion()
        }
    }
    
    func updateAllContactsToCNContact() {
        // no-op
    }

    func updateAllContacts() {
        // no-op
    }

    func deleteContact(identity: String, entityManagerObject: NSObject) {
        deleteContactCalls.append(identity)
    }
    
    func resetCustomReadReceipts() {
        // no-op
    }
}
