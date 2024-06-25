//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CocoaLumberjackSwift
import Foundation
import TrustKit

class SSLCAHelper: NSObject, SSLCAHelperProtocol {

    private var cachedTrustKit: TrustKit?
    private var cachedConfiguredDomains: [String]?

    /// Check is authentication mode like server trust.
    /// - Parameter protectionSpace: Received protection space
    /// - Returns: True if server trust
    @objc static func canAuthenticate(_ protectionSpace: URLProtectionSpace) -> Bool {
        protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
    }

    /// Handling authentication challenges received within a NSURLSessionDelegate.
    /// - Parameter challenge: Authentication challenge
    /// - Returns: Disposition and credential to respond to the challenge
    @objc func handle(challenge: URLAuthenticationChallenge) async throws
        -> (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?) {

        let (trustKit, _) = try await initTrustKit()

        return try await withCheckedThrowingContinuation { continuation in
            // Pass the authentication challenge to the validator; if the validation fails, the connection will be
            // blocked
            let isSuccessfullyHandled = trustKit.pinningValidator.handle(challenge) { disposition, credential in
                switch disposition {
                case .useCredential:
                    if let credential {
                        challenge.sender?.use(credential, for: challenge)
                    }
                    else {
                        // TOCHECK:
                        challenge.sender?.continueWithoutCredential(for: challenge)
                    }
                case .performDefaultHandling:
                    challenge.sender?.performDefaultHandling?(for: challenge)
                case .cancelAuthenticationChallenge:
                    challenge.sender?.cancel(challenge)
                case .rejectProtectionSpace:
                    challenge.sender?.rejectProtectionSpaceAndContinue?(with: challenge)
                @unknown default:
                    challenge.sender?.continueWithoutCredential(for: challenge)
                }

                continuation.resume(returning: (disposition, credential))
            }

            if !isSuccessfullyHandled {
                DDLogWarn("The challenge could not be handled because it was not for server certificate validation.")
            }
        }
    }

    /// Evaluate the supplied server trust against the SSL pinning policy.
    /// - Parameters:
    /// - trust: Server trust
    /// - domain: Hostname of the server
    /// - completionHandler: True means connection is allowed
    func evaluate(trust: SecTrust, domain: String, completionHandler: @escaping (Bool) -> Void) {
        Task {
            await completionHandler(evaluate(trust: trust, domain: domain))
        }
    }

    /// Evaluate the supplied server trust against the SSL pinning policy.
    /// - Parameters:
    /// - trust: Server trust
    /// - domain: Hostname of the server
    /// - Returns: True means connection is allowed
    func evaluate(trust: SecTrust, domain: String) async -> Bool {
        do {
            let (trustKit, configuredDomains) = try await initTrustKit()

            if trustKit.pinningValidator.evaluateTrust(trust, forHostname: domain) != .shouldAllowConnection {
                // Check is domain configured, if not than allow anyway
                return !configuredDomains.contains(domain)
            }

            return true
        }
        catch {
            DDLogError("Evaluate of trust failed \(error)")
            return false
        }
    }

    /// Loads TrustKit with SSL cert pinning config for Public or OnPrem server
    private func initTrustKit() async throws -> (trustKit: TrustKit, configuredDomains: [String]) {
        if let cachedTrustKit, let cachedConfiguredDomains {
            return (cachedTrustKit, cachedConfiguredDomains)
        }

        let result: (
            trustKit: TrustKit,
            configuredDomains: [String]
        ) = try await withCheckedThrowingContinuation { continuation in
            ServerInfoProviderFactory.makeServerInfoProvider().domains { domains, error in
                if let error {
                    return continuation.resume(throwing: error)
                }

                guard let domains else {
                    return continuation.resume(throwing: OnPremConfigError.missingDomainsConfig)
                }

                // Add configured domains
                var trustKitConfig = [String: Any]()
                trustKitConfig[kTSKSwizzleNetworkDelegates] = false

                var pinnedDomains = [String: Any]()
                var configuredDomains = [String]()

                for rule in domains {
                    guard !rule.spkis.isEmpty else {
                        return continuation.resume(throwing: OnPremConfigError.noDomainSpkis)
                    }

                    guard rule.matchMode != .unsupported else {
                        return continuation.resume(throwing: OnPremConfigError.unsupportedDomainMatchMode)
                    }

                    guard rule.spkis.map(\.values.first!).filter({ $0 == .unsupported }).isEmpty else {
                        return continuation.resume(throwing: OnPremConfigError.unsupportedDomainSpkisAlgorithm)
                    }

                    var pinnedDomain = [String: Any]()

                    pinnedDomain[kTSKIncludeSubdomains] = rule.matchMode == .includeSubdomains

                    var publicKeyHashes: [String] = rule.spkis.map(\.keys.first!)
                    // Test with wrong keys
                    // var publicKeyHashes: [String] = [
                    //    BytesUtility.generateRandomBytes(length: 32)!.base64EncodedString()
                    // ]

                    // TrustKit must have min. 2 pins! Adding fake pin if only one configured
                    if publicKeyHashes.count == 1 {
                        publicKeyHashes.append(BytesUtility.generateRandomBytes(length: 32)!.base64EncodedString())
                    }
                    pinnedDomain[kTSKPublicKeyHashes] = publicKeyHashes
                    pinnedDomain[kTSKEnforcePinning] = true
                    if let reportUris = rule.reportUris {
                        pinnedDomain[kTSKReportUris] = reportUris
                    }
                    else {
                        pinnedDomain[kTSKDisableDefaultReportUri] = true
                    }

                    pinnedDomains[rule.domain] = pinnedDomain
                    configuredDomains.append(rule.domain)
                }

                trustKitConfig[kTSKPinnedDomains] = pinnedDomains

                continuation.resume(returning: (TrustKit(configuration: trustKitConfig), configuredDomains))
            }
        }

        cachedTrustKit = result.trustKit
        cachedConfiguredDomains = result.configuredDomains

        return (result.trustKit, result.configuredDomains)
    }
}
