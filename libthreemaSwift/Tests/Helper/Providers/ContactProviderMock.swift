import Foundation
import libthreemaSwift

final class ContactProviderMock: libthreemaSwift.ContactProvider {

    private let identities: Set<LibthreemaThreemaID>
    private let contacts: [LibthreemaContact]

    init(identities: Set<LibthreemaThreemaID>, contacts: [LibthreemaContact]) {
        self.identities = identities
        self.contacts = contacts
    }

    func isExplicitlyBlocked(identity: LibthreemaThreemaID) throws -> Bool {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func getExplicitlyBlockedIdentities() throws -> [LibthreemaThreemaID] {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func addExplicitlyBlockedIdentities(identities: [LibthreemaThreemaID]) throws {
        // Not implemeted yet
    }

    func getExcludeFromSyncIdentities() throws -> [LibthreemaThreemaID] {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func addExcludeFromSyncIdentities(identities: [LibthreemaThreemaID]) throws {
        // Not implemeted yet
    }

    func isPartOfAnyGroup(
        identity: LibthreemaThreemaID,
        filter: libthreemaSwift.GroupMembershipFilter
    ) throws -> Bool {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func has(identity: LibthreemaThreemaID) throws -> Bool {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func countExisting(identities: [LibthreemaThreemaID]) throws -> UInt32 {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func getIdentities() throws -> Set<LibthreemaThreemaID> {
        self.identities
    }

    func get(identity: LibthreemaThreemaID) throws -> libthreemaSwift.Contact? {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func add(contacts: [libthreemaSwift.Contact]) throws {
        // Not implemeted yet
    }

    func getWithProfilePictures(identity: LibthreemaThreemaID) throws -> libthreemaSwift
        .ContactWithProfilePictures? {
        guard let contact = contacts.first(where: { $0.identity == identity }) else {
            return nil
        }

        return ContactWithProfilePictures(
            contact: contact,
            contactDefinedProfilePicture: nil,
            userDefinedProfilePicture: nil
        )
    }

    func addWithProfilePictures(contacts: [libthreemaSwift.ContactWithProfilePictures]) throws {
        // Not implemeted yet
    }

    func update(updates contacts: [libthreemaSwift.ContactUpdate]) throws {
        // Not implemeted yet
    }

    func getContactDefinedProfilePicture(identity: LibthreemaThreemaID) throws -> libthreemaSwift
        .ProfilePicture? {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func setContactDefinedProfilePicture(
        identity: LibthreemaThreemaID,
        profilePicture: libthreemaSwift.ProfilePicture?
    ) throws {
        // Not implemeted yet
    }

    func getUserDefinedProfilePicture(identity: LibthreemaThreemaID) throws -> libthreemaSwift
        .ProfilePicture? {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func setUserDefinedProfilePicture(
        identity: LibthreemaThreemaID,
        profilePicture: libthreemaSwift.ProfilePicture?
    ) throws {
        // Not implemeted yet
    }
}
