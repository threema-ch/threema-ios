//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2026-2025 Threema GmbH
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

extension AppGroup {
    @objc static func refreshDirtyObjects() {
        guard let remoteSecretManager = AppLaunchManager.remoteSecretManager else {
            DDLogWarn(
                "Refresh of dirty objects not possible rigth now, because remote secret manager is not initialized"
            )
            return
        }

        let persistenceManager = PersistenceManager(
            appGroupID: AppGroup.groupID(),
            userDefaults: AppGroup.userDefaults(),
            remoteSecretManager: remoteSecretManager
        )

        // Call refresh of dirty objects with reset `false` to not remove them from NSUserDefault.
        // Because of different processes of the Notification Extension (adding dirty objects)
        // and the App (refresh and remove dirty objects) it's not guaranteed that a dirty object has been refreshed.
        persistenceManager.dirtyObjectManager.refreshDirtyObjects(reset: false)
    }
}
