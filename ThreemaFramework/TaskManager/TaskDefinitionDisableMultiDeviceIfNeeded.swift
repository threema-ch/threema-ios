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

/// Task to disable multi-device if there are no other devices left in the group
///
/// You should never create such a task on your own. Use `MultiDeviceManagerProtocol.disableMultiDeviceIfNeeded()`
/// instead.
///
/// This is implemented as a task such that it is executed when a server connection exists and no other task is
/// executed. It is expected when this task disables MD that the task will be marked as dropped (because disabling MD
/// leads to a disconnect).
class TaskDefinitionDisableMultiDeviceIfNeeded: TaskDefinition {
    override func create(
        frameworkInjector: any FrameworkInjectorProtocol,
        taskContext: any TaskContextProtocol
    ) -> any TaskExecutionProtocol {
        TaskExecutionDisableMultiDeviceIfNeeded(
            taskContext: taskContext,
            taskDefinition: self,
            backgroundFrameworkInjector: frameworkInjector
        )
    }
    
    override func create(frameworkInjector: any FrameworkInjectorProtocol) -> any TaskExecutionProtocol {
        create(
            frameworkInjector: frameworkInjector,
            taskContext: TaskContext(
                logReflectMessageToMediator: .none,
                logReceiveMessageAckFromMediator: .none,
                logSendMessageToChat: .none,
                logReceiveMessageAckFromChat: .none
            )
        )
    }
    
    override var description: String {
        "<\(Swift.type(of: self))>"
    }
    
    init() {
        super.init(type: .dropOnDisconnect)
    }
    
    required init(from decoder: any Decoder) throws {
        fatalError("This task should never be persisted")
    }
}
