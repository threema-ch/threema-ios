import CocoaLumberjackSwift
import CoreData
import FileUtility
import Foundation
import RemoteSecretProtocol

public protocol DatabaseManagerProtocol: DatabaseManagerProtocolObjc {
    var persistentStoreCoordinator: NSPersistentStoreCoordinator { get throws }

    static func storeRequiresImport(fileUtility: FileUtilityProtocol) -> Bool

    /// Database main context for main thread.
    func databaseContext() -> DatabaseContextProtocol

    /// Database child context for main or background thread.
    /// - Parameter withChildContextForBackgroundProcess: Is true get database context for background thread
    func databaseContext(withChildContextForBackgroundProcess: Bool) -> DatabaseContextProtocol

    /// Check free available storage on the device, if there a database file.
    /// - Parameter showAlert: Called if not enough disk space available
    /// - Throws: DatabaseManagerError.notEnoughDiskSpaceAvailable
    func checkFreeDiskSpaceForDatabaseMigration() throws

    static func dbExists(appGroupID: String, fileUtility: FileUtilityProtocol) -> Bool

    func storeRequiresMigration() -> DatabaseManager.StoreRequiresMigration

    func migrateDB() throws

    #if DEBUG
        /// Imports an database from App/Documents folder, this is useful for testing database migration.
        func importOldVersionDatabase() throws -> Bool
    #endif

    /// Imports a repaired database.
    func importRepairedDatabase() throws
}

@objc public protocol DatabaseManagerProtocolObjc {
    func eraseDB() throws
}

public final class DatabaseManager: NSObject, DatabaseManagerProtocol {

    // MARK: - Internal types
    
    public enum StoreRequiresMigration {
        case none, required, error
    }
    
    public enum DatabaseManagerError: Error {
        case notEnoughDiskSpaceAvailable(minimumRequiredDiskSpace: String, freeDiskSpace: String)
        case migrationFailed(message: String?)
        case appDataDirectoryMissing
        case appDocumentsDirectoryMissing
    }
    
    private struct StorePaths {
        let storeURL: URL

        let urlToBackupStore: URL
        let tmpURLToBackupStore: URL

        let walURL: URL
        let urlToBackupWal: URL
        let tmpURLToBackupWal: URL

        let shmURL: URL
        let urlToBackupShm: URL
        let tmpURLToBackupShm: URL

        let urlToExternalStorage: URL
        let tmpURLToExternalStorage: URL

        let urlToOldStore: URL
        let urlToOldWal: URL
        let urlToOldShm: URL
        let urlToOldSupport: URL
        let urlToOldExternalStorage: URL

        let urlToRepairedStore: URL

        let urlToOldVersion: URL
        let urlToOldVersionStore: URL
        let urlToOldVersionWal: URL
        let urlToOldVersionShm: URL
        let urlToOldVersionExternalStorage: URL

