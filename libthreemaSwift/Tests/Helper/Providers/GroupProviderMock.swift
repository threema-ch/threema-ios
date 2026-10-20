import libthreemaSwift

final class GroupProviderMock: libthreemaSwift.GroupProvider {
    func addWithProfilePicture(groups: [libthreemaSwift.GroupWithProfilePicture]) throws {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func setProfilePicture(identity: libthreemaSwift.GroupIdentity, profilePicture: libthreemaSwift.ProfilePicture?) throws {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func update(updates: [libthreemaSwift.GroupUpdate]) throws {
        throw ProviderError.ContractViolation("Not implemented yet")
    }
    
    func get(identity: libthreemaSwift.GroupIdentity) throws -> libthreemaSwift.Group? {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func getIdentities() throws -> Set<libthreemaSwift.GroupIdentity> {
        throw ProviderError.ContractViolation("Not implemented yet")
    }
    
    func getWithProfilePicture(identity: libthreemaSwift.GroupIdentity) throws -> libthreemaSwift.GroupWithProfilePicture? {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func has(identity: libthreemaSwift.GroupIdentity) throws -> Bool {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func isPartOfAnyGroup(identity: LibthreemaThreemaID, filter: libthreemaSwift.GroupMembershipFilter) throws -> Bool {
        throw ProviderError.ContractViolation("Not implemented yet")
    }
}
