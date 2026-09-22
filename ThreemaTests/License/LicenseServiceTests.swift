import Foundation
import Testing
import ThreemaFramework
@testable import Threema

@MainActor
struct LicenseServiceTests {

    // MARK: - Validation

    @Test("A private app is licensed without a license check")
    func validatesPrivateAppWithoutCheck() async {
        let licenseStore = LicenseStoreAdapterMock()
        let service = makeService(licenseStore: licenseStore, flavorService: .threema)

        #expect(await service.validate() == .licensed)
        #expect(licenseStore.performLicenseCheckCount == 0)
    }

    @Test("A valid license is not checked again")
    func validatesValidLicenseWithoutCheck() async {
        let licenseStore = LicenseStoreAdapterMock()
        licenseStore.isValid = true
        let service = makeService(licenseStore: licenseStore)

        #expect(await service.validate() == .licensed)
        #expect(licenseStore.performLicenseCheckCount == 0)
    }

    @Test("An unchecked license is checked", arguments: [true, false])
    func validatesUncheckedLicense(isLicensed: Bool) async {
        let licenseStore = LicenseStoreAdapterMock()
        licenseStore.performLicenseCheckResult = isLicensed
        let service = makeService(licenseStore: licenseStore)

        #expect(await service.validate() == (isLicensed ? .licensed : .notLicensed))
        #expect(licenseStore.performLicenseCheckCount == 1)
    }

    // MARK: - License Activation Link

    @Test("Credentials of a license activation link are written to the license store")
    func appliesCredentials() {
        let licenseStore = LicenseStoreAdapterMock()
        let service = makeService(licenseStore: licenseStore)

        let result = service.apply(
            LicenseCredentials(username: "test-user", password: "test-password", server: nil)
        )

        #expect(result == .complete)
        #expect(licenseStore.licenseStoreMock.licenseUsername == "test-user")
        #expect(licenseStore.licenseStoreMock.licensePassword == "test-password")
    }

    @Test("An incomplete license activation link is reported as such")
    func appliesIncompleteCredentials() {
        let service = makeService()

        let result = service.apply(
            LicenseCredentials(username: "test-user", password: nil, server: nil)
        )

        #expect(result == .incomplete)
    }

    /// The result of a check that started before the link arrived belongs to the credentials from
    /// before, so it must not decide whether the license entry screen is shown.
    @Test("A check repeats for credentials that arrive while it runs")
    func repeatsCheckForCredentialsArrivingDuringCheck() async {
        let gate = CheckGate()
        let licenseStore = LicenseStoreAdapterMock()
        licenseStore.performLicenseCheckHandler = { [gate] callNumber in
            guard callNumber == 1 else {
                // Check for the credentials of the link
                return true
            }

            // Check for the credentials from before the link
            await gate.startAndWait()
            return false
        }
        let service = makeService(licenseStore: licenseStore)

        let validation = Task { await service.validate() }
        await gate.waitUntilStarted()

        #expect(
            service.apply(
                LicenseCredentials(username: "test-user", password: "test-password", server: nil)
            ) == .complete
        )

        gate.release()

