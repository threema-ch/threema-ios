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

class MediatorReflectedUserProfileSyncProcessor {

    private let frameworkInjector: FrameworkInjectorProtocol

    init(frameworkInjector: FrameworkInjectorProtocol) {
        self.frameworkInjector = frameworkInjector
    }

    func process(userProfileSync: D2d_UserProfileSync) -> Promise<Void> {
        switch userProfileSync.action {
        case let .update(sync):
            return update(with: sync.userProfile)
        default:
            break
        }
        return Promise()
    }

    /// Update user profile sync (download user profile image).
    /// - Parameter with: User profile sync data
    /// - Throws: `MediatorReflectedProcessorError.messageNotProcessed`
    private func update(with userProfile: Sync_UserProfile) -> Promise<Void> {
        firstly {
            Guarantee { $0(userProfile.hasProfilePicture && userProfile.profilePicture.updated.hasBlob) }
        }
        .then { hasProfilePicture -> Promise<Data?> in
            if hasProfilePicture {
                let downloader = ImageBlobDownloader(frameworkInjector: self.frameworkInjector)
                return downloader.download(userProfile.profilePicture.updated.blob, origin: .local)
            }
            else {
                return Promise { $0.fulfill(nil) }
            }
        }
        .then { (downloadedBlobData: Data?) -> Promise<Void> in
            let profileStore = ProfileStore(
                serverConnector: self.frameworkInjector.serverConnector,
                myIdentityStore: self.frameworkInjector.myIdentityStore,
                contactStore: self.frameworkInjector.contactStore,
                userSettings: self.frameworkInjector.userSettings,
                taskManager: nil
            )
            profileStore.save(
                syncUserProfile: userProfile,
                profileImage: downloadedBlobData,
                isLinkMobileNoPending: false,
                isLinkEmailPending: false
            )

            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationIncomingProfileSynchronization),
                object: nil
            )

            return Promise()
        }
    }
}
