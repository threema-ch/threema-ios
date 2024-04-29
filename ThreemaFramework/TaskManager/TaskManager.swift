//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

enum TaskManagerError: Error {
    case flushedTask, noTaskQueueFound
}

typealias TaskCompletionHandler = (TaskDefinitionProtocol, Error?) -> Void
typealias TaskReceiverNonce = [String: Data]

public final class TaskManager: NSObject, TaskManagerProtocol {
    private let entityManager: EntityManager?

    private static var incomingQueue: TaskQueue?
    private static var outgoingQueue: TaskQueue?

    private static let dispatchIncomingQueue = DispatchQueue(label: "ch.threema.TaskManager.dispatchIncomingQueue")
    private static let dispatchOutgoingQueue = DispatchQueue(label: "ch.threema.TaskManager.dispatchOutgoingQueue")

    @objc required init(backgroundEntityManager entityManager: EntityManager?) {
        self.entityManager = entityManager
        super.init()

        load()
    }

    override convenience init() {
        self.init(backgroundEntityManager: nil)
    }

    func add(taskDefinition: TaskDefinitionProtocol) {
        do {
            try add(task: taskDefinition, completionHandler: nil)
        }
        catch {
            DDLogError("Failed add task to queue \(error)")
        }

        spool()
    }

    func add(taskDefinition: TaskDefinitionProtocol, completionHandler: @escaping TaskCompletionHandler) {
        do {
            try add(task: taskDefinition, completionHandler: completionHandler)
        }
        catch {
            DDLogError("Failed add task to queue \(error)")
        }

        spool()
    }

    func add(taskDefinitionTuples: [(
        taskDefinition: TaskDefinitionProtocol,
        completionHandler: TaskCompletionHandler
    )]) {
        // Add addQueue
        do {
            for taskDefinitionTuple in taskDefinitionTuples {
                try add(
                    task: taskDefinitionTuple.taskDefinition,
                    completionHandler: taskDefinitionTuple.completionHandler
                )
            }
        }
        catch {
            DDLogError("Failed add task to queue \(error)")
        }

        spool()
    }

    private func add(task: TaskDefinitionProtocol, completionHandler: TaskCompletionHandler? = nil) throws {
        guard let task = task as? TaskDefinition else {
            throw TaskManagerError.noTaskQueueFound
        }
        
        if let queue = TaskManager.incomingQueue, queue.supportedTypes.contains(where: { $0 === type(of: task) }) {
            try TaskManager.dispatchIncomingQueue.sync {
                try queue.enqueue(task: task, completionHandler: completionHandler)
            }
        }
        else if let queue = TaskManager.outgoingQueue, queue.supportedTypes.contains(where: { $0 === type(of: task) }) {
            try TaskManager.dispatchOutgoingQueue.sync {
                try queue.enqueue(task: task, completionHandler: completionHandler)
            }
        }
        else {
            throw TaskManagerError.noTaskQueueFound
        }
    }

    @objc public static func interrupt(queueType: TaskQueueType) {
        switch queueType {
        case .incoming:
            TaskManager.incomingQueue?.interrupt()
        case .outgoing:
            TaskManager.outgoingQueue?.interrupt()
        }
    }

    @objc public static func flush(queueType: TaskQueueType) {
        switch queueType {
        case .incoming:
            TaskManager.incomingQueue?.removeAll()
        case .outgoing:
            TaskManager.outgoingQueue?.removeCurrent()
        }
    }

    @objc public static func isEmpty(queueType: TaskQueueType) -> Bool {
        switch queueType {
        case .incoming:
            return TaskManager.incomingQueue?.list.isEmpty ?? true
        case .outgoing:
            return TaskManager.outgoingQueue?.list.isEmpty ?? true
        }
    }

    /// Get notification name for particular reflecting/acking of a message.
    ///
    /// - Returns: kNotificationMediatorMessageAck + hex string of reflect ID
    @objc static func mediatorMessageAckObserverName(reflectID: Data) -> Notification.Name {
        Notification.Name("\(kNotificationMediatorMessageAck)\(reflectID.hexString)")
    }

