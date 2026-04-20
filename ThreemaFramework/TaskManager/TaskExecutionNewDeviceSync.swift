import Foundation
import PromiseKit

// If this task blocks the queue on iOS 15 or 16 see IOS-4911
final class TaskExecutionNewDeviceSync: TaskExecutionTransaction {
    override func executeTransaction() throws -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionNewDeviceSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }
        
        // Not so great, but we have to combine Promises with Swift Concurrency here
        return Promise { seal in
            Task {
                do {
                    try await task.join(CancelableDropOnDisconnectTask(
                        taskDefinition: task,
                        serverConnector: frameworkInjector.serverConnector
                    ))
                    seal.fulfill_()
                }
                catch {
                    seal.reject(error)
                }
            }
        }
    }
    
    override func writeLocal() -> Promise<Void> {
        // Nothing to do...
        Promise()
    }
}
