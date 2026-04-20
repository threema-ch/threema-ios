import CocoaLumberjackSwift
import Foundation
import PromiseKit
import ThreemaProtocols

final class TaskExecutionMdmParameterSync: TaskExecutionTransaction {

    override func executeTransaction() throws -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionMdmParameterSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }

        let envelope = frameworkInjector.mediatorMessageProtocol
            .getEnvelopeForMdmParametersUpdate(mdmParameters: task.mdmParameters)

        try reflectMessage(
            envelope: envelope,
            ltReflect: taskContext.logReflectMessageToMediator,
            ltAck: taskContext.logReceiveMessageAckFromMediator
        )

        return Promise()
    }

    override func writeLocal() -> Promise<Void> {
        Promise()
    }
}
