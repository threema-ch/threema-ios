import Foundation

extension ServerAPIConnector {

    enum ServerAPIConnectorError: Error {
        case directorySearchFailed
        case genericError
    }

    public func searchDirectory(
        text: String,
        categoryIdentifiers: [String],
        page: Int,
        businessInjector: BusinessInjectorProtocol = BusinessInjector.ui
    ) async throws -> (results: [CompanyDirectoryContact], paging: [String: Any]) {
        try await withCheckedThrowingContinuation { continuation in
            search(
                inDirectory: text,
                categories: categoryIdentifiers,
                page: Int32(page),
                for: businessInjector.licenseStore,
                for: businessInjector.myIdentityStore as? MyIdentityStore
            ) { results, paging in

                guard let paging = paging as? [String: Any], let results else {
                    continuation.resume(throwing: ServerAPIConnectorError.directorySearchFailed)
                    return
                }

                var directoryContacts: [CompanyDirectoryContact] = []
                for result in results {
                    guard let result = result as? [AnyHashable: Any] else {
                        continue
                    }
                    directoryContacts.append(CompanyDirectoryContact(dictionary: result))
                }
                continuation.resume(returning: (directoryContacts, paging))

            } onError: { _ in
                continuation.resume(throwing: ServerAPIConnectorError.directorySearchFailed)
            }
        }
    }
    
    public func update(myIdentityStore: MyIdentityStore) async throws {
        try await withCheckedThrowingContinuation { continuation in
            update(myIdentityStore) {
                continuation.resume()
            } onError: { _ in
                continuation.resume(throwing: ServerAPIConnectorError.genericError)
            }
        }
    }
    
    public func fetchBulkIdentityInfo(_ identities: [String]) async throws -> (
        identities: [Any]?,
        publicKeys: [Any]?,
        featureMasks: [Any]?,
        states: [Any]?,
        types: [Any]?
    ) {
        try await withCheckedThrowingContinuation { continuation
            in
            fetchBulkIdentityInfo(identities) { identities, publicKeys, featureMasks, states, types in
                continuation.resume(returning: (identities, publicKeys, featureMasks, states, types))
            } onError: { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ([], [], [], [], []))
            }
        }
    }

    public func fetchIdentityInfo(_ identity: String) async throws -> (
        publicKey: Data,
        state: NSNumber,
        type: NSNumber,
        featureMask: NSNumber
    ) {
        try await withCheckedThrowingContinuation { continuation in
            self.fetchIdentityInfo(identity) { key, state, type, featureMask in
                guard let key, let state, let type, let featureMask else {
                    continuation.resume(throwing: ServerAPIConnectorError.genericError)
                    return
                }
                continuation.resume(returning: (publicKey: key, state: state, type: type, featureMask: featureMask))
            } onError: { error in
                continuation.resume(throwing: error ?? ServerAPIConnectorError.genericError)
            }
        }
    }
}
