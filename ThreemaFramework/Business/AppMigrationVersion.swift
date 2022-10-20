//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

import Foundation

public enum AppMigrationVersion: Int, Comparable, CaseIterable {
    case none = 0
    case v48 = 3
    // Add here new version for app migration...

    public static func isMigrationRequired(userSettings: UserSettingsProtocol) -> Bool {
        AppMigrationVersion.allCases.last!.rawValue > userSettings.appMigratedToVersion
    }

    public static func < (lhs: AppMigrationVersion, rhs: AppMigrationVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}