        #expect(await validation.value == .licensed)
        #expect(licenseStore.performLicenseCheckCount == 2)
    }

    @Test("A check doesn't repeat for an incomplete license activation link")
    func doesNotRepeatCheckForIncompleteCredentials() async {
        let gate = CheckGate()
        let licenseStore = LicenseStoreAdapterMock()
        licenseStore.performLicenseCheckResult = false
        licenseStore.performLicenseCheckHandler = { [gate] _ in
            await gate.startAndWait()
            return false
        }
        let service = makeService(licenseStore: licenseStore)

        let validation = Task { await service.validate() }
        await gate.waitUntilStarted()

        #expect(
            service.apply(
                LicenseCredentials(username: "test-user", password: nil, server: nil)
            ) == .incomplete
        )

        gate.release()

        #expect(await validation.value == .notLicensed)
        #expect(licenseStore.performLicenseCheckCount == 1)
    }

    @Test("Only one validation runs at a time")
    func rejectsValidationWhileValidating() async {
        let gate = CheckGate()
        let licenseStore = LicenseStoreAdapterMock()
        licenseStore.performLicenseCheckHandler = { [gate] _ in
            await gate.startAndWait()
            return true
        }
        let service = makeService(licenseStore: licenseStore)

        let validation = Task { await service.validate() }
        await gate.waitUntilStarted()

        #expect(await service.validate() == .alreadyValidating)
        #expect(licenseStore.performLicenseCheckCount == 1)

        gate.release()

        #expect(await validation.value == .licensed)
    }

    @Test("A validation runs again after the previous one finished")
    func validatesAgainAfterValidation() async {
        let licenseStore = LicenseStoreAdapterMock()
        let service = makeService(licenseStore: licenseStore)

        #expect(await service.validate() == .licensed)
        #expect(await service.validate() == .licensed)
        #expect(licenseStore.performLicenseCheckCount == 2)
    }

    // MARK: - Stored Credentials

    @Test("Stored credentials of a previous installation are restored")
    func restoresStoredCredentials() {
        let licenseStore = LicenseStoreAdapterMock()
        let loader = LicenseCredentialsLoaderMock(credentials: storedCredentials)
        let service = makeService(
            licenseStore: licenseStore,
            flavorService: .onPrem,
            credentialsLoader: loader
        )

        #expect(service.restoreStoredCredentials())

        #expect(licenseStore.licenseUsername == "stored-user")
        #expect(licenseStore.licensePassword == "stored-password")
        #expect(licenseStore.onPremConfigURL == "https://onprem.example.com/prov/config.oppf")
        // Keeps the license seat of the previous installation
        #expect(licenseStore.licenseDeviceID == "stored-device-id")
    }

    @Test("Credentials that are already set are not replaced")
    func doesNotRestoreOverExistingCredentials() {
        let licenseStore = LicenseStoreAdapterMock()
        licenseStore.licenseUsername = "link-user"
        licenseStore.licensePassword = "link-password"
        let loader = LicenseCredentialsLoaderMock(credentials: storedCredentials)
        let service = makeService(licenseStore: licenseStore, credentialsLoader: loader)

        #expect(service.restoreStoredCredentials() == false)

        #expect(loader.loadCredentialsCallCount == 0)
        #expect(licenseStore.licenseUsername == "link-user")
        #expect(licenseStore.licensePassword == "link-password")
    }

    @Test("A missing password is filled in from the keychain")
    func restoresMissingPassword() {
        let licenseStore = LicenseStoreAdapterMock()
        licenseStore.licenseUsername = "mdm-user"
        let loader = LicenseCredentialsLoaderMock(credentials: storedCredentials)
        let mdmSetup = LicenseMDMSetupMock(managedKeys: [MDM_KEY_LICENSE_USERNAME])
        let service = makeService(
            licenseStore: licenseStore,
            mdmSetup: mdmSetup,
            credentialsLoader: loader
        )

        #expect(service.restoreStoredCredentials())

        // The username is managed by MDM and must not be overwritten
        #expect(licenseStore.licenseUsername == "mdm-user")
        #expect(licenseStore.licensePassword == "stored-password")
    }

    @Test("A private app has no license to restore")
    func doesNotRestoreForPrivateApp() {
        let loader = LicenseCredentialsLoaderMock(credentials: storedCredentials)
        let service = makeService(flavorService: .threema, credentialsLoader: loader)

        #expect(service.restoreStoredCredentials() == false)
        #expect(loader.loadCredentialsCallCount == 0)
    }

    @Test("Nothing is restored without stored credentials")
    func doesNotRestoreWithoutStoredCredentials() {
        let licenseStore = LicenseStoreAdapterMock()
        let service = makeService(licenseStore: licenseStore)

        #expect(service.restoreStoredCredentials() == false)
        #expect(licenseStore.licenseUsername == nil)
    }

    @Test("A failing keychain is not fatal")
    func doesNotRestoreWhenLoadingFails() {
        let licenseStore = LicenseStoreAdapterMock()
        let loader = LicenseCredentialsLoaderMock(error: TestError.loadFailed)
        let service = makeService(licenseStore: licenseStore, credentialsLoader: loader)

        #expect(service.restoreStoredCredentials() == false)
        #expect(licenseStore.licenseUsername == nil)
    }

    @Test("Restored credentials the license check rejects are discarded")
    func discardsRejectedRestoredCredentials() async {
        let licenseStore = LicenseStoreAdapterMock()
        licenseStore.performLicenseCheckResult = false
        let loader = LicenseCredentialsLoaderMock(credentials: storedCredentials)
        let service = makeService(licenseStore: licenseStore, credentialsLoader: loader)

        #expect(service.restoreStoredCredentials())
        #expect(await service.validate() == .notLicensed)

        #expect(licenseStore.licenseUsername == nil)
        #expect(licenseStore.licensePassword == nil)
        // The device ID is not a credential and stays, so a later check keeps the same seat
        #expect(licenseStore.licenseDeviceID == "stored-device-id")
    }

    @Test("Restored credentials the license check accepts are kept")
    func keepsAcceptedRestoredCredentials() async {
        let licenseStore = LicenseStoreAdapterMock()
        let loader = LicenseCredentialsLoaderMock(credentials: storedCredentials)
        let service = makeService(licenseStore: licenseStore, credentialsLoader: loader)

        #expect(service.restoreStoredCredentials())
        #expect(await service.validate() == .licensed)

        #expect(licenseStore.licenseUsername == "stored-user")
        #expect(licenseStore.licensePassword == "stored-password")
    }

    @Test("Credentials entered after a rejected restore are not discarded")
    func doesNotDiscardCredentialsOfALaterCheck() async {
        let licenseStore = LicenseStoreAdapterMock()
        licenseStore.performLicenseCheckResult = false
        let loader = LicenseCredentialsLoaderMock(credentials: storedCredentials)
        let service = makeService(licenseStore: licenseStore, credentialsLoader: loader)

        #expect(service.restoreStoredCredentials())
        #expect(await service.validate() == .notLicensed)

        // As the license entry screen does it
        licenseStore.licenseUsername = "entered-user"
        licenseStore.licensePassword = "entered-password"

        #expect(await service.validate() == .notLicensed)

        #expect(licenseStore.licenseUsername == "entered-user")
        #expect(licenseStore.licensePassword == "entered-password")
    }

    // MARK: - Private helpers

    private enum TestError: Error {
        case loadFailed
    }

    private var storedCredentials: LicenseCredentials {
        LicenseCredentials(
            username: "stored-user",
            password: "stored-password",
            server: "https://onprem.example.com/prov/config.oppf",
            deviceID: "stored-device-id"
        )
    }

    private func makeService(
        licenseStore: LicenseStoreAdapterMock? = nil,
        flavorService: AppFlavorServiceMock = .work,
        mdmSetup: LicenseMDMSetupMock = LicenseMDMSetupMock(),
        credentialsLoader: LicenseCredentialsLoaderMock = LicenseCredentialsLoaderMock()
    ) -> LicenseService {
        LicenseService(
            licenseStore: licenseStore ?? LicenseStoreAdapterMock(),
            flavorService: flavorService,
            licenseMDMSetup: mdmSetup,
            credentialsLoader: credentialsLoader
        )
    }
}

// MARK: - CheckGate

/// Holds a license check until the test releases it, so a test can act while a validation is in
/// flight
@MainActor
private final class CheckGate {

    private var didStart = false
    private var isReleased = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    /// Called by the license check: reports that it started and waits for ``release()``
    func startAndWait() async {
        didStart = true
        startContinuation?.resume()
        startContinuation = nil

        guard !isReleased else {
            return
        }

        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    /// Waits until the license check started
    func waitUntilStarted() async {
        guard !didStart else {
            return
        }

        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func release() {
        isReleased = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
