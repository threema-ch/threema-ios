import CocoaLumberjackSwift
import Foundation
import PromiseKit
import ThreemaProtocols

public enum TaskExecutionTransactionError: Error {
    case lockTimeout
    case otherTransactionInProgress
    case sameTransactionInProgress
    case badResponse
    case preconditionFailed
    case localTransactionAlreadyInProgress
    case blobDataEncryptionFailed
    case blobIDDecodeFailed
    case blobIDMismatch
    case blobIDMissing
    case blobUploadURLMissing
}

class TaskExecutionTransaction: TaskExecution, TaskExecutionProtocol {
    fileprivate struct TaskExecutionTransactionResponse {
        let messageType: MediatorMessageProtocol.MediatorMessageType
        let scope: D2d_TransactionScope.Scope?
    }

    fileprivate var transactionResponse: TaskExecutionTransactionResponse?
    fileprivate var transactionResponseTimeout: DispatchGroup?

    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinition, task is TaskDefinitionTransactionProtocol else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }

        return firstly {
            isMultiDeviceRegistered()
        }
        .then { doReflect -> Promise<Void> in
            guard doReflect else {
                throw TaskExecutionError.multiDeviceNotRegistered
            }

            self.frameworkInjector.serverConnector.registerTaskExecutionTransactionDelegate(delegate: self)

            // TODO: The following two guard statements are not very elegant.
            // They could be handled as part of the preparation for the transaction
            // However we'll leave it like this for the time being.
            guard try self.checkPreconditions() else {
                throw TaskExecutionTransactionError.preconditionFailed
            }
            guard try !(self.shouldDrop()) else {
                DDLogNotice("\(self.taskDefinition) should be dropped")
                task.isDropped = true
                throw TaskExecutionError.taskDropped
            }
            
            try task.checkDropping()

            return self.prepare()
        }
        .then { _ -> Promise<Void> in
            try task.checkDropping()
            return try self.beginTransaction(scope: (task as! TaskDefinitionTransactionProtocol).scope)
        }
        .then { _ -> Promise<Void> in
            try self.executeAndCommitTransaction(for: task)
        }
        .then { _ -> Promise<Void> in
            self.writeLocal()
        }
        .ensure {
            self.frameworkInjector.serverConnector.unregisterTaskExecutionTransactionDelegate(delegate: self)
        }
    }

    /// Executes the transaction after successful begin of the transaction and
    /// commits the transaction, even if an error occurs.
    ///
    /// If the commit fails, then the task will be finished as a failed task and it should retried again.
    ///
    /// - Parameter task: Actual running task
    private func executeAndCommitTransaction(for task: TaskDefinition) throws -> Promise<Void> {
        Promise { seal in
            do {
                guard try self.checkPreconditions() else {
                    throw TaskExecutionTransactionError.preconditionFailed
                }

                try task.checkDropping()

                _ = try self.executeTransaction()
                    .then {
                        try self.commitTransaction()

                        seal.fulfill_()
                        return Promise()
                    }
                    .catch(on: .global()) { error in
                        seal.reject(error)
                    }
            }
            catch {
                do {
                    try self.commitTransaction()
                }
                catch {
                    DDLogError("\(task) commit transaction failed with error: \(error)")
                }
                seal.reject(error)
            }
        }
    }

    // MARK: Override functions

    func prepare() -> Promise<Void> {
        Promise()
    }

    // TODO: (IOS-4835) Check if this can/should be combined with `shouldDrop()`
    func checkPreconditions() throws -> Bool {
        true
    }

    // TODO: (IOS-4835) Check if this can/should be combined with `checkPreconditions()`
    func shouldDrop() throws -> Bool {
        false
    }

    @discardableResult func executeTransaction() throws -> Promise<Void> {
        preconditionFailure("This function must be overridden")
    }

    func writeLocal() -> Promise<Void> {
        preconditionFailure("This function must be overridden")
    }

    // MARK: Transaction handling

    private func beginTransaction(scope: D2d_TransactionScope.Scope) throws -> Promise<Void> {
        guard let message = frameworkInjector.mediatorMessageProtocol.encodeBeginTransactionMessage(
            messageType: .lock,
            reason: scope
        ) else {
            throw TaskExecutionError.createReflectedMessageFailed
        }

        guard try reflectAndWaitForResponse(message: message, messageType: .lock) == .lockAck else {
            throw TaskExecutionTransactionError.badResponse
        }

        DDLogNotice(
            "\(LoggingTag.sendBeginTransactionToMediator.hexString) \(LoggingTag.sendBeginTransactionToMediator) \(String(describing: taskDefinition))"
        )

        return Promise()
    }

    private func commitTransaction() throws {
        guard let message = frameworkInjector.mediatorMessageProtocol
            .encodeCommitTransactionMessage(messageType: .unlock) else {
            throw TaskExecutionError.createReflectedMessageFailed
        }

        guard try reflectAndWaitForResponse(message: message, messageType: .unlock) == .unlockAck else {
            throw TaskExecutionTransactionError.badResponse
        }

        DDLogNotice(
            "\(LoggingTag.sendCommitTransactionToMediator.hexString) \(LoggingTag.sendCommitTransactionToMediator) \(String(describing: taskDefinition))"
        )
    }

    private func reflectAndWaitForResponse(
        message: Data,
        messageType: MediatorMessageProtocol.MediatorMessageType
    ) throws -> MediatorMessageProtocol.MediatorMessageType {

        transactionResponse = nil
        transactionResponseTimeout = DispatchGroup()
        transactionResponseTimeout?.enter()

        let loggingMsgInfo = "message type: \(messageType)"

        // Add observer to release the waiting of the lock or unlock response, if the task is interrupted
        let task = taskDefinition as? TaskDefinition
        let interruptionObserver = observeInterruption(of: taskDefinition as? TaskDefinition) {
            DDLogWarn("\(loggingMsgInfo) interrupted")
            self.transactionResponseTimeout?.leave()
        }

        if let error = frameworkInjector.serverConnector.reflectMessage(message) {
            throw TaskExecutionError.reflectMessageFailed(message: "\(loggingMsgInfo) / \(error)")
        }

        let result = transactionResponseTimeout?.wait(
            timeout: .now() + .seconds(taskContext.transactionResponseTimeoutInSeconds)
        )
        guard result == .success else {
            throw TaskExecutionTransactionError.lockTimeout
        }

        if let interruptionObserver {
            interruptionObserver.invalidate()
        }

        guard let task, !task.isInterrupted else {
            throw TaskExecutionError.reflectMessageInterrupted(message: loggingMsgInfo)
        }

        if let type = transactionResponse?.messageType {
            if type == .lockAck || type == .unlockAck {
                return type
            }
            if type == .rejected, let task = taskDefinition as? TaskDefinitionTransactionProtocol {
                throw transactionResponse?.scope == task.scope ? TaskExecutionTransactionError
                    .sameTransactionInProgress : TaskExecutionTransactionError.otherTransactionInProgress
            }
        }

        throw TaskExecutionTransactionError.badResponse
    }
}

// MARK: - TaskExecutionTransactionDelegate

extension TaskExecutionTransaction: TaskExecutionTransactionDelegate {
    func transactionResponse(_ messageType: UInt8, reason: Data?) {
        var scope: D2d_TransactionScope.Scope?
        if let reasonInt: Int = reason?.paddedLittleEndian() {
            scope = D2d_TransactionScope.Scope(rawValue: reasonInt)
        }
        if let type = MediatorMessageProtocol.MediatorMessageType(rawValue: messageType) {
            transactionResponse = TaskExecutionTransactionResponse(messageType: type, scope: scope)
        }
        transactionResponseTimeout?.leave()
    }
}
