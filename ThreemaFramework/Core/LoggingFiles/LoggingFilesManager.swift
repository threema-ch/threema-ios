import FileUtility
import Foundation

public final class LoggingFilesManager: LoggingFilesManagerProtocol {
    private let fileUtility: FileUtilityProtocol

    public init(fileUtility: FileUtilityProtocol) {
        self.fileUtility = fileUtility
    }

    // MARK: - LoggingFilesManagerProtocol

    public func logDirectoriesAndFiles() {
        let urls = [
            fileUtility.appDataDirectory(appGroupID: AppGroup.groupID()),
            fileUtility.appDocumentsDirectory,
            fileUtility.appCachesDirectory,
            FileManager.default.temporaryDirectory,
        ].compactMap { $0 }

        urls.forEach { fileUtility.logDirectoriesAndFiles(pathURL: $0) }
    }
}
