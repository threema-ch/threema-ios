import Foundation
import ThreemaFramework
@testable import Threema

/// A configurable implementation of `LicenseStoreAdapterProtocol` for testing
///
/// Credentials are written to ``licenseStoreMock``, so tests can assert what a license activation
/// link stored.
@MainActor
final class LicenseStoreAdapterMock: LicenseStoreAdapterProtocol {

    // MARK: - Store

    let licenseStoreMock = LicenseStoreMock()

    var store: any LicenseStoreProtocol {
        licenseStoreMock
    }

    var licenseUsername: String? {
        get { licenseStoreMock.licenseUsername }
        set { licenseStoreMock.licenseUsername = newValue }
    }

    var licensePassword: String? {
        get { licenseStoreMock.licensePassword }
        set { licenseStoreMock.licensePassword = newValue }
    }

    var licenseDeviceID: String? {
        get { licenseStoreMock.licenseDeviceID }
        set { licenseStoreMock.licenseDeviceID = newValue ?? String() }
    }

    var onPremConfigURL: String? {
        get { licenseStoreMock.onPremConfigURL }
        set { licenseStoreMock.onPremConfigURL = newValue }
    }

    // MARK: - Configurable behavior

    var isValid = false

    /// Result of ``performLicenseCheck()``, ignored if ``performLicenseCheckHandler`` is set
    var performLicenseCheckResult = true

    /// Called for every ``performLicenseCheck()`` with the number of the call, starting at 1
    var performLicenseCheckHandler: ((Int) async -> Bool)?

    // MARK: - Call tracking

    private(set) var performLicenseCheckCount = 0
    private(set) var performUpdateWorkInfoCount = 0

    // MARK: - LicenseStoreAdapterProtocol

    func performLicenseCheck() async -> Bool {
        performLicenseCheckCount += 1

        guard let performLicenseCheckHandler else {
            return performLicenseCheckResult
        }

        return await performLicenseCheckHandler(performLicenseCheckCount)
    }

    func performUpdateWorkInfo() {
        performUpdateWorkInfoCount += 1
    }
}
