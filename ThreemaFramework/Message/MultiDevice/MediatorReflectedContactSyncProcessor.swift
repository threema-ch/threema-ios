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
import PromiseKit

class MediatorReflectedContactSyncProcessor {

    private let frameworkInjector: FrameworkInjectorProtocol

    required init(frameworkInjector: FrameworkInjectorProtocol) {
        self.frameworkInjector = frameworkInjector
    }

    func process(contactSync: D2d_ContactSync) -> Promise<Void> {
        switch contactSync.action {
        case let .delete(delete):
            deleteContact(identity: delete.deleteIdentity)
        case let .set(set):
            return setContact(with: set.contact)
        case .none, .some:
            break
        }
        return Promise()
    }

    /// Delete contact and its settings.
    /// - Parameter identity: Contact that will be delete
    private func deleteContact(identity: String) {
        if let contact = frameworkInjector.backgroundEntityManager.entityFetcher
            .contact(for: identity) {
            // Remove from blacklist, if present
            if frameworkInjector.userSettings.blacklist.contains(identity) {
                var blacklist = Array(frameworkInjector.userSettings.blacklist)
                blacklist.removeAll(where: { $0 as? String == identity })
                frameworkInjector.userSettings.blacklist = NSOrderedSet(array: blacklist)
            }

            // Remove from profile picture receiver list
            if frameworkInjector.userSettings.profilePictureContactList
                .contains(where: { $0 as? String == identity }) {
                var profilePictureContactList = Array(frameworkInjector.userSettings.profilePictureContactList)
                profilePictureContactList
                    .removeAll(where: { $0 as? String == identity })
                frameworkInjector.userSettings.profilePictureContactList = profilePictureContactList
            }

            // Remove from profile picture request list
            frameworkInjector.contactStore.removeProfilePictureRequest(identity)

            if contact.cnContactID != nil {
                var exclusionList = Array(frameworkInjector.userSettings.syncExclusionList)
                exclusionList.append(identity)
                frameworkInjector.userSettings.syncExclusionList = exclusionList
            }

            frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                self.frameworkInjector.backgroundEntityManager.entityDestroyer.deleteObject(object: contact)
            }
        }
    }

    /// Download profile picture and create/update contact.
    /// - Parameter with: Contact to sync
    /// - Throws: `MediatorReflectedProcessorError.messageNotProcessed`, `MediatorReflectedProcessorError.contactNotFound`
    private func setContact(with syncContact: Sync_Contact) -> Promise<Void> {
        var contactDefinedProfilePicture: Data?
        var contactDefinedProfilePictureIndex: Int?
        var userDefinedProfilePicture: Data?
        var userDefinedProfilePictureIndex: Int?

        let downloader = ImageBlobDownloader(frameworkInjector: frameworkInjector)
        var downloads = [Promise<Data?>]()

        if syncContact.hasUserDefinedProfilePicture, syncContact.userDefinedProfilePicture.updated.hasBlob {
            downloads.append(downloader.download(syncContact.userDefinedProfilePicture.updated.blob))
            userDefinedProfilePictureIndex = 0
        }

        if syncContact.hasContactDefinedProfilePicture, syncContact.contactDefinedProfilePicture.updated.hasBlob {
            downloads.append(downloader.download(syncContact.contactDefinedProfilePicture.updated.blob))
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
                    self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                        var contact: Contact? = self.frameworkInjector.backgroundEntityManager.entityFetcher
                            .contact(for: syncContact.identity)
                        if contact == nil {
                            guard syncContact.hasPublicKey else {
                                seal
                                    .reject(
                                        MediatorReflectedProcessorError
                                            .missingPublicKey(identity: syncContact.identity)
                                    )
                                return
                            }

                            contact = self.frameworkInjector.backgroundEntityManager.entityCreator.contact()
                            contact?.identity = syncContact.identity
                            contact?.publicKey = syncContact.publicKey
                        }
                        guard let contact = contact else {
                            seal.reject(MediatorReflectedProcessorError.contactNotFound(message: syncContact.identity))
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
                                let dbImageData = self.frameworkInjector.backgroundEntityManager.entityCreator
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
                                contact.workContact = false
                            case .work:
                                contact.workContact = true
                            case .UNRECOGNIZED:
                                contact.workContact = false
                            }
                        }
                        if syncContact.hasSyncState {
                            contact.importedStatus = ImportedStatus(rawValue: syncContact.syncState.rawValue)!
                        }
                        if syncContact.hasCreatedAt {
                            contact.createdAt = syncContact.createdAtNullable?.date
                        }
                    }

                    seal.fulfill_()
                }
            }
    }
}