        init(appDataDirectoryURL: URL, appDocumentsDirectoryURL: URL, coreDataModelVersion: String) {
            let timeStamp = Date.now.timeIntervalSince1970

            // Actual database URL's
            self.storeURL = appDataDirectoryURL.appendingPathComponent(databaseFileName, isDirectory: false)

            self.urlToBackupStore = URL(
                fileURLWithPath: "\(storeURL.path).bak.\(coreDataModelVersion)",
                isDirectory: false
            )
            self.tmpURLToBackupStore = URL(
                fileURLWithPath: urlToBackupStore.absoluteURL.path.appending(".\(timeStamp)"),
                isDirectory: false
            )

            self.walURL = URL(fileURLWithPath: storeURL.absoluteURL.path.appending("-wal"), isDirectory: false)
            self.urlToBackupWal = URL(
                fileURLWithPath: walURL.absoluteURL.path.appending(".bak.\(coreDataModelVersion)"),
                isDirectory: false
            )
            self.tmpURLToBackupWal = URL(
                fileURLWithPath: urlToBackupWal.absoluteURL.path.appending(".\(timeStamp)"),
                isDirectory: false
            )

            self.shmURL = URL(fileURLWithPath: storeURL.absoluteURL.path.appending("-shm"), isDirectory: false)
            self.urlToBackupShm = URL(
                fileURLWithPath: shmURL.absoluteURL.path.appending(".bak.\(coreDataModelVersion)"),
                isDirectory: false
            )
            self.tmpURLToBackupShm = URL(
                fileURLWithPath: urlToBackupShm.absoluteURL.path.appending(".\(timeStamp)"),
                isDirectory: false
            )

            self.urlToExternalStorage = appDataDirectoryURL
                .appendingPathComponent(databaseExternalStoragePath, isDirectory: true)
            self.tmpURLToExternalStorage = appDataDirectoryURL
                .appendingPathComponent(databaseTemporaryExternalStoragePath, isDirectory: true)

            // Old database URL's
            self.urlToOldStore = appDocumentsDirectoryURL.appendingPathComponent(databaseFileName, isDirectory: false)
            self.urlToOldWal = URL(
                fileURLWithPath: urlToOldStore.absoluteURL.path.appending("-wal"),
                isDirectory: false
            )
            self.urlToOldShm = URL(
                fileURLWithPath: urlToOldStore.absoluteURL.path.appending("-shm"),
                isDirectory: false
            )
            self.urlToOldSupport = appDocumentsDirectoryURL.appendingPathComponent(
                databaseSupportPath,
                isDirectory: true
            )
            self.urlToOldExternalStorage = appDocumentsDirectoryURL.appendingPathComponent(
                databaseExternalStoragePath,
                isDirectory: true
            )

            // Repaired and old version (for migration test) URL's
            self.urlToRepairedStore = appDocumentsDirectoryURL
                .appendingPathComponent(databaseRepairedFileName, isDirectory: false)

            self.urlToOldVersion = appDocumentsDirectoryURL.appendingPathComponent(
                databaseOldVersionPath,
                isDirectory: true
            )
            self.urlToOldVersionStore = urlToOldVersion.absoluteURL.appendingPathComponent(
                databaseFileName,
                isDirectory: false
            )
            self.urlToOldVersionWal = URL(
                fileURLWithPath: urlToOldVersionStore.absoluteURL.path.appending("-wal"),
                isDirectory: false
            )
            self.urlToOldVersionShm = URL(
                fileURLWithPath: urlToOldVersionStore.absoluteURL.path.appending("-shm"),
                isDirectory: false
            )
            self.urlToOldVersionExternalStorage = urlToOldVersion.absoluteURL
                .appendingPathComponent(databaseExternalStoragePath, isDirectory: true)
        }
    }

    // Relative paths and file names
    public static let databaseFileName = "ThreemaData.sqlite"
    public static let databaseSupportPath = ".ThreemaData_SUPPORT"
    public static let databaseExternalStoragePath = "\(databaseSupportPath)/_EXTERNAL_DATA"
    public static let databaseTemporaryExternalStoragePath = "tmpPathToReplacementData"
    public static let databaseRepairedFileName = "RepairedThreemaData.sqlite"
    public static let databaseOldVersionPath = "ThreemaDataOldVersion"

    static let databaseModelName = "ThreemaData"
    static let databaseEncryptedModelName = "ThreemaDataEncrypted"
    static let databaseModelVersion = 54

    // MARK: - Private properties

    private let appGroupID: String
    private let fileUtility: FileUtilityProtocol
    private let isRemoteSecretEnabled: Bool
    
    private static let persistentStoreCoordinatorQueue = DispatchQueue(label: "persistentStoreCoordinatorQueue")
    #if DEBUG
        static var localPersistentStoreCoordinator: NSPersistentStoreCoordinator?
    #else
        private static var localPersistentStoreCoordinator: NSPersistentStoreCoordinator?
    #endif

    private lazy var managedObjectModel: NSManagedObjectModel? = {
        let modelName = isRemoteSecretEnabled ? DatabaseManager.databaseEncryptedModelName : DatabaseManager
            .databaseModelName
        guard let modelURL = BundleUtil.url(
            forResource: modelName,
            withExtension: "momd"
        )
        else {
            return nil
        }
        return NSManagedObjectModel(contentsOf: modelURL)
    }()

    // MARK: - Lifecycle

