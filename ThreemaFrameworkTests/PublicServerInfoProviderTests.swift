import Testing
@testable import ThreemaFramework

struct PublicServerInfoProviderTests {

    @Test func domains() async throws {
        let serverInfoProvider = PublicServerInfoProvider()

        let domainsCount = await withCheckedContinuation { continuation in
            serverInfoProvider.domains { domains, _ in
                continuation.resume(returning: domains?.count)
            }
        }

        #expect(domainsCount == 4)
    }
}
