//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

protocol TaskManagerProtocol: TaskManagerProtocolObjc {
    /// Add task definition
    /// - Parameter taskDefinition: New task definition to add to queue
    func add(taskDefinition: TaskDefinitionProtocol)
    
    /// Add task definition
    /// - Parameters:
    ///   - taskDefinition: New task definition to add to queue
    ///   - completionHandler: Called when the task is completed (NOT when adding is completed). This handler is not persisted!
    func add(taskDefinition: TaskDefinitionProtocol, completionHandler: @escaping TaskCompletionHandler)
    
    /// Add list of task definitions
    ///
    /// See `add(taskDefinition:completionHandler:)` for details.
    ///
    /// - Parameter taskDefinitionTuples: List of task definitions
    func add(taskDefinitionTuples: [(taskDefinition: TaskDefinitionProtocol, completionHandler: TaskCompletionHandler)])
    
    /// Process all tasks
    func spool()
    
    /// Remove all tasks in queue of given queue name.
    /// - Parameter queueType: Flush particular queue or all queues
    static func flush(queueType: TaskQueueType)

    /// Is task queue empty?
    /// - Parameter queueType: Queue type
    static func isEmpty(queueType: TaskQueueType) -> Bool
}

@objc protocol TaskManagerProtocolObjc {
    func addObjc(taskDefinition: AnyObject)
    func addObjc(taskDefinition: AnyObject, completionHandler: @escaping (AnyObject, Error?) -> Void)
}
