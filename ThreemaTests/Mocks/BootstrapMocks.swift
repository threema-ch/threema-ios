import Foundation
import Keychain
import RemoteSecretProtocol
import ThreemaEssentials
import ThreemaFramework
import UIKit
@testable import Threema

// MARK: - AppLaunchManagerMock

@MainActor
final class AppLaunchManagerMock: AppLaunchManagerProtocol {
    var isAppSetupCompleted = false
    var hasPreexistingDatabaseFile = false
    var isDatabaseEncrypted = false
    var shouldDirectlyShowSetupWizard = false
    var isBusinessApp = false

    private(set) var runPostOnboardingSetupCallCount = 0

    func runSetupForApplicationDelegateInitialization() { }

    func runSetupForApplicationDidFinishLaunchingWithOptions() { }

    func runLaunchSetup(window: UIWindow) { }

    func runPostOnboardingSetup() async throws {
        runPostOnboardingSetupCallCount += 1
    }
}

// MARK: - BootstrapMDMMock

@MainActor
final class BootstrapMDMMock: BootstrapMDMSetupProtocol {
    var isRemoteSecretEnabled = false
    var disableBackups = false
    var isSafeRestoreForced = false
    var isSafeRestoreDisabled = false
    var hasIDBackup = false
    var idBackup: String?
    var idBackupPassword: String?
    var skipWizard = false
    var isSafeBackupDisabled = false
    var isSafeBackupForced = false
    var isSafeBackupPasswordPreset = false
    var isSafeBackupServerPreset = false
    var safePassword: String?
    var safeServerURL: String?
    var safeServerUsername: String?
    var safeServerPassword: String?

    /// Error thrown by `restoreIDBackup()`, if any.
    var restoreIDBackupError: Error?

    private(set) var loadIDCreationValuesCallCount = 0
    private(set) var loadRenewableValuesCallCount = 0
    private(set) var restoreIDBackupCallCount = 0

    lazy var mdmSetup: MDMSetup = MDMSetup()

    func loadIDCreationValues() {
        loadIDCreationValuesCallCount += 1
    }

    func loadRenewableValues() {
        loadRenewableValuesCallCount += 1
    }

    func restoreIDBackup() async throws {
        restoreIDBackupCallCount += 1

        if let restoreIDBackupError {
            throw restoreIDBackupError
        }
    }
}

// MARK: - BootstrapWorkDataFetcherMock

final class BootstrapWorkDataFetcherMock: BootstrapWorkDataFetcherProtocol {

    /// Error thrown by `checkUpdateThreemaMDM()`, if any.
    var error: Error?

    private(set) var callCount = 0

    func checkUpdateThreemaMDM() async throws {
        callCount += 1

        if let error {
            throw error
        }
    }
}

// MARK: - BootstrapKeychainManagerMock

@MainActor
final class BootstrapKeychainManagerMock: BootstrapKeychainManagerProtocol {
    var isKeychainLocked = false
    var currentIdentity: ThreemaIdentity?

    private(set) var deleteAllItemsCallCount = 0

    func deleteAllItems() throws {
        deleteAllItemsCallCount += 1
    }
}

// MARK: - BootstrapBackupStoreMock

@MainActor
final class BootstrapBackupStoreMock: BootstrapBackupStoreProtocol {
    var identityBackup: String?
    var isValidBackup = true

    func loadIdentityBackup() -> String? {
        identityBackup
    }

    func isValidBackupFormat(_ backup: String) -> Bool {
        isValidBackup
    }
}

// MARK: - BootstrapIdentityCreatorMock

@MainActor
final class BootstrapIdentityCreatorMock: BootstrapIdentityCreatorProtocol {
    var createIdentityResult: BootstrapIdentityCreationResult = .success(())

    private(set) var generatedSeed: Data?
    private(set) var createIdentityCallCount = 0

    func generateKeyPair(withSeed seed: Data) {
        generatedSeed = seed
    }

    func createIdentity() async -> BootstrapIdentityCreationResult {
        createIdentityCallCount += 1
        return createIdentityResult
    }
}

// MARK: - BootstrapIdentityStoreMock

