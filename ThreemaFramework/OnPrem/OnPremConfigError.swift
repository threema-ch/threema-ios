// swiftformat:disable acronyms

import Foundation
import ThreemaMacros

enum OnPremConfigError: Int, Error {
    case badInputOppfData
    case unsupportedVersion
    case badSignature
    case signatureKeyMismatch
    case missingConfigurationURL
    case missingLicenseInfo
    case missingPublicKeys
    case invalidPublicKey
    case unauthorized
    case missingWorkConfig
    case missingAvatarConfig
    case missingSafeConfig
    case missingMediatorConfig
    case missingRendezvousConfig
    case missingWebServerInfoConfig
    case missingDomainsConfig
    case noDomainSpkis
    case unsupportedDomainMatchMode
    case unsupportedDomainSpkisAlgorithm
    case licenseExpired
    case fetchRequestFailed
}

// MARK: - LocalizedError

extension OnPremConfigError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .badInputOppfData, .badSignature, .signatureKeyMismatch, .missingConfigurationURL,
             .missingLicenseInfo, .missingPublicKeys, .invalidPublicKey, .missingWorkConfig,
             .missingAvatarConfig, .missingSafeConfig, .missingMediatorConfig,
             .missingRendezvousConfig, .missingWebServerInfoConfig, .missingDomainsConfig,
             .noDomainSpkis, .unsupportedDomainMatchMode, .unsupportedDomainSpkisAlgorithm,
             .fetchRequestFailed:
            String.localizedStringWithFormat(
                #localize("enter_license_onprem_error_config"),
                TargetManager.appName,
                rawValue
            )
       
        case .unsupportedVersion:
            String.localizedStringWithFormat(
                #localize("enter_license_onprem_error_version"),
                TargetManager.appName,
                rawValue
            )

        case .unauthorized, .licenseExpired:
            String.localizedStringWithFormat(
                #localize("enter_license_onprem_error_credentials"),
                TargetManager.appName,
                rawValue
            )
        }
    }
}
