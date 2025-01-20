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
import PromiseKit

class TaskExecutionDisableMultiDeviceIfNeeded: TaskExecution, TaskExecutionProtocol {
    // This is best-effort and will always succeed even if a legit disabling fails
    func execute() -> Promise<Void> {
        Promise { seal in
            Task {
                guard frameworkInjector.settingsStore.isMultiDeviceRegistered else {
                    // Nothing to-do if multi-device is already disabled
                    seal.fulfill_()
                    return
                }
                
                // Check if any other device is in the group
                
                guard let otherDevices = try? await frameworkInjector.multiDeviceManager.sortedOtherDevices() else {
                    seal.fulfill_()
                    return
                }
                
                guard otherDevices.isEmpty else {
                    seal.fulfill_()
                    return
                }
                
                // No other device in group. Disable multi-device...
                
                do {
                    try await frameworkInjector.multiDeviceManager.disableMultiDevice()
                }
                catch {
                    DDLogError("Failed to automatically disable multi-device: \(error)")
                    seal.fulfill_()
                    return
                }
                
                DDLogNotice("Automatically disabled multi-device")
                seal.fulfill_()
            }
        }
    }
}