@MainActor
final class BootstrapIdentityStoreMock: BootstrapIdentityStoreProtocol {
    var identity: String?
    var isValidIdentity = false
    var pushFromName: String?
    var linkedEmail: String?
    var linkedMobileNo: String?

    /// Unused by the tests; the real singleton keeps the concrete type satisfiable.
    var store: MyIdentityStore {
        MyIdentityStore.shared()
    }
}

// MARK: - BootstrapUserSettingsMock

@MainActor
final class BootstrapUserSettingsMock: BootstrapUserSettingsProtocol {
    var acceptedPrivacyPolicyDate: Date?
    var acceptedPrivacyPolicyVariant = 0
    var enableMultiDevice = false
    var syncContacts = false
    var safeIntroShown = false
}

// MARK: - BootstrapServerAPIMock

@MainActor
final class BootstrapServerAPIMock: BootstrapServerAPIProtocol {
    var serverAPIConnector: ServerAPIConnector {
        ServerAPIConnector()
    }

    func linkEmail(_ email: String) async throws -> Bool {
        true
    }

    func linkMobileNo(_ mobileNo: String) async throws -> Bool {
        true
    }
}

// MARK: - BootstrapContactStoreMock

@MainActor
final class BootstrapContactStoreMock: BootstrapContactStoreProtocol {
    func synchronizeAddressBook(forceFullSync: Bool) async throws -> Bool {
        true
    }
}

// MARK: - RemoteSecretResolvingMock

@MainActor
final class RemoteSecretResolvingMock: RemoteSecretResolving {

    /// Result handed back by `resolve()`. Defaults to an error so a test only reaches the setup wizard when
    /// it says so; tests that need to get past resolution set a `.ready` result explicitly.
    var readyRemoteSecretResolverResult: Result<RemoteSecretResolverResult, Error> = .failure(
        RemoteSecretResolver.ResolverError.missingInfo
    )

    private(set) var resolveCallCount = 0

    func resolve() async throws -> RemoteSecretResolverResult {
        resolveCallCount += 1
        return try readyRemoteSecretResolverResult.get()
    }

    func continueAfterFetch(
        remoteSecretManager: any RemoteSecretManagerProtocol
    ) throws -> (
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol
    ) {
        throw RemoteSecretResolver.ResolverError.missingInfo
    }
}

// MARK: - OnboardingCompletingMock

@MainActor
final class OnboardingCompletingMock: OnboardingCompleting {

    /// Always throws. `AppDependencyContainer` has a `fileprivate init` and twenty concrete members
    /// (`IncomingMessageManager`, `TypingIndicatorManager`, `BlobManager`,
    /// `GlobalGroupCallManagerSingleton`, …), so only `AppDependencyContainerHelper` can build one — a mock
    /// cannot return a successful result. Tests therefore assert what the coordinator *asks for*, and that a
    /// failure does not complete onboarding.
    let error: Error

    private(set) var callCount = 0
    private(set) var capturedRemoteSecretManager: (any RemoteSecretManagerProtocol)?
    private(set) var capturedKeychainManager: (any KeychainManagerProtocol)?
    private(set) var capturedSetupConfiguration: SetupConfiguration?
    private(set) var capturedBootstrapMDM: (any BootstrapMDMSetupProtocol)?
    var didCaptureNilSetupConfiguration: Bool {
        capturedSetupConfiguration == nil
    }

    init(error: Error) {
        self.error = error
    }

    func complete(
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol,
        setupConfiguration: SetupConfiguration?,
        bootstrapMDM: any BootstrapMDMSetupProtocol
    ) async throws -> AppDependencyContainer {
        callCount += 1
        capturedRemoteSecretManager = remoteSecretManager
        capturedKeychainManager = keychainManager
        capturedSetupConfiguration = setupConfiguration
        capturedBootstrapMDM = bootstrapMDM

        throw error
    }
}

// MARK: - SafeRestoringMock

@MainActor
final class SafeRestoringMock: SafeRestoring {

    enum Call: Equatable {
        case prepareRestore(identity: String)
        case performRestore(restoreIdentityOnly: Bool)
    }

    /// Error thrown by `prepareRestore(with:)`, if any.
    var prepareError: Error?

    /// Error thrown by `performRestore(preparation:remoteSecretManager:)`, if any.
    var performError: Error?

