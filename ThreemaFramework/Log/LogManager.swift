//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CocoaLumberjackSwift
import Foundation

@objc public class LogManager: NSObject {
    
    private static var isDebug = false
    @objc public static let validationLogFile: URL? = FileUtility.appDataDirectory?
        .appendingPathComponent("validation_log.txt")
    @objc public static let debugLogFile: URL? = FileUtility.appDataDirectory?.appendingPathComponent("debug_log.txt")
    @objc public static let dbMigrationLogFile: URL? = FileUtility.appDataDirectory?
        .appendingPathComponent("db-migration.log")
    public static let safeRestoreLogFile: URL? = FileUtility.appDataDirectory?
        .appendingPathComponent("safe-restore.log")

    // Only used for debug
    @objc public static let dbMigrationBeforeLogFilename = "db-migration-before.log"
    @objc public static let dbMigrationAfterLogFilename = "db-migration-after.log"
            
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
            DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
            DDLog.add(DDTTYLogger.sharedInstance!, with: LogManager.logLevel())
        }

        // Add Debug Logger is enabled by user
        if let validationLogging = UserSettings.shared()?.validationLogging,
           validationLogging {

            addFileLogger(debugLogFile)
        }
        else {
            removeFileLogger(debugLogFile)
        }
    }

    @objc public static func addFileLogger(_ logFile: URL?) {
        guard let logFile else {
            return
        }
        
        if let existingLogger = findFileLogger(logFile),
           existingLogger.isEmpty {
        
            let fileLogger: FileLoggerCustom! = FileLoggerCustom(logFile: logFile)
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
        FileUtility.delete(at: logFile)
    }
    
    @objc public static func logFileSize(_ logFile: URL?) -> Int64 {
        guard let logFile else {
            return 0
        }
        
        return FileUtility.fileSizeInBytes(fileURL: logFile) ?? 0
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
