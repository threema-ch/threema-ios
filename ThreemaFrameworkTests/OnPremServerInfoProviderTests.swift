import FileUtility
import Testing
@testable import ThreemaFramework

struct OnPremServerInfoProviderTests {

    init() {
        let appGroupID = "group.ch.threema"

        AppGroup.setGroupID(appGroupID)
        FileUtility.updateSharedInstance(with: FileUtility())
        LicenseStore.shared().onPremConfigURL = "https://threema.ch"
    }

    @Test func doRecovery() async throws {
        let (configDownloaderMock, configVerifierMock, serverInfoProvider) = makeSUT()

        try await serverInfoProvider.doRecovery()

        #expect(configDownloaderMock.downloadDataCalls.count == 1)
        #expect(configDownloaderMock.downloadDataCalls.first! == true, "Recovery Mode must be true")
        #expect(configVerifierMock.verifyCalls.count == 1)
    }

    @Test func chatServer() async throws {
        let (configDownloaderMock, configVerifierMock, serverInfoProvider) = makeSUT()

        await withCheckedContinuation { continuation in
            serverInfoProvider.chatServer(ipv6: true) { _, _ in
                continuation.resume()
            }
        }

        #expect(configDownloaderMock.downloadDataCalls.count == 1)
        #expect(configDownloaderMock.downloadDataCalls.first! == false, "Recovery Mode must be false")
        #expect(configVerifierMock.verifyCalls.count == 1)
    }

    @Test func domains() async throws {
        let (configDownloaderMock, configVerifierMock, serverInfoProvider) = makeSUT()

        await withCheckedContinuation { continuation in
            serverInfoProvider.domains { _, _ in
                continuation.resume()
            }
        }

        #expect(configDownloaderMock.downloadDataCalls.isEmpty)
        #expect(configVerifierMock.verifyCalls.count == 1)
    }

    private func makeSUT() -> (OnPremConfigDownloaderMock, OnPremConfigVerifierMock, OnPremServerInfoProvider) {
        let configDownloaderMock = OnPremConfigDownloaderMock()
        let configVerifierMock = OnPremConfigVerifierMock()

        let serverInfoProvider = OnPremServerInfoProvider(
            configDownloader: configDownloaderMock,
            configVerifier: configVerifierMock
        )

        return (configDownloaderMock, configVerifierMock, serverInfoProvider)
    }
}
