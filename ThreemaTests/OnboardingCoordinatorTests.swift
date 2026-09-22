import Foundation
import Keychain
import KeychainTestHelper
import RemoteSecret
import RemoteSecretProtocol
import RemoteSecretProtocolTestHelper
import Testing
import ThreemaEssentials
import ThreemaFramework
import UIKit
@testable import Threema

@MainActor
struct OnboardingCoordinatorTests {

    init() {
        AppGroup.setGroupID("group.ch.threema")
    }

    // MARK: - MDM Flow Decision

    @Test("Forced Safe restore takes precedence over an MDM ID backup")
    func forcedSafeRestoreWins() {
        let fixture = makeFixture(configureMDM: { mdm in
            mdm.isSafeRestoreForced = true
            mdm.hasIDBackup = true
        })

        #expect(fixture.coordinator.mdmFlow(hasDataOnDevice: false) == .forceSafeRestore(identityOnly: false))
    }

    @Test("Forced Safe restore restores the identity only when the device already holds data")
    func forcedSafeRestorePassesHasDataOnDeviceAsIdentityOnly() {
        let fixture = makeFixture(configureMDM: { $0.isSafeRestoreForced = true })

        #expect(fixture.coordinator.mdmFlow(hasDataOnDevice: true) == .forceSafeRestore(identityOnly: true))
    }

    @Test("An MDM ID backup is restored while app setup is incomplete")
    func mdmIDBackupIsRestoredWhileSetupIsIncomplete() {
        let fixture = makeFixture(
            configureMDM: { $0.hasIDBackup = true },
            configureAppLaunchManager: { $0.isAppSetupCompleted = false }
        )

        #expect(fixture.coordinator.mdmFlow(hasDataOnDevice: false) == .restoreFromMDMBackup)
    }

    @Test("An MDM ID backup is ignored once app setup is completed")
    func mdmIDBackupIsIgnoredOnceSetupIsCompleted() {
        let fixture = makeFixture(
            configureMDM: { $0.hasIDBackup = true },
            configureAppLaunchManager: { $0.isAppSetupCompleted = true }
        )

        #expect(fixture.coordinator.mdmFlow(hasDataOnDevice: false) == .showPrivacyControls)
    }

    @Test("An interrupted setup resumes straight in the setup wizard")
    func setupWizardIsShownDirectlyWhenRequested() {
        let fixture = makeFixture(configureAppLaunchManager: { $0.shouldDirectlyShowSetupWizard = true })

        #expect(fixture.coordinator.mdmFlow(hasDataOnDevice: false) == .directSetupWizard)
    }

    @Test("Without any MDM configuration the privacy controls are shown")
    func defaultFlowShowsPrivacyControls() {
        let fixture = makeFixture()

        #expect(fixture.coordinator.mdmFlow(hasDataOnDevice: false) == .showPrivacyControls)
    }

    // MARK: - Launch

    @Test("The restore button is hidden when MDM disables backups")
    func appearingHidesTheRestoreButtonWhenMDMDisablesBackups() async {
        let fixture = makeFixture(configureMDM: { $0.disableBackups = true })

        fixture.coordinator.splashViewControllerDidAppear(splashArgument())
        await drainTasks()

        #expect(fixture.splash.contains(.setRestoreButtonHidden(true)))
    }

    @Test("A consumer build reaches the MDM flow without a license check")
    func consumerBuildReachesTheMDMFlowWithoutALicenseCheck() async {
        let fixture = makeFixture(isBusinessApp: false)

        fixture.coordinator.splashViewControllerDidAppear(splashArgument())
        await drainTasks()

        // The consumer path must not stop at the license gate. Gating the whole sequence on isBusinessApp
        // skipped AppSetup.shouldDirectlyShowSetupWizard for consumer builds resuming an interrupted setup.
        #expect(fixture.splash.contains(.showPrivacyControls))
        #expect(fixture.licenseStore.performLicenseCheckCount == 0)
        #expect(fixture.workDataFetcher.callCount == 1)
    }

    @Test("A business build with an invalid license presents license entry and stops")
    func businessBuildWithAnInvalidLicensePresentsLicenseEntryAndStops() async {
        let fixture = makeFixture(
            isBusinessApp: true,
            licenseIsValid: false,
            licenseCheckResult: false
        )

        fixture.coordinator.splashViewControllerDidAppear(splashArgument())
        await drainTasks()

        #expect(fixture.splash.contains(.showLicenseViewController))
        #expect(fixture.licenseStore.performLicenseCheckCount == 1)
        #expect(fixture.workDataFetcher.callCount == 0)
        #expect(!fixture.splash.contains(.showPrivacyControls))
    }

