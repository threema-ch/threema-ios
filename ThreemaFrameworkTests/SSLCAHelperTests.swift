import Foundation
import Testing
@testable import ThreemaFramework

struct SSLCAHelperTests {
    private let unpinnedDomain = "unpinned.example.com"
    private let pinnedDomain = "pinned.example.com"

    /// Pin that match the certificate for pinned domain
    private let matchingPins: [[String: DomainSpkisAlgorithm]] = [
        ["Mbr31AYsFplg5jrdDvMHZDQcItKbVcZnVHbHtuyT+Xc=": .sha256],
        ["ntsNvhRgKzcpZPEO/e2PC9mUcVvVQejuwxMGbLi0Ng4=": .sha256],
    ]

    /// Pins that never match any test certificate
    private let neverMatchingPins: [[String: DomainSpkisAlgorithm]] = [
        [Data(repeating: 0x01, count: 32).base64EncodedString(): .sha256],
        [Data(repeating: 0x02, count: 32).base64EncodedString(): .sha256],
    ]

    @Test(arguments: [
        (NSURLAuthenticationMethodNTLM, false),
        (NSURLAuthenticationMethodDefault, false),
        (NSURLAuthenticationMethodNegotiate, false),
        (NSURLAuthenticationMethodHTMLForm, false),
        (NSURLAuthenticationMethodHTTPBasic, false),
        (NSURLAuthenticationMethodHTTPDigest, false),
        (NSURLAuthenticationMethodServerTrust, true),
        (NSURLAuthenticationMethodClientCertificate, false),
    ])
    func canAuthenticate(methode: String?, expectedResult: Bool) {
        let protectionSpace = URLProtectionSpace(
            host: pinnedDomain,
            port: 255,
            protocol: nil,
            realm: nil,
            authenticationMethod: methode
        )

        let result = SSLCAHelper.canAuthenticate(protectionSpace)

        #expect(result == expectedResult)
    }

    // MARK: Test the pinned domain

    @Test func `Evaluate request pinned domain to server with matching pins`() async throws {
        let sslCAHelper = SSLCAHelper(
            serverInfoProvider: makeServerInfoProvider(domain: pinnedDomain, pins: matchingPins),
            systemTrustEvaluation: { _, _ in
                Issue.record("A pinned certificate must not be validated against the system trust store")
                return false
            }
        )

        let trust = try makeTrust(for: makeSelfSignedCertificateForPinnedDomain(), domain: pinnedDomain)
        let isTrusted = await sslCAHelper.evaluate(trust: trust, domain: pinnedDomain)

        #expect(isTrusted == true)
    }

    @Test func `Evaluate request expired pinned domain to server with matching pins`() async throws {
        let sslCAHelper = SSLCAHelper(
            serverInfoProvider: makeServerInfoProvider(domain: pinnedDomain, pins: matchingPins),
            systemTrustEvaluation: { _, _ in
                Issue.record("A pinned certificate must not be validated against the system trust store")
                return false
            }
        )

        let trust = try makeTrust(for: makeSelfSignedCertificateForPinnedDomainExpired(), domain: pinnedDomain)
        let isTrusted = await sslCAHelper.evaluate(trust: trust, domain: pinnedDomain)

        print(isTrusted)

        #expect(isTrusted == false)
    }

    @Test func `Evaluate request pinned domain to server with never matching pins`() async throws {
        let sslCAHelper = SSLCAHelper(
            serverInfoProvider: makeServerInfoProvider(domain: pinnedDomain, pins: neverMatchingPins),
            systemTrustEvaluation: { _, _ in
                Issue.record("A pinned certificate must not be validated against the system trust store")
                return false
            }
        )

        let trust = try makeTrust(for: makeSelfSignedCertificateForPinnedDomain(), domain: pinnedDomain)
        let isTrusted = await sslCAHelper.evaluate(trust: trust, domain: pinnedDomain)

        #expect(isTrusted == false)
    }

