import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials
import TrustKit

enum SSLCAHelperError: Error {
    case authenticationChallengeNotHandeld
}

final class SSLCAHelper: NSObject, SSLCAHelperProtocol {

    /// Validation of a certificate chain against the systems trust store
    typealias SystemTrustEvaluation = (_ trust: SecTrust, _ domain: String) -> Bool

    private let serverInfoProvider: ServerInfoProvider
    private let systemTrustEvaluation: SystemTrustEvaluation

    private var cachedTrustKit: TrustKit?

    // MARK: - Lifecycle

    override convenience init() {
        self.init(serverInfoProvider: ServerInfoProviderFactory.makeServerInfoProvider())
    }

    /// - Parameters:
    ///   - serverInfoProvider: Provides the pinning configuration (e.g. from the OPPF for OnPrem)
    ///   - systemTrustEvaluation: Validation for domains without pins
    init(
        serverInfoProvider: ServerInfoProvider,
        systemTrustEvaluation: @escaping SystemTrustEvaluation = SSLCAHelper.evaluateWithSystemTrustStore
    ) {
        self.serverInfoProvider = serverInfoProvider
        self.systemTrustEvaluation = systemTrustEvaluation

        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetCache),
            name: .resetSSLCAHelperCache,
            object: nil
        )
    }

    // MARK: - Public methods

    /// Check is authentication mode like server trust.
    /// - Parameter protectionSpace: Received protection space
    /// - Returns: True if server trust
    static func canAuthenticate(_ protectionSpace: URLProtectionSpace) -> Bool {
        protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
    }

    /// Handling authentication challenges received within a NSURLSessionDelegate.
    /// - Parameter challenge: Authentication challenge
    /// - Returns: Disposition and credential to respond to the challenge
    @objc func handle(challenge: URLAuthenticationChallenge) async throws
        -> (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?) {

        let trustKit = try await initTrustKit()

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
                        challenge.sender?.continueWithoutCredential(for: challenge)
                    }
                case .performDefaultHandling:
                    challenge.sender?.performDefaultHandling?(for: challenge)
                case .cancelAuthenticationChallenge:
                    challenge.sender?.cancel(challenge)
                case .rejectProtectionSpace:
                    challenge.sender?.rejectProtectionSpaceAndContinue?(with: challenge)
                }

                continuation.resume(returning: (disposition, credential))
            }

            if !isSuccessfullyHandled {
                DDLogWarn("The challenge could not be handled because it was not for server certificate validation.")
                continuation.resume(throwing: SSLCAHelperError.authenticationChallengeNotHandeld)
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
    ///
    /// This is the only trust evaluation for connections using a custom cert pinner (i.e. the mediator web socket).
    /// Such a pinner replaces the systems own chain validation, thus every case that is not pinned must still be
    /// validated here.
    func evaluate(trust: SecTrust, domain: String) async -> Bool {
        do {
            let trustKit = try await initTrustKit()

            let trustDecision = trustKit.pinningValidator.evaluateTrust(trust, forHostname: domain)

            switch trustDecision {
            case .shouldAllowConnection:
                return true

            case .domainNotPinned:
                // Pinning is optional (e.g. for OnPrem), so a domain without pins must not be rejected. It still needs
                // standard system validation, because no one else does it for us.
                return systemTrustEvaluation(trust, domain)

            case .shouldBlockConnection:
                DDLogError("Pinning validation of domain \(domain) failed")
                return false

            @unknown default:
                DDLogError("Unknown trust decision for domain \(domain)")
                return false
            }
        }
        catch {
            DDLogError("Evaluate of trust failed \(error)")
            return false
        }
    }

    /// Standard system validation of the certificate chain, including the hostname.
    /// - Returns: True if the chain is valid for this hostname
    static func evaluateWithSystemTrustStore(trust: SecTrust, domain: String) -> Bool {
        SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, domain as CFString))

        var error: CFError?
        let isValidChain = SecTrustEvaluateWithError(trust, &error)
        if !isValidChain {
            DDLogError("Standard trust evaluation of unpinned domain \(domain) failed: \(String(describing: error))")
        }

        return isValidChain
    }

    // MARK: - Private helper

    /// Reset cache to pick up most recent pins from OPPF if needed
    @objc private func resetCache() {
        cachedTrustKit = nil
    }

    /// Loads TrustKit with SSL cert pinning config for Public or OnPrem server
    private func initTrustKit() async throws -> TrustKit {
        if let cachedTrustKit {
            return cachedTrustKit
        }

        let provider = serverInfoProvider

        let trustKit: TrustKit = try await withCheckedThrowingContinuation { continuation in
            provider.domains { domains, error in
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
                }

                trustKitConfig[kTSKPinnedDomains] = pinnedDomains

                continuation.resume(returning: TrustKit(configuration: trustKitConfig))
            }
        }

        cachedTrustKit = trustKit

        return trustKit
    }
}
