import libthreemaSwift

final class GroupProviderMock: libthreemaSwift.GroupProvider {
    func isPartOfAnyGroup(identity: LibthreemaThreemaID, filter: libthreemaSwift.GroupMembershipFilter) throws -> Bool {
        throw ProviderError.InvalidState("Not implemented yet")
    }

    func getIdentities() throws -> [libthreemaSwift.GroupIdentity] {
        throw ProviderError.InvalidState("Not implemented yet")
    }
    
    func getWithProfilePicture(identity: libthreemaSwift.GroupIdentity) throws -> libthreemaSwift.GroupWithProfilePicture? {
        throw ProviderError.InvalidState("Not implemented yet")
    }
    
    func addWithProfilePicture(groups: [libthreemaSwift.GroupWithProfilePicture]) throws {
        throw ProviderError.InvalidState("Not implemented yet")
    }
    
    func setProfilePicture(identity: libthreemaSwift.GroupIdentity, profilePicture: libthreemaSwift.ProfilePicture?) throws {
        throw ProviderError.InvalidState("Not implemented yet")
    }
}
