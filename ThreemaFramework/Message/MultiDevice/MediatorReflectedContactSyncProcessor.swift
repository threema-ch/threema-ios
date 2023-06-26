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

class MediatorReflectedContactSyncProcessor {

    private let frameworkInjector: FrameworkInjectorProtocol

    required init(frameworkInjector: FrameworkInjectorProtocol) {
        self.frameworkInjector = frameworkInjector
    }

    func process(contactSync: D2d_ContactSync) -> Promise<Void> {
        switch contactSync.action {
        case let .create(sync):
            return create(contact: sync.contact)
        case let .delete(sync):
            return delete(identity: sync.deleteIdentity)
        case let .update(sync):
            return update(contact: sync.contact)
        case .none:
            break
        }
        return Promise()
    }

    /// Delete contact and its settings.
    /// - Parameter identity: Contact that will be delete
    private func delete(identity: String) -> Promise<Void> {
        var internalError: Error?

        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            guard let contact = self.frameworkInjector.backgroundEntityManager.entityFetcher.contact(for: identity)
            else {
                internalError = MediatorReflectedProcessorError.contactToDeleteNotExists(identity: identity)
                return
            }

            // Check is contact not member in any active groups
            guard let conversations = self.frameworkInjector.backgroundEntityManager.entityFetcher
                .groupConversations(for: contact) as? [Conversation], conversations.filter({ conversation in
                    guard let group = self.frameworkInjector.backgroundGroupManager.getGroup(conversation: conversation)
                    else {
                        return true
                    }
                    return group.state == .active
                }).isEmpty else {
                internalError = MediatorReflectedProcessorError.contactToDeleteMemberOfGroup(identity: identity)
                return
            }

            // Remove from blacklist, if present
            if self.frameworkInjector.userSettings.blacklist.contains(identity) {
                var blacklist = Array(self.frameworkInjector.userSettings.blacklist)
                blacklist.removeAll(where: { $0 as? String == identity })
                self.frameworkInjector.userSettings.blacklist = NSOrderedSet(array: blacklist)
            }

            // Remove from profile picture receiver list
            if self.frameworkInjector.userSettings.profilePictureContactList
                .contains(where: { $0 as? String == identity }) {
                var profilePictureContactList = Array(self.frameworkInjector.userSettings.profilePictureContactList)
                profilePictureContactList
                    .removeAll(where: { $0 as? String == identity })
                self.frameworkInjector.userSettings.profilePictureContactList = profilePictureContactList
            }

            // Remove from profile picture request list
            self.frameworkInjector.contactStore.removeProfilePictureRequest(identity)

            if contact.cnContactID != nil {
                var exclusionList = Array(self.frameworkInjector.userSettings.syncExclusionList)
                exclusionList.append(identity)
                self.frameworkInjector.userSettings.syncExclusionList = exclusionList
            }

            self.frameworkInjector.backgroundEntityManager.entityDestroyer.deleteObject(object: contact)
        }

