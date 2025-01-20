//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

/// App migration versions
///
/// Migrations are done in `AppMigration`.
///
/// # How to add a new version?
///
/// Add a new  case with a higher integer than the existing ones. If another migration is needed during the beta phase
/// just increment the number by one. This enforced another run of this migration. **After a release don't increment the
/// number anymore.**
public enum AppMigrationVersion: Int, Comparable, CaseIterable {
    case none = 0
    case v4_8 = 3
    case v5_1 = 4
    case v5_2 = 5
    case v5_3_1 = 6
    case v5_4 = 9
    case v5_5 = 10
    case v5_6 = 11
    case v5_7 = 12
    case v5_9 = 21
    case v5_9_2 = 22
    case v6_0 = 24
    case v6_2 = 25
    case v6_2_1 = 26
    case v6_3 = 27
    case v6_6 = 28
    // Add new version for app migration here...

    public static func isMigrationRequired(userSettings: UserSettingsProtocol) -> Bool {
        // If `appMigratedToVersion` greater than latest migration version means, that the BETA user has downgraded the
        // app. In this case run all migrations again.
        if AppMigrationVersion.allCases.last!.rawValue < userSettings.appMigratedToVersion {
            userSettings.appMigratedToVersion = AppMigrationVersion.none.rawValue
        }
        
        return AppMigrationVersion.allCases.last!.rawValue > userSettings.appMigratedToVersion
    }

    public static func < (lhs: AppMigrationVersion, rhs: AppMigrationVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
