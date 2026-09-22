import DataBackup
import Observation
import ThreemaFramework
import ThreemaMacros
import UIKit

@MainActor
@Observable
final class LocalBackupRecoveryKeyViewModel {

    // MARK: - Public types

    struct KeyRow: Identifiable {
        let id: Int
        let cells: [KeyCell]

        struct KeyCell: Identifiable {
            let id: Int
            let text: String
        }
    }

    // MARK: - Public properties

    @ObservationIgnored var onSaveButtonTapped: () -> Void = { /* no-op */ }
    @ObservationIgnored var onDeleteKeyConfirmed: () -> Void = { /* no-op */ }
    @ObservationIgnored var onCreateNewKeyConfirmed: () -> Void = { /* no-op */ }

    let copyIconName = "document.on.document"
    let deleteIconName = "trash"
    let errorIconName = "exclamationmark.circle"
    let headerSymbolName = "key.fill"
    let createKeyIconName = "chevron.forward"

    let cancelButtonTitle = #localize("cancel")
    let copyLabel = #localize("copy")
    let copiedLabel = #localize("copied_exclamationmark")
    let createKeyDescription = #localize("create_a_key_description")
    let createKeyLabel = #localize("create_a_key")
    let currentKeyLabel = #localize("current_key")
    let deleteLabel = #localize("remove_key")
    let createNewKeyLabel = #localize("backup_local_recovery_create_new_key_backup_title")
    let keyDescription = #localize("backup_local_recovery_key_description")
    let keyTitle = #localize("recovery_key")
    let saveButtonTitle = #localize("backup_local_recovery_key_save_button_title")
    let stepLabel = String.localizedStringWithFormat(#localize("step_count_from_total_steps"), 1, 3).uppercased()

    var recoveryKeyUsage: String?

    let warning = #localize("backup_local_recovery_password_warning")
    let warningIconName = "info.circle"

    let deleteAlertTitle = #localize("backup_local_recovery_delete_confirmation_title")
    let deleteAlertMessage = #localize("backup_local_recovery_delete_confirmation_message")

    let createNewKeyAlertTitle = #localize("backup_local_recovery_create_new_confirmation_title")
    let createNewKeyAlertMessage = #localize("backup_local_recovery_create_new_confirmation_message")

    var currentRecoveryKey: BackupEncryptionKey = .none {
        didSet {
            updateRecoveryKeyInfo()
        }
    }

    var info: (title: String, content: String)?

    var showDeleteKeyAlert = false
    var showCreateNewKeyAlert = false

    var copyButtonTitle: String {
        didCopyKey ? copiedLabel : copyLabel
    }

    var hasDefaultRecoveryKey: Bool {
        currentRecoveryKey.isDefault
    }

    private var didCopyKey = false
    private let manager: any BackupCreateManagerProtocol

    // MARK: - Lifecycle

    init(manager: any BackupCreateManagerProtocol) {
        self.manager = manager
    }

    // MARK: - Public methods

    func onAppear() {
        do {
            if case .none = manager.currentRecoveryKey {
                try manager.createNewRecoveryKey()
            }
        }
        catch {
            // TODO: Show user facing error
        }

        self.currentRecoveryKey = manager.currentRecoveryKey
    }

    func onDisappear() {
        didCopyKey = false
    }

    func copyKeyButtonTapped() {
        UIPasteboard.general.set(string: currentRecoveryKey.rawValue, sensitiveContent: .secretAllDevices)
        didCopyKey = true
    }

    func deleteKeyButtonTapped() {
        showDeleteKeyAlert = true
    }

    func saveButtonTapped() {
        onSaveButtonTapped()
    }

    func createNewKeyButtonTapped() {
        showCreateNewKeyAlert = true
    }

    func deleteKeyConfirmed() {
        showDeleteKeyAlert = false

        do {
            try manager.deleteDefaultRecoveryKey()
            onDeleteKeyConfirmed()
        }
        catch {
            // TODO: Display error to the user
        }
    }

    func createNewKeyConfirmed() {
        showCreateNewKeyAlert = false
        do {
            try manager.createNewRecoveryKey()
            try manager.removePreviousBackup()

            onCreateNewKeyConfirmed()
        }
        catch {
            // TODO: Display error to the user
        }
    }

    /// Splits the recovery key raw string into fixed-size chunks and groups them into rows for display.
    func keyRows(columnsPerRow: Int, charactersPerColumn: Int = 4) -> [KeyRow] {
        let characters = Array(currentRecoveryKey.rawValue)

        let cells = stride(from: 0, to: characters.count, by: charactersPerColumn)
            .map { offset in
                KeyRow.KeyCell(
                    id: offset,
                    text: String(characters[offset..<min(offset + charactersPerColumn, characters.count)])
                )
            }

        guard columnsPerRow > 0 else {
            return cells.isEmpty ? [] : [KeyRow(id: 0, cells: cells)]
        }

        return stride(from: 0, to: cells.count, by: columnsPerRow)
            .map { index in
                KeyRow(id: index, cells: Array(cells[index..<min(index + columnsPerRow, cells.count)]))
            }
    }

    // MARK: Helpers

    private func updateRecoveryKeyInfo() {
        guard hasDefaultRecoveryKey else {
            info = nil
            recoveryKeyUsage = nil
            return
        }

        info = (
            title: #localize("backup_local_recovery_key_info_description"),
            content: #localize("backup_local_recovery_key_info_title")
        )

        if let date = currentRecoveryKey.lastBackupDate {
            let formatted = date.formatted(.dateTime.day().month(.wide).year())
            recoveryKeyUsage = String.localizedStringWithFormat(
                #localize("backup_local_recovery_key_usage_description"), formatted
            )
        }
    }
}