    @Test func `Evaluate request pinned domain to server without pins`() async throws {
        var isSystemTrustEvaluationCalled = false

        let sslCAHelper = SSLCAHelper(
            serverInfoProvider: makeServerInfoProvider(domain: pinnedDomain),
            systemTrustEvaluation: { trust, domain in
                isSystemTrustEvaluationCalled = true
                return SSLCAHelper.evaluateWithSystemTrustStore(trust: trust, domain: domain)
            }
        )

        let trust = try makeTrust(for: makeSelfSignedCertificateForPinnedDomain(), domain: pinnedDomain)
        let isTrusted = await sslCAHelper.evaluate(trust: trust, domain: pinnedDomain)

        #expect(isTrusted == true)
        #expect(isSystemTrustEvaluationCalled == true)
    }

    @Test func `Handle request pinned domain to server with matching pins`() async throws {
        let sslCAHelper = SSLCAHelper(
            serverInfoProvider: makeServerInfoProvider(domain: pinnedDomain, pins: matchingPins),
            systemTrustEvaluation: { _, _ in
                Issue.record("Should not be called for handel a challange")
                return false
            }
        )

        let challenge = try URLAuthenticationChallenge(
            protectionSpace: URLProtectionSpaceMock(
                host: pinnedDomain,
                serverTrust: makeTrust(for: makeSelfSignedCertificateForPinnedDomain(), domain: pinnedDomain)
            ),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: URLAuthenticationChallengeSenderMock()
        )

        let result = try await sslCAHelper.handle(challenge: challenge)

        #expect(result.credential != nil)
        #expect(result.disposition == .useCredential)
    }

    @Test func `Handle request pinned domain to server with never matching pins`() async throws {
        let sslCAHelper = SSLCAHelper(
            serverInfoProvider: makeServerInfoProvider(domain: pinnedDomain, pins: neverMatchingPins),
            systemTrustEvaluation: { _, _ in
                Issue.record("Should not be called for handel a challange")
                return false
            }
        )

        let challenge = try URLAuthenticationChallenge(
            protectionSpace: URLProtectionSpaceMock(
                host: pinnedDomain,
                serverTrust: makeTrust(for: makeSelfSignedCertificateForPinnedDomain(), domain: pinnedDomain)
            ),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: URLAuthenticationChallengeSenderMock()
        )

        let result = try await sslCAHelper.handle(challenge: challenge)

        #expect(result.credential == nil)
        #expect(result.disposition == .cancelAuthenticationChallenge)
    }

    @Test func `Handle request pinned domain to server without pins`() async throws {
        let sslCAHelper = SSLCAHelper(
            serverInfoProvider: makeServerInfoProvider(domain: pinnedDomain),
            systemTrustEvaluation: { _, _ in
                Issue.record("Should not be called for handel a challange")
                return false
            }
        )

        let challenge = try URLAuthenticationChallenge(
            protectionSpace: URLProtectionSpaceMock(
                host: pinnedDomain,
                serverTrust: makeTrust(for: makeSelfSignedCertificateForPinnedDomain(), domain: pinnedDomain)
            ),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: URLAuthenticationChallengeSenderMock()
        )

        let result = try await sslCAHelper.handle(challenge: challenge)

        #expect(result.credential == nil)
        #expect(result.disposition == .performDefaultHandling)
    }

