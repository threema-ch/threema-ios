#if DEBUG
    import Foundation
    import ThreemaEssentials
    import ThreemaFramework
    import ThreemaProtocols

    public final class ProfileStoreMock: ProfileStoreProtocol {
        public var saveCalls = 0
        public var savedProfile: ProfileStore.Profile?

        public var profile = ProfileStore.Profile(
            myIdentity: ThreemaIdentity("TESTERID"),
            sendProfilePicture: SendProfilePictureNone,
            profilePictureContactList: [],
            isLinkMobileNoPending: false,
            isLinkEmailPending: false
        )

        public init() { /* no-op */ }

        public func syncAndSave(workAvailabilityStatus: WorkAvailabilityStatus) async throws {
            // Noop
        }

        public func save(
            syncUserProfile: D2dSync_UserProfile,
            profileImage: Data?,
            isLinkMobileNoPending: Bool,
            isLinkEmailPending: Bool
        ) {
            saveCalls += 1
        }

        public func save(_ profile: ProfileStore.Profile) {
            savedProfile = profile
        }
    }

    extension ProfileStoreProtocol where Self == ProfileStore {
        public static var mock: any ProfileStoreProtocol {
            ProfileStoreMock()
        }
    }

#endif
