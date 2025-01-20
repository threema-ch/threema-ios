//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

final class TaskDefinitionReceiveReflectedMessage: TaskDefinition {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionReceiveReflectedMessage(
            taskContext: taskContext,
            taskDefinition: self,
            backgroundFrameworkInjector: frameworkInjector
        )
    }

    override func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol {
        create(frameworkInjector: frameworkInjector, taskContext: TaskContext())
    }
    
    override var description: String {
        "<\(Swift.type(of: self))>"
    }
    
    required init(
        reflectedMessage: Data,
        receivedAfterInitialQueueSend: Bool,
        maxBytesToDecrypt: Int,
        timeoutDownloadThumbnail: Int
    ) {
        self.reflectedMessage = reflectedMessage
        self.maxBytesToDecrypt = Int32(maxBytesToDecrypt)
        self.timeoutDownloadThumbnail = Int32(timeoutDownloadThumbnail)
        self.receivedAfterInitialQueueSend = receivedAfterInitialQueueSend

        super.init(type: .dropOnDisconnect)
        self.retry = false
    }

    let reflectedMessage: Data
    let receivedAfterInitialQueueSend: Bool
    let maxBytesToDecrypt: Int32
    let timeoutDownloadThumbnail: Int32

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}
