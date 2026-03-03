//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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
import FileUtility
import Foundation

@objc public final class BackupFilesManager: NSObject {

    private let fileUtility: FileUtilityProtocol

    @objc override public init() {
        self.fileUtility = FileUtility.shared
        super.init()
    }

    init(fileUtility: FileUtilityProtocol) {
        self.fileUtility = fileUtility
        super.init()
    }

    @objc public func setIsExcludedFromBackup(exclude: Bool) {
        let fileAndDirectoryNames = [
            DatabaseManager.databaseFileName,
            DatabaseManager.databaseSupportPath,
            DatabaseManager.databaseTemporaryExternalStoragePath,
            DatabaseManager.databaseRepairedFileName,
            DatabaseManager.databaseOldVersionPath,
            PendingUserNotificationManager.processedUserNotificationsFileName,
            SQLDHSessionStore.databaseName,
            LogManager.debugLogFileName,
            LogManager.validationLogFileName,
            LogManager.dbMigrationLogFileName,
            LogManager.safeRestoreLogFileName,
            LogManager.appSetupStepsLogFileName,
            "safe-backup.json",
            "DoneMessages",
            "WebSessions",
            "PreviousContext",
        ]

        do {
            try fileUtility.backup(of: fileAndDirectoryNames, exclude: exclude, appGroupID: AppGroup.groupID())
        }
        catch {
            DDLogError("Failed set exclude flag for backup files: \(error)")
        }
    }
}
