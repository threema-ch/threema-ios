import CocoaLumberjackSwift
import Foundation
import PromiseKit
import ThreemaEssentials
import ThreemaProtocols

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
                myIdentity: ThreemaIdentity(self.frameworkInjector.myIdentityStore.identity),
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
