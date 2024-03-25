//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

class MediatorReflectedGroupSyncProcessor {
    
    private let frameworkInjector: FrameworkInjectorProtocol

    required init(frameworkInjector: FrameworkInjectorProtocol) {
        self.frameworkInjector = frameworkInjector
    }

    func process(groupSync: D2d_GroupSync) -> Promise<Void> {
        switch groupSync.action {
        case let .create(sync):
            return create(group: sync.group)
        case let .delete(sync):
            return delete(identity: sync.groupIdentity)
        case let .update(sync):
            return update(group: sync.group)
        case .none:
            break
        }
        return Promise()
    }

    private func delete(identity: Common_GroupIdentity) -> Promise<Void> {
        Promise { seal in
            let groupIdentity = try GroupIdentity(commonGroupIdentity: identity)

            guard self.frameworkInjector.groupManager.getGroup(
                groupIdentity.id,
                creator: groupIdentity.creator.string
            ) != nil
            else {
                seal
                    .reject(
                        MediatorReflectedProcessorError
                            .groupToDeleteNotExists(groupIdentity: groupIdentity)
                    )
                return
            }

            self.frameworkInjector.groupManager.dissolve(
                groupID: groupIdentity.id, to: nil
            )

            seal.fulfill_()
        }
    }

    private func create(group syncGroup: Sync_Group) -> Promise<Void> {
        Promise { seal in
            let groupIdentity = try GroupIdentity(commonGroupIdentity: syncGroup.groupIdentity)

            guard self.frameworkInjector.groupManager.getGroup(
                groupIdentity.id,
                creator: groupIdentity.creator.string
            ) == nil
            else {
                seal
                    .reject(
                        MediatorReflectedProcessorError
                            .groupToCreateAlreadyExists(groupIdentity: groupIdentity)
                    )
                return
            }

            self.update(with: syncGroup)
                .done {
                    seal.fulfill_()
                }
                .catch { error in
                    seal.reject(error)
                }
        }
    }

    private func update(group syncGroup: Sync_Group) -> Promise<Void> {
        Promise { seal in
            let groupIdentity = try GroupIdentity(commonGroupIdentity: syncGroup.groupIdentity)

            guard self.frameworkInjector.groupManager.getGroup(
                groupIdentity.id,
                creator: groupIdentity.creator.string
            ) != nil
            else {
                seal
                    .reject(
                        MediatorReflectedProcessorError
                            .groupToUpdateNotExists(groupIdentity: groupIdentity)
                    )
                return
            }
            seal.fulfill_()
        }
        .then {
            self.update(with: syncGroup)
        }
    }

    private func update(with syncGroup: Sync_Group) -> Promise<Void> {
        var profilePicture: Data?

        let downloader = ImageBlobDownloader(frameworkInjector: frameworkInjector)
        var downloads = [Promise<Data?>]()

        if syncGroup.hasProfilePicture, syncGroup.profilePicture.updated.hasBlob {
            downloads.append(downloader.download(syncGroup.profilePicture.updated.blob, origin: .local))
        }

        return when(fulfilled: downloads)
            .then { (results: [Data?]) -> Guarantee<Void> in
                if downloads.count == 1 {
                    guard results.count == 1, let data = results[0] else {
                        throw MediatorReflectedProcessorError
                            .messageNotProcessed(message: "Blob for group profile picture cannot be nil")
                    }

                    profilePicture = data
                }

                return Guarantee()
            }
            .then { () -> Promise<Void> in
                Promise<Group?> { seal in
                    let groupIdentity = try GroupIdentity(commonGroupIdentity: syncGroup.groupIdentity)
                    
                    if syncGroup.hasMemberIdentities {
                        self.frameworkInjector.groupManager.createOrUpdateDB(
                            for: groupIdentity,
                            members: Set<String>(syncGroup.memberIdentities.identities),
                            systemMessageDate: Date(),
                            sourceCaller: .sync
                        )
                        .done { group in
                            seal.fulfill(group)
                        }
                        .catch { error in
                            seal.reject(error)
                        }
                    }
                    else {
                        let group = self.frameworkInjector.groupManager.getGroup(
                            groupIdentity.id,
                            creator: groupIdentity.creator.string
                        )
                        seal.fulfill(group)
                    }
                }
                .then { group -> Promise<Void> in
                    Promise { seal in
                        guard let group else {
                            seal.reject(
                                MediatorReflectedProcessorError.groupNotFound(message: "\(syncGroup.groupIdentity)")
                            )
                            return
                        }

                        if syncGroup.hasUserState, syncGroup.userState == .left {
                            self.frameworkInjector.groupManager.leaveDB(
                                groupID: group.groupIdentity.id,
                                creator: group.groupIdentity.creator.string,
                                member: self.frameworkInjector.myIdentityStore.identity,
                                systemMessageDate: Date()
                            )
                        }

                        if syncGroup.hasName {
                            self.frameworkInjector.groupManager.setName(
                                groupID: group.groupIdentity.id,
                                creator: group.groupIdentity.creator.string,
                                name: syncGroup.name,
                                systemMessageDate: Date(),
                                send: false
                            )
                            .catch { error in
                                DDLogError("Changing of reflected group name failed: \(error)")
                            }
                        }

                        if syncGroup.hasProfilePicture {
                            switch syncGroup.profilePicture.image {
                            case .removed:
                                self.frameworkInjector.groupManager.deletePhoto(
                                    groupID: group.groupIdentity.id,
                                    creator: group.groupIdentity.creator.string,
                                    sentDate: Date(),
                                    send: false
                                )
                                .catch { error in
                                    DDLogError("Removing of reflected group profile picture failed: \(error)")
                                }
                            case .updated:
                                if let imageData = profilePicture {
                                    self.frameworkInjector.groupManager.setPhoto(
                                        groupID: group.groupIdentity.id,
                                        creator: group.groupIdentity.creator.string,
                                        imageData: imageData,
                                        sentDate: Date(),
                                        send: false
                                    )
                                    .catch { error in
                                        DDLogError("Changing of reflected group profile picture failed: \(error)")
                                    }
                                }
                            case .none:
                                break
                            }
                        }

                        // Save on main thread (main DB context), otherwise observer of `Conversation` will not be
                        // called
                        self.frameworkInjector.conversationStoreInternal.updateConversation(withGroup: syncGroup)

                        Task {
                            var pushSetting = self.frameworkInjector.pushSettingManager
                                .find(forGroup: group.groupIdentity)
                            pushSetting.update(syncGroup: syncGroup)
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
