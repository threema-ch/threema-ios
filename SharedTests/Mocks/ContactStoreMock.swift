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
import ThreemaFramework

class ContactStoreMock: NSObject, ContactStoreProtocol {

    private let callOnCompletion: Bool
    private var contact: Contact?
    private let errorHandler: NSError?

    required init(callOnCompletion: Bool, _ contact: Contact? = nil, errorHandler: NSError? = nil) {
        self.callOnCompletion = callOnCompletion
        self.contact = contact
        self.errorHandler = errorHandler
    }
    
    override convenience init() {
        self.init(callOnCompletion: false)
    }
    
    func contact(for identity: String?) -> Contact? {
        contact?.identity == identity ? contact : nil
    }
    
    func prefetchIdentityInfo(_ identities: Set<String>, onCompletion: () -> Void, onError: (Error) -> Void) {
        if callOnCompletion {
            onCompletion()
        }
    }
    
    func fetchWorkIdentities(
        inBlockUnknownCheck identities: [Any],
        onCompletion: @escaping ([Any]) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        if callOnCompletion {
            onCompletion([])
        }
    }
    
    func fetchPublicKey(
        for identity: String,
        onCompletion: @escaping (Data) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        if callOnCompletion {
            onCompletion(Data())
        }
    }

    func fetchPublicKey(
        for identity: String?,
        entityManager entityManagerObject: NSObject,
        onCompletion: @escaping (Data?) -> Void,
        onError: ((Error?) -> Void)? = nil
    ) {
        if let errorHandler = errorHandler, let onError = onError {
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
        // no-op
    }
    
    func reflect(_ contact: Contact?) {
        // no-op
    }
    
    func reflectDeleteContact(_ identity: String?) {
        // no-op
    }
    
    func updateProfilePicture(
        _ identity: String?,
        imageData: Data,
        shouldReflect: Bool,
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
        onCompletion: @escaping (Contact?, Bool) -> Void,
        onError: ((Error) -> Void)? = nil
    ) {
        // no-op
    }

    func updateAllContactsToCNContact() {
        // no-op
    }

    func updateAllContacts() {
        // no-op
    }
}
