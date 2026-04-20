import DeveloperToolsSupport
import Observation
import SwiftUI
import ThreemaFramework
import ThreemaMacros

@Observable @MainActor
final class ThreemaSafeDashboardViewModel {

    // MARK: - Public properties

    let backupButtonTitle = #localize("rs_view_create_backup_button_title")
    let maxBackupBytesLabel = #localize("safe_max_backup_size")
    let backupSectionHeader = #localize("backup").uppercased()
    let backupSizeLabel = #localize("backup_last_size")
    let backupStatusLabel = #localize("safe_backup_status")
    let deactivateActionTitle = #localize("safe_deactivate_action")
    let deactivateSectionFooter = #localize("disabled_by_device_policy_feature")
    let errorIcon = "exclamationmark.circle.fill"
    let infoIcon =
        if #available(iOS 26.0, *) {
            "info"
        }
        else {
            "info.circle"
        }

    let backupDateLabel = #localize("safe_last_backup")
    let learnMoreButtonTitle = #localize("safe_learn_more_button_title")
    let serverNameLabel = #localize("safe_server_name")
    let serverSectionHeader = #localize("server").uppercased()
    let storageDurationLabel = #localize("safe_storage_duration")
    let successIcon = "checkmark.circle.fill"
    let threemaSafeIcon = ImageResource(name: "ThreemaSafeIntro", bundle: .main)

    var alert: AlertData?
    var backupDateValue = "-"
    var backupSizeValue = "-"
    var backupStatusValue: BackupStatus = .undetermined
    var destination: Destination?
    var isActivated = false
    var isLoading = false
    var maxBackupBytesValue = "-"
    var serverNameValue = "-"
    var showsConfirmationDialog = false
    var storageDurationValue = "-"

    var aboutButtonTitle: String {
        .localizedStringWithFormat(#localize("safe_learn_more_title"), appFlavor.localizedAppName)
    }

    var activateButtonTitle: String {
        .localizedStringWithFormat(#localize("safe_activate_button_title"), appFlavor.localizedAppName)
    }

    var changePasswordButtonTitle: String {
        isSafePasswordDefinedByAdmin
            ? #localize("safe_change_password_disabled")
            : #localize("safe_change_password")
    }

    var confirmationMessage: String {
        .localizedStringWithFormat(#localize("safe_deactivate_confirmation_message"), appFlavor.localizedAppName)
    }

    var deactivateButtonTitle: String {
        .localizedStringWithFormat(#localize("safe_deactivate_button_title"), appFlavor.localizedAppName)
    }

    var isDeactivationDisabled: Bool {
        mdmSetup.isSafeBackupForce()
    }

    var isChangePasswordDisabled: Bool {
        isSafePasswordDefinedByAdmin
    }

    var screenTitle: String {
        .localizedStringWithFormat(#localize("safe_setup_backup_title"), appFlavor.localizedAppName)
    }

    var threemaSafeDescription: String {
        .localizedStringWithFormat(#localize("safe_description"), appFlavor.localizedAppName)
    }

    var turnOffActionTitle: String {
        .localizedStringWithFormat(#localize("safe_turn_off_action_title"), appFlavor.localizedAppName)
    }

    // MARK: - Private properties

    private let appFlavor: any AppFlavorServiceProtocol
    private let backupTriggerName = Notification.Name(kSafeBackupTrigger)
    private let mdmSetup: any MDMSetupProtocol
    private let myIdentityStore: any MyIdentityStoreProtocol
    private let notificationCenter: any NotificationCenterProtocol
    private let safeConfigManager: any SafeConfigManagerProtocol
    private let safeManager: any SafeManagerProtocol
    private let safeStore: any SafeStoreProtocol

    private var observers: [any NSObjectProtocol] = []
    private var fileSizeFormatter = ByteCountFormatter()

    // MARK: - Lifecycle

    init(
        appFlavor: any AppFlavorServiceProtocol,
        myIdentityStore: any MyIdentityStoreProtocol,
        mdmSetup: any MDMSetupProtocol,
        notificationCenter: any NotificationCenterProtocol,
        safeConfigManager: any SafeConfigManagerProtocol,
        safeManager: any SafeManagerProtocol,
        safeStore: any SafeStoreProtocol
    ) {
        self.appFlavor = appFlavor
        self.myIdentityStore = myIdentityStore
        self.mdmSetup = mdmSetup
        self.notificationCenter = notificationCenter
        self.safeConfigManager = safeConfigManager
        self.safeManager = safeManager
        self.safeStore = safeStore
    }

    // MARK: - Public methods

    func onAppear() {
        observeNotifications()
        refresh()
    }

    func onDisappear() {
        cancelObservation()
    }

    func learnMoreButtonTapped() {
        let model = ThreemaSafeLearnMoreViewModel(appFlavor: appFlavor)
        destination = .learnMore(model)
    }

    func activateButtonTapped() {
        navigateToSetupPassword()
    }

    func changePasswordButtonTapped() {
        navigateToSetupPassword()
    }

    func deactivateButtonTapped() {
        showsConfirmationDialog = true
    }

    func deactivateActionConfirmed() {
        safeManager.deactivate()
        refresh()
    }

    func createBackupButtonTapped() {
        notificationCenter.post(name: backupTriggerName, object: 0)
    }

    func backupStatusRowTapped() {
        if let backupLastResult = safeConfigManager.getLastResult(), backupLastResult != #localize("safe_successful") {
            alert = AlertData(
                title: #localize("safe_backup_error_title"),
                message: backupLastResult,
                dismissTitle: #localize("ok")
            )
        }
    }

    // MARK: - Helpers

    private func observeNotifications() {
        guard observers.isEmpty else {
            return
        }
        let observerRefresh = notificationCenter.addObserver(
            forName: Notification.Name(kSafeBackupUIRefresh),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { [weak self] in
                self?.refresh()
            }
        }

        let name = Notification.Name.backupInProgressStatus
        let observerBackup = notificationCenter
            .addObserver(forName: name, object: nil, queue: .main) { [weak self] info in
                MainActor.assumeIsolated { [weak self] in
                    guard let self, let backupIsRunning = info.userInfo?[name.rawValue] as? Bool else {
                        return
                    }
                    isLoading = backupIsRunning
                }
            }
        observers.append(contentsOf: [observerRefresh, observerBackup])
    }

    private func cancelObservation() {
        observers.forEach { notificationCenter.removeObserver($0) }
        observers.removeAll()
    }

    private func resetValues() {
        serverNameValue = "-"
        maxBackupBytesValue = "-"
        storageDurationValue = "-"
        backupStatusValue = .undetermined
        backupDateValue = "-"
        backupSizeValue = "-"
    }

    private func refresh() {
        if safeManager.isActivated, safeConfigManager.getKey() != nil {
            resetValues()

            serverNameValue = safeStore.getSafeServerToDisplay()

            if let value = safeConfigManager.getMaxBackupBytes() {
                let bytes = Measurement<UnitInformationStorage>(value: Double(value), unit: .bytes)
                maxBackupBytesValue = fileSizeFormatter.string(for: bytes) ?? "-"
            }
            if let value = safeConfigManager.getRetentionDays() {
                storageDurationValue = String.localizedStringWithFormat(#localize("number_of_days"), value)
            }
            if let value = safeConfigManager.getLastResult() {
                backupStatusValue = (value == #localize("safe_successful"))
                    ? .succeeded(value)
                    : .failed(value)
            }
            if let value = safeConfigManager.getLastBackup() {
                backupDateValue = DateFormatter.mediumStyleDateShortStyleTime(value)
            }
            if let value = safeConfigManager.getBackupSize() {
                let bytes = Measurement<UnitInformationStorage>(value: Double(value), unit: .bytes)
                backupSizeValue = fileSizeFormatter.string(for: bytes) ?? "-"
            }
        }
        isActivated = safeManager.isActivated
    }

    private func navigateToSetupPassword() {
        let model = ThreemaSafePasswordViewModel(
            appFlavor: appFlavor,
            myIdentityStore: myIdentityStore,
            safeConfigManager: safeConfigManager,
            safeManager: safeManager,
            mdmSetup: mdmSetup
        )
        model.onFinish = { [weak self] in
            self?.refresh()
        }
        model.onCancel = { [weak self] in
            self?.refresh()
        }
        destination = .updatePassword(model)
    }

    private var isSafePasswordDefinedByAdmin: Bool {
        guard mdmSetup.isSafeBackupPasswordPreset(), let password = mdmSetup.safePassword() else {
            return false
        }
        let current = safeConfigManager.getKey()
        let poss = safeStore.createKey(identity: myIdentityStore.identity, safePassword: password)
        return current == poss
    }
}

extension ThreemaSafeDashboardViewModel {

    // MARK: - Public types

    struct AlertData: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
        let dismissTitle: String
    }

    enum Destination: Identifiable {
        case learnMore(ThreemaSafeLearnMoreViewModel)
        case updatePassword(ThreemaSafePasswordViewModel)

        var id: String {
            switch self {
            case .learnMore:
                "learnMore"
            case .updatePassword:
                "updatePassword"
            }
        }
    }

    enum BackupStatus {
        case undetermined
        case failed(String)
        case succeeded(String)

        var message: String {
            switch self {
            case .undetermined:
                "-"
            case let .failed(message):
                message
            case let .succeeded(message):
                message
            }
        }
    }
}
