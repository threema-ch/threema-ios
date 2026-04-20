import CocoaLumberjackSwift
import FileUtility
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
                let fileUtility = FileUtility.shared!
                if let appDataURL = fileUtility.appDataDirectory(appGroupID: AppGroup.groupID()) {
                    let dbURL = appDataURL.appendingPathComponent("ThreemaData.sqlite")
                    dbSize = fileUtility.fileSizeInBytes(fileURL: dbURL) ?? 0
                    DDLogInfo(
                        "DB size \(ByteCountFormatter.string(fromByteCount: dbSize, countStyle: ByteCountFormatter.CountStyle.file))"
                    )
                    
                    fileUtility.pathSizeInBytes(pathURL: appDataURL, size: &appSize)
                    fileUtility.pathSizeInBytes(pathURL: fileUtility.appTemporaryDirectory, size: &appSize)
                    DDLogInfo(
                        "APP size \(ByteCountFormatter.string(fromByteCount: appSize, countStyle: ByteCountFormatter.CountStyle.file))"
                    )
                }
                
                return appSize
            }.value
        }
    }
}
