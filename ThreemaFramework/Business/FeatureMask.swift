//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import ThreemaProtocols

public enum FeatureMaskError: Error {
    case unknownError
}

public class FeatureMask: NSObject, FeatureMaskProtocol {
    
    // MARK: - Local
    
    /// Updates local feature mask and sends it to server
    @objc public static func updateLocalObjc() {
        FeatureMask.updateLocal()
    }
    
    /// Updates local feature mask and sends it to server
    public static func updateLocal(completion: (() -> Void)? = nil, onError: ((Error) -> Void)? = nil) {

        guard let identityStore = MyIdentityStore.shared() else {
            DDLogError("Update local feature mask failed, identityStore was nil.")
            completion?()
            return
        }

        let defaults = AppGroup.userDefaults()
        
        let lastUpdate = defaults?.object(forKey: "LastFeatureMaskSet") as? Date ?? .distantPast
        let updateThreshold = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        
        let newMask = FeatureMaskBuilder.current().build()
        let lastMask = identityStore.lastSentFeatureMask
        
        guard updateThreshold > lastUpdate || newMask != lastMask else {
            DDLogVerbose("Local feature mask is up-to-date.")
            completion?()
            return
        }
            
        DDLogNotice("[FeatureMask] Update feature mask on Server to: new=\(newMask) old=\(lastMask)")
        let serverAPIConnector = ServerAPIConnector()
        serverAPIConnector.setFeatureMask(NSNumber(integerLiteral: newMask), for: identityStore) {
            identityStore.lastSentFeatureMask = newMask
            defaults?.set(Date.now, forKey: "LastFeatureMaskSet")
            defaults?.synchronize()
            completion?()
        } onError: { error in
            identityStore.lastSentFeatureMask = 0
            
            let fullError: Error
            if let error {
                fullError = error
            }
            else {
                fullError = FeatureMaskError.unknownError
            }
            
            if let onError {
                onError(fullError)
            }
            else {
                DDLogError("Update feature mask failed with error: \(fullError)")
                completion?()
            }
        }
    }
    
    /// Updates local feature mask and sends it to server
    ///
    /// Async version of `updateLocal(completion:)`
    public static func updateLocal() async throws {
        try await withCheckedThrowingContinuation { continuation in
            updateLocal {
                continuation.resume()
            } onError: { error in
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Contacts
    
    /// Checks if ContactEntities support a given feature mask, returns unsupported contacts.
    /// - Parameters:
    ///   - contacts: ContactEntities to check
    ///   - mask: Mask to use
    ///   - completion: Array of ContactEntities that are not supported. There is no guarantee on the queue the
    ///                 completion handler is called on. So if you access the ContactEntities again you need to
    ///                 perform the access on the right Core Data Context queue.
    @objc public static func checkObjc(
        contacts: Set<ContactEntity>,
        for mask: Int,
        completion: @escaping ([ContactEntity]) -> Void
    ) {
        FeatureMask.check(contacts: contacts, for: mask, completion: completion)
    }
    
    /// Checks if ContactEntities support a given feature mask, returns unsupported contacts.
    /// - Parameters:
    ///   - contacts: ContactEntities to check
    ///   - mask: Mask to use
    ///   - force: Force sync to MD
    ///   - completion: Array of ContactEntities that are not supported. There is no guarantee on the queue the
    ///                 completion handler is called on. So if you access the ContactEntities again you need to
    ///                 perform the access on the right Core Data Context queue.
    public static func check(
        contacts: Set<ContactEntity>,
        for mask: Int,
        force: Bool = false,
        completion: @escaping ([ContactEntity]) -> Void
    ) {
        let unsupported = force ? Array(contacts) : filterUnsupported(contacts: contacts, for: mask)
        
        guard !unsupported.isEmpty else {
            completion([])
            return
        }
        
        let mediatorSyncableContacts = MediatorSyncableContacts()
        let contactStore = ContactStore.shared()
        
        contactStore.updateFeatureMasks(forContacts: unsupported, contactSyncer: mediatorSyncableContacts) {
            mediatorSyncableContacts.syncObjc { error in
                if error == nil {
                    // Re-read feature mask
                    completion(filterUnsupported(contacts: unsupported, for: mask))
                }
                else {
                    // Always run onCompletion
                    completion(unsupported)
                }
            }
        } onError: { _ in
            // Always run onCompletion
            completion(unsupported)
        }
    }
    
    /// Checks if a `Contact` supports a given `Common_CspFeatureMaskFlag`
    /// - Parameters:
    ///   - contact: `Contact` to check
    ///   - mask: `Common_CspFeatureMaskFlag` to check contact for
    /// - Returns: `true` if `contact` supports `mask`, `false` otherwise
    public static func check(contact: Contact, for mask: ThreemaProtocols.Common_CspFeatureMaskFlag) -> Bool {
        mask.rawValue & contact.featureMask != 0
    }
    
    private static func filterUnsupported(contacts: any Sequence<ContactEntity>, for mask: Int) -> [ContactEntity] {
        contacts.filter { contact in
            // This should only be `nil` if contact is deleted
            if let managedObjectContext = contact.managedObjectContext {
                return managedObjectContext.performAndWait {
                    managedObjectContext.refresh(contact, mergeChanges: true)
                    return (mask & contact.featureMask.intValue) == 0
                }
            }
            else {
                return false
            }
        }
    }
}
