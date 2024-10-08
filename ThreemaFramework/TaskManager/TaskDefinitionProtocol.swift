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

enum TaskExecutionState: String, Codable {
    case pending
    case executing
    case interrupted
}

enum TaskType {
    /// Task is persisted on disk and reloaded on relaunch
    case persistent
    /// Task lives on until the app is terminated (i.e. it will be kept on backgrounding)
    case volatile
    /// Task is dropped on next chat/mediator server disconnect
    case dropOnDisconnect
}

protocol TaskDefinitionProtocol {
    /// Class name for serialize and deserialize task.
    var className: String { get }

    var type: TaskType { get }

    var state: TaskExecutionState { get set }

    /// Retry task execution on failure
    var retry: Bool { get }

    /// Retry count of task execution
    var retryCount: Int { get set }

    /// Create task execution handler for task definition.
    /// - Parameters:
    ///     - frameworkInjector: Framework business injector (necessary for unit testing)
    ///     - taskContext: Context where the task is created
    /// - Returns: Task execution handler
    func create(frameworkInjector: FrameworkInjectorProtocol, taskContext: TaskContextProtocol)
        -> TaskExecutionProtocol

    func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol
}
