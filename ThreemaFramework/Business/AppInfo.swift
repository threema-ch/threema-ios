//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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
}
