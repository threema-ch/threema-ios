//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

extension StorageManagementView {
    final class StorageUsage: ObservableObject, @unchecked Sendable {
        static let shared = StorageUsage()
        
        private var isLoading = false
        
        @Published private(set) var total: Int64 = 0
        @Published private(set) var totalInUse: Int64 = 0
        @Published private(set) var totalFree: Int64 = 0
        @Published private(set) var threema: Int64 = 0
        
        private init() { }
        
        @Sendable
        func calcDeviceStorage() async {
            if isLoading {
                return
            }
            
            isLoading = true
            let deviceStorage = DeviceUtility.getStorageSize()
            await MainActor.run {
                total = deviceStorage.totalSize ?? 0
                totalFree = deviceStorage.totalFreeSize ?? 0
                totalInUse = total - totalFree
            }
            let threemaCount = await StorageUsage.calcThreemaStorage()
            await MainActor.run {
                threema = threemaCount
                isLoading = false
            }
        }
        
        /// Calculates the storage used by the Threema app.
        /// It includes the size of the Threema database and the size of all files in the app's data directory and
        /// temporary directory.
        /// - Returns: The total storage size used by Threema in bytes as an `Int64`.
        private static func calcThreemaStorage() async -> Int64 {
            await Task(priority: .background) {
                var dbSize: Int64 = 0
                var appSize: Int64 = 0
                if let appDataURL = FileUtility.shared.appDataDirectory {
                    let dbURL = appDataURL.appendingPathComponent("ThreemaData.sqlite")
                    dbSize = FileUtility.shared.fileSizeInBytes(fileURL: dbURL) ?? 0
                    DDLogInfo(
                        "DB size \(ByteCountFormatter.string(fromByteCount: dbSize, countStyle: ByteCountFormatter.CountStyle.file))"
                    )
                    
                    FileUtility.shared.pathSizeInBytes(pathURL: appDataURL, size: &appSize)
                    FileUtility.shared.pathSizeInBytes(pathURL: FileManager.default.temporaryDirectory, size: &appSize)
                    DDLogInfo(
                        "APP size \(ByteCountFormatter.string(fromByteCount: appSize, countStyle: ByteCountFormatter.CountStyle.file))"
                    )
                }
                
                return appSize
            }.value
        }
    }
}