    @Test("A business build with a valid license fetches work data and continues")
    func businessBuildWithAValidLicenseFetchesWorkDataAndContinues() async {
        let fixture = makeFixture(isBusinessApp: true, licenseIsValid: true)

        fixture.coordinator.splashViewControllerDidAppear(splashArgument())
        await drainTasks()

        #expect(fixture.licenseStore.performLicenseCheckCount == 0)
        #expect(fixture.workDataFetcher.callCount == 1)
        #expect(fixture.splash.contains(.showPrivacyControls))
    }

    @Test("A failing work data fetch surfaces the alert instead of continuing")
    func aFailedWorkDataFetchIsSurfaced() async {
        let fixture = makeFixture(isBusinessApp: true, workDataFetchError: TestError.fetchFailed)

        fixture.coordinator.splashViewControllerDidAppear(splashArgument())
        await drainTasks()

        #expect(fixture.splash.contains(.showWorkDataFetchFailedAlert))
        #expect(!fixture.splash.contains(.showPrivacyControls))
    }

    @Test("MDM values are loaded before the flow decision and again after the work data fetch")
    func mdmValuesAreLoadedBeforeTheFlowDecision() async {
        let fixture = makeFixture()

        fixture.coordinator.splashViewControllerDidAppear(splashArgument())
        await drainTasks()

        #expect(fixture.mdm.loadIDCreationValuesCallCount == 2)
        #expect(fixture.mdm.loadRenewableValuesCallCount == 2)
    }

    @Test("Appearing a second time does not restart the flow")
    func repeatedAppearanceDoesNotRestartTheFlow() async {
        let fixture = makeFixture(isBusinessApp: true)

        // viewDidAppear fires again on every slide-back to the splash screen and after the license modal is
        // dismissed. Without the guard the MDM flow ran twice.
        fixture.coordinator.splashViewControllerDidAppear(splashArgument())
        await drainTasks()
        fixture.coordinator.splashViewControllerDidAppear(splashArgument())
        await drainTasks()

        #expect(fixture.workDataFetcher.callCount == 1)
        #expect(fixture.splash.calls.filter { $0 == .showPrivacyControls }.count == 1)
    }

    @Test("Forced Safe restore is dispatched to the Safe restore screen")
    func forcedSafeRestoreIsDispatched() async {
        let fixture = makeFixture(
            configureMDM: { $0.isSafeRestoreForced = true },
            configureAppLaunchManager: { $0.hasPreexistingDatabaseFile = true }
        )

        fixture.coordinator.splashViewControllerDidAppear(splashArgument())
        await drainTasks()

        #expect(fixture.splash.contains(.navigateToRestoreSafeViewController(identityOnly: true)))
    }

    @Test("Confirming a license resumes the flow")
    func confirmingALicenseResumesTheFlow() async {
        let fixture = makeFixture(
            isBusinessApp: true,
            licenseIsValid: false,
            licenseCheckResult: false
        )

        fixture.coordinator.splashViewControllerDidAppear(splashArgument())
        await drainTasks()
        #expect(fixture.workDataFetcher.callCount == 0)

        fixture.coordinator.splashViewControllerDidConfirmLicense(splashArgument())
        await drainTasks()

        #expect(fixture.workDataFetcher.callCount == 1)
        #expect(fixture.splash.contains(.showPrivacyControls))
    }

    @Test("Dismissing the license entry fetches work data even when the fetch fails")
    func dismissingLicenseEntryFetchesWorkData() async {
        let fixture = makeFixture(
            isBusinessApp: true,
            licenseIsValid: false,
            licenseCheckResult: false,
            workDataFetchError: TestError.fetchFailed
        )

        fixture.coordinator.splashViewControllerDidAppear(splashArgument())
        await drainTasks()
        #expect(fixture.workDataFetcher.callCount == 0)
        #expect(fixture.splash.contains(.showLicenseViewController))

        fixture.coordinator.splashViewControllerDidConfirmLicense(splashArgument())
        await drainTasks()

        #expect(fixture.workDataFetcher.callCount == 1)
        #expect(fixture.splash.contains(.showWorkDataFetchFailedAlert))
    }

    // MARK: - Setup Wizard

    @Test("A resumed setup presents the wizard once the remote secret resolves")
    func directSetupWizardPresentsTheWizard() async {
        let fixture = makeFixture(
            configureAppLaunchManager: { $0.shouldDirectlyShowSetupWizard = true },
            configureRemoteSecretResolver: {
                $0.readyRemoteSecretResolverResult = .success(
                    Self.readyRemoteSecretResolverResult
                )
            }
        )

        fixture.coordinator.splashViewControllerDidAppear(splashArgument())
        await drainTasks()

        #expect(fixture.remoteSecretResolver.resolveCallCount == 1)
        #expect(fixture.licenseStore.performUpdateWorkInfoCount == 1)
        #expect(fixture.splash.contains(.presentPageViewController))
    }

