import Foundation
import Observation
import ThreemaFramework
import ThreemaMacros

@MainActor
@Observable
final class LocalBackupDetailsViewModel {
    let screenTitle = #localize("data_backup")

    let shareActionTitle = #localize("share_backup")
    let shareActionIconName = "square.and.arrow.up"
    let keyActionTitle = #localize("recovery_key")
    let buttonTitle = #localize("create_new_backup")

    @ObservationIgnored var onCreateButtonTapped: () -> Void = { /* no-op */ }
    @ObservationIgnored var onKeyActionButtonTapped: () -> Void = { /* no-op */ }

    var shareURL: URL {
        manager.backupURL
    }

    var detailItems: [DetailItem] {
        guard let lastBackup = manager.lastBackup else {
            return []
        }

        return [
            DetailItem(label: #localize("last_backup"), value: formattedDate(lastBackup.date)),
            DetailItem(label: #localize("backup_size"), value: formattedSize(lastBackup.size)),
            DetailItem(
                label: #localize("messages"),
                value: includedValue(lastBackup.includesMessages),
                isValueHighlighted: lastBackup.includesMessages
            ),
            DetailItem(
                label: #localize("media"),
                value: includedValue(lastBackup.includesMedia),
                isValueHighlighted: lastBackup.includesMedia
            ),
            DetailItem(label: #localize("backup_location"), value: backupLocation),
        ]
    }

    var isRecoveryKeyNavigationVisible: Bool {
        if case .default = manager.currentRecoveryKey {
            true
        }
        else {
            false
        }
    }

    private var backupLocation: String {
        let url = manager.backupURL
        return "\(url.deletingLastPathComponent().lastPathComponent)/\(url.lastPathComponent)"
    }

    private let manager: any BackupCreateManagerProtocol

    init(manager: any BackupCreateManagerProtocol) {
        self.manager = manager
    }

    func keyActionButtonTapped() {
        onKeyActionButtonTapped()
    }

    func createButtonTapped() {
        onCreateButtonTapped()
    }

    // MARK: - Private methods

    private func formattedDate(_ date: Date) -> String {
        DateFormatter.accessibilityRelativeDayTime(date)
    }

    private func formattedSize(_ sizeInBytes: UInt64) -> String {
        Int64(clamping: sizeInBytes).formatted(.byteCount(style: .file))
    }

    private func includedValue(_ isIncluded: Bool) -> String {
        isIncluded
            ? #localize("backup_local_details_included")
            : #localize("backup_local_details_not_included")
    }

    struct DetailItem: Identifiable, Hashable {
        let label: String
        let value: String
        var isValueHighlighted = false

        var id: String { label }
    }
}
