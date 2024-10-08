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

/// Called when a task is completed (NOT when adding is completed)
///
/// - This handler is not persisted!
/// - For canceled tasks a `TaskExecutionError.taskDropped` is reported when the task is dropped. If the canceled task
///   is currently executing this is only called when the task actually stopped execution (and without an error if the
///   task run to completion). This might take a while if the network is bad or the task doesn't cooperatively checks
///   for cancelation (dropping). If the cancelation was initiated by the user consider updating the UI before this is
///   called.
typealias TaskCompletionHandler = (TaskDefinitionProtocol, Error?) -> Void

protocol TaskManagerProtocol: TaskManagerProtocolObjc {
    /// Add task definition
    /// - Parameter taskDefinition: New task definition to add to queue
    /// - Returns: Cancelable task if task can be canceled
    @discardableResult func add(taskDefinition: TaskDefinitionProtocol) -> CancelableTask?
    
    /// Add task definition
    /// - Parameters:
    ///   - taskDefinition: New task definition to add to queue
    ///   - completionHandler: Called when the task is completed (NOT when adding is completed). For details see
    ///                        `TaskCompletionHandler`
    /// - Returns: Cancelable task if task can be canceled
    @discardableResult func add(
        taskDefinition: TaskDefinitionProtocol,
        completionHandler: @escaping TaskCompletionHandler
    ) -> CancelableTask?
    
    /// Add list of task definitions
    ///
    /// See `add(taskDefinition:completionHandler:)` for details.
    ///
    /// - Parameter taskDefinitionTuples: List of task definitions
    /// - Returns: Array of cancelable task for the tasks that can be canceled. Otherwise the entry is `nil`
    @discardableResult func add(taskDefinitionTuples: [(
        taskDefinition: TaskDefinitionProtocol,
        completionHandler: TaskCompletionHandler
    )]) -> [CancelableTask?]
    
    /// Process all tasks
    func spool()
    
    /// Remove all tasks from queue
    static func removeAllTasks()

    /// Remove current task from queue
    static func removeCurrentTask()

    /// Is task queue empty?
    static func isEmpty() -> Bool
}

@objc protocol TaskManagerProtocolObjc {
    func addObjc(taskDefinition: AnyObject)
    func addObjc(taskDefinition: AnyObject, completionHandler: @escaping (AnyObject, Error?) -> Void)
}
