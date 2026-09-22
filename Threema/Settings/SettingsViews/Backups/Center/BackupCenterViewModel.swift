import Foundation
import Observation
import ThreemaMacros

@MainActor
@Observable
final class BackupCenterViewModel {

    // MARK: - Properties

    let screenTitle = #localize("backup_center")
    let onlineSectionHeader = #localize("online").uppercased()
    let onlineSubHeadline = #localize("backup_center_threema_safe_description")
    let offlineSectionHeader = #localize("backup_center_offline_section_header_title").uppercased()
    let offlineTitle = #localize("backup_center_local_backup_title")
    let offlineSubHeadline = #localize("backup_center_local_backup_description")

    let learnMoreButtonTitle = #localize("learn_more")

    var safeStatusLabel: String {
        isActivated ? #localize("on") : #localize("off")
    }

    var onlineTitle: String {
        String.localizedStringWithFormat(#localize("threema_safe_flavored"), appFlavor.appName)
    }

    var offlineBackupStatus = ""
    var hasLastBackup: Bool = false

    @ObservationIgnored var onSafeLearnMoreButtonTapped: () -> Void = { /* no-op */ }
    @ObservationIgnored var onLocalDataBackupLearnMoreButtonTapped: () -> Void = { /* no-op */ }
    @ObservationIgnored var onSafeButtonTapped: () -> Void = { /* no-op */ }
    @ObservationIgnored var onLocalDataBackupDataButtonTapped: () -> Void = { /* no-op */ }

    // MARK: - Private properties

    private let appFlavor: any AppFlavorServiceProtocol
    private let manager: any BackupCreateManagerProtocol
    private let safeManager: SafeManagerProtocol
    private var isActivated = false

    // MARK: - Lifecycle

    init(
        appFlavor: any AppFlavorServiceProtocol,
        manager: any BackupCreateManagerProtocol,
        safeManager: SafeManagerProtocol
    ) {
        self.appFlavor = appFlavor
        self.manager = manager
        self.safeManager = safeManager
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
        hasLastBackup = manager.lastBackup != nil

        offlineBackupStatus =
            if let date = manager.lastBackup?.date {
                String.localizedStringWithFormat(
                    #localize("backup_local_backup_center_status_available"),
                    DateFormatter.accessibilityRelativeDayTime(date)
                )
            }
            else {
                #localize("backup_local_backup_center_status_unavailable")
            }
    }
}
