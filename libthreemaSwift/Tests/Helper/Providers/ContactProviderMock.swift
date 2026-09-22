import Foundation
import libthreemaSwift

final class ContactProviderMock: libthreemaSwift.ContactProvider {

    private let identities: [LibthreemaThreemaID]
    private let contacts: [LibthreemaContact]

    init(identities: [LibthreemaThreemaID], contacts: [LibthreemaContact]) {
        self.identities = identities
        self.contacts = contacts
    }

    // swiftformat:disable:next acronyms
    func isExplicitlyBlocked(identity: libthreemaSwift.ThreemaId) throws -> Bool {
        throw ProviderError.InvalidState("Not implemented yet")
    }

    // swiftformat:disable:next acronyms
    func getExplicitlyBlockedIdentities() throws -> [libthreemaSwift.ThreemaId] {
        throw ProviderError.InvalidState("Not implemented yet")
    }

    // swiftformat:disable:next acronyms
    func addExplicitlyBlockedIdentities(identities: [libthreemaSwift.ThreemaId]) throws {
        // Not implemeted yet
    }

    // swiftformat:disable:next acronyms
    func getExcludeFromSyncIdentities() throws -> [libthreemaSwift.ThreemaId] {
        throw ProviderError.InvalidState("Not implemented yet")
    }

    // swiftformat:disable:next acronyms
    func addExcludeFromSyncIdentities(identities: [libthreemaSwift.ThreemaId]) throws {
        // Not implemeted yet
    }

    func isPartOfAnyGroup(
        // swiftformat:disable:next acronyms
        identity: libthreemaSwift.ThreemaId,
        filter: libthreemaSwift.GroupMembershipFilter
    ) throws -> Bool {
        throw ProviderError.InvalidState("Not implemented yet")
    }

    func has(identity: LibthreemaThreemaID) throws -> Bool {
        throw ProviderError.InvalidState("Not implemented yet")
    }

    // swiftformat:disable:next acronyms
    func countExisting(identities: [libthreemaSwift.ThreemaId]) throws -> UInt32 {
        throw ProviderError.InvalidState("Not implemented yet")
    }

    // swiftformat:disable:next acronyms
    func getIdentities() throws -> [libthreemaSwift.ThreemaId] {
        self.identities
    }

    // swiftformat:disable:next acronyms
    func get(identity: libthreemaSwift.ThreemaId) throws -> libthreemaSwift.Contact? {
        throw ProviderError.InvalidState("Not implemented yet")
    }

    func add(contacts: [libthreemaSwift.Contact]) throws {
        // Not implemeted yet
    }

    // swiftformat:disable:next acronyms
    func getWithProfilePictures(identity: libthreemaSwift.ThreemaId) throws -> libthreemaSwift
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

    // swiftformat:disable:next acronyms
    func getContactDefinedProfilePicture(identity: libthreemaSwift.ThreemaId) throws -> libthreemaSwift
        .ProfilePicture? {
        throw ProviderError.InvalidState("Not implemented yet")
    }

    func setContactDefinedProfilePicture(
        // swiftformat:disable:next acronyms
        identity: libthreemaSwift.ThreemaId,
        profilePicture: libthreemaSwift.ProfilePicture?
    ) throws {
        // Not implemeted yet
    }

    // swiftformat:disable:next acronyms
    func getUserDefinedProfilePicture(identity: libthreemaSwift.ThreemaId) throws -> libthreemaSwift
        .ProfilePicture? {
        throw ProviderError.InvalidState("Not implemented yet")
    }

    func setUserDefinedProfilePicture(
        // swiftformat:disable:next acronyms
        identity: libthreemaSwift.ThreemaId,
        profilePicture: libthreemaSwift.ProfilePicture?
    ) throws {
        // Not implemeted yet
    }
}
