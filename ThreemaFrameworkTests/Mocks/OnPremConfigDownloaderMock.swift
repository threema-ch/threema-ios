import Foundation
@testable import ThreemaFramework

final class OnPremConfigDownloaderMock: @unchecked Sendable, OnPremConfigDownloaderProtocol {
    private(set) var downloadDataCalls = [Bool]()

    private(set) var isRecoveryModeEnabled = false

    func enableRecoveryMode(_ value: Bool) async {
        isRecoveryModeEnabled = value
    }

    func downloadData() async throws -> (oppfData: Data, response: URLResponse) {
        downloadDataCalls.append(isRecoveryModeEnabled)

        return (
            Data(),
            HTTPURLResponse(
                url: URL(string: "https://threema.com")!,
                mimeType: nil,
                expectedContentLength: 0,
                textEncodingName: nil
            )
        )
    }
}
