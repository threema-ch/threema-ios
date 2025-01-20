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

/// Cancelable drop on disconnect task
///
/// - Note: This should be internal to the task management system. Only `CancelableTask` should be public.
///
/// # How does this work?
///
/// The protocol doesn't have a concept of canceling a task. A similar behavior only exists for drop on disconnect tasks
/// combined with a disconnect from the chat/mediator server. This is what we do here. The report of the cancelation (or
/// drop for internal reasons) happens in the task completion handler (`TaskCompletionHandler`). If we would just mark
/// the task dropped we might run into unexpected protocol issues down the line.
class CancelableDropOnDisconnectTask: CancelableTask {
    var isCanceled: Bool {
        taskDefinition.isDropped
    }
    
    private let taskDefinition: TaskDefinition
    private let serverConnector: ServerConnectorProtocol

    init(taskDefinition: TaskDefinition, serverConnector: ServerConnectorProtocol) {
        assert(taskDefinition.type == .dropOnDisconnect, "Only canceling of drop on disconnect tasks is supported")
        
        self.taskDefinition = taskDefinition
        self.serverConnector = serverConnector
    }
    
    func cancel() {
        guard taskDefinition.type == .dropOnDisconnect else {
            DDLogError("Only canceling of drop on disconnect tasks is supported")
            assertionFailure()
            return
        }
        
        DDLogNotice("Trying to cancel \(taskDefinition)")
        serverConnector.reconnect()
    }
}
