//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import ThreemaEssentials
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
            
            let fullError: Error =
                if let error {
                    error
                }
                else {
                    FeatureMaskError.unknownError
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

    /// Get Feature Masks of given contacts from sever.
    /// - Parameter identities: Get Feature Masks for Identities
    /// - Returns: Dictionary with Identity and it's Feature Mask
    @objc static func getFeatureMask(for identities: [String]) async throws -> [String: Int] {
        guard !identities.isEmpty else {
            return [:]
        }

        return try await withCheckedThrowingContinuation { continuation in
            let serverAPIConnector = ServerAPIConnector()
            serverAPIConnector.getFeatureMasks(forIdentities: identities) { featureMasks in
                var values: [String: Int] = [:]
                if let masks = featureMasks as? [Int] {
                    var index = 0
                    for identity in identities {
                        values[identity] = masks[index]
                        index += 1
                    }
                }
                continuation.resume(returning: values)
            } onError: { error in
                continuation.resume(throwing: error!)
            }
        }
    }

    /// Gets feature mask of contacts from directory server and updates them.
    /// - Parameter identities: Identities to update Feature Mask for
    @MainActor
    public static func updateFeatureMask(for identities: [ThreemaIdentity]) async throws {
        let featureMasks = try await FeatureMask.getFeatureMask(for: identities.map(\.string))

        let mediatorSyncableContacts = MediatorSyncableContacts()
        let entityManager = EntityManager()

        await entityManager.performSave {
            for featureMask in featureMasks {
                guard featureMask.value >= 0 else {
                    continue
                }

                guard let contactEntity = entityManager.entityFetcher.contact(for: featureMask.key) else {
                    continue
                }

                let oldFeatureMask = contactEntity.featureMask

                // Always update feature mask of local contact
                contactEntity.setFeatureMask(to: featureMask.value)

                if !oldFeatureMask.isEqual(to: contactEntity.featureMask) {
                    mediatorSyncableContacts.updateFeatureMask(
                        identity: featureMask.key,
                        value: contactEntity.featureMask
                    )
                }
            }
        }

        try await mediatorSyncableContacts.sync().async()
    }

    /// Checks whether contacts support a specific feature mask, returns unsupported contacts.
    /// - Parameters:
    ///   - identities: Identities of contacts to check
    ///   - mask: Mask to use
    ///   - completion: Array of contact identities that are not supported. Is called on main thread.
    @available(*, deprecated, renamed: "check(identities:for:force:)", message: "Use from Objective-C only")
    @objc public static func check(
        identities: Set<String>,
        for mask: Int,
        completion: @escaping ([String]) -> Void
    ) {
        Task { @MainActor in
            let unsupported = await FeatureMask.check(
                identities: Set(identities.map { ThreemaIdentity($0) }),
                for: mask,
                force: false
            )

            completion(unsupported.map(\.string))
        }
    }
    
    /// Checks whether contacts support a specific feature mask, returns unsupported contacts.
    /// - Parameters:
    ///   - identities: Identities of contacts to check
    ///   - mask: Mask to use
    ///   - force: Force the update of the feature mask and sync to MD of all contacts
    /// - Returns: Array of contact identities that are not supported
    @MainActor
    public static func check(
        identities: Set<ThreemaIdentity>,
        for mask: Int,
        force: Bool = false
    ) async -> [ThreemaIdentity] {

        func filterUnsupported(identities: any Sequence<ThreemaIdentity>, for mask: Int) async -> [ThreemaIdentity] {
            let entityManager = EntityManager()
            return await entityManager.perform {
                // Load contacts to check feature mask
                var contacts: Set<ContactEntity> = []
                for identity in identities {
                    guard let contact = entityManager.entityFetcher.contact(for: identity.string) else {
                        continue
                    }
                    contacts.insert(contact)
                }

                // Get contacts has not the feature mask
                return contacts.filter {
                    (mask & $0.featureMask.intValue) == 0
                }
                .map(\.threemaIdentity)
            }
        }

        let unsupported = force ? Array(identities) : await filterUnsupported(identities: identities, for: mask)

        guard !unsupported.isEmpty else {
            return []
        }

        do {
            try await updateFeatureMask(for: unsupported)

            return await filterUnsupported(identities: unsupported, for: mask)
        }
        catch {
            DDLogError("Failed to update/sync contacts feature masks: \(error)")
        }

        return unsupported
    }
    
    /// Checks if a `Contact` supports a given `Common_CspFeatureMaskFlag`
    /// - Parameters:
    ///   - contact: `Contact` to check
    ///   - mask: `Common_CspFeatureMaskFlag` to check contact for
    /// - Returns: `true` if `contact` supports `mask`, `false` otherwise
    public static func check(contact: Contact, for mask: ThreemaProtocols.Common_CspFeatureMaskFlag) -> Bool {
        mask.rawValue & contact.featureMask != 0
    }
    
    /// Check if the receiver(s) supports given `Common_CspFeatureMaskFlag`
    ///
    /// - Parameters:
    ///   - message: Message to check
    ///   - mask: `Common_CspFeatureMaskFlag` to check receiver(s) for
    ///   - Returns: `true` if min. one receiver supports the mask, all unsupported contacts
    public static func check(
        message: BaseMessageEntity,
        for mask: ThreemaProtocols.Common_CspFeatureMaskFlag
    ) -> (isSupported: Bool, unsupported: [Contact]) {
        guard let managedObjectContext = message.managedObjectContext else {
            return (false, [Contact]())
        }

        let contactsToCheck = managedObjectContext.performAndWait {
            var contactsToCheck = [Contact]()
            if message.conversation.isGroup {
                contactsToCheck
                    .append(contentsOf: message.conversation.unwrappedMembers.map { Contact(contactEntity: $0) })
            }
            else if let contactEntity = message.conversation.contact {
                contactsToCheck.append(Contact(contactEntity: contactEntity))
            }
            return contactsToCheck
        }

        var isSupported = false
        var unsupported = [Contact]()
        for contact in contactsToCheck {
            if FeatureMask.check(contact: contact, for: mask) {
                isSupported = true
            }
            else {
                unsupported.append(contact)
            }
        }
        return (isSupported, unsupported)
    }
}
