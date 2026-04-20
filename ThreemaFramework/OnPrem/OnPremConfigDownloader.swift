import CocoaLumberjackSwift
import Foundation
import Keychain

protocol OnPremConfigDownloaderProtocol: Sendable {
    var isRecoveryModeEnabled: Bool { get async }
    func enableRecoveryMode(_ value: Bool) async
    func downloadData() async throws -> (oppfData: Data, response: URLResponse)
}

actor OnPremConfigDownloader: OnPremConfigDownloaderProtocol {

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral

        // Ephemeral sessions will still store a cache in memory. Setting these to `nil` fully disables caching
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil

        return URLSession(configuration: configuration)
    }()

    private let licenseStore: LicenseStore

    init(licenseStore: LicenseStore = LicenseStore.shared()) {
        self.licenseStore = licenseStore
    }

    private(set) var isRecoveryModeEnabled = false

    func enableRecoveryMode(_ value: Bool) async {
        isRecoveryModeEnabled = value
    }

    /// Download the OPPF file from the normal endpoint if the license set and the OnPrem server is known.
    /// Or if the recovery mode is enabled download the OPPF file from the fallback endpoint (gets the OnPrem
    /// server from keychain).
    ///
    /// - Returns: The data and the URL response
    func downloadData() async throws -> (oppfData: Data, response: URLResponse) {
        if !isRecoveryModeEnabled {
            guard let user = licenseStore.licenseUsername,
                  let password = licenseStore.licensePassword,
                  let server = licenseStore.onPremConfigURL, let serverURL = URL(string: server) else {
                DDLogError("Missing license username or password or server URL")
                throw OnPremConfigError.missingLicenseInfo
            }

            DDLogVerbose("[Fetch OPPF] Fetching from \(serverURL.absoluteString)")

            // Use the HTTPClient for pinned HTTP request
            let httpClient = HTTPClient(user: user, password: password)
            return try await httpClient.downloadData(url: serverURL, contentType: .octetStream)
        }
        else {
            guard let server = try KeychainManager.loadOnPremServer(),
                  let serverURL = URL(string: server.replacing(
                      "config.oppf",
                      with: "config.fallback.oppf"
                  )) else {
                DDLogError("Missing server URL")
                throw OnPremConfigError.missingConfigurationURL
            }

            DDLogVerbose("[Fetch OPPF] Fetching from \(serverURL.absoluteString)")

            // We don't use the HTTPClient for the fallback server URL, because the current pins are no valid anymore
            return try await session.data(from: serverURL)
        }
    }
}
