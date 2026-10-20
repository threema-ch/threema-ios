import DataBackup
import Foundation
import Observation
import ThreemaFramework
import ThreemaMacros

@MainActor
@Observable
final class LocalBackupRecoveryKeySheetViewModel {

    // MARK: - Public properties

    @ObservationIgnored var onCloseButtonTapped: () -> Void = { /* no-op */ }
    @ObservationIgnored var onContentHeightChange: (CGFloat) -> Void = { _ in /* no-op */ }
    @ObservationIgnored var onCreateNewKeyButtonTapped: () -> Void = { /* no-op */ }

    let createNewKeyIconName = "chevron.forward"
    let createNewKeyLabel = #localize("create_new_key")
    let currentKeyIconName = "checkmark"
    let currentKeyLabel = #localize("current_key")
    let title = #localize("Recovery_Key")

    var recoveryKeyTrimmed: String {
        manager.currentRecoveryKey.trimmedValue
    }

    var titleRowHeight: CGFloat {
        navigationBarHeight ?? 44
    }

    private let manager: any BackupCreateManagerProtocol

    @ObservationIgnored private var contentHeight: CGFloat?

    private var navigationBarHeight: CGFloat?

    // MARK: - Lifecycle

    init(manager: any BackupCreateManagerProtocol) {
        self.manager = manager
    }

    // MARK: - Public methods

    func closeButtonTapped() {
        onCloseButtonTapped()
    }

    func contentHeightChanged(_ height: CGFloat) {
        contentHeight = height
        reportSheetHeight()
    }

    func navigationBarHeightChanged(_ height: CGFloat) {
        navigationBarHeight = height
        reportSheetHeight()
    }

    func createNewKeyButtonTapped() {
        onCreateNewKeyButtonTapped()
    }

    // MARK: - Private methods

    private func reportSheetHeight() {
        guard let contentHeight, let navigationBarHeight else {
            return
        }

        onContentHeightChange(contentHeight + navigationBarHeight)
    }
}