    /// Get notification name for particular sending/acking of a message.
    ///
    /// - Returns: kNotificationChatMessageAck + hex string of message ID
    @objc static func chatMessageAckObserverName(messageID: Data, toIdentity: String) -> Notification.Name {
        Notification.Name("\(kNotificationChatMessageAck)\(messageID.hexString)\(toIdentity)")
    }

    /// Execute all pending tasks.
    @objc func spool() {
        TaskManager.incomingQueue?.spool()
        TaskManager.outgoingQueue?.spool()
    }

    private func load() {
        TaskManager.dispatchIncomingQueue.sync {
            if TaskManager.incomingQueue == nil {
                TaskManager.incomingQueue = TaskQueue(
                    queueType: .incoming,
                    supportedTypes: [
                        TaskDefinitionReceiveMessage.self,
                        TaskDefinitionReceiveReflectedMessage.self,
                    ],
                    frameworkInjectorResolver: FrameworkInjectorResolver(backgroundEntityManager: self.entityManager)
                )

                self.load(queue: TaskManager.incomingQueue)
            }
        }

        TaskManager.dispatchOutgoingQueue.sync {
            if TaskManager.outgoingQueue == nil {
                TaskManager.outgoingQueue = TaskQueue(
                    queueType: .outgoing,
                    supportedTypes: [
                        TaskDefinitionGroupDissolve.self,
                        TaskDefinitionSendAbstractMessage.self,
                        TaskDefinitionSendBallotVoteMessage.self,
                        TaskDefinitionSendBaseMessage.self,
                        TaskDefinitionSendDeliveryReceiptsMessage.self,
                        TaskDefinitionSendLocationMessage.self,
                        TaskDefinitionSendGroupCreateMessage.self,
                        TaskDefinitionSendGroupDeletePhotoMessage.self,
                        TaskDefinitionSendGroupLeaveMessage.self,
                        TaskDefinitionSendGroupRenameMessage.self,
                        TaskDefinitionSendGroupSetPhotoMessage.self,
                        TaskDefinitionSendGroupDeliveryReceiptsMessage.self,
                        TaskDefinitionDeleteContactSync.self,
                        TaskDefinitionProfileSync.self,
                        TaskDefinitionUpdateContactSync.self,
                        TaskDefinitionGroupSync.self,
                        TaskDefinitionSettingsSync.self,
                        TaskDefinitionMdmParameterSync.self,
                        TaskDefinitionSendGroupCallStartMessage.self,
                        TaskDefinitionRunForwardSecurityRefreshSteps.self,
                    ],
                    frameworkInjectorResolver: FrameworkInjectorResolver(backgroundEntityManager: self.entityManager)
                )

                self.load(queue: TaskManager.outgoingQueue)
            }
        }
    }

    private func load(queue: TaskQueue?) {
        if let queuePath = queue?.queuePath(),
           FileUtility.isExists(fileURL: queuePath) {
            if let data = FileUtility.read(fileURL: queuePath) {
                FileUtility.delete(at: queuePath)
                
                queue?.decode(data)
            }
        }
    }
}

// MARK: - TaskManagerProtocolObjc

extension TaskManager: TaskManagerProtocolObjc {
    @objc func addObjc(taskDefinition: AnyObject) {
        assert(taskDefinition is TaskDefinition)
        guard let taskDefinition = taskDefinition as? TaskDefinition else {
            DDLogError("Worng type for taskDefinition")
            return
        }
        
        add(taskDefinition: taskDefinition)
    }

    @objc func addObjc(taskDefinition: AnyObject, completionHandler: @escaping (AnyObject, Error?) -> Void) {
        assert(taskDefinition is TaskDefinition)
        guard let taskDefinition = taskDefinition as? TaskDefinition else {
            DDLogError("Worng type for taskDefinition")
            return
        }

        add(taskDefinition: taskDefinition, completionHandler: { task, error in
            completionHandler(task as! TaskDefinition, error)
        })
    }
}