    required init(
        appGroupID: String,
        fileUtility: FileUtilityProtocol,
        remoteSecretManager: RemoteSecretManagerProtocol
    ) {
        self.appGroupID = appGroupID
        self.fileUtility = fileUtility
        self.isRemoteSecretEnabled = remoteSecretManager.isRemoteSecretEnabled
    }

    convenience init(
        appGroupID: String,
        remoteSecretManager: RemoteSecretManagerProtocol
    ) {
        self.init(
            appGroupID: appGroupID,
            fileUtility: FileUtility.shared,
            remoteSecretManager: remoteSecretManager
        )
    }

    // MARK: - Public properties
    
    public static func storeRequiresImport(fileUtility: FileUtilityProtocol) -> Bool {
        fileUtility.fileExists(
            at: fileUtility.appDocumentsDirectory?.appendingPathComponent(DatabaseManager.databaseRepairedFileName)
        )
    }
    
    @objc public static func isExistingDBEncrypted() -> Bool {
        guard let storePaths = try? DatabaseManager.storePaths(
            appGroupID: AppGroup.groupID(),
            fileUtility: FileUtility.shared
        ) else {
            DDLogError("Failed to get store paths")
            return false
        }

        guard FileUtility.shared.fileExists(at: storePaths.storeURL) else {
            return false
        }

        let options: [AnyHashable: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
            NSPersistentStoreFileProtectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
        ]

        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                type: .sqlite,
                at: storePaths.storeURL,
                options: options
            )

            guard let modelVersion = metadata["NSStoreModelVersionIdentifiers"] else {
                return false
            }
            let modelVersionString = (modelVersion as? [String])?.first ?? ""
            
