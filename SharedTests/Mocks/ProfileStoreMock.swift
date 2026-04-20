import Foundation
import ThreemaEssentials
@testable import ThreemaFramework

final class ProfileStoreMock: ProfileStoreProtocol {
    var profile: ProfileStore.Profile {
        ProfileStore.Profile(
            myIdentity: ThreemaIdentity("ECHOECHO"),
            sendProfilePicture: SendProfilePictureNone,
            profilePictureContactList: [],
            isLinkMobileNoPending: false,
            isLinkEmailPending: false
        )
    }
    
    func save(_ profile: ThreemaFramework.ProfileStore.Profile) {
        // Noop
    }
}
