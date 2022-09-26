//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

public enum TaskExecutionTransactionError: Error {
    case lockTimeout
    case otherTransactionInProgress
    case sameTransactionInProgress
    case badResponse
    case preconditionFailed
    case localTransactionAlreadyInProgress
    case blobUploadFailed
    case blobEncryptFailed
    case shouldSkip
}

class TaskExecutionTransaction: TaskExecution, TaskExecutionProtocol {
    fileprivate struct TaskExecutionTransactionResponse {
        let messageType: MediatorMessageProtocol.MediatorMessageType
        let scope: D2d_TransactionScope.Scope?
    }

    fileprivate var transactionResponse: TaskExecutionTransactionResponse?
    fileprivate var transactionResponseTimeout: DispatchGroup?

    private let responseTimeoutInSeconds = 25

    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinition, task is TaskDefinitionTransactionProtocol else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }

        return firstly {
            isMultiDeviceActivated()
        }
        .then { doReflect -> Promise<Void> in
            guard doReflect else {
                throw TaskExecutionError.noDeviceGroupPathKey
            }

            self.frameworkInjector.serverConnector.registerTaskExecutionTransactionDelegate(delegate: self)

            // TODO: The following two guard statements are not very elegant.
            // They could be handled as part of the preparation for the transaction
            // However we'll leave it like this for the time being.
            guard try self.checkPreconditions() else {
                throw TaskExecutionTransactionError.preconditionFailed
            }
            guard !(try self.shouldSkip()) else {
                throw TaskExecutionTransactionError.shouldSkip
            }

            return self.prepare()
        }
        .then { _ -> Promise<Void> in
            try self.beginTransaction(scope: (task as! TaskDefinitionTransactionProtocol).scope)
        }
        .then { _ -> Promise<Void> in
            guard try self.checkPreconditions() else {
                throw TaskExecutionTransactionError.preconditionFailed
            }

            let reflectResult = try self.reflectTransactionMessages()
            return when(fulfilled: reflectResult).asVoid()
        }
        .then { _ -> Promise<Void> in
            try self.commitTransaction()
        }
        .then { _ -> Promise<Void> in
            self.writeLocal()
        }
        .ensure {
            self.frameworkInjector.serverConnector.unregisterTaskExecutionTransactionDelegate(delegate: self)
        }
    }

    // MARK: Override functions

    func prepare() -> Promise<Void> {
        Promise()
    }

    func checkPreconditions() throws -> Bool {
        true
    }

    func shouldSkip() throws -> Bool {
        false
    }

    @discardableResult func reflectTransactionMessages() throws -> [Promise<Void>] {
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

        guard try wait(forType: .lockAck, message: message, messageType: .lock) == .lockAck else {
            throw TaskExecutionTransactionError.badResponse
        }

        DDLogNotice(
            "\(LoggingTag.sendBeginTransactionToMediator.hexString) \(LoggingTag.sendBeginTransactionToMediator) \(String(describing: taskDefinition))"
        )

        return Promise()
    }

    private func commitTransaction() throws -> Promise<Void> {
        guard let message = frameworkInjector.mediatorMessageProtocol
            .encodeCommitTransactionMessage(messageType: .unlock) else {
            throw TaskExecutionError.createReflectedMessageFailed
        }

        guard try wait(forType: .unlockAck, message: message, messageType: .unlock) == .unlockAck else {
            throw TaskExecutionTransactionError.badResponse
        }

        DDLogNotice(
            "\(LoggingTag.sendCommitTransactionToMediator.hexString) \(LoggingTag.sendCommitTransactionToMediator) \(String(describing: taskDefinition))"
        )

        return Promise()
    }

    private func wait(
        forType: MediatorMessageProtocol.MediatorMessageType,
        message: Data,
        messageType: MediatorMessageProtocol.MediatorMessageType
    ) throws -> MediatorMessageProtocol.MediatorMessageType {

        transactionResponse = nil
        transactionResponseTimeout = DispatchGroup()
        transactionResponseTimeout?.enter()

        if !frameworkInjector.serverConnector.reflectMessage(message) {
            throw TaskExecutionError.reflectMessageFailed(message: "type: \(messageType)")
        }

        let result = transactionResponseTimeout?.wait(timeout: .now() + .seconds(responseTimeoutInSeconds))
        guard result == .success else {
            throw TaskExecutionTransactionError.lockTimeout
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
        if let reasonInt: Int = reason?.convert() {
            scope = D2d_TransactionScope.Scope(rawValue: reasonInt)
        }
        if let type = MediatorMessageProtocol.MediatorMessageType(rawValue: messageType) {
            transactionResponse = TaskExecutionTransactionResponse(messageType: type, scope: scope)
        }
        transactionResponseTimeout?.leave()
    }
}
