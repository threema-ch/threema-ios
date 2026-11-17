import CocoaLumberjackSwift
import FileUtility
import Foundation

/// Manages the file of a backup ``BackupCreateManager`` writes until it is recorded: it carries a partial name until
/// then, so a file the app was terminated before recording can be recognized and deleted.
public struct PartialBackupFiles {

    // MARK: Private properties

    private let fileUtility: any FileUtilityProtocol

    private let pathExtension = "partial"

    // MARK: Lifecycle

    public init(fileUtility: any FileUtilityProtocol) {
        self.fileUtility = fileUtility
    }

    // MARK: Public methods

    /// Where the backup that ends up at `url` is written to until it is recorded.
    func partialURL(for url: URL) -> URL {
        url.appendingPathExtension(pathExtension)
    }

    /// Renames the partial file of the backup to `url`, replacing a file that is already there.
    func moveToFinalName(_ url: URL) throws {
        try fileUtility.replaceFile(from: partialURL(for: url), to: url)
    }

    /// Deletes all partial backup files in the documents directory, where ``BackupCreateManager`` writes backups to.
    ///
    /// - Important: Must not be called while a backup is written, because its file would be deleted underneath it.
    ///              Call it on app launch, before any backup can be started.
    public func removeLeftovers() {
        let urls: [URL]
        do {
            urls = try fileUtility.contentsOfDirectory(
                at: .documentsDirectory,
                includingPropertiesForKeys: nil,
                options: []
            )
        }
        catch {
            DDLogError("[PartialBackupFiles] Could not list the documents directory: \(error)")
            return
        }

        for url in urls where url.pathExtension == pathExtension {
            DDLogNotice("[PartialBackupFiles] Deleting a backup that was never recorded: \(url.lastPathComponent)")

            do {
                try fileUtility.delete(at: url)
            }
            catch {
                // Still has its partial name, so the next call tries again.
                DDLogError("[PartialBackupFiles] Could not delete a backup that was never recorded: \(error)")
            }
        }
    }
}
