//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

/// Task definition must be codable to persists task definitions.
class TaskDefinition: NSObject, Codable, TaskDefinitionProtocol {
    var className: String { String(describing: type(of: self)) }

    var isPersistent: Bool
    var state: TaskExecutionState
    var retry: Bool
    var retryCount: Int
    
    private enum CodingKeys: String, CodingKey {
        case isPersistent
        case state
        case retry
        case retryCount
    }
    
    init(isPersistent: Bool) {
        self.isPersistent = isPersistent
        self.state = .pending
        self.retry = false
        self.retryCount = 0
    }
    
    func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        preconditionFailure("This function must be overridden")
    }

    func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol {
        preconditionFailure("This function must be overridden")
    }
}
