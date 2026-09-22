import CocoaLumberjackSwift
import Foundation
import ThreemaFramework

/// Owns the license state of a business app before and during onboarding
///
/// Single place for validating the license and for storing the credentials of a license activation
/// link (`<scheme>://license?…`). Presenting the license entry screen stays with the coordinators.
@MainActor
final class LicenseService {

    // MARK: - ValidationResult

    enum ValidationResult: Equatable {
        /// The app is licensed
        case licensed

        /// The app is not licensed, license credentials are needed
        case notLicensed

        /// Another validation is already running and reports the result to its caller. It repeats its
        /// check for credentials stored in the meantime, so it also covers the credentials of this
        /// caller.
        case alreadyValidating
    }

    // MARK: - Private properties

    private let licenseStore: any LicenseStoreAdapterProtocol
    private let flavorService: any AppFlavorServiceProtocol
    private let licenseMDMSetup: any LicenseMDMSetupProtocol
    private let credentialsLoader: any OnboardingLicenseCredentialsLoading

    private var isValidating = false
    private var hasUnvalidatedCredentials = false

    /// Set while the license store holds credentials from ``restoreStoredCredentials()`` that no
    /// license check confirmed yet
    private var hasRestoredCredentials = false

    // MARK: - Lifecycle

    init(
        licenseStore: any LicenseStoreAdapterProtocol,
        flavorService: any AppFlavorServiceProtocol,
        licenseMDMSetup: any LicenseMDMSetupProtocol,
        credentialsLoader: any OnboardingLicenseCredentialsLoading
    ) {
        self.licenseStore = licenseStore
        self.flavorService = flavorService
        self.licenseMDMSetup = licenseMDMSetup
        self.credentialsLoader = credentialsLoader
    }

    // MARK: - Validation

    /// Validates the license, performing a license check if needed
    ///
    /// The check is repeated if credentials were stored while it was in flight (see ``apply(_:)``),
    /// so the result always reflects the latest credentials. Only one validation runs at a time; a
    /// caller arriving while a validation is in flight gets ``ValidationResult/alreadyValidating``
    /// and must not act on the license state itself.
    func validate() async -> ValidationResult {
        guard !isValidating else {
            return .alreadyValidating
        }
        isValidating = true
        defer { isValidating = false }

        var isLicensed = false
        repeat {
            hasUnvalidatedCredentials = false
            isLicensed = await performCheck()
        }
        while hasUnvalidatedCredentials

        guard isLicensed else {
            discardRestoredCredentialsIfNeeded()
            return .notLicensed
        }

        hasRestoredCredentials = false

        return .licensed
    }

    private func performCheck() async -> Bool {
        guard flavorService.isBusinessApp else {
            return true
        }

        guard licenseStore.isValid else {
            return await licenseStore.performLicenseCheck()
        }

        return true
    }

    // MARK: - License Activation Link

    /// Stores the credentials of a license activation link, skipping all values managed by MDM
    ///
    /// Storing credentials resets the validation state of the license store, so the next
    /// ``validate()`` performs a fresh check.
    /// - Parameter credentials: Credentials of the license activation link
    /// - Returns: Whether the resulting configuration is complete enough for a license check
    @discardableResult
    func apply(_ credentials: LicenseCredentials) -> LicenseCredentials.ApplyResult {
        let result = credentials.apply(
            to: licenseStore.store,
            mdmSetup: licenseMDMSetup,
            isOnPrem: flavorService.isOnPrem
        )

        guard result == .complete else {
            DDLogError("[LicenseService] License activation link is \(result). Credentials not validated.")
            return result
        }

        hasUnvalidatedCredentials = true

        return result
    }

    // MARK: - Stored Credentials

    /// Restores the license credentials of a previous installation of this app
    ///
    /// Does nothing if the store already holds a username and a password: MDM and a license
    /// activation link are applied before this runs and win. Values managed by MDM are never
    /// overwritten. The restored credentials are unvalidated — ``validate()`` discards them again if
    /// the license check rejects them, so the user doesn't end up editing values of a license that is
    /// no longer valid.
    /// - Returns: Whether credentials were restored
    @discardableResult
    func restoreStoredCredentials() -> Bool {
        guard flavorService.isBusinessApp else {
            return false
        }

        guard licenseStore.licenseUsername == nil || licenseStore.licensePassword == nil else {
            return false
        }

        do {
            guard let credentials = try credentialsLoader.loadCredentials() else {
                return false
            }

            let result = credentials.apply(
                to: licenseStore.store,
                mdmSetup: licenseMDMSetup,
                isOnPrem: flavorService.isOnPrem
            )

            DDLogNotice("[LicenseService] Restored stored license credentials (\(result))")

            hasRestoredCredentials = true

            return true
        }
        catch {
            DDLogError("[LicenseService] Unable to restore stored license credentials: \(error)")
            return false
        }
    }

    /// Removes restored credentials the license check rejected for this run, so the license entry screen doesn't
    /// show values of a license that is no longer valid
    private func discardRestoredCredentialsIfNeeded() {
        guard hasRestoredCredentials else {
            return
        }
        hasRestoredCredentials = false

        DDLogNotice("[LicenseService] Restored license credentials are not valid. Discarding them.")

        // Keeps the restored device ID and every value managed by MDM
        LicenseCredentials(username: nil, password: nil, server: nil).apply(
            to: licenseStore.store,
            mdmSetup: licenseMDMSetup,
            isOnPrem: flavorService.isOnPrem
        )
    }
}
