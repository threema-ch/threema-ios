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
import ThreemaProtocols

class MediatorReflectedContactSyncProcessor {

    private let frameworkInjector: FrameworkInjectorProtocol

    required init(frameworkInjector: FrameworkInjectorProtocol) {
        self.frameworkInjector = frameworkInjector
    }

    func process(contactSync: D2d_ContactSync) -> Promise<Void> {
        switch contactSync.action {
        case let .create(sync):
            return create(contact: sync.contact)
        case let .update(sync):
            return update(contact: sync.contact)
        case .none:
            break
        }
        return Promise()
    }

    private func create(contact syncContact: Sync_Contact) -> Promise<Void> {
        Promise { seal in
            guard self.frameworkInjector.entityManager.entityFetcher
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

            frameworkInjector.entityManager.performAndWaitSave {
                guard let contact = self.frameworkInjector.entityManager.entityCreator.contact() else {
                    seal.reject(MediatorReflectedProcessorError.createContactFailed(identity: syncContact.identity))
                    return
                }

                // Mandatory fields
                contact.setIdentity(to: syncContact.identity)
                contact.publicKey = syncContact.publicKey
                if syncContact.hasCreatedAt {
                    contact.createdAt = syncContact.createdAtNullable?.date
                }
                contact.contactVerificationLevel = .unverified
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
            frameworkInjector.entityManager.performAndWaitSave {
                guard self.frameworkInjector.entityManager.entityFetcher
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
                    Task {
                        let identity = await self.frameworkInjector.entityManager
                            .performSave { [self] () -> ThreemaIdentity? in
                                guard let contactEntity = frameworkInjector.entityManager.entityFetcher
                                    .contact(for: syncContact.identity) else {
                                    seal
                                        .reject(
                                            MediatorReflectedProcessorError
                                                .contactNotFound(identity: syncContact.identity)
                                        )
                                    return nil
                                }

                                contactEntity.update(
                                    syncContact: syncContact,
                                    userDefinedProfilePicture: userDefinedProfilePicture,
                                    contactDefinedProfilePicture: contactDefinedProfilePicture,
                                    entityManager: frameworkInjector.entityManager,
                                    contactStore: frameworkInjector.contactStore
                                )

                                if contactEntity.isHidden {
                                    frameworkInjector.entityManager.entityDestroyer
                                        .deleteOneToOneConversation(for: contactEntity)
                                }
                                else {
                                    // Save on main thread (main DB context), otherwise observer of `Conversation` will
                                    // not
                                    // be called
                                    frameworkInjector.conversationStoreInternal
                                        .updateConversation(withContact: syncContact)
                                }

                                return contactEntity.threemaIdentity
                            }

                        // If `contactEntity` is nil means promise is rejected
                        if let identity {
                            var pushSetting = self.frameworkInjector.pushSettingManager
                                .find(forContact: identity)
                            pushSetting.update(syncContact: syncContact)
                            await self.frameworkInjector.pushSettingManager.save(
                                pushSetting: pushSetting,
                                sync: false
                            )

                            seal.fulfill_()
                        }
                    }
                }
            }
    }
}
