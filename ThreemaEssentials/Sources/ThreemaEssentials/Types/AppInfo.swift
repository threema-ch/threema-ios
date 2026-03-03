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

/// Information about current app
///
/// Use this to inject information about the current app
///
/// Vision: (IOS-5456) This should be extended to contain all app info (e.g. app name, flavor, environment, feature
/// flags?, ...) and be injected in all the packages that need this information
public struct AppInfo {
    public let version: String
    public let locale: String
    public let deviceModel: String
    public let osVersion: String
    
    public init(version: String, locale: String, deviceModel: String, osVersion: String) {
        self.version = version
        self.locale = locale
        self.deviceModel = deviceModel
        self.osVersion = osVersion
    }
}
