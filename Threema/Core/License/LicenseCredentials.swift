import Foundation
import ThreemaFramework

// MARK: - LicenseMDMSetupProtocol

/// MDM values license credentials must not overwrite
protocol LicenseMDMSetupProtocol {
    /// Whether the value of the MDM key is managed by MDM
    func existsMdmKey(_ mdmKey: String) -> Bool
}

// MARK: - MDMSetup + LicenseMDMSetupProtocol

extension MDMSetup: LicenseMDMSetupProtocol { }

// MARK: - LicenseCredentials

/// License credentials of a business app, from a license activation link
/// (`<scheme>://license?username=…&password=…&server=…`) or from the keychain
///
/// Every source applies the same MDM gating and completeness rules through
/// ``apply(to:mdmSetup:isOnPrem:)``, so the pre-setup (onboarding) and the running-app license paths
/// behave the same.
struct LicenseCredentials {

    // MARK: - ApplyResult

    /// Outcome of applying credentials to a license store
    enum ApplyResult: Equatable {
        /// All values required by the current flavor are set and a license check can be performed
        case complete

        /// Username, password or the OnPrem server is missing
        case incomplete

        /// The server is not the server this custom OnPrem app is built for
        case invalidServer
    }

    // MARK: - Properties

    let username: String?
    let password: String?
    let server: String?

    /// Device ID of a previous installation, only set for credentials from the keychain
    ///
    /// Reusing it keeps the license seat of that installation, because it is sent as the device of
    /// this app to the license check.
    let deviceID: String?

    // MARK: - Lifecycle

    init(query: [String: String]) {
        self.init(
            username: query["username"],
            password: query["password"],
            server: query["server"]
        )
    }

    init(username: String?, password: String?, server: String?, deviceID: String? = nil) {
        self.username = username
        self.password = password
        self.server = server
        self.deviceID = deviceID
    }

    // MARK: - Apply

    /// Writes the credentials into the provided license store, skipping all values managed by MDM
    ///
    /// Values skipped because of MDM count towards the completeness of the result, as long as they
    /// are in the store: a license check can use them. Values stored before don't count, the applied
    /// credentials have to bring them.
    /// - Parameters:
    ///   - licenseStore: Store to write the credentials to
    ///   - mdmSetup: MDM setup deciding which values are managed and must not be overwritten
    ///   - isOnPrem: Whether the app needs an OnPrem server to check the license
    /// - Returns: Whether the resulting configuration is complete enough for a license check
    @discardableResult
    func apply(
        to licenseStore: any LicenseStoreProtocol,
        mdmSetup: any LicenseMDMSetupProtocol,
        isOnPrem: Bool
    ) -> ApplyResult {
        // swiftformat:disable:next acronyms
        let hasValidServer = licenseStore.validCustomOnPremConfigUrl(withPredefinedUrl: server)

        // Values managed by MDM are written to the store by `MDMSetup.loadLicenseInfo()` and are
        // authoritative, so applied credentials must neither overwrite them nor repeat them here.
        let isUsernameManagedByMDM = mdmSetup.existsMdmKey(MDM_KEY_LICENSE_USERNAME)
        let isPasswordManagedByMDM = mdmSetup.existsMdmKey(MDM_KEY_LICENSE_PASSWORD)
        let isServerManagedByMDM = mdmSetup.existsMdmKey(MDM_KEY_ONPREM_SERVER)

        if !isUsernameManagedByMDM {
            licenseStore.licenseUsername = username
        }
        if !isPasswordManagedByMDM {
            licenseStore.licensePassword = password
        }
        if isOnPrem, hasValidServer, !isServerManagedByMDM {
            licenseStore.onPremConfigURL = server
        }

        // MDM never provides a device ID
        if let deviceID {
            licenseStore.licenseDeviceID = deviceID
        }

        // A value skipped because of MDM counts as provided, as long as MDM really put it into the
        // store: an MDM key without a value leaves the store untouched and a check would fail. Values
        // stored before don't count, so credentials that miss values are reported as incomplete
        // instead of starting a check that can only fail. The provided server counts even if it
        // wasn't written, so a link for another custom OnPrem app is reported as invalid below.
        let hasUsername = username != nil || (isUsernameManagedByMDM && licenseStore.licenseUsername != nil)
        let hasPassword = password != nil || (isPasswordManagedByMDM && licenseStore.licensePassword != nil)
        let hasServer = server != nil || (isServerManagedByMDM && licenseStore.onPremConfigURL != nil)

        // Only OnPrem apps need a server to check a license
        let hasRequiredServer = !isOnPrem || hasServer

        // Completeness before validity: credentials without a server aren't credentials for the wrong
        // server. Custom OnPrem apps prefill their server on the license entry screen.
        guard hasUsername, hasPassword, hasRequiredServer else {
            return .incomplete
        }

        // Without a server of their own the credentials use the one of MDM, which was validated when
        // it was written
        guard server == nil || hasValidServer else {
            return .invalidServer
        }

        return .complete
    }
}
