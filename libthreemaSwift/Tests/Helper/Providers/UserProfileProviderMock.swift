import libthreemaSwift

final class UserProfileProviderMock: libthreemaSwift.UserProfileProvider {
    private let _userProfile: libthreemaSwift.UserProfile

    init(userProfile: libthreemaSwift.UserProfile) {
        self._userProfile = userProfile
    }

    func get() throws -> libthreemaSwift.UserProfile {
        _userProfile
    }
    
    func set(userProfile: libthreemaSwift.UserProfile) throws {
        throw ProviderError.InvalidState("Not implemented yet")
    }
}