    @Test("A failing remote secret resolution keeps the wizard closed")
    func directSetupWizardWithoutARemoteSecretDoesNotPresentTheWizard() async {
        let fixture = makeFixture(
            configureAppLaunchManager: { $0.shouldDirectlyShowSetupWizard = true },
            configureRemoteSecretResolver: { $0.readyRemoteSecretResolverResult = .failure(TestError.remoteSecretFailed) }
        )

        fixture.coordinator.splashViewControllerDidAppear(splashArgument())
        await drainTasks()

        #expect(fixture.remoteSecretResolver.resolveCallCount == 1)
        #expect(!fixture.splash.contains(.presentPageViewController))
    }

    @Test("Keeping an existing identity marks it as added and presents the wizard")
    func keepingTheExistingIdentityPresentsTheWizard() async {
        let fixture = makeFixture(
            configureKeychain: { $0.currentIdentity = ThreemaIdentity("ECHOECHO") },
            configureRemoteSecretResolver: { $0.readyRemoteSecretResolverResult = .success(
                Self.readyRemoteSecretResolverResult
            ) }
        )

        defer { AppSetup.state = .notSetup }

        fixture.coordinator.splashViewController(splashArgument(), didAnswerIDExistsQuestion: true)
        await drainTasks()

        // Advancing the state early keeps the keychain data from being wiped later on.
        #expect(AppSetup.state == .identityAdded)
        #expect(fixture.splash.contains(.presentPageViewController))
    }

    // MARK: - MDM ID Backup Restore

