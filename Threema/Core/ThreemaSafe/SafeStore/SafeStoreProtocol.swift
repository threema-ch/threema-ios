import ThreemaMacros

protocol SafeStoreProtocol {
    func getSafeServerToDisplay() -> String
    func createKey(identity: String, safePassword: String?) -> [UInt8]?
}

#if DEBUG

    final class MockSafeStore: SafeStoreProtocol {
        var safeServerToDisplay = #localize("safe_default_server")
        var createdKey: [UInt8]?

        func getSafeServerToDisplay() -> String {
            safeServerToDisplay
        }

        func createKey(identity: String, safePassword: String?) -> [UInt8]? {
            createdKey
        }
    }

    extension SafeStoreProtocol where Self == MockSafeStore {
        static var mock: Self { Self() }
    }

#endif
