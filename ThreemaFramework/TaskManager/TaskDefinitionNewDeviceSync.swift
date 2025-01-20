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
import ThreemaProtocols

class TaskDefinitionNewDeviceSync: TaskDefinition,
    TaskDefinitionTransactionProtocol {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionNewDeviceSync(
            taskContext: taskContext,
            taskDefinition: self,
            backgroundFrameworkInjector: frameworkInjector
        )
    }
    
    override func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol {
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
    
    typealias JoinHandler = (CancelableTask) async throws -> Void
    
    var scope: D2d_TransactionScope.Scope {
        .newDeviceSync
    }
    
    /// Closure executed during transaction
    let join: JoinHandler
    
    /// Create new device sync transaction task
    /// - Parameter join: Closure to execute during transaction. If it throws the transaction will be aborted.
    init(join: @escaping JoinHandler) {
        self.join = join
        
        super.init(type: .dropOnDisconnect)
        
        self.retry = false
    }
    
    required init(from decoder: Decoder) throws {
        fatalError("This task should never be persisted")
    }
}