    @Test("A failing MDM ID backup restore shows the identity restore screen with the error")
    func failingMDMBackupRestoreShowsTheErrorOnTheRestoreScreen() async {
        let fixture = makeFixture(
            configureMDM: { mdm in
                mdm.hasIDBackup = true
                mdm.idBackup = "BACKUP"
                mdm.idBackupPassword = "PASSWORD"
                mdm.restoreIDBackupError = TestError.restoreFailed
            },
            configureAppLaunchManager: { $0.isAppSetupCompleted = false }
        )

        fixture.coordinator.splashViewControllerDidAppear(splashArgument())
        await drainTasks()

        #expect(fixture.splash.contains(.setAcceptPrivacyPolicyValues(.implicitly)))
        #expect(fixture.splash.contains(
            .showRestoreIdentityViewController(backupData: "BACKUP", password: "PASSWORD", hasError: true)
        ))
    }

    // MARK: - Setup Tap

    @Test("Tapping setup asks about an existing identity on consumer builds")
    func setupTapAsksAboutAnExistingIdentityOnConsumerBuilds() async {
        let fixture = makeFixture(
            isBusinessApp: false,
            configureKeychain: { $0.currentIdentity = ThreemaIdentity("ECHOECHO") }
        )

        await fixture.coordinator.splashViewControllerDidTapSetup(splashArgument())

        #expect(fixture.splash.contains(.showIDExistsQuestion(identity: "ECHOECHO")))
    }

    @Test("Tapping setup skips the existing identity question on business builds")
    func setupTapSkipsTheExistingIdentityQuestionOnBusinessBuilds() async {
        let fixture = makeFixture(
            isBusinessApp: true,
            configureKeychain: { $0.currentIdentity = ThreemaIdentity("ECHOECHO") }
        )

        await fixture.coordinator.splashViewControllerDidTapSetup(splashArgument())

        #expect(fixture.splash.contains(.showRandomSeedViewController))
    }

    @Test("Tapping setup asks about a found ID backup")
    func setupTapAsksAboutAFoundIDBackup() async {
        let fixture = makeFixture(configureBackupStore: { $0.identityBackup = "BACKUP" })

        await fixture.coordinator.splashViewControllerDidTapSetup(splashArgument())

        #expect(fixture.splash.contains(.showIDBackupQuestion))
    }

    @Test("Tapping setup goes straight to the seed screen when there is nothing to restore")
    func setupTapGoesStraightToTheSeedScreenWithNothingToRestore() async {
        let fixture = makeFixture()

        await fixture.coordinator.splashViewControllerDidTapSetup(splashArgument())

        #expect(fixture.splash.contains(.setAcceptPrivacyPolicyValues(.explicitly)))
        #expect(fixture.splash.contains(.showRandomSeedViewController))
    }

    // MARK: - Questions

    @Test("Accepting a found ID backup opens the identity restore screen with it")
    func acceptingTheIDBackupQuestionRestoresFromThatBackup() async {
        let fixture = makeFixture(configureBackupStore: { $0.identityBackup = "BACKUP" })

        await fixture.coordinator.splashViewControllerDidTapSetup(splashArgument())
        fixture.coordinator.splashViewController(splashArgument(), didAnswerIDBackupQuestion: true)

        #expect(fixture.splash.contains(
            .showRestoreIdentityViewController(backupData: "BACKUP", password: nil, hasError: false)
        ))
    }

    @Test("Declining a found ID backup during setup continues with a new identity")
    func decliningTheIDBackupQuestionDuringSetupCreatesANewIdentity() async {
        let fixture = makeFixture(configureBackupStore: { $0.identityBackup = "BACKUP" })

        await fixture.coordinator.splashViewControllerDidTapSetup(splashArgument())
        fixture.coordinator.splashViewController(splashArgument(), didAnswerIDBackupQuestion: false)
        await drainTasks()

        #expect(fixture.splash.contains(.showRandomSeedViewController))
    }

    @Test("Declining a found ID backup during restore opens the identity restore screen empty")
    func decliningTheIDBackupQuestionDuringRestoreOpensAnEmptyRestoreScreen() {
        let fixture = makeFixture()

        fixture.coordinator.splashViewController(splashArgument(), didAnswerIDBackupQuestion: false)

        #expect(fixture.splash.contains(
            .showRestoreIdentityViewController(backupData: nil, password: nil, hasError: false)
        ))
    }

    @Test("Declining an existing identity wipes the keychain and starts a new setup")
    func decliningTheExistingIdentityQuestionWipesTheKeychain() async {
        let fixture = makeFixture(configureKeychain: { $0.currentIdentity = ThreemaIdentity("ECHOECHO") })

        fixture.coordinator.splashViewController(splashArgument(), didAnswerIDExistsQuestion: false)
        await drainTasks()

        #expect(fixture.keychainManager.deleteAllItemsCallCount == 1)
        #expect(fixture.splash.contains(.showRandomSeedViewController))
    }

    // MARK: - Identity Creation

    @Test("A generated seed creates an identity behind a loading HUD")
    func aGeneratedSeedCreatesAnIdentity() async {
        let fixture = makeFixture()
        let seed = Data(repeating: 0xAB, count: 32)

        fixture.coordinator.splashViewController(splashArgument(), didGenerateRandomSeed: seed)
        await drainTasks()

        #expect(fixture.splash.contains(.showLoadingHUD))
        #expect(fixture.identityCreator.generatedSeed == seed)
        #expect(fixture.identityCreator.createIdentityCallCount == 1)
    }

    @Test("A failed identity creation hides the HUD and reports the error")
    func aFailedIdentityCreationReportsTheError() async {
        let fixture = makeFixture(configureIdentityCreator: {
            $0.createIdentityResult = .failure(TestError.identityCreationFailed)
        })

        fixture.coordinator.splashViewController(
            splashArgument(),
            didGenerateRandomSeed: Data(repeating: 0xAB, count: 32)
        )
        await drainTasks()

        #expect(fixture.splash.contains(.hideLoadingHUD))
        #expect(fixture.splash.contains(.showIdentityCreationError))
        #expect(fixture.splash.identityCreationError as? TestError == .identityCreationFailed)
    }

    @Test("Cancelling identity creation is forwarded to the splash screen")
    func cancellingIdentityCreationIsForwarded() {
        let fixture = makeFixture()

        fixture.coordinator.splashViewControllerDidCancelIDCreation(splashArgument())

        #expect(fixture.splash.contains(.cancelIDCreation))
    }

    // MARK: - Restore Tap

    @Test("Tapping restore offers the local data option when the device holds data")
    func restoreTapOffersTheDataOptionWhenTheDeviceHasData() async {
        let fixture = makeFixture(configureAppLaunchManager: { $0.hasPreexistingDatabaseFile = true })

        fixture.coordinator.splashViewControllerDidTapRestore(splashArgument())
        await drainTasks()

        #expect(fixture.splash.contains(.navigateToRestoreOptionDataViewController))
    }

    @Test("Tapping restore offers the backup option on an empty device")
    func restoreTapOffersTheBackupOptionOnAnEmptyDevice() async {
        let fixture = makeFixture(configureAppLaunchManager: { $0.hasPreexistingDatabaseFile = false })

        fixture.coordinator.splashViewControllerDidTapRestore(splashArgument())
        await drainTasks()

        #expect(fixture.splash.contains(.navigateToRestoreOptionBackupViewController))
    }

    @Test("Tapping restore goes straight to identity restore when MDM disables Safe restore")
    func restoreTapGoesStraightToIdentityRestoreWhenSafeRestoreIsDisabled() async {
        let fixture = makeFixture(configureMDM: { $0.isSafeRestoreDisabled = true })

        fixture.coordinator.splashViewControllerDidTapRestore(splashArgument())
        await drainTasks()

        #expect(fixture.splash.contains(
            .showRestoreIdentityViewController(backupData: nil, password: nil, hasError: false)
        ))
    }

    @Test("Tapping restore asks about a found ID backup when MDM disables Safe restore")
    func restoreTapAsksAboutAFoundIDBackupWhenSafeRestoreIsDisabled() async {
        let fixture = makeFixture(
            configureMDM: { $0.isSafeRestoreDisabled = true },
            configureBackupStore: { $0.identityBackup = "BACKUP" }
        )

        fixture.coordinator.splashViewControllerDidTapRestore(splashArgument())
        await drainTasks()

        #expect(fixture.splash.contains(.showIDBackupQuestion))
    }

    // MARK: - Restore Options

    @Test("The Safe restore option opens Safe restore")
    func safeRestoreOptionOpensSafeRestore() {
        let fixture = makeFixture()

        fixture.coordinator.splashViewController(splashArgument(), didSelectRestoreOption: .safe)

        #expect(fixture.splash.contains(.navigateToRestoreSafeViewController(identityOnly: false)))
    }

    @Test("The identity-only option opens Safe restore for the identity alone")
    func identityOnlyRestoreOptionOpensSafeRestoreForTheIdentityOnly() {
        let fixture = makeFixture()

        fixture.coordinator.splashViewController(splashArgument(), didSelectRestoreOption: .safeIdentityOnly)

        #expect(fixture.splash.contains(.navigateToRestoreSafeViewController(identityOnly: true)))
    }

    @Test("The ID backup option slides the current screen out before asking about the backup")
    func idBackupRestoreOptionSlidesOutBeforeAskingAboutTheFoundBackup() {
        let fixture = makeFixture(configureBackupStore: { $0.identityBackup = "BACKUP" })

        fixture.coordinator.splashViewController(splashArgument(), didSelectRestoreOption: .idBackup)

        // The question is drawn on top of the current screen, so it has to slide out first.
        #expect(fixture.splash.calls == [
            .slideOutRestoreOptionBackupViewController,
            .showIDBackupQuestion,
        ])
    }

    @Test("The ID backup option opens an empty restore screen when no backup is found")
    func idBackupRestoreOptionOpensAnEmptyRestoreScreenWithoutABackup() {
        let fixture = makeFixture()

        fixture.coordinator.splashViewController(splashArgument(), didSelectRestoreOption: .idBackup)

        #expect(fixture.splash.contains(
            .showRestoreIdentityViewController(backupData: nil, password: nil, hasError: false)
        ))
    }

    @Test("Keeping local data offers the backup option")
    func keepLocalDataOptionOffersTheBackupOption() {
        let fixture = makeFixture()

        fixture.coordinator.splashViewController(splashArgument(), didSelectRestoreOption: .keepLocalData)

        #expect(fixture.splash.contains(.navigateToRestoreOptionBackupViewController))
    }

    // MARK: - Completion

    @Test("Completing ID setup hands the wizard's own configuration and credentials to the completer")
    func completingIDSetupForwardsTheWizardConfiguration() async {
        let fixture = makeFixture()
        let (configuration, remoteSecretManager, keychainManager) = makeSetupConfiguration()

        await fixture.coordinator.splashViewController(
            splashArgument(),
            didCompleteIDSetupWith: configuration
        )

        #expect(fixture.completer.callCount == 1)
        #expect(fixture.completer.capturedSetupConfiguration === configuration)
        #expect(fixture.completer.capturedRemoteSecretManager as? RemoteSecretManagerMock === remoteSecretManager)
        #expect(fixture.completer.capturedKeychainManager as? KeychainManagerMock === keychainManager)
    }

    @Test("A failing completion does not finish onboarding")
    func aFailingCompletionDoesNotFinishOnboarding() async {
        let fixture = makeFixture()
        let (configuration, _, _) = makeSetupConfiguration()

        await fixture.coordinator.splashViewController(
            splashArgument(),
            didCompleteIDSetupWith: configuration
        )

        #expect(fixture.completer.callCount == 1)
        #expect(fixture.delegate.didCompleteCallCount == 0)
    }

    // MARK: - Safe Restore

    @Test("Safe restore runs prepare, then remote secret resolution, then perform")
    func safeRestoreRunsBothPhasesInOrder() async {
        let fixture = makeFixture(
            configureRemoteSecretResolver: { $0.readyRemoteSecretResolverResult = .success(
                Self.readyRemoteSecretResolverResult
            ) }
        )

        await fixture.coordinator.handleSafeRestore(
            info: Self.safeRestoreInformation,
            presenter: SafeRestorePresentingMock()
        )

        #expect(fixture.safeRestore.calls == [
            .prepareRestore(identity: "ECHOECHO"),
            .performRestore(restoreIdentityOnly: false),
        ])
        #expect(fixture.remoteSecretResolver.resolveCallCount == 1)
    }

    @Test("Phase two receives the remote secret resolved between the phases")
    func safeRestorePassesTheResolvedRemoteSecretToPhaseTwo() async {
        let remoteSecretManager = RemoteSecretManagerMock(isRemoteSecretEnabled: false)
        let fixture = makeFixture(configureRemoteSecretResolver: {
            $0.readyRemoteSecretResolverResult = .success(
                .ready(remoteSecretManager: remoteSecretManager, keychainManager: KeychainManagerMock())
            )
        })

        await fixture.coordinator.handleSafeRestore(
            info: Self.safeRestoreInformation,
            presenter: SafeRestorePresentingMock()
        )

        #expect(fixture.safeRestore.capturedRemoteSecretManager as? RemoteSecretManagerMock === remoteSecretManager)
    }

    @Test("Safe restore completes onboarding without a setup configuration")
    func safeRestoreCompletesWithoutASetupConfiguration() async {
        let fixture = makeFixture(
            configureRemoteSecretResolver: { $0.readyRemoteSecretResolverResult = .success(
                Self.readyRemoteSecretResolverResult
            ) }
        )

        await fixture.coordinator.handleSafeRestore(
            info: Self.safeRestoreInformation,
            presenter: SafeRestorePresentingMock()
        )

        // performRestore already ran the migrations and Safe activation the wizard steps would do.
        #expect(fixture.completer.callCount == 1)
        #expect(fixture.completer.didCaptureNilSetupConfiguration == true)
    }

    @Test("A failing first phase skips remote secret resolution and reports the error")
    func aFailingPrepareSkipsTheRestOfTheRestore() async {
        let fixture = makeFixture(configureSafeRestore: { $0.prepareError = TestError.restoreFailed })
        let presenter = SafeRestorePresentingMock()

        await fixture.coordinator.handleSafeRestore(
            info: Self.safeRestoreInformation,
            presenter: presenter
        )

        #expect(fixture.safeRestore.calls == [.prepareRestore(identity: "ECHOECHO")])
        #expect(fixture.remoteSecretResolver.resolveCallCount == 0)
        #expect(fixture.completer.callCount == 0)
        #expect(presenter.didFailError as? TestError == .restoreFailed)
        #expect(presenter.didFinishCallCount == 0)
    }

    @Test("A failing remote secret resolution skips the second phase")
    func aFailingRemoteSecretResolutionSkipsPhaseTwo() async {
        let fixture = makeFixture(
            configureRemoteSecretResolver: { $0.readyRemoteSecretResolverResult = .failure(TestError.remoteSecretFailed) }
        )
        let presenter = SafeRestorePresentingMock()

        await fixture.coordinator.handleSafeRestore(
            info: Self.safeRestoreInformation,
            presenter: presenter
        )

        #expect(fixture.safeRestore.calls == [.prepareRestore(identity: "ECHOECHO")])
        #expect(fixture.completer.callCount == 0)
        #expect(presenter.didFailError as? TestError == .remoteSecretFailed)
    }

    @Test("A failing second phase does not complete onboarding")
    func aFailingPerformDoesNotCompleteOnboarding() async {
        let fixture = makeFixture(
            configureRemoteSecretResolver: { $0.readyRemoteSecretResolverResult = .success(
                Self.readyRemoteSecretResolverResult
            ) },
            configureSafeRestore: { $0.performError = TestError.restoreFailed }
        )
        let presenter = SafeRestorePresentingMock()

        await fixture.coordinator.handleSafeRestore(
            info: Self.safeRestoreInformation,
            presenter: presenter
        )

        #expect(fixture.completer.callCount == 0)
        #expect(presenter.didFailError as? TestError == .restoreFailed)
        #expect(presenter.didFinishCallCount == 0)
    }

    @Test("A restore that reaches completion reports through the presenter")
    func aRestoreReachingCompletionReportsThroughThePresenter() async {
        let fixture = makeFixture(
            configureRemoteSecretResolver: { $0.readyRemoteSecretResolverResult = .success(
                Self.readyRemoteSecretResolverResult
            ) }
        )
        let presenter = SafeRestorePresentingMock()

        await fixture.coordinator.handleSafeRestore(
            info: Self.safeRestoreInformation,
            presenter: presenter
        )

        // `OnboardingCompletingMock` cannot succeed (see its documentation) so the restore lands in the
        // failure branch. What this pins is that the outcome is reported through the presenter either way.
        #expect(presenter.didFailError as? TestError == .completionFailed)
        #expect(presenter.didFinishCallCount == 0)
    }

    // MARK: - Cancellation

    @Test("Cancelling identity restore reached from setup returns to the splash screen")
    func cancellingIdentityRestoreReturnsToSplashWhenReachedFromSetup() async {
        let fixture = makeFixture(configureBackupStore: { $0.identityBackup = "BACKUP" })

        // The setup tap is what marks the flow as setup-triggered.
        await fixture.coordinator.splashViewControllerDidTapSetup(splashArgument())
        fixture.coordinator.splashViewControllerDidCancelRestoreIdentity(splashArgument())

        #expect(fixture.splash.contains(.navigateBackToSplash))
    }

    @Test("Cancelling identity restore reached from restore returns to the backup option")
    func cancellingIdentityRestoreReturnsToTheBackupOptionWhenReachedFromRestore() async {
        let fixture = makeFixture()

        fixture.coordinator.splashViewControllerDidTapRestore(splashArgument())
        await drainTasks()
        fixture.coordinator.splashViewControllerDidCancelRestoreIdentity(splashArgument())

        #expect(fixture.splash.contains(.navigateBackToRestoreOptionBackupViewController))
    }

    @Test("Cancelling identity restore returns to the splash screen when MDM disables Safe restore")
    func cancellingIdentityRestoreReturnsToSplashWhenSafeRestoreIsDisabled() {
        let fixture = makeFixture(configureMDM: { $0.isSafeRestoreDisabled = true })

        fixture.coordinator.splashViewControllerDidCancelRestoreIdentity(splashArgument())

        #expect(fixture.splash.contains(.navigateBackToSplash))
    }

    @Test("Cancelling the local data option returns to the splash screen")
    func cancellingTheDataOptionReturnsToSplash() {
        let fixture = makeFixture()

        fixture.coordinator.splashViewControllerDidCancelRestore(splashArgument())

        #expect(fixture.splash.contains(.navigateBackToSplash))
    }

    @Test("Cancelling the backup option returns to the local data option when the device holds data")
    func cancellingTheBackupOptionReturnsToTheDataOptionWhenTheDeviceHasData() {
        let fixture = makeFixture(configureAppLaunchManager: { $0.hasPreexistingDatabaseFile = true })

        fixture.coordinator.splashViewControllerDidCancelRestoreOptionBackup(splashArgument())

        #expect(fixture.splash.contains(.navigateBackToRestoreOptionDataViewController))
    }

    @Test("Cancelling the backup option returns to the splash screen on an empty device")
    func cancellingTheBackupOptionReturnsToSplashOnAnEmptyDevice() {
        let fixture = makeFixture(configureAppLaunchManager: { $0.hasPreexistingDatabaseFile = false })

        fixture.coordinator.splashViewControllerDidCancelRestoreOptionBackup(splashArgument())

        #expect(fixture.splash.contains(.navigateBackToSplash))
    }

    @Test("Cancelling Safe restore returns to the backup option it came from")
    func cancellingSafeRestoreReturnsToTheBackupOption() {
        let fixture = makeFixture()

        fixture.coordinator.splashViewControllerDidCancelRestoreSafe(splashArgument())

        #expect(fixture.splash.contains(.navigateBackToRestoreOptionBackupViewController))
    }

    // MARK: - Helpers

    private enum TestError: Error, Equatable {
        case fetchFailed
        case restoreFailed
        case identityCreationFailed
        case remoteSecretFailed
        case completionFailed
    }

    private static var safeRestoreInformation: OnboardingRestoreSafeInformation {
        OnboardingRestoreSafeInformation(
            identity: "ECHOECHO",
            password: "password",
            server: nil,
            customServer: nil,
            restoreIdentityOnly: false,
            activateSafeAnyway: false
        )
    }

    /// A configuration shaped like the one the setup wizard produces.
    private func makeSetupConfiguration() -> (
        configuration: SetupConfiguration,
        remoteSecretManager: RemoteSecretManagerMock,
        keychainManager: KeychainManagerMock
    ) {
        let remoteSecretManager = RemoteSecretManagerMock(isRemoteSecretEnabled: false)
        let keychainManager = KeychainManagerMock()

        let configuration = SetupConfiguration(
            remoteSecretAndKeychain: RemoteSecretAndKeychainObjC(
                remoteSecretManager: remoteSecretManager,
                keychainManager: keychainManager
            ),
            mdm: MDMSetup()
        )

        return (configuration, remoteSecretManager, keychainManager)
    }

    /// A resolved remote secret that leaves the process globals the coordinator writes to
    /// (`RemoteSecretProvider` and `FileUtility.shared`) in a passthrough state, because remote secret
    /// encryption is disabled.
    private static var readyRemoteSecretResolverResult: RemoteSecretResolverResult {
        .ready(
            remoteSecretManager: RemoteSecretManagerMock(isRemoteSecretEnabled: false),
            keychainManager: KeychainManagerMock()
        )
    }

    private struct Fixture {
        let coordinator: OnboardingCoordinator
        let splash: SplashPresentingMock
        let appLaunchManager: AppLaunchManagerMock
        let licenseStore: LicenseStoreAdapterMock
        let mdm: BootstrapMDMMock
        let workDataFetcher: BootstrapWorkDataFetcherMock
        let keychainManager: BootstrapKeychainManagerMock
        let backupStore: BootstrapBackupStoreMock
        let identityCreator: BootstrapIdentityCreatorMock
        let remoteSecretResolver: RemoteSecretResolvingMock
        let completer: OnboardingCompletingMock
        let safeRestore: SafeRestoringMock
        let delegate: OnboardingCoordinatorDelegateMock
    }

    private func makeFixture(
        isBusinessApp: Bool = false,
        licenseIsValid: Bool = true,
        licenseCheckResult: Bool = true,
        workDataFetchError: Error? = nil,
        configureMDM: @MainActor (BootstrapMDMMock) -> Void = { _ in },
        configureAppLaunchManager: @MainActor (AppLaunchManagerMock) -> Void = { _ in },
        configureKeychain: @MainActor (BootstrapKeychainManagerMock) -> Void = { _ in },
        configureBackupStore: @MainActor (BootstrapBackupStoreMock) -> Void = { _ in },
        configureIdentityCreator: @MainActor (BootstrapIdentityCreatorMock) -> Void = { _ in },
        configureRemoteSecretResolver: @MainActor (RemoteSecretResolvingMock) -> Void = { _ in },
        configureSafeRestore: @MainActor (SafeRestoringMock) -> Void = { _ in }
    ) -> Fixture {
        let appLaunchManager = AppLaunchManagerMock()
        appLaunchManager.isBusinessApp = isBusinessApp
        configureAppLaunchManager(appLaunchManager)

        let licenseStore = LicenseStoreAdapterMock()
        licenseStore.isValid = licenseIsValid
        licenseStore.performLicenseCheckResult = licenseCheckResult

        let mdm = BootstrapMDMMock()
        configureMDM(mdm)

        let workDataFetcher = BootstrapWorkDataFetcherMock()
        workDataFetcher.error = workDataFetchError

        let keychainManager = BootstrapKeychainManagerMock()
        configureKeychain(keychainManager)

        let backupStore = BootstrapBackupStoreMock()
        configureBackupStore(backupStore)

        let identityCreator = BootstrapIdentityCreatorMock()
        configureIdentityCreator(identityCreator)

        var flavorService = AppFlavorServiceMock()
        flavorService.isBusinessApp = isBusinessApp

        let bootstrap = BootstrapContainer.mock(
            appLaunchManager: appLaunchManager,
            licenseStore: licenseStore,
            bootstrapWorkDataFetcher: workDataFetcher,
            bootstrapKeychainManager: keychainManager,
            bootstrapBackupStore: backupStore,
            bootstrapIdentityCreator: identityCreator,
            flavorService: flavorService
        )

        let splash = SplashPresentingMock()
        let delegate = OnboardingCoordinatorDelegateMock()

        let remoteSecretResolver = RemoteSecretResolvingMock()
        configureRemoteSecretResolver(remoteSecretResolver)

        let completer = OnboardingCompletingMock(error: TestError.completionFailed)

        let safeRestore = SafeRestoringMock()
        configureSafeRestore(safeRestore)

        let coordinator = OnboardingCoordinator(
            bootstrap: bootstrap,
            bootstrapMDMSetup: mdm,
            delegate: delegate,
            window: UIWindow(),
            remoteSecretResolver: remoteSecretResolver,
            splash: splash,
            onboardingCompleter: completer,
            restoreSafeManager: safeRestore
        )

        return Fixture(
            coordinator: coordinator,
            splash: splash,
            appLaunchManager: appLaunchManager,
            licenseStore: licenseStore,
            mdm: mdm,
            workDataFetcher: workDataFetcher,
            keychainManager: keychainManager,
            backupStore: backupStore,
            identityCreator: identityCreator,
            remoteSecretResolver: remoteSecretResolver,
            completer: completer,
            safeRestore: safeRestore,
            delegate: delegate
        )
    }

    /// The delegate methods take the reporting `SplashViewController`, but the coordinator drives the
    /// injected `SplashPresenting` instead, so this argument is never touched.
    private func splashArgument() -> SplashViewController {
        SplashViewController(nibName: nil, bundle: nil)
    }

    /// Several delegate callbacks hand their work to a `Task`, so assertions have to let it run first.
    private func drainTasks() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }
}
