//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

public enum AppInfo {
    /// App Version and Build number
    public static var appVersion: (version: String?, build: String?) {
        var version = BundleUtil.mainBundle()?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        var build: String?
        if let suffix = BundleUtil.mainBundle()?.object(forInfoDictionaryKey: "ThreemaVersionSuffix") as? String {
            version = version?.appending(suffix)
            build = BundleUtil.mainBundle()?.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
        }
        return (version, build)
    }

    public static var version: (major: Int, minor: Int, maintenance: Int, build: Int) {
        var major = 0
        var minor = 0
        var maintenance = 0
        var build = 0

        let (appVersion, appBuild) = appVersion

        if let versionDigits = appVersion?.split(separator: ".") {
            if versionDigits.count >= 1 {
                major = Int(versionDigits[0]) ?? 0
                if versionDigits.count >= 2 {
                    minor = Int(versionDigits[1]) ?? 0
                    if versionDigits.count >= 3 {
                        maintenance = Int(versionDigits[2]) ?? 0
                    }
                }
            }
        }

        if let appBuild {
            build = Int(appBuild) ?? 0
        }

        return (major, minor, maintenance, build)
    }
}
