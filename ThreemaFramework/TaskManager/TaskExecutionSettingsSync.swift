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

class TaskExecutionSettingsSync: TaskExecutionTransaction {
    
    override func reflectTransactionMessages() throws -> [Promise<Void>] {
        guard let task = taskDefinition as? TaskDefinitionSettingsSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }
        
        let envelope = frameworkInjector.mediatorMessageProtocol
            .getEnvelopeForSettingsUpdate(settings: task.syncSettings)
        
        return [Promise { $0.fulfill(try reflectMessage(
            envelope: envelope,
            ltReflect: self.taskContext.logReflectMessageToMediator,
            ltAck: self.taskContext.logReceiveMessageAckFromMediator
        )) }]
    }

    override func shouldSkip() throws -> Bool {
        guard let task = taskDefinition as? TaskDefinitionSettingsSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }

        return !(
            task.syncSettings.hasBlockedIdentities
                || task.syncSettings.hasCallConnectionPolity
                || task.syncSettings.hasCallPolicy
                || task.syncSettings.hasContactSyncPolicy
                || task.syncSettings.hasTypingIndicatorPolicy
                || task.syncSettings.hasExcludeFromSyncIdentities
                || task.syncSettings.hasUnknownContactPolicy
                || task.syncSettings.hasReadReceiptPolicy
        )
    }
    
    override func writeLocal() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSettingsSync else {
            return Promise<Void> { $0.reject(TaskExecutionError.wrongTaskDefinitionType) }
        }
        
        let settingsStore = SettingsStore(
            serverConnector: frameworkInjector.serverConnector,
            myIdentityStore: frameworkInjector.myIdentityStore,
            contactStore: frameworkInjector.contactStore,
            userSettings: frameworkInjector.userSettings,
            taskManager: nil
        )
        settingsStore.save(syncSettings: task.syncSettings)
        
        return Promise()
    }
}
