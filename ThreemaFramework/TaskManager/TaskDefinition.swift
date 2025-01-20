//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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

/// Task definition must be codable to persists task definitions.
class TaskDefinition: NSObject, Codable, TaskDefinitionProtocol {
    var className: String { String(describing: Swift.type(of: self)) }

    var type: TaskType = .persistent
    var state: TaskExecutionState
    
    /// Is this task dropped?
    ///
    /// This is similar to a cancel, but used for wording in line with Threema Protocol.
    ///
    /// This should only be set internally and only from the default `false` to `true`
    var isDropped = false {
        didSet {
            assert(isDropped, "This should only ever be set to `false`")
        }
    }
    
    var retry: Bool
    var retryCount: Int
    
    private enum CodingKeys: String, CodingKey {
        case state
        case retry
        case retryCount
    }
    
    init(type: TaskType) {
        self.type = type
        self.state = .pending
        self.retry = true
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
