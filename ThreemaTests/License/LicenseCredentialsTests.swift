import Foundation
import Testing
import ThreemaFramework
@testable import Threema

private let testUsername = "test-user"
private let testPassword = "test-password"
private let testServer = "https://onprem.example.com"
private let mdmUsername = "mdm-user"
private let mdmPassword = "mdm-password"
private let mdmServer = "https://mdm.example.com"

struct LicenseCredentialsTests {
    
    // MARK: - Private properties

    private var completeCredentials: LicenseCredentials {
        LicenseCredentials(
            username: testUsername,
            password: testPassword,
            server: testServer
        )
    }

    // MARK: - Parsing

    @Test("Credentials are read from the query of a license activation link")
    func parsesQuery() {
        let credentials = LicenseCredentials(query: [
            "username": testUsername,
            "password": testPassword,
            "server": testServer,
        ])

        #expect(credentials.username == testUsername)
        #expect(credentials.password == testPassword)
        #expect(credentials.server == testServer)
    }

    @Test("A link without a query has no credentials")
    func parsesEmptyQuery() {
        let credentials = LicenseCredentials(query: [:])

        #expect(credentials.username == nil)
        #expect(credentials.password == nil)
        #expect(credentials.server == nil)
    }

    // MARK: - Apply

    @Test("Credentials are written to the license store")
    func appliesCredentials() {
        let licenseStore = LicenseStoreMock()

        let result = completeCredentials.apply(
            to: licenseStore,
            mdmSetup: LicenseMDMSetupMock(),
            isOnPrem: true
        )

        #expect(result == .complete)
        #expect(licenseStore.licenseUsername == testUsername)
        #expect(licenseStore.licensePassword == testPassword)
        #expect(licenseStore.onPremConfigURL == testServer)
    }

    @Test("The server is not written for flavors that don't use an OnPrem server")
    func doesNotApplyServerForNonOnPremFlavors() {
        let licenseStore = LicenseStoreMock()

        let result = completeCredentials.apply(
            to: licenseStore,
            mdmSetup: LicenseMDMSetupMock(),
            isOnPrem: false
        )

        #expect(result == .complete)
        #expect(licenseStore.onPremConfigURL == nil)
    }

    @Test("The server of a link for another custom OnPrem app is not written")
    func doesNotApplyInvalidServer() {
        let licenseStore = LicenseStoreMock()
        licenseStore.validCustomOnPremConfigURLResult = false

        let result = completeCredentials.apply(
            to: licenseStore,
            mdmSetup: LicenseMDMSetupMock(),
            isOnPrem: true
        )

        #expect(result == .invalidServer)
        #expect(licenseStore.onPremConfigURL == nil)
    }

    // MARK: - MDM

    @Test("Values managed by MDM are not overwritten", arguments: [
        MDM_KEY_LICENSE_USERNAME,
        MDM_KEY_LICENSE_PASSWORD,
        MDM_KEY_ONPREM_SERVER,
    ])
    func doesNotOverwriteMDMManagedValues(managedKey: String) {
        // MDM values are in the store before a link is applied (`MDMSetup.loadLicenseInfo()`)
        let licenseStore = LicenseStoreMock()
        licenseStore.licenseUsername = mdmUsername
        licenseStore.licensePassword = mdmPassword
        licenseStore.onPremConfigURL = mdmServer
        let mdmSetup = LicenseMDMSetupMock(managedKeys: [managedKey])

        let result = completeCredentials.apply(to: licenseStore, mdmSetup: mdmSetup, isOnPrem: true)

        #expect(result == .complete)
        #expect(licenseStore.licenseUsername == (managedKey == MDM_KEY_LICENSE_USERNAME ? mdmUsername : testUsername))
        #expect(licenseStore.licensePassword == (managedKey == MDM_KEY_LICENSE_PASSWORD ? mdmPassword : testPassword))
        #expect(licenseStore.onPremConfigURL == (managedKey == MDM_KEY_ONPREM_SERVER ? mdmServer : testServer))
    }

    @Test("A link may omit the values managed by MDM", arguments: [
        MDM_KEY_LICENSE_USERNAME,
        MDM_KEY_LICENSE_PASSWORD,
        MDM_KEY_ONPREM_SERVER,
    ])
    func reportsLinkWithoutMDMManagedValuesAsComplete(managedKey: String) {
        // MDM values are in the store before a link is applied (`MDMSetup.loadLicenseInfo()`)
        let licenseStore = LicenseStoreMock()
        licenseStore.licenseUsername = managedKey == MDM_KEY_LICENSE_USERNAME ? testUsername : nil
        licenseStore.licensePassword = managedKey == MDM_KEY_LICENSE_PASSWORD ? testPassword : nil
        licenseStore.onPremConfigURL = managedKey == MDM_KEY_ONPREM_SERVER ? testServer : nil

        let credentials = LicenseCredentials(
            username: managedKey == MDM_KEY_LICENSE_USERNAME ? nil : testUsername,
            password: managedKey == MDM_KEY_LICENSE_PASSWORD ? nil : testPassword,
            server: managedKey == MDM_KEY_ONPREM_SERVER ? nil : testServer
        )

        let result = credentials.apply(
            to: licenseStore,
            mdmSetup: LicenseMDMSetupMock(managedKeys: [managedKey]),
            isOnPrem: true
        )

        #expect(result == .complete)
        #expect(licenseStore.licenseUsername == testUsername)
        #expect(licenseStore.licensePassword == testPassword)
        #expect(licenseStore.onPremConfigURL == testServer)
    }

