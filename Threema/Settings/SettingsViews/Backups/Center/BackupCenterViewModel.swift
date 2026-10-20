import Foundation
import Observation
import ThreemaMacros

@MainActor
@Observable
final class BackupCenterViewModel {

    // MARK: - Properties

    let screenTitle = #localize("backup_center")
    let onlineSectionHeader = #localize("online")
    let onlineSubHeadline = #localize("backup_center_threema_safe_description")
    let offlineSectionHeader = #localize("backup_center_offline_section_header_title")
    let offlineTitle = #localize("backup_center_local_backup_title")
    let offlineSubHeadline = #localize("backup_center_local_backup_description")
    let noBackupStatus = #localize("backup_local_backup_center_status_unavailable")
    let learnMoreButtonTitle = #localize("learn_more")
    let statusIconName = "circle.fill"

    var onlineTitle: String {
        String.localizedStringWithFormat(#localize("threema_safe_flavored"), appFlavor.appName)
    }

    var safeStatusLabel = ""
    var hasSafeBackup: Bool = false

    var localBackupStatus = ""
    var hasLocalBackup: Bool = false

    @ObservationIgnored var onSafeLearnMoreButtonTapped: () -> Void = { /* no-op */ }
    @ObservationIgnored var onLocalDataBackupLearnMoreButtonTapped: () -> Void = { /* no-op */ }
    @ObservationIgnored var onSafeButtonTapped: () -> Void = { /* no-op */ }
    @ObservationIgnored var onLocalDataBackupDataButtonTapped: () -> Void = { /* no-op */ }

    // MARK: - Private properties

    private var isActivated = false

    private let appFlavor: any AppFlavorServiceProtocol
    private let backupManager: any BackupCreateManagerProtocol
    private let safeManager: any SafeManagerProtocol
    private let safeConfigManager: any SafeConfigManagerProtocol

    // MARK: - Lifecycle

    init(
        appFlavor: any AppFlavorServiceProtocol,
        backupManager: any BackupCreateManagerProtocol,
        safeManager: any SafeManagerProtocol,
        safeConfigManager: any SafeConfigManagerProtocol
    ) {
        self.appFlavor = appFlavor
        self.backupManager = backupManager
        self.safeManager = safeManager
        self.safeConfigManager = safeConfigManager
    }

    func onAppear() {
        refresh()
    }

    func safeLearnMoreButtonTapped() {
        onSafeLearnMoreButtonTapped()
    }

    func localDataBackupLearnMoreButtonTapped() {
        onLocalDataBackupLearnMoreButtonTapped()
    }

    func safeButtonTapped() {
        onSafeButtonTapped()
    }

    func localDataBackupDataButtonTapped() {
        onLocalDataBackupDataButtonTapped()
    }

    // MARK: - Private methods

    private func refresh() {
        isActivated = safeManager.isActivated
        hasSafeBackup = safeConfigManager.getLastBackup() != nil

        safeStatusLabel =
            if let date = safeConfigManager.getLastBackup() {
                String.localizedStringWithFormat(
                    #localize("backup_status_availability_label"),
                    DateFormatter.accessibilityRelativeDayTime(date)
                )
            }
            else {
                noBackupStatus
            }

        hasLocalBackup = backupManager.lastBackup != nil
        localBackupStatus =
            if let date = backupManager.lastBackup?.date {
                String.localizedStringWithFormat(
                    #localize("backup_status_availability_label"),
                    DateFormatter.accessibilityRelativeDayTime(date)
                )
            }
            else {
                noBackupStatus
            }
    }
}
