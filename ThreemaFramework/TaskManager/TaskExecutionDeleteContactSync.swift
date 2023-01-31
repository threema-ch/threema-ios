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

/// Reflect deletion of contacts to mediator server.
class TaskExecutionDeleteContactSync: TaskExecutionTransaction {
    override func reflectTransactionMessages() throws -> [Promise<Void>] {
        guard let taskDefinition = taskDefinition as? TaskDefinitionDeleteContactSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }

        var reflectResults = [Promise<Void>]()
        
        for identity in taskDefinition.contacts {
            let envelope = frameworkInjector.mediatorMessageProtocol.getEnvelopeForContactSyncDelete(identity: identity)

            reflectResults.append(Promise { $0.fulfill(try self.reflectMessage(
                envelope: envelope,
                ltReflect: self.taskContext.logReflectMessageToMediator,
                ltAck: self.taskContext.logReceiveMessageAckFromMediator
            )) })
        }

        return reflectResults
    }
    
    override func checkPreconditions() throws -> Bool {
        guard let task = taskDefinition as? TaskDefinitionDeleteContactSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }

        task.contacts = task.contacts.filter { checkPrecondition(identity: $0) }
        return task.contacts.count > -1
    }
    
    override func shouldSkip() throws -> Bool {
        guard let task = taskDefinition as? TaskDefinitionDeleteContactSync else {
            DDLogError("Wrong kind of task for shouldSkip")
            return false
        }

        task.contacts = task.contacts.filter { checkPrecondition(identity: $0) }
        return task.contacts.count <= 0
    }
    
    override func writeLocal() -> Promise<Void> {
        DDLogInfo("Contact sync writes local data immediately")
        return Promise()
    }
    
    private func checkPrecondition(identity: String) -> Bool {
        frameworkInjector.backgroundEntityManager.entityFetcher.contact(for: identity) == nil
    }
}
