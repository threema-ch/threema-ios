import Foundation
import ThreemaEssentials
import ThreemaProtocols
@testable import ThreemaFramework

final class ProfileStoreMock: ProfileStoreProtocol {
    var saveCalls = 0
    
    var profile: ProfileStore.Profile {
        ProfileStore.Profile(
            myIdentity: ThreemaIdentity("ECHOECHO"),
            sendProfilePicture: SendProfilePictureNone,
            profilePictureContactList: [],
            isLinkMobileNoPending: false,
            isLinkEmailPending: false
        )
    }
    
    func syncAndSave(workAvailabilityStatus: ThreemaFramework.WorkAvailabilityStatus) async throws {
        // Noop
    }
    
    func save(
        syncUserProfile: ThreemaProtocols.D2dSync_UserProfile,
        profileImage: Data?,
        isLinkMobileNoPending: Bool,
        isLinkEmailPending: Bool
    ) {
        saveCalls += 1
    }
    
    func save(_ profile: ThreemaFramework.ProfileStore.Profile) {
        // Noop
    }
}
