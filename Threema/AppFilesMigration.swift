//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import OSLog

/// Migrate files.
///
/// - Important: Don't use any business services (like `BusinessInjector`, `ContactStore` and so on) in here.
/// - Warning: Only use this to migrate files!
///
/// Use this if you need to change files in the file system that are required for a correct behavior of business
/// services (e.g. task manager) after the update. All migrations should not change the outcome if they are run
/// multiple times.
///
/// How to add a new migration:
///
/// 1. Add a new `AppMigrationVersion`. See its documentation for details
/// 2. Add a new migrate function (`migrateFilesToX_Y`)
///     - Document the function and describe what is migrated
/// 3. Call the migration in `run()`
/// 4. Add the migration check and upgrade to `AppMigration.run()` (Note: this is in `AppMigration`!)
///    ```Swift
///    if migratedTo < .vX_Y {
///        migratedTo = .vX_Y
///    }
///    ```
/// 5. Extend the `AppMigrationTests` with the new migration
struct AppFilesMigration {
    private let osPOILog = OSLog(subsystem: "ch.threema.iapp.appFilesMigration", category: .pointsOfInterest)

    let migratedTo: AppMigrationVersion

    func run() throws {
        if migratedTo < .v6_2_1 {
            try migrateFilesTo6_2_1()
        }
        if migratedTo < .v6_3 {
            try migrateFilesTo6_3()
        }
    }

    /// Migrate to version 6.2.1:
    /// - Move file of appDataDirectory/taskQueue to appDataDirectory/outgoingQueue. This is needed for a downgrade from
    /// 6.3+.
    private func migrateFilesTo6_2_1() throws {
        DDLogNotice("[AppMigration] Files migration to version 6.2.1 started")
        os_signpost(.begin, log: osPOILog, name: "6.2.1 migration")

        if let outgoingQueuePath = FileUtility.shared.appDataDirectory?.appendingPathComponent(
            "outgoingQueue",
            isDirectory: false
        ),
            let taskQueuePath = FileUtility.shared.appDataDirectory?.appendingPathComponent(
                "taskQueue",
                isDirectory: false
            ) {

            if !FileUtility.shared.isExists(fileURL: outgoingQueuePath),
               FileUtility.shared.isExists(fileURL: taskQueuePath) {
                _ = FileUtility.shared.move(source: taskQueuePath, destination: outgoingQueuePath)
            }
            else {
                DDLogWarn(
                    "Task queue file couldn't renamed, because no 'taskQueue' file exists or 'outgoingQueue' already exists"
                )
            }
        }
        else {
            DDLogError("Couldn't evaluate file paths for task queue")
        }

        os_signpost(.end, log: osPOILog, name: "6.2.1 migration")
        DDLogNotice("[AppMigration] Files migration to version 6.2.1 successfully finished")
    }

    /// Migrate to version 6.3:
    /// - Move file of appDataDirectory/outgoingQueue to appDataDirectory/taskQueue.
    private func migrateFilesTo6_3() throws {
        DDLogNotice("[AppMigration] Files migration to version 6.3 started")
        os_signpost(.begin, log: osPOILog, name: "6.3 migration")

        if let outgoingQueuePath = FileUtility.shared.appDataDirectory?.appendingPathComponent(
            "outgoingQueue",
            isDirectory: false
        ),
            let taskQueuePath = FileUtility.shared.appDataDirectory?.appendingPathComponent(
                "taskQueue",
                isDirectory: false
            ) {

            if FileUtility.shared.isExists(fileURL: outgoingQueuePath),
               !FileUtility.shared.isExists(fileURL: taskQueuePath) {
                _ = FileUtility.shared.move(source: outgoingQueuePath, destination: taskQueuePath)
            }
            else {
                DDLogWarn(
                    "Task queue file couldn't renamed, because no 'outgoingQueue' file exists or 'taskQueue' already exists"
                )
            }
        }
        else {
            DDLogError("Couldn't evaluate file paths for task queue")
        }

        os_signpost(.end, log: osPOILog, name: "6.3 migration")
        DDLogNotice("[AppMigration] Files migration to version 6.3 successfully finished")
    }
}
