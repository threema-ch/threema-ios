import Foundation
import libthreemaSwift
import ThreemaEssentials

extension ThreemaIdentity {
    /// Thorws `ProviderError.InvalidParameter` if the given identity is equals the identity.
    func throwIsEqual(to identity: LibthreemaThreemaID) throws {
        if identity == self.rawValue {
            throw ProviderError.InvalidParameter("Identity must not be the user's own identity.")
        }
    }

    /// Thorws `ProviderError.InvalidParameter` if the given contacts contains the identity.
    func throwIsContaining(contacts: [LibthreemaContact]) throws {
        try throwIsContaining(identities: contacts.map(\.identity))
    }

    /// Thorws the a `ProviderError.InvalidParameter` if the given identities contains the identity.
    func throwIsContaining(identities: [LibthreemaThreemaID]) throws {
        if identities.contains(self.rawValue) {
            throw ProviderError.InvalidParameter("Identities must not contain the user's own identity.")
        }
    }
}
