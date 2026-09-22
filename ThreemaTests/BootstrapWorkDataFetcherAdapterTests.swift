import Foundation
import Testing
import ThreemaFramework
@testable import Threema

struct BootstrapWorkDataFetcherAdapterTests {

    /// The fetcher must be built per call. `WorkDataAPICaller` snapshots the license credentials on
    /// construction, and the adapter is created at app launch, before a fresh install has a license — so a
    /// cached fetcher would keep sending the empty credentials captured back then.
    @Test("A fetcher is built for every call, never cached")
    func buildsAFetcherForEveryCall() async throws {
        let factory = FetcherFactory()
        let adapter = BootstrapWorkDataFetcherAdapter(makeFetcher: factory.make)

        #expect(factory.callCount == 0)

        try await adapter.checkUpdateThreemaMDM()
        try await adapter.checkUpdateThreemaMDM()

        #expect(factory.callCount == 2)
    }

    @Test("The call is forwarded to the fetcher without forcing a send")
    func forwardsToTheFetcherWithoutForcingASend() async throws {
        let fetcher = FetcherStub()
        let adapter = BootstrapWorkDataFetcherAdapter { fetcher }

        try await adapter.checkUpdateThreemaMDM()

        #expect(fetcher.checkUpdateCallCount == 1)
        #expect(fetcher.capturedForceSend == false)
    }

    @Test("A fetcher error is propagated to the caller")
    func propagatesTheFetcherError() async {
        let fetcher = FetcherStub()
        fetcher.error = TestError.fetchFailed
        let adapter = BootstrapWorkDataFetcherAdapter { fetcher }

        await #expect(throws: TestError.fetchFailed) {
            try await adapter.checkUpdateThreemaMDM()
        }
    }

    // MARK: - Helpers

    private enum TestError: Error, Equatable {
        case fetchFailed
    }

    private final class FetcherStub: WorkDataThreemaMDMFetcherProtocol {
        var error: Error?

        private(set) var checkUpdateCallCount = 0
        private(set) var capturedForceSend: Bool?

        func processAndApply(_ data: Data, forceSend: Bool) async throws { }

        func checkUpdateThreemaMDM(forceSend: Bool) async throws {
            checkUpdateCallCount += 1
            capturedForceSend = forceSend

            if let error {
                throw error
            }
        }
    }

    /// Counts how often the adapter asks for a fetcher.
    private final class FetcherFactory {
        private(set) var callCount = 0

        func make() -> any WorkDataThreemaMDMFetcherProtocol {
            callCount += 1
            return FetcherStub()
        }
    }
}