            return modelVersionString.contains("Encrypted")
        }
        catch {
            DDLogError("PersistentStoreCoordinator could not get the metadata of the store: \(error)")
            return false
        }
    }

    public var persistentStoreCoordinator: NSPersistentStoreCoordinator {
        get throws {
            try DatabaseManager.persistentStoreCoordinatorQueue.sync {
                if let localPersistentStoreCoordinator = DatabaseManager.localPersistentStoreCoordinator {
                    return localPersistentStoreCoordinator
                }

                let storePaths = try self.storePaths()

                try migrateDatabaseFromOldToNewLocation()

                let requiresMigration: StoreRequiresMigration = self.storeRequiresMigration()

                switch requiresMigration {
                case .none:
                    // Migration is currently not required, but if a previous migration completed without
                    // us having a chance to put the external data storage folder back in place, we will
                    // end up with the media in tmpURLToExternalStorage where it is inaccessible to Core Data.
                    // Attempt to move the media back in such a case, if necessary
                    if fileUtility.fileExists(at: storePaths.tmpURLToExternalStorage) {
                        // Ooops, the external storage directory already exists, so we should not delete it or
                        // we will risk losing some (new) media. Instead, merge the contents of the two directories
                        do {
                            try fileUtility.mergeContentsOfPath(
                                from: storePaths.tmpURLToExternalStorage,
                                to: storePaths.urlToExternalStorage
                            )

                            fileUtility.deleteIfExists(at: storePaths.tmpURLToExternalStorage)
                        }
                        catch {
                            DDLogError("Failed to merge temporary external storage directory: \(error)")
                        }
                    }

                    if fileUtility.fileExists(at: storePaths.urlToBackupStore) {
                        removeMigrationLeftovers()
                    }

                case .required:
                    // Migration is required - check if a store backup file (.bak) exists. If so, the last migration
                    // attempt has failed, and before trying again, we copy the backup back to the store URL so
                    // Core Data can make another try. Also, during migration, we move away the external data
                    // storage folder to keep Core Data from copying every single external data item (media etc.),
                    // which is useless, and takes a long time and a lot of disk space.
                    if backupStoreExists(storePaths) {
                        // Delete the broken, half-migrated store and restore the backup
                        try restoreStore(storePaths)

                        // Remove external storage folder; the original will be at tmpURLToExternalStorage at this point
                        if fileUtility.fileExists(at: storePaths.urlToExternalStorage) {
                            try fileUtility.mergeContentsOfPath(
                                from: storePaths.urlToExternalStorage,
                                to: storePaths.tmpURLToExternalStorage
                            )
                            fileUtility.deleteIfExists(at: storePaths.urlToExternalStorage)
                        }
                    }
                    else {
                        // Before migration begins, copy the store to a backup file (.bak). We do this in two steps:
                        // first we copy the store to a .bak2 file, and then we rename the .bak2 to .bak. This is
                        // so that if the copy operation is interrupted (which is possible as it can take some time for
                        // large stores), we don't end up using a broken .bak when we start again.
                        removeMigrationLeftovers()
                        fileUtility.deleteIfExists(at: storePaths.tmpURLToExternalStorage)

                        try backupStore(storePaths)

                        // Move away external storage directory during migration
                        if fileUtility.fileExists(at: storePaths.urlToExternalStorage) {
                            try fileUtility.move(
                                from: storePaths.urlToExternalStorage,
                                to: storePaths.tmpURLToExternalStorage
                            )
                        }
                    }

                case .error:
                    throw DatabaseManagerError.migrationFailed(message: "Could not load the managed object model")
                }

                guard let managedObjectModel else {
                    throw DatabaseManagerError.migrationFailed(message: "Could not load the managed object model")
                }

                let options: [AnyHashable: Any] = [
                    NSMigratePersistentStoresAutomaticallyOption: true,
                    NSInferMappingModelAutomaticallyOption: true,
                    NSPersistentStoreFileProtectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
                ]

                GroupDeliveryReceiptValueTransformer.register()

                let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
                try coordinator.addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: storePaths.storeURL,
                    options: options
                )

                if case requiresMigration = StoreRequiresMigration.required {
                    // Core Data migration is now complete. Replace the default external storage folder with the version
                    // pre upgrade, and delete the store backup files.
                    try fileUtility.mergeContentsOfPath(
                        from: storePaths.tmpURLToExternalStorage,
                        to: storePaths.urlToExternalStorage
                    )

                    if fileUtility.fileExists(at: storePaths.tmpURLToExternalStorage) {
                        try fileUtility.delete(at: storePaths.tmpURLToExternalStorage)
                    }

                    removeMigrationLeftovers()
                }

                DatabaseManager.localPersistentStoreCoordinator = coordinator

                return DatabaseManager.localPersistentStoreCoordinator!
            }
        }
    }

    // MARK: - Migration

    public func migrateDB() throws {
        _ = try persistentStoreCoordinator
    }
    
    public func storeRequiresMigration() -> StoreRequiresMigration {
        var storePaths: StorePaths
        do {
            storePaths = try self.storePaths()
        }
        catch {
            DDLogError("\(error)")
            return .error
        }

        guard fileUtility.fileExists(at: storePaths.storeURL) else {
            return .none
        }

        let options: [AnyHashable: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
            NSPersistentStoreFileProtectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
        ]

        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                type: .sqlite,
                at: storePaths.storeURL,
                options: options
            )

            guard let managedObjectModel else {
                DDLogError("Could not load the managed object model")
                return .error
            }

            return managedObjectModel
                .isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) ? .none : .required
        }
        catch {
            DDLogError("PersistentStoreCoordinator could not get the metadata of the store: \(error)")
            print(error.localizedDescription)
            return .error
        }
    }
    
    public func checkFreeDiskSpaceForDatabaseMigration() throws {
        guard let storePaths = try? storePaths(),
              let storeSize = fileUtility.fileSizeInBytes(fileURL: storePaths.storeURL) else {
            DDLogError("Failed to get file size of the database, looks like no database file found")
            return
        }

        let freeDiskSpace = fileUtility.freeDiskSpaceInBytes()
        let minimumRequiredDiskSpace: Int64 = max(3 * storeSize, 1024 * 1024 * 512)

        // Must have at least 3 * storeSize free, and in any case at least 512 MB
        guard freeDiskSpace >= minimumRequiredDiskSpace else {
            let storeSizeString = ByteCountFormatter.string(fromByteCount: storeSize, countStyle: .file)
            let freeDiskSpaceString = ByteCountFormatter.string(fromByteCount: freeDiskSpace, countStyle: .file)
            let minimumRequiredDiskSpaceString = ByteCountFormatter.string(
                fromByteCount: minimumRequiredDiskSpace,
                countStyle: .file
            )
            DDLogError(
                "Not enough disk space for migration (database size \(storeSizeString), \(freeDiskSpaceString) free)"
            )

            throw DatabaseManagerError.notEnoughDiskSpaceAvailable(
                minimumRequiredDiskSpace: minimumRequiredDiskSpaceString,
                freeDiskSpace: freeDiskSpaceString
            )
        }
    }

    public func importRepairedDatabase() throws {
        let storePaths = try storePaths()

        guard fileUtility.fileExists(at: storePaths.urlToRepairedStore) else {
            return
        }

        let startTime = CACurrentMediaTime()

        // Replace DB with repaired one
        try fileUtility.delete(at: storePaths.storeURL)
        try fileUtility.move(from: storePaths.urlToRepairedStore, to: storePaths.storeURL)

        let endTime = CACurrentMediaTime()
        DDLogInfo("DB setup time \(endTime - startTime) s")
    }

    #if DEBUG
        public func importOldVersionDatabase() throws -> Bool {
            let storePaths = try storePaths()

            guard fileUtility.fileExists(at: storePaths.urlToOldVersionStore) else {
                return false
            }

            // Replace DB with old version
            try fileUtility.delete(at: storePaths.storeURL)
            try fileUtility.move(from: storePaths.urlToOldVersionStore, to: storePaths.storeURL)

            // Delete temp. WAL and SHM files anyway, otherwise will ending in a corrupt database
            try fileUtility.delete(at: storePaths.walURL)
            if fileUtility.fileExists(at: storePaths.urlToOldVersionWal) {
                try fileUtility.move(from: storePaths.urlToOldVersionWal, to: storePaths.walURL)
            }
            try fileUtility.delete(at: storePaths.shmURL)
            if fileUtility.fileExists(at: storePaths.urlToOldVersionShm) {
                try fileUtility.move(from: storePaths.urlToOldVersionShm, to: storePaths.shmURL)
            }

            if fileUtility.fileExists(at: storePaths.urlToOldVersionExternalStorage) {
                // Replace External Storage with old version
                try fileUtility.delete(at: storePaths.urlToExternalStorage)
                try fileUtility.move(
                    from: storePaths.urlToOldVersionExternalStorage,
                    to: storePaths.urlToExternalStorage
                )
            }

            try fileUtility.delete(at: storePaths.urlToOldVersion)

            return true
        }
    #endif
    
    // Copy all store files to .bak.version.timeStamp and rename to .bak.version
    private func backupStore(_ storePaths: StorePaths) throws {
        try fileUtility.copy(from: storePaths.storeURL, to: storePaths.tmpURLToBackupStore)
        try fileUtility.move(from: storePaths.tmpURLToBackupStore, to: storePaths.urlToBackupStore)

        try fileUtility.copy(from: storePaths.walURL, to: storePaths.tmpURLToBackupWal)
        try fileUtility.move(from: storePaths.tmpURLToBackupWal, to: storePaths.urlToBackupWal)

        try fileUtility.copy(from: storePaths.shmURL, to: storePaths.tmpURLToBackupShm)
        try fileUtility.move(from: storePaths.tmpURLToBackupShm, to: storePaths.urlToBackupShm)
    }

    // Restore all the database files
    private func restoreStore(_ storePaths: StorePaths) throws {
        if fileUtility.fileExists(at: storePaths.urlToBackupStore) {
            try fileUtility.delete(at: storePaths.storeURL)
            try fileUtility.copy(from: storePaths.urlToBackupStore, to: storePaths.storeURL)
        }

        if fileUtility.fileExists(at: storePaths.urlToBackupWal) {
            try fileUtility.delete(at: storePaths.walURL)
            try fileUtility.copy(from: storePaths.urlToBackupWal, to: storePaths.walURL)
        }

        if fileUtility.fileExists(at: storePaths.urlToBackupShm) {
            try fileUtility.delete(at: storePaths.shmURL)
            try fileUtility.copy(from: storePaths.urlToBackupShm, to: storePaths.shmURL)
        }
    }

    /// Remove any leftover files from previous migrations
    private func removeMigrationLeftovers() {
        guard let appDataDirectoryURL = fileUtility.appDataDirectory(appGroupID: appGroupID),
              let files = fileUtility.dir(at: appDataDirectoryURL) else {
            return
        }

        for file in files {
            guard file.lastPathComponent.hasPrefix("\(DatabaseManager.databaseFileName).v2") ||
                file.lastPathComponent.hasPrefix("\(DatabaseManager.databaseFileName).v2.bak") ||
                file.lastPathComponent.hasPrefix("\(DatabaseManager.databaseFileName).bak") ||
                file.lastPathComponent.hasPrefix("\(DatabaseManager.databaseFileName)-wal.bak") ||
                file.lastPathComponent.hasPrefix("\(DatabaseManager.databaseFileName)-shm.bak") else {
                continue
            }

            fileUtility.deleteIfExists(at: file)
        }
    }

    /// Migrate all database files form app documents folder to app group folder
    private func migrateDatabaseFromOldToNewLocation() throws {
        let storePaths = try storePaths()

        try fileUtility.replaceFile(from: storePaths.urlToOldStore, to: storePaths.storeURL)
        try fileUtility.replaceFile(from: storePaths.urlToOldWal, to: storePaths.walURL)
        try fileUtility.replaceFile(from: storePaths.urlToOldShm, to: storePaths.shmURL)

        try fileUtility.mergeContentsOfPath(
            from: storePaths.urlToOldExternalStorage,
            to: storePaths.urlToExternalStorage
        )
        if fileUtility.fileExists(at: storePaths.urlToOldSupport) {
            try fileUtility.delete(at: storePaths.urlToOldSupport)
        }
    }
    
    // MARK: - Public functions

    public static func dbExists(appGroupID: String, fileUtility: FileUtilityProtocol) -> Bool {
        guard let storePaths = try? DatabaseManager.storePaths(appGroupID: appGroupID, fileUtility: fileUtility) else {
            DDLogError("Failed to get store paths")
            return false
        }
        return fileUtility.fileExists(at: storePaths.storeURL)
    }

    public func eraseDB() throws {
        guard DatabaseManager.dbExists(appGroupID: appGroupID, fileUtility: fileUtility) else {
            return
        }

        let persistentStores: [NSPersistentStore] = try persistentStoreCoordinator
            .persistentStores.map { $0.copy() as! NSPersistentStore }

        for persistentStore in persistentStores {
            try persistentStoreCoordinator.remove(persistentStore)
            if let storeURL = persistentStore.url {
                try fileUtility.delete(at: storeURL)
            }
        }

        DatabaseManager.localPersistentStoreCoordinator = nil
    }

    public func databaseContext() -> DatabaseContextProtocol {
        do {
            return try DatabaseContext(persistentStoreCoordinator: persistentStoreCoordinator)
        }
        catch {
            fatalError("Could not create persistent store coordinator: \(error)")
        }
    }

    public func databaseContext(withChildContextForBackgroundProcess: Bool) -> DatabaseContextProtocol {
        do {
            return try DatabaseContext(
                persistentStoreCoordinator: persistentStoreCoordinator,
                withChildContextInBackground: withChildContextForBackgroundProcess
            )
        }
        catch {
            fatalError("Could not create persistent store coordinator: \(error)")
        }
    }

    // MARK: Private functions

    private func storePaths() throws -> StorePaths {
        try DatabaseManager.storePaths(appGroupID: appGroupID, fileUtility: fileUtility)
    }

    private static func storePaths(appGroupID: String, fileUtility: FileUtilityProtocol) throws -> StorePaths {
        guard let appDataDirectory = fileUtility.appDataDirectory(appGroupID: appGroupID) else {
            throw DatabaseManagerError.appDataDirectoryMissing
        }

        guard let appDocumentsDirectory = fileUtility.appDocumentsDirectory else {
            throw DatabaseManagerError.appDocumentsDirectoryMissing
        }

        return StorePaths(
            appDataDirectoryURL: appDataDirectory,
            appDocumentsDirectoryURL: appDocumentsDirectory,
            coreDataModelVersion: "\(DatabaseManager.databaseModelVersion)"
        )
    }

    private func backupStoreExists(_ storePaths: StorePaths) -> Bool {
        fileUtility.fileExists(at: storePaths.urlToBackupStore)
    }
}
