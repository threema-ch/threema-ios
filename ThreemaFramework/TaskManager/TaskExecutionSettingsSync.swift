import CocoaLumberjackSwift
import Foundation
import PromiseKit

final class TaskExecutionSettingsSync: TaskExecutionTransaction {
    
    override func executeTransaction() throws -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSettingsSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }
        
        let envelope = frameworkInjector.mediatorMessageProtocol
            .getEnvelopeForSettingsUpdate(settings: task.syncSettings)
        
        try reflectMessage(
            envelope: envelope,
            ltReflect: taskContext.logReflectMessageToMediator,
            ltAck: taskContext.logReceiveMessageAckFromMediator
        )

        return Promise()
    }

    override func shouldDrop() throws -> Bool {
        guard let task = taskDefinition as? TaskDefinitionSettingsSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }

        return !(
            task.syncSettings.hasBlockedIdentities
                || task.syncSettings.hasO2OCallConnectionPolicy
                || task.syncSettings.hasO2OCallPolicy
                || task.syncSettings.hasContactSyncPolicy
                || task.syncSettings.hasTypingIndicatorPolicy
                || task.syncSettings.hasExcludeFromSyncIdentities
                || task.syncSettings.hasUnknownContactPolicy
                || task.syncSettings.hasReadReceiptPolicy
                || task.syncSettings.hasGroupCallPolicy
        )
    }
    
    override func writeLocal() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSettingsSync else {
            return Promise<Void> { $0.reject(TaskExecutionError.wrongTaskDefinitionType) }
        }
        
        frameworkInjector.settingsStoreInternal.updateSettingsStore(with: task.syncSettings)
        
        return Promise()
    }
}
