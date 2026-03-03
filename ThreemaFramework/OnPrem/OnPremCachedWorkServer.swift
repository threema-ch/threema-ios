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

// TODO: (IOS-5579) This can be removed if proper OPPF caching is implemented

/// Cache work url in file needed to fetch RS on app launch because OPPF cannot be fetched as the credentials are
/// encrypted with RS
class OnPremCachedWorkServer {
    private static let cacheFileName = "work_server_url.cache"
    private static let cacheFileURL = FileUtility.shared.appDataDirectory(
        appGroupID: AppGroup.groupID()
    )!.appendingPathComponent(cacheFileName)
    
    /// Current cached URL string
    private(set) static var urlString: String? = {
        guard let data = FileUtility.shared.read(fileURL: cacheFileURL) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }()
    
    /// Update/set cached URL string
    /// - Parameter url: URL string to cache
    static func storeURLString(_ urlString: String?) {
        self.urlString = urlString
        
        if let urlStringData = urlString?.data(using: .utf8) {
            FileUtility.shared.write(contents: urlStringData, to: cacheFileURL)
        }
        else {
            FileUtility.shared.deleteIfExists(at: cacheFileURL)
        }
    }
}
