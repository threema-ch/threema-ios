enum RemoteSecretFileEncryptionWhitelist: String, CaseIterable {
    case configOPPF = "config.oppf"
    case workServerCache = "work_server_url.cache"
    case idBackup = "idbackup.txt"
    case threemaDataSqlite = "ThreemaData.sqlite"
    case repairedThreemaDataSqlite = "RepairedThreemaData.sqlite"
    case threemaForwardSecrecyDB = "threema-fs.db"
    case unencryptedDirectory = "/unencrypted/"
    case appSetupNotCompleted = "APP_SETUP_NOT_COMPLETED"
    
    case debugLog = "debug_log.txt"
    case validationLogFileName = "validation_log.txt"
    case dbMigrationLogFileName = "db-migration.log"
    case safeRestoreLogFileName = "safe-restore.log"
    case appSetupStepsLogFileName = "app-setup-steps.log"
    case appLaunchLogFileName = "app-launch.log"

    static var whiteList: [String] {
        allCases.map(\.rawValue)
    }
}
