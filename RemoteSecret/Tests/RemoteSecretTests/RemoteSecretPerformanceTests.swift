import XCTest
@testable import RemoteSecret

final class RemoteSecretPerformanceTests: XCTestCase {
     
    let remoteSecret = RemoteSecret(rawValue: Data(repeating: 0, count: 32))

    func testPerformanceEncrypt() throws {
        throw XCTSkip("Skipped due to taking too much time and delivering wrong results")

        let crypto = try RemoteSecretCrypto(remoteSecret: remoteSecret)
        let data = Data(repeating: 1, count: 100_000_000)

        measure(metrics: [XCTMemoryMetric(), XCTClockMetric()]) {
            _ = crypto.encrypt(data)
        }
    }

    func testPerformanceDecrypt() throws {
        throw XCTSkip("Skipped due to taking too much time and delivering wrong results")

        let crypto = try RemoteSecretCrypto(remoteSecret: remoteSecret)
        let data = Data(repeating: 1, count: 100_000_000)
        let encrypted = crypto.encrypt(data)

        measure(metrics: [XCTMemoryMetric(), XCTClockMetric()]) {
            let _: Data = crypto.decrypt(encrypted)
        }
    }
}
