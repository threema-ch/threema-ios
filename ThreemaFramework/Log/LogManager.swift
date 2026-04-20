import CocoaLumberjackSwift
import FileUtility
import Foundation
import libthreemaSwift

@objc public final class LogManager: NSObject {

    static let debugLogFileName = "debug_log.txt"
    static let validationLogFileName = "validation_log.txt"
    static let dbMigrationLogFileName = "db-migration.log"
    static let safeRestoreLogFileName = "safe-restore.log"
    static let appSetupStepsLogFileName = "app-setup-steps.log"
    static let appLaunchLogFileName = "app-launch.log"

    private static var isDebug = false
    @objc public static let validationLogFile: URL? = FileUtility.shared
        .appDataDirectory(appGroupID: AppGroup.groupID())?
        .appendingPathComponent(validationLogFileName)
    @objc public static let debugLogFile: URL? = FileUtility.shared.appDataDirectory(appGroupID: AppGroup.groupID())?
        .appendingPathComponent(debugLogFileName)

    // Setup logs that should be accessible though Finder/iTunes (document directory) as they are helpful if setup fails
    @objc public static let dbMigrationLogFile: URL? =
        FileUtility.shared.appDocumentsDirectory?.appendingPathComponent(
            dbMigrationLogFileName
        )
    public static let safeRestoreLogFile: URL? = FileUtility.shared.appDocumentsDirectory?.appendingPathComponent(
        safeRestoreLogFileName
    )
    @objc public static let appSetupStepsLogFile: URL? = FileUtility.shared.appDocumentsDirectory?
        .appendingPathComponent(
            appSetupStepsLogFileName
        )
    @objc public static let appLaunchLogFile: URL? = FileUtility.shared.appDocumentsDirectory?.appendingPathComponent(
        appLaunchLogFileName
    )

    private static var libthreemaLogDispatcherInitialized = false
    private static let libthreemaLogDispatcher = LibthreemaLogDispatcher()
            
    /// Log levels definition for Swift. Includes new Notice Log level at the end, to not break the standard Log levels
    /// like in <CocoaLumberjack/DDLog.h>
    public enum DDLogLevelCustom: UInt {
        case err = 0b0000001
        case warn = 0b0000010
        case info = 0b0000100
        case verbose = 0b0001000
        case debug = 0b0010000
        case notice = 0b0100000
    }

    @objc public static func initializeGlobalLogger(debug: Bool) {
        isDebug = debug
        if isDebug {
            DDOSLogger.sharedInstance.logFormatter = LogFormatterCustom()
            DDLog.add(DDOSLogger.sharedInstance, with: LogManager.logLevel())
        }

        // Add Debug Logger is enabled by user
        if let validationLogging = UserSettings.shared()?.validationLogging,
           validationLogging {

            addFileLogger(debugLogFile)
        }
        else {
            removeFileLogger(debugLogFile)
        }
        
        // libthreema logging
        
        // Workaround: This should only be initialized once, however this function is called for every received
        // notification in the notification extension
        // TODO: (IOS-5355) Only initialize libthreema once
        if !libthreemaLogDispatcherInitialized {
            // .trace should only be used to closely debug something
            let libthreemaMinLogLevel: LogLevel = debug ? .debug : .info
            libthreemaSwift.initialize(
                minLogLevel: libthreemaMinLogLevel,
                logDispatcher: libthreemaLogDispatcher
            )
            libthreemaLogDispatcherInitialized = true
        }
    }

    @objc public static func addFileLogger(_ logFile: URL?) {
        guard let logFile else {
            return
        }
        
        if let existingLogger = findFileLogger(logFile),
           existingLogger.isEmpty, let fileLogger = FileLoggerCustom(logFile: logFile) {
            DDLog.add(fileLogger, with: logLevel())
        }
    }
    
    @objc public static func removeFileLogger(_ logFile: URL?) {
        guard let logFile else {
            return
        }
        
        if let existingLoggers = findFileLogger(logFile),
           !existingLoggers.isEmpty {
            for logger in existingLoggers {
                DDLog.remove(logger)
            }
        }
    }
    
    @objc public static func deleteLogFile(_ logFile: URL?) {
        FileUtility.shared.deleteIfExists(at: logFile)
    }
    
    @objc public static func logFileSize(_ logFile: URL?) -> Int64 {
        guard let logFile else {
            return 0
        }
        
        return FileUtility.shared.fileSizeInBytes(fileURL: logFile) ?? 0
    }

    /// Get Log Level dependent on if is in debug environment or not.
    ///
    /// - Returns: Log Level
    private static func logLevel() -> DDLogLevel {
        // Default log level is Error, Warning and Notice
        var ddLogLevel = DDLogLevel(
            rawValue: DDLogLevelCustom.err.rawValue | DDLogLevelCustom.warn
                .rawValue | DDLogLevelCustom.notice.rawValue
        )!
        if isDebug {
            ddLogLevel = .all
        }
        return ddLogLevel
    }

    /// Looking for existing file logger (FileLoggerCustom).
    ///
    /// - Parameters:
    /// - logFile: Log file path
    ///
    /// - Returns: Array of file loggers
    private static func findFileLogger(_ logFile: URL?) -> [DDLogger]? {
        guard let logFile else {
            return nil
        }
        
        var fileLoggers: [DDLogger] = []
        for logger in DDLog.allLoggers {
            if let fileLogger = logger as? FileLoggerCustom,
               fileLogger.logFile == logFile {
                
                fileLoggers.append(logger)
            }
        }
        return fileLoggers
    }
}