    /// An MDM key can exist without a usable value, which `MDMSetup.loadLicenseInfo()` doesn't write.
    /// Such a link is incomplete: a license check with it could only fail.
    @Test("A link without a value that MDM manages but didn't store is incomplete", arguments: [
        MDM_KEY_LICENSE_USERNAME,
        MDM_KEY_LICENSE_PASSWORD,
        MDM_KEY_ONPREM_SERVER,
    ])
    func reportsLinkWithoutUnstoredMDMManagedValuesAsIncomplete(managedKey: String) {
        let credentials = LicenseCredentials(
            username: managedKey == MDM_KEY_LICENSE_USERNAME ? nil : testUsername,
            password: managedKey == MDM_KEY_LICENSE_PASSWORD ? nil : testPassword,
            server: managedKey == MDM_KEY_ONPREM_SERVER ? nil : testServer
        )

        let result = credentials.apply(
            to: LicenseStoreMock(),
            mdmSetup: LicenseMDMSetupMock(managedKeys: [managedKey]),
            isOnPrem: true
        )

        #expect(result == .incomplete)
    }

    @Test("A value managed by MDM is not written at all")
    func doesNotWriteMDMManagedValue() {
        let licenseStore = LicenseStoreMock()
        let mdmSetup = LicenseMDMSetupMock(managedKeys: [MDM_KEY_LICENSE_USERNAME])

        completeCredentials.apply(to: licenseStore, mdmSetup: mdmSetup, isOnPrem: true)

        #expect(licenseStore.licenseUsernameSetCount == 0)
        #expect(licenseStore.licensePasswordSetCount == 1)
    }

    // MARK: - Completeness

    @Test("Completeness depends on the values of the link and the flavor", arguments: [
        CompletenessFixture(
            username: testUsername, password: testPassword, server: testServer,
            isOnPrem: false, expected: .complete
        ),
        CompletenessFixture(
            username: testUsername, password: testPassword, server: nil,
            isOnPrem: false, expected: .complete
        ),
        CompletenessFixture(
            username: testUsername, password: testPassword, server: testServer,
            isOnPrem: true, expected: .complete
        ),
        CompletenessFixture(
            username: testUsername, password: testPassword, server: nil,
            isOnPrem: true, expected: .incomplete
        ),
        CompletenessFixture(
            username: testUsername, password: nil, server: testServer,
            isOnPrem: true, expected: .incomplete
        ),
        CompletenessFixture(
            username: nil, password: testPassword, server: testServer,
            isOnPrem: true, expected: .incomplete
        ),
        CompletenessFixture(
            username: nil, password: nil, server: nil,
            isOnPrem: false, expected: .incomplete
        ),
    ])
    func reportsCompleteness(fixture: CompletenessFixture) {
        let credentials = LicenseCredentials(
            username: fixture.username,
            password: fixture.password,
            server: fixture.server
        )

        let result = credentials.apply(
            to: LicenseStoreMock(),
            mdmSetup: LicenseMDMSetupMock(),
            isOnPrem: fixture.isOnPrem
        )

        #expect(result == fixture.expected)
    }

    /// Credentials of an earlier link or entry are not managed by MDM and were checked already, so a
    /// link that misses values doesn't become complete through them: a check with them would only
    /// fail again.
    @Test("Values stored before don't complete a link")
    func reportsIncompleteLinkOnTopOfStoredValues() {
        let licenseStore = LicenseStoreMock()
        licenseStore.licenseUsername = testUsername
        licenseStore.licensePassword = testPassword
        licenseStore.onPremConfigURL = testServer

        let credentials = LicenseCredentials(
            username: testUsername,
            password: nil,
            server: testServer
        )

        let result = credentials.apply(
            to: licenseStore,
            mdmSetup: LicenseMDMSetupMock(),
            isOnPrem: true
        )

        #expect(result == .incomplete)
    }

    /// A custom OnPrem app is built for one server, so its links may omit it. Such a link is
    /// incomplete — the license entry screen prefills the server of the app — and not a link for a
    /// different server.
    @Test("A link without a server is incomplete, not invalid")
    func reportsMissingServerAsIncomplete() {
        let licenseStore = LicenseStoreMock()
        // A missing server never matches the server the app is built for
        licenseStore.validCustomOnPremConfigURLResult = false

        let credentials = LicenseCredentials(
            username: testUsername,
            password: testPassword,
            server: nil
        )

        let result = credentials.apply(
            to: licenseStore,
            mdmSetup: LicenseMDMSetupMock(),
            isOnPrem: true
        )

        #expect(result == .incomplete)
    }

    @Test("Missing credentials are reported before the server of another app")
    func reportsMissingCredentialsBeforeInvalidServer() {
        let licenseStore = LicenseStoreMock()
        licenseStore.validCustomOnPremConfigURLResult = false

        let credentials = LicenseCredentials(
            username: nil,
            password: testPassword,
            server: testServer
        )

        let result = credentials.apply(
            to: licenseStore,
            mdmSetup: LicenseMDMSetupMock(),
            isOnPrem: true
        )

        #expect(result == .incomplete)
    }
    
    // MARK: - Completeness fixture

    /// A link and the flavor it is opened in, with the expected outcome
    struct CompletenessFixture: CustomTestStringConvertible {
        let username: String?
        let password: String?
        let server: String?
        let isOnPrem: Bool
        let expected: LicenseCredentials.ApplyResult

        var testDescription: String {
            let values = [
                username == nil ? "no username" : "username",
                password == nil ? "no password" : "password",
                server == nil ? "no server" : "server",
            ]
            return "\(values.joined(separator: ", ")) in \(isOnPrem ? "OnPrem" : "Work") → \(expected)"
        }
    }
}
