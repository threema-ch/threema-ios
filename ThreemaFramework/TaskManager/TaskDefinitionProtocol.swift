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

protocol TaskDefinitionProtocol {
    /// Class name for serialize and deserialize task.
    var className: String { get }

    /// Define that task will be serialized and deserialized.
    var isPersistent: Bool { get set }

    var state: TaskExecutionState { get set }

    /// Retry task execution on failer
    var retry: Bool { get }

    /// Retry count of task execution
    var retryCount: Int { get set }

    /// Create task excution handler for task definition.
    /// - Parameters:
    ///     - frameworkInjector: Framework business injector (necessary for unit testing)
    ///     - taskContext: Context where the task is created
    /// - Returns: Task execution handler
    func create(frameworkInjector: FrameworkInjectorProtocol, taskContext: TaskContextProtocol)
        -> TaskExecutionProtocol

    func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol
}
