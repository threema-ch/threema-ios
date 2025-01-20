//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
import PromiseKit

// If this task blocks the queue on iOS 15 or 16 see IOS-4911
class TaskExecutionNewDeviceSync: TaskExecutionTransaction {
    override func executeTransaction() throws -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionNewDeviceSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }
        
        // Not so great, but we have to combine Promises with Swift Concurrency here
        return Promise { seal in
            Task {
                do {
                    try await task.join(CancelableDropOnDisconnectTask(
                        taskDefinition: task,
                        serverConnector: frameworkInjector.serverConnector
                    ))
                    seal.fulfill_()
                }
                catch {
                    seal.reject(error)
                }
            }
        }
    }
    
    override func writeLocal() -> Promise<Void> {
        // Nothing to do...
        Promise()
    }
}
