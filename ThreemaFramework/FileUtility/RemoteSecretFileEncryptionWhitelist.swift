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
