import CocoaLumberjackSwift
import Foundation
import PromiseKit
import ThreemaProtocols

final class TaskExecutionReflectWorkSyncDelta: TaskExecutionTransaction {
    private var changes: [D2dSync_Contact]?
    
    override func executeTransaction() throws -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionReflectWorkSyncDelta else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }
        
        //  1. Begin a transaction with scope `WORK_SYNC_DELTA` and no precondition.

        // 2. Run the _Work Sync Delta Change Determination Steps_ another time and update `changes` with the
        // result.
        return Promise { seal in
            Task {
                do {
                    changes = try await task.determineChanges(task.deltas)

                    seal.fulfill_()
                }
                catch {
                    seal.reject(error)
                }
            }
        }
        .then { _ in
            guard let changed = self.changes, !changed.isEmpty else {
                DDLogInfo("No work sync changes to sync")
                return Promise()
            }

            // 4. Commit the transaction and await acknowledgement
            var reflectResults = [Promise<Void>]()

            for change in changed {
                let envelope = self.frameworkInjector.mediatorMessageProtocol.getEnvelopeForContactSync(
                    contact: change,
                    syncAction: .update
                )

                reflectResults.append(Promise { try $0.fulfill(
                    _ = self.reflectMessage(
                        envelope: envelope,
                        ltReflect: self.taskContext.logReflectMessageToMediator,
                        ltAck: self.taskContext.logReceiveMessageAckFromMediator
                    )
                ) })
            }

            return when(fulfilled: reflectResults).asVoid()
        }
    }

    override func writeLocal() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionReflectWorkSyncDelta else {
            return Promise<Void> { $0.reject(TaskExecutionError.wrongTaskDefinitionType) }
        }

        frameworkInjector.entityManager.updateWorkAvailabilityStatus(
            changes: changes,
            changedObjectID: task.changedManagedObjectID
        )

        return Promise()
    }
}
