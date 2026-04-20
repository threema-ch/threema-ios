import Combine
import FileUtility
import SwiftUI
import ThreemaFramework
import ThreemaMacros

@MainActor
final class OrphanedFilesViewModel: ObservableObject {

    // MARK: - Public properties

    @Published var isLoading = false
    @Published var isShowingBinConfirmationDialog = false

    @Published var orphanedPaths: [String] = []
    @Published var totalFilesCount = 0

    @Published var trashedPaths: [String] = []
    @Published var binSize: Int64 = 0

    var orphanedFilesSectionEnabled: Bool {
        !orphanedPaths.isEmpty
    }

    var trashBinSectionEnabled: Bool {
        !trashedPaths.isEmpty
    }

    var orphanedFilesSectionFooter: String {
        orphanedPaths.isEmpty
            ? Strings.OrphanedFiles.noFilesfooter
            : String.localizedStringWithFormat(
                #localize("settings_orphaned_files_footer"),
                "\(orphanedPaths.count)",
                "\(totalFilesCount + orphanedPaths.count)",
                TargetManager.appName
            )
    }

    var trashBinSectionFooter: String {
        trashedPaths.isEmpty
            ? Strings.TrashBin.noFilesFooter
            : String.localizedStringWithFormat(
                #localize("settings_orphaned_files_bin_footer"),
                "\(trashedPaths.count)",
                ByteCountFormatter.string(fromByteCount: binSize, countStyle: .file),
                TargetManager.appName
            )
    }

    let validationLoggingEnabled: Bool

    enum Strings {
        enum DeleteOrphanedFiles {
            static let header = #localize("settings_advanced_orphaned_files_cleanup")
            static let description = String.localizedStringWithFormat(
                #localize("settings_orphaned_files_description"),
                TargetManager.appName,
                TargetManager.appName
            )
        }

        enum OrphanedFiles {
            static let header = #localize("settings_orphaned_files_title")
            static let moveButton = #localize("settings_orphaned_files_button")
            static let noFilesfooter = #localize("settings_orphaned_files_footer_no_files")
        }

        enum TrashBin {
            static let header = #localize("settings_orphaned_files_bin_title")
            static let restoreButton = #localize("settings_orphaned_files_bin_restore_button")
            static let deleteButton = #localize("settings_orphaned_files_bin_delete_button")
            static let noFilesFooter = #localize("settings_orphaned_files_bin_footer_no_files")
        }

        enum LogFiles {
            static let header = #localize("settings_orphaned_files_log_title")
            static let logButton = #localize("settings_orphaned_files_log_all_files_button")
        }

        enum Confirmation {
            static let title = #localize("settings_orphaned_files_bin_delete_confirmation")
            static let deleteButton = #localize("settings_orphaned_files_bin_delete_button")
            static let cancelButton = #localize("cancel")
        }
    }

    // MARK: - Private Properties

    private let loggingFilesManager: LoggingFilesManagerProtocol
    private let orphanedFilesManager: OrphanedFilesManagerProtocol
    private let trashBinManager: TrashBinManagerProtocol

    // MARK: - Lifecycle

    init(
        loggingFilesManager: LoggingFilesManagerProtocol,
        orphanedFilesManager: OrphanedFilesManagerProtocol,
        trashBinManager: TrashBinManagerProtocol,
        validationLoggingEnabled: Bool
    ) {
        self.loggingFilesManager = loggingFilesManager
        self.orphanedFilesManager = orphanedFilesManager
        self.trashBinManager = trashBinManager
        self.validationLoggingEnabled = validationLoggingEnabled
    }

    // MARK: - Public methods

    func loadInitialData() async {
        await performWithLoadingAndRefresh { /* no task except for the refresh */ }
    }

    func moveOrphanedFilesToBin() async {
        await performWithLoadingAndRefresh { [weak self, orphanedPaths] in
            self?.trashBinManager.moveToTrashBin(orphanedPaths)
        }
    }

    func restoreTrashBin() async {
        await performWithLoadingAndRefresh { [weak self] in
            self?.trashBinManager.restoreTrashBin()
        }
    }

    func emptyTrashBin() {
        isShowingBinConfirmationDialog = true
    }

    func emptyTrashBinConfirmed() async {
        await performWithLoadingAndRefresh { [weak self] in
            self?.trashBinManager.emptyTrashBin()
        }
    }

    func logAppFiles() async {
        await performWithLoadingAndRefresh { [weak self] in
            self?.loggingFilesManager.logDirectoriesAndFiles()
        }
    }

    // MARK: - Helpers

    private func refreshData() {
        (orphanedPaths, totalFilesCount) = orphanedFilesManager.getOrphanedFilesData()
        (trashedPaths, binSize) = trashBinManager.getTrashBinFilesData()
    }

    private func performWithLoadingAndRefresh(_ work: () async -> Void) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await Task.sleep(seconds: 0.3)
        }
        catch {
            // No operation. Task canceled before sleep has ended
        }
        await work()
        refreshData()
    }
}
