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

public enum DeviceUtility {

    /// Get total size and total free size of the device.
    ///
    /// - Returns:
    ///    - totalSize: total size in bytes of device
    ///    - totalFreeSize: total free size in bytes on device
    public static func getStorageSize() -> (totalSize: Int64?, totalFreeSize: Int64?) {
        var size: Int64?
        var freeSize: Int64?

        let homeDirectory = URL(fileURLWithPath: NSHomeDirectory())
        if let systemResources = try? homeDirectory
            .resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
            size = systemResources.allValues[.volumeTotalCapacityKey] as? Int64
            freeSize = systemResources.allValues[.volumeAvailableCapacityForImportantUsageKey] as? Int64
        }

        return (size, freeSize)
    }

    /// Amount of physical memory.
    /// - Returns: Amount of bytes
    public static func getTotalMemory() -> UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    /// Amount of physical memory in used.
    /// - Returns: Amount of bytes
    public static func getUsageMemory() -> Float? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr
                .withMemoryRebound(
                    to: integer_t.self,
                    capacity: Int(count)
                ) { (machPtr: UnsafeMutablePointer<integer_t>) in
                    task_info(
                        mach_task_self(),
                        task_flavor_t(MACH_TASK_BASIC_INFO),
                        machPtr,
                        &count
                    )
                }
        }
        guard kerr == KERN_SUCCESS else {
            return nil
        }
        return Float(info.resident_size) // / (1024 * 1024)
    }

    private static func mach_task_self() -> task_t {
        mach_task_self_
    }
}
