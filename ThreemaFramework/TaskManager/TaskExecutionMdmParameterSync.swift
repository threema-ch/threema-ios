//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import ThreemaProtocols

final class TaskExecutionMdmParameterSync: TaskExecutionTransaction {

    override func reflectTransactionMessages() throws -> [Promise<Void>] {
        guard let task = taskDefinition as? TaskDefinitionMdmParameterSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }

        let envelope = frameworkInjector.mediatorMessageProtocol
            .getEnvelopeForMdmParametersUpdate(mdmParameters: task.mdmParameters)

        return [Promise { try $0.fulfill(_ = reflectMessage(
            envelope: envelope,
            ltReflect: self.taskContext.logReflectMessageToMediator,
            ltAck: self.taskContext.logReceiveMessageAckFromMediator
        )) }]
    }

    override func writeLocal() -> Promise<Void> {
        Promise()
    }
}
