//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import PromiseKit

/// Process and ack incoming (reflected) message from mediator server.
class TaskExecutionReceiveReflectedMessage: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionReceiveReflectedMessage, task.message != nil else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }

        let mediatorReflectedProcessor = MediatorReflectedProcessor(
            frameworkInjector: frameworkInjector,
            messageProcessorDelegate: frameworkInjector.serverConnector
        )

        return mediatorReflectedProcessor.process(
            envelope: task.message,
            timestamp: task.mediatorTimestamp,
            receivedAfterInitialQueueSend: task.receivedAfterInitialQueueSend,
            maxBytesToDecrypt: Int(task.maxBytesToDecrypt),
            timeoutDownloadThumbnail: Int(task.timeoutDownloadThumbnail)
        )
    }
}