        if let internalError {
            return Promise(error: internalError)
        }
        return Promise()
    }

    private func create(contact syncContact: Sync_Contact) -> Promise<Void> {
        Promise { seal in
            guard self.frameworkInjector.backgroundEntityManager.entityFetcher
                .contact(for: syncContact.identity) == nil else {
                seal
                    .reject(
                        MediatorReflectedProcessorError
                            .contactToCreateAlreadyExists(identity: syncContact.identity)
                    )
                return
            }

            guard syncContact.hasPublicKey else {
                seal.reject(
                    MediatorReflectedProcessorError
                        .missingPublicKey(identity: syncContact.identity)
                )
                return
            }

            frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                guard let contact = self.frameworkInjector.backgroundEntityManager.entityCreator.contact() else {
                    seal.reject(MediatorReflectedProcessorError.createContactFailed(identity: syncContact.identity))
                    return
                }

                // Mandatory fields
                contact.identity = syncContact.identity
                contact.publicKey = syncContact.publicKey
                contact.verificationLevel = NSNumber(integerLiteral: Int(kVerificationLevelUnverified))
            }

            self.update(with: syncContact)
                .done {
                    seal.fulfill_()
                }
                .catch { error in
                    seal.reject(error)
                }
        }
    }

    private func update(contact syncContact: Sync_Contact) -> Promise<Void> {
        Promise { seal in
            frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                guard self.frameworkInjector.backgroundEntityManager.entityFetcher
                    .contact(for: syncContact.identity) != nil else {
                    seal
                        .reject(
                            MediatorReflectedProcessorError
                                .contactToUpdateNotExists(identity: syncContact.identity)
                        )
                    return
                }
            }
            seal.fulfill_()
        }
        .then {
            self.update(with: syncContact)
        }
    }

    /// Download profile picture and update contact.
    /// - Parameter with: Contact to sync
    /// - Throws: `MediatorReflectedProcessorError.messageNotProcessed`,
    /// `MediatorReflectedProcessorError.contactNotFound`
    private func update(with syncContact: Sync_Contact) -> Promise<Void> {
        var contactDefinedProfilePicture: Data?
        var contactDefinedProfilePictureIndex: Int?
        var userDefinedProfilePicture: Data?
        var userDefinedProfilePictureIndex: Int?

        let downloader = ImageBlobDownloader(frameworkInjector: frameworkInjector)
        var downloads = [Promise<Data?>]()

        if syncContact.hasUserDefinedProfilePicture, syncContact.userDefinedProfilePicture.updated.hasBlob {
            downloads.append(downloader.download(syncContact.userDefinedProfilePicture.updated.blob, origin: .local))
            userDefinedProfilePictureIndex = 0
        }

        if syncContact.hasContactDefinedProfilePicture, syncContact.contactDefinedProfilePicture.updated.hasBlob {
            downloads.append(downloader.download(syncContact.contactDefinedProfilePicture.updated.blob, origin: .local))
            contactDefinedProfilePictureIndex = userDefinedProfilePictureIndex != nil ? 1 : 0
        }

        return when(fulfilled: downloads)
            .then { (results: [Data?]) -> Guarantee<(Data?, Data?)> in
                if let index = userDefinedProfilePictureIndex,
                   results.count >= index {
                    guard let data = results[index] else {
                        throw MediatorReflectedProcessorError
                            .messageNotProcessed(message: "Blob for user defined profile picture cannot be nil")
                    }
                    userDefinedProfilePicture = data
                }
                if let index = contactDefinedProfilePictureIndex,
                   results.count >= index {
                    guard let data = results[index] else {
                        throw MediatorReflectedProcessorError
                            .messageNotProcessed(message: "Blob for contact defined profile picture cannot be nil")
                    }
                    contactDefinedProfilePicture = data
                }

                return Guarantee<(Data?, Data?)> { $0((userDefinedProfilePicture, contactDefinedProfilePicture)) }
            }
            .then { (userDefinedProfilePicture: Data?, contactDefinedProfilePicture: Data?) -> Promise<Void> in
                Promise { seal in
                    self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe { [self] in
                        guard let contact = frameworkInjector.backgroundEntityManager.entityFetcher
                            .contact(for: syncContact.identity) else {
                            seal.reject(MediatorReflectedProcessorError.contactNotFound(identity: syncContact.identity))
                            return
                        }

                        if syncContact.hasUserDefinedProfilePicture {
                            switch syncContact.userDefinedProfilePicture.image {
                            case .removed:
                                contact.imageData = nil
                            case .updated:
                                contact.imageData = userDefinedProfilePicture
                            case .none:
                                break
                            }
                        }

                        if syncContact.hasContactDefinedProfilePicture {
                            switch syncContact.contactDefinedProfilePicture.image {
                            case .removed:
                                contact.contactImage = nil
                            case .updated:
                                let dbImageData = frameworkInjector.backgroundEntityManager.entityCreator
                                    .imageData()
                                contact.contactImage = dbImageData
                                contact.contactImage?.data = contactDefinedProfilePicture
                            case .none:
                                break
                            }
                        }

                        if syncContact.hasVerificationLevel {
                            contact.verificationLevel = NSNumber(integerLiteral: syncContact.verificationLevel.rawValue)
                        }

                        if syncContact.hasFeatureMask {
                            contact.featureMask = NSNumber(value: syncContact.featureMask)
                        }

                        if syncContact.hasNickname {
                            contact.publicNickname = syncContact.nicknameNullable
                        }

                        if syncContact.hasFirstName {
                            contact.firstName = syncContact.firstNameNullable
                        }

                        if syncContact.hasLastName {
                            contact.lastName = syncContact.lastNameNullable
                        }

                        if syncContact.hasIdentityType {
                            switch syncContact.identityType {
                            case .regular:
                                break
                            case .work:
                                frameworkInjector.contactStore
                                    .addAsWork(identities: NSOrderedSet(array: [contact.identity]), contactSyncer: nil)
                            case .UNRECOGNIZED:
                                break
                            }
                        }

                        if syncContact.hasWorkVerificationLevel {
                            switch syncContact.workVerificationLevel {
                            case .none:
                                contact.workContact = false
                            case .workSubscriptionVerified:
                                contact.workContact = true
                            case .UNRECOGNIZED:
                                break
                            }
                        }

                        if syncContact.hasSyncState {
                            contact.importedStatus = ImportedStatus(rawValue: syncContact.syncState.rawValue)!
                        }

                        if syncContact.hasCreatedAt {
                            contact.createdAt = syncContact.createdAtNullable?.date
                        }

                        if syncContact.hasAcquaintanceLevel {
                            contact.isContactHidden = syncContact.acquaintanceLevel == .group
                        }

                        // Save on main thread (main DB context), otherwise observer of `Conversation` will not be
                        // called
                        frameworkInjector.conversationStoreInternal.updateConversation(withContact: syncContact)
                    }

                    seal.fulfill_()
                }
            }
    }
}