    @Test func `Handle request pinned domain no server trust`() async throws {
        let sslCAHelper = SSLCAHelper(
            serverInfoProvider: makeServerInfoProvider(domain: pinnedDomain, pins: matchingPins),
            systemTrustEvaluation: { _, _ in
                Issue.record("Should not be called for handel a challange")
                return false
            }
        )

        let challenge = try URLAuthenticationChallenge(
            protectionSpace: URLProtectionSpaceMock(
                host: pinnedDomain,
                serverTrust: makeTrust(for: makeSelfSignedCertificateForPinnedDomain(), domain: pinnedDomain),
                authenticationMethod: NSURLAuthenticationMethodDefault
            ),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: URLAuthenticationChallengeSenderMock()
        )

        await #expect(throws: SSLCAHelperError.authenticationChallengeNotHandeld) {
            _ = try await sslCAHelper.handle(challenge: challenge)
        }
    }

    // MARK: Test the unpinned domain

    @Test(arguments: [true, false])
    func `Evaluate request unpinned domain to server wit matching pins`(installCertificate: Bool) async throws {
        var isSystemTrustEvaluationCalled = false

        let sslCAHelper = SSLCAHelper(
            serverInfoProvider: makeServerInfoProvider(domain: pinnedDomain, pins: matchingPins),
            systemTrustEvaluation: { trust, domain in
                isSystemTrustEvaluationCalled = true
                return SSLCAHelper.evaluateWithSystemTrustStore(trust: trust, domain: domain)
            }
        )

        let trust = try makeTrust(
            for: makeSelfSignedCertificateForUnpinnedDomain(),
            domain: unpinnedDomain,
            installCertificate: installCertificate
        )
        let isTrusted = await sslCAHelper.evaluate(trust: trust, domain: unpinnedDomain)

        #expect(isTrusted == installCertificate)
        #expect(isSystemTrustEvaluationCalled == true)
    }

    @Test func `Evaluate request expired unpinned domain to server with matching pins`() async throws {
        var isSystemTrustEvaluationCalled = false

        let sslCAHelper = SSLCAHelper(
            serverInfoProvider: makeServerInfoProvider(domain: pinnedDomain, pins: matchingPins),
            systemTrustEvaluation: { trust, domain in
                isSystemTrustEvaluationCalled = true
                return SSLCAHelper.evaluateWithSystemTrustStore(trust: trust, domain: domain)
            }
        )

        let trust = try makeTrust(for: makeSelfSignedCertificateForUnpinnedDomainExpired(), domain: unpinnedDomain)
        let isTrusted = await sslCAHelper.evaluate(trust: trust, domain: unpinnedDomain)

        #expect(isTrusted == false)
        #expect(isSystemTrustEvaluationCalled == true)
    }

    // MARK: Test reset of pinning configuration

    @Test func `Reset cache reloads pinning configuration`() async throws {
        let trust = try makeTrust(for: makeSelfSignedCertificateForPinnedDomain(), domain: pinnedDomain)

        // Server info provider with matching pins
        let serverInfoProviderMock = makeServerInfoProvider(domain: pinnedDomain, pins: matchingPins)

        let sslCAHelper = SSLCAHelper(
            serverInfoProvider: serverInfoProviderMock,
            systemTrustEvaluation: { _, _ in true }
        )

        // Request with matching pins, should be trusted
        let isTrustedWithMachingPins = await sslCAHelper.evaluate(trust: trust, domain: pinnedDomain)
        #expect(isTrustedWithMachingPins == true)

        // Simmulates OPPF reload, server info provider with never matching pins
        serverInfoProviderMock.domainsConfig = [Domain(pinnedDomain, spkis: neverMatchingPins, matchMode: .exact)]
        NotificationCenter.default.post(name: .resetSSLCAHelperCache, object: nil)

        // Request with never matching pins, should be not be trusted
        let isTrustedWithNeverMachingPins = await sslCAHelper.evaluate(trust: trust, domain: pinnedDomain)
        #expect(isTrustedWithNeverMachingPins == false, "The new configuration with never matching pins should be used")

        // Simmulates OPPF reload, server info provider without pins
        serverInfoProviderMock.domainsConfig = []
        NotificationCenter.default.post(name: .resetSSLCAHelperCache, object: nil)

        // Request without pins, should be be trusted. Because it' a unpinned domain!
        let isTrustedWithoutPins = await sslCAHelper.evaluate(trust: trust, domain: pinnedDomain)
        #expect(isTrustedWithoutPins == true, "The new configuration without pins should be used")
    }

    // MARK: - Private helper

    /// Get the configurated `ServerInfoProviderMock`.
    ///
    /// - Parameters:
    ///   - domain: Domain of the server
    ///   - pins: Pins for the domain, nil means no pins
    private func makeServerInfoProvider(domain: String, pins: [[String: DomainSpkisAlgorithm]]? = nil) -> ServerInfoProviderMock {
        var domainsConfig: [Domain]?
        if let pins {
            domainsConfig = [Domain(domain, spkis: pins, matchMode: .exact)]
        }

        return ServerInfoProviderMock(baseURLString: domain, domainsConfig: domainsConfig)
    }

    /// Self-signed certificate for `unpinned.example.com`, until 2027-08-24
    ///
    /// # Generate new certificate and key
    /// openssl req -x509 -new -outform DER \
    ///     -subj "/CN=unpinned.example.com/O=Threema Test Pinned" \
    ///     -addext "basicConstraints = critical, CA:TRUE" \
    ///     -addext "keyUsage = critical, digitalSignature, keyCertSign" \
    ///     -addext "extendedKeyUsage = serverAuth" \
    ///     -addext "subjectAltName = DNS:unpinned.example.com" \
    ///     -days +365 -newkey rsa:2048 -keyout key.pem -out req.pem
    ///
    /// # Convert certificate to base64
    /// openssl enc -base64 -in req.pem
    /// output: see `makeSelfSignedCertificateForUnpinnedDomain()`
    ///
    /// # Extract pin as base64 form ceritificate
    /// openssl x509 -in req.pem -pubkey -noout -inform DER | openssl pkey -pubin -outform der | openssl dgst -sha256
    /// -binary | openssl enc -base64
    /// output: O4yBtAhzfGQ2Iwy5wuvmm6gNh6RPDtiNtVFaS6FGBQs=
    private func makeSelfSignedCertificateForUnpinnedDomain() throws -> SecCertificate {
        try makeCertificate(base64Encoded: """
            MIIDozCCAougAwIBAgIUCdQVediR4CppDXtFqVzYKlWhulcwDQYJKoZIhvcNAQEL\
            BQAwPTEdMBsGA1UEAwwUdW5waW5uZWQuZXhhbXBsZS5jb20xHDAaBgNVBAoME1Ro\
            cmVlbWEgVGVzdCBQaW5uZWQwHhcNMjYwODI4MTUwMTMwWhcNMjcwODI4MTUwMTMw\
            WjA9MR0wGwYDVQQDDBR1bnBpbm5lZC5leGFtcGxlLmNvbTEcMBoGA1UECgwTVGhy\
            ZWVtYSBUZXN0IFBpbm5lZDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB\
            AMZNKfheHEWLSXO1Wt/eA8Tdj5FFnT3EfbeRu1CgUe7+3nZacoSlpayldcVQ1tAo\
            svXCDJWHejAV/Eh36FtNyVywkm1wPS/sIXBkWBj2Jlpn64MDqCClCxzi1IgbYfM3\
            WtnYTIz59wqGxw3AC5zUq3pybe3bqJ/Qg4esI2sFGmyB1VcyJeMAMqecthfBVyd+\
            24oh8nEaZ/Ns7rNsU80P7+hPTexzDzNQSoS4q+XuffDV1GJpkDz9Q04lGRe0464d\
            Awnn1UJ3GMyWXKeMmhQh4ErW0Gr1nxqb980AcTm/NN4N1a9AAxbU5UdGWAUEL5mS\
            TsTXinUTZC4jcSXjoCLouQkCAwEAAaOBmjCBlzAdBgNVHQ4EFgQUryCmkK7TApPC\
            RJVG+E0uo3g+41swHwYDVR0jBBgwFoAUryCmkK7TApPCRJVG+E0uo3g+41swDwYD\
            VR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAoQwEwYDVR0lBAwwCgYIKwYBBQUH\
            AwEwHwYDVR0RBBgwFoIUdW5waW5uZWQuZXhhbXBsZS5jb20wDQYJKoZIhvcNAQEL\
            BQADggEBAFgddwxKLGrLeOLqPIPJgMVFD46PkAyopUtlllfXLicrIqoyvI908dHN\
            aEuGpDIm37Bop3zhJNKKo/1piL+pYt7bULChnuE4eARHL32Wss+ym2RCQRYhC4m1\
            gMPCzuGs9AV1ACerLnDdn3BvHLKwbOmLuEC+F9pD3u+Ef7I13cZTzl5SIPL+6Osg\
            wzwr0Ezxvg2t4io69hC4BTfbVgiflll1LKE2tRSwdMldECr9tYZ5ffSsmJvdAQpP\
            yKbH97u8JplfSYaHZmUN23e8CWTvznn5x3lxIszlzFv6vsLVFE1s0DmVWJhK6Tu+\
            RnWBdDB2By5Wzr12WC6/76vWWeL5vHc=
            """)
    }

    /// Self-signed certificate for `unpinned.example.com`, until 2026-08-29
    ///
    /// # Generate new certificate and key
    /// openssl req -x509 -new -outform DER \
    ///     -subj "/CN=unpinned.example.com/O=Threema Test Pinned" \
    ///     -addext "basicConstraints = critical, CA:TRUE" \
    ///     -addext "keyUsage = critical, digitalSignature, keyCertSign" \
    ///     -addext "extendedKeyUsage = serverAuth" \
    ///     -addext "subjectAltName = DNS:unpinned.example.com" \
    ///     -days +1 -newkey rsa:2048 -keyout key.pem -out req.pem
    ///
    /// # Convert certificate to base64
    /// openssl enc -base64 -in req.pem
    /// output: see `makeSelfSignedCertificateForUnpinnedDomainExpired()`
    ///
    /// # Extract pin as base64 form ceritificate
    /// openssl x509 -in req.pem -pubkey -noout -inform DER | openssl pkey -pubin -outform der | openssl dgst -sha256
    /// -binary | openssl enc -base64
    /// output: acKH3X1Q+IzBB88Pi7IhoChuOM854V7Z3GVu11EloUk=
    private func makeSelfSignedCertificateForUnpinnedDomainExpired() throws -> SecCertificate {
        try makeCertificate(base64Encoded: """
            MIIDozCCAougAwIBAgIUC6G+mlCdbgkeALKdX5gwTtg1iBIwDQYJKoZIhvcNAQEL\
            BQAwPTEdMBsGA1UEAwwUdW5waW5uZWQuZXhhbXBsZS5jb20xHDAaBgNVBAoME1Ro\
            cmVlbWEgVGVzdCBQaW5uZWQwHhcNMjYwODI4MTYwNjI2WhcNMjYwODI5MTYwNjI2\
            WjA9MR0wGwYDVQQDDBR1bnBpbm5lZC5leGFtcGxlLmNvbTEcMBoGA1UECgwTVGhy\
            ZWVtYSBUZXN0IFBpbm5lZDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB\
            ALJtXKL2A/s2o9Tt5jNpz7fjzF/FM4g8v0pz8hT6DWJg+688aY5Gqx2WHQiSm+5B\
            ZNEeZoWvxOetr5SsplpJTNyJc+4SY8Sr3kVYhyEV8SliFgcMYQp+htwEJfX4XHy2\
            1PVF7uFNDBqj2epnYov+81cYUZUpwGAqJ4ZAb1vsXjJW73oLcOGMUqhHfRn5T1rj\
            KnaaomFOaKoY0PizctMrPFhOhzbL+MD1v5dih3+RCfpn+8QEKsnV8z9wFeplTg61\
            RU6xZ5xxMk5e1Ffs0eVBclPq4oVjJ36iOJYQ4qof0ZLHy9qrSDbDFesMFXAWGxnh\
            mZNczIOocJGRlrWZxrBn73kCAwEAAaOBmjCBlzAdBgNVHQ4EFgQUbnwxB27Dwqjd\
            xELnMgnGwOTPMk8wHwYDVR0jBBgwFoAUbnwxB27DwqjdxELnMgnGwOTPMk8wDwYD\
            VR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAoQwEwYDVR0lBAwwCgYIKwYBBQUH\
            AwEwHwYDVR0RBBgwFoIUdW5waW5uZWQuZXhhbXBsZS5jb20wDQYJKoZIhvcNAQEL\
            BQADggEBABjmgJGuf6UMvanMYvoClGHsfZoJ8Mbqxw1dxNEwZtAlBtwT535EoMB7\
            C0su/Cbhh3SxKZpoXQi59zUXDpjhcE489bFAy7WLYGOzOViBr7p4oZ//zTjlhVn9\
            jfbuHHwHcxlPx1KI2Ocs8Gd85tM3dzJa6xvA8lO6u8JUmwgL4AvZ+ooLZQgWXZOU\
            c7POz167JrmVIUjC/svkUjKp3/8MzRsqpaBcaTPMOjNBKoq0nJwOH9ZL+xEApSx8\
            QJFdkaMHEbnLs6nmmBp5kAoNplXAWY2a99Hcub2/y8RFHmQ2rrdg97Zw0HCB09MK\
            VENcR0k0uq0/hDYnMA3TpbMXlA82M4Q=
            """)
    }

    /// Self-signed certificate for `pinned.example.com`, until 2027-08-24
    ///
    /// # Generate new certificate and key
    /// openssl req -x509 -new -outform DER -subj "/CN=pinned.example.com/O=Threema Test Pinned" \
    ///     -addext "basicConstraints = critical, CA:TRUE" \
    ///     -addext "keyUsage = critical, digitalSignature, keyCertSign" \
    ///     -addext "extendedKeyUsage = serverAuth" \
    ///     -addext "subjectAltName = DNS:pinned.example.com" \
    ///     -days +365 -newkey rsa:2048 -keyout key.pem -out req.pem
    ///
    /// # Convert certificate to base64
    /// openssl enc -base64 -in req.pem
    /// output: see `makeSelfSignedCertificateForPinnedDomain()`
    ///
    /// # Extract pin as base64 form ceritificate
    /// openssl x509 -in req.pem -pubkey -noout -inform DER | openssl pkey -pubin -outform der | openssl dgst -sha256
    /// -binary | openssl enc -base64
    /// output: Mbr31AYsFplg5jrdDvMHZDQcItKbVcZnVHbHtuyT+Xc=
    private func makeSelfSignedCertificateForPinnedDomain() throws -> SecCertificate {
        try makeCertificate(base64Encoded: """
            MIIDnTCCAoWgAwIBAgIUNI+PJiniWkfxshJwpwCKLc381lAwDQYJKoZIhvcNAQEL\
            BQAwOzEbMBkGA1UEAwwScGlubmVkLmV4YW1wbGUuY29tMRwwGgYDVQQKDBNUaHJl\
            ZW1hIFRlc3QgUGlubmVkMB4XDTI2MDgyODEzNDUyM1oXDTI3MDgyODEzNDUyM1ow\
            OzEbMBkGA1UEAwwScGlubmVkLmV4YW1wbGUuY29tMRwwGgYDVQQKDBNUaHJlZW1h\
            IFRlc3QgUGlubmVkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAkFvR\
            Q3910MqoqCg9E9UMPP+Esp14Uw/JmOyE9BqEPzWfUAcVuVEn25KPQL3hPe2sHjMb\
            r7GwGKIEmByO9BqYn+P1lli1Y5Z6aoCtIfIHdnyStRYmh6skVHx0EmCzKOlgvLVi\
            FE7/KjQffht6z7RXf+qiKC7ZyZ530Wmqa076J4XY1zA4hbCw7bXQLR7XL4B3gHpI\
            O2jw22WSZw+EW11G1BIih1QJc2BOFvyjkpDA2wVcCk6MRReBjvoZCtjxo1eobpm3\
            CYIQ9b1mIJuooSMfaTO5sW9IG3bW+gfRhcHPZYEGjSvccjCVLPi46OrWai2aUeAJ\
            lsn1s9mfThVXL+Fd8QIDAQABo4GYMIGVMB0GA1UdDgQWBBT132mynHjLW2tOont+\
            v+da6VgK5jAfBgNVHSMEGDAWgBT132mynHjLW2tOont+v+da6VgK5jAPBgNVHRMB\
            Af8EBTADAQH/MA4GA1UdDwEB/wQEAwIChDATBgNVHSUEDDAKBggrBgEFBQcDATAd\
            BgNVHREEFjAUghJwaW5uZWQuZXhhbXBsZS5jb20wDQYJKoZIhvcNAQELBQADggEB\
            AI8VsHOEVIXZ8CJbXCRtZkbHOW29NY3QxVzHIOrzl0Pz7gxpbC6cNMV7mOtTb4OM\
            bobxwHdu0GSABLhEY/gQqlz4/uU9aFAeqJW2RGLic7IhdFfjvOd77I0+/q2SkL2i\
            qW90hqn9ey3d7JTfCfzrlkRwGGbW8hpnjPWMO1q7/deSN3fvtCiFpKQpqlb8VWJi\
            CfNfj9SU+yL2Sv0UYf9bnVH3l12H/zilem8VnOMlNqxCE+0OeFJvHaPNhY1yPowe\
            oXnJMv0nCY7Aba7gaMAzZTSdlRB/E0KOf9B/5aSrggrWYYYAI0t5nDK3xBN0yxpT\
            NipAwGJMwwE/s4NuERFbxwo=
            """)
    }

    /// Self-signed certificate for `pinned.example.com`, until 2026-09-11
    ///
    /// # Generate new certificate and key
    /// openssl req -x509 -new -outform DER \
    ///     -subj "/CN=pinned.example.com/O=Threema Test Pinned" \
    ///     -addext "basicConstraints = critical, CA:TRUE" \
    ///     -addext "keyUsage = critical, digitalSignature, keyCertSign" \
    ///     -addext "extendedKeyUsage = serverAuth" \
    ///     -addext "subjectAltName = DNS:pinned.example.com" \
    ///     -days +1 -newkey rsa:2048 -keyout key.pem -out req.pem
    ///
    /// # Convert certificate to base64
    /// openssl enc -base64 -in req.pem
    /// output: see `makeSelfSignedCertificateForPinnedDomainExpired()`
    ///
    /// # Extract pin as base64 form ceritificate
    /// openssl x509 -in req.pem -pubkey -noout -inform DER | openssl pkey -pubin -outform der | openssl dgst -sha256
    /// -binary | openssl enc -base64
    /// output: ntsNvhRgKzcpZPEO/e2PC9mUcVvVQejuwxMGbLi0Ng4=
    private func makeSelfSignedCertificateForPinnedDomainExpired() throws -> SecCertificate {
        try makeCertificate(base64Encoded: """
            MIIDnTCCAoWgAwIBAgIUQItvpZ+HJ7S6UdlRJfk4BYmvTRwwDQYJKoZIhvcNAQEL\
            BQAwOzEbMBkGA1UEAwwScGlubmVkLmV4YW1wbGUuY29tMRwwGgYDVQQKDBNUaHJl\
            ZW1hIFRlc3QgUGlubmVkMB4XDTI2MDkxMDA2NTU0OVoXDTI2MDkxMTA2NTU0OVow\
            OzEbMBkGA1UEAwwScGlubmVkLmV4YW1wbGUuY29tMRwwGgYDVQQKDBNUaHJlZW1h\
            IFRlc3QgUGlubmVkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmQps\
            0IhLWNcTgG0/SSR4h3PCHQEkOf8PtRpl195Rz6SSPLovSCfRCbNJ5ywJNC8HwB/g\
            Nq8pqAdwwetzi5xhbe4BWgKliZ3VZSwCQhsQfQ59rDHXvF4oOFKgRioCn4R+DR4b\
            y+f7mcwb/Fb5U3smqc2pI1KpmYqIOaWTfHDHJ8TiaoRwdOdp6qYPmOEcSZSCruK1\
            YjQQ8P1rtbusVUzRDs6lbZWZrODjUaxCUufc5lTX7/Z2SI+wvB2pE4w7UvuYBiVf\
            9VCO3UzaBctZahZGsJcWXqbBCy6fFE7C6GCCEDj0Sf69bAdBOr6gA+innPOq/RWu\
            vNozv3ALH0skmDLBswIDAQABo4GYMIGVMB0GA1UdDgQWBBTwXtlWENyaFiN4JimY\
            346pdH3v2TAfBgNVHSMEGDAWgBTwXtlWENyaFiN4JimY346pdH3v2TAPBgNVHRMB\
            Af8EBTADAQH/MA4GA1UdDwEB/wQEAwIChDATBgNVHSUEDDAKBggrBgEFBQcDATAd\
            BgNVHREEFjAUghJwaW5uZWQuZXhhbXBsZS5jb20wDQYJKoZIhvcNAQELBQADggEB\
            AAo3zfYHJvxmpVrnL78YqMQUK9+hxAOToph91/luNkZS5s0G9MetZte/f9TVnQUv\
            zEeDhU/TRg8yctFC5MYLHD5ahFlwIiTlZvtTtLr9flS4rpbwHk4BjllQ38yboDHb\
            kFEm1/ker7m15nCm2bbLIHPakvV4EKeEpLXvMb+JE/Ytxn39pqCeg4CM+2GMo7Ax\
            UXxl/ozbkIx1RmXnHYfKm15m0wGh1A/bWfPYxfLkYMzVCOCIHrjOLDQ4HYtJA4vh\
            WbyhfQsr9A1XjxTnGUiwiNqTWu17wuwgTNWjgEWFrSGSQrOXN1tHHON7P8UTi+Mp\
            y95Y0ZaKn3GMgH8bwWpLQTY=
            """)
    }

    private func makeCertificate(base64Encoded certificate: String) throws -> SecCertificate {
        let data = try #require(Data(base64Encoded: certificate))

        return try #require(SecCertificateCreateWithData(nil, data as CFData))
    }

    private func makeTrust(for certificate: SecCertificate, domain: String, installCertificate: Bool = true) throws -> SecTrust {
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(certificate, SecPolicyCreateSSL(true, domain as CFString), &trust)

        #expect(status == errSecSuccess)

        let validTrust = try #require(trust)

        if installCertificate {
            // Trust the test certificate itself, so the expiration is the only remaining reason for a rejection.
            // Otherwise the certificate must be installed in the simulator (like xcrun simctl keychain booted
            // add-root-cert
            // req.pem).
            #expect(SecTrustSetAnchorCertificates(validTrust, [certificate] as CFArray) == errSecSuccess)
            #expect(SecTrustSetAnchorCertificatesOnly(validTrust, true) == errSecSuccess)
        }

        return validTrust
    }

    // MARK: Mocks

    final class URLAuthenticationChallengeSenderMock: NSObject, URLAuthenticationChallengeSender {
        func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {
            // no-op
        }

        func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {
            // no-op
        }

        func cancel(_ challenge: URLAuthenticationChallenge) {
            // no-op
        }
    }

    final class URLProtectionSpaceMock: URLProtectionSpace, @unchecked Sendable {
        private let trust: SecTrust

        init(
            host: String,
            serverTrust trust: SecTrust,
            authenticationMethod: String? = NSURLAuthenticationMethodServerTrust
        ) {
            self.trust = trust
            super.init(host: host, port: 255, protocol: nil, realm: nil, authenticationMethod: authenticationMethod)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var serverTrust: SecTrust? {
            trust
        }
    }
}