    /// Phase 1's result. Set by `prepareRestore` from the info it receives.
    private(set) var preparation: SafeRestorePreparation?

    private(set) var calls: [Call] = []
    private(set) var capturedRemoteSecretManager: (any RemoteSecretManagerProtocol)?

    func prepareRestore(with info: OnboardingRestoreSafeInformation) async throws -> SafeRestorePreparation {
        calls.append(.prepareRestore(identity: info.identity))

        if let prepareError {
            throw prepareError
        }

        let preparation = SafeRestorePreparation(
            safeBackupData: SafeJsonParser.SafeBackupData(info: .init(version: 1, device: nil)),
            identity: info.identity,
            password: info.password,
            server: info.server,
            customServer: info.customServer,
            restoreIdentityOnly: info.restoreIdentityOnly,
            activateSafeAnyway: info.activateSafeAnyway
        )
        self.preparation = preparation

        return preparation
    }

    func performRestore(
        preparation: SafeRestorePreparation,
        remoteSecretManager: any RemoteSecretManagerProtocol
    ) async throws {
        calls.append(.performRestore(restoreIdentityOnly: preparation.restoreIdentityOnly))
        capturedRemoteSecretManager = remoteSecretManager

        if let performError {
            throw performError
        }
    }
}

// MARK: - SafeRestorePresentingMock

@MainActor
final class SafeRestorePresentingMock: SafeRestorePresenting {
    private(set) var didFinishCallCount = 0
    private(set) var didFailError: Error?

    func safeRestoreDidFinish() {
        didFinishCallCount += 1
    }

    func safeRestoreDidFail(with error: Error) {
        didFailError = error
    }
}

// MARK: - OnboardingCoordinatorDelegateMock

final class OnboardingCoordinatorDelegateMock: OnboardingCoordinatorDelegate {
    private(set) var didCompleteCallCount = 0

    func onboardingDidComplete(_ coordinator: OnboardingCoordinator, appContainer: AppDependencyContainer) {
        didCompleteCallCount += 1
    }
}

// MARK: - BootstrapContainer Test Factory

extension BootstrapContainer {

    /// A container wired entirely from mocks. Pass the pieces a test needs to steer; the rest are inert.
    /// The parameters are optional rather than defaulted because default argument expressions are evaluated
    /// in a nonisolated context, which cannot reach the `@MainActor` initialisers of the mocks.
    @MainActor
    static func mock(
        appLaunchManager: AppLaunchManagerMock? = nil,
        licenseStore: LicenseStoreAdapterMock? = nil,
        bootstrapWorkDataFetcher: BootstrapWorkDataFetcherMock? = nil,
        bootstrapKeychainManager: BootstrapKeychainManagerMock? = nil,
        bootstrapBackupStore: BootstrapBackupStoreMock? = nil,
        bootstrapIdentityCreator: BootstrapIdentityCreatorMock? = nil,
        bootstrapIdentityStore: BootstrapIdentityStoreMock? = nil,
        flavorService: AppFlavorServiceMock? = nil
    ) -> BootstrapContainer {
        BootstrapContainer(
            appLaunchManager: appLaunchManager ?? AppLaunchManagerMock(),
            bootstrapUserSettings: BootstrapUserSettingsMock(),
            bootstrapIdentityStore: bootstrapIdentityStore ?? BootstrapIdentityStoreMock(),
            licenseStore: licenseStore ?? LicenseStoreAdapterMock(),
            bootstrapServerAPI: BootstrapServerAPIMock(),
            bootstrapIdentityCreator: bootstrapIdentityCreator ?? BootstrapIdentityCreatorMock(),
            bootstrapKeychainManager: bootstrapKeychainManager ?? BootstrapKeychainManagerMock(),
            bootstrapBackupStore: bootstrapBackupStore ?? BootstrapBackupStoreMock(),
            bootstrapContactStore: BootstrapContactStoreMock(),
            bootstrapWorkDataFetcher: bootstrapWorkDataFetcher ?? BootstrapWorkDataFetcherMock(),
            bootstrapPhoneNumberNormalizer: PhoneNumberNormalizer(),
            flavorService: flavorService ?? AppFlavorServiceMock()
        )
    }
}
