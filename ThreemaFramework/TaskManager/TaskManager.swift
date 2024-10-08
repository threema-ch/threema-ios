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

typealias TaskReceiverNonce = [String: Data]

public final class TaskManager: NSObject, TaskManagerProtocol {
    private let entityManager: EntityManager?
    private let serverConnector: ServerConnectorProtocol

    private static var taskQueue: TaskQueue?

    private static let addTaskQueue = DispatchQueue(label: "ch.threema.TaskManager.addTaskQueue")

    @objc required init(
        backgroundEntityManager entityManager: EntityManager?,
        serverConnector: ServerConnectorProtocol
    ) {
        self.entityManager = entityManager
        self.serverConnector = serverConnector
        super.init()

        load()
    }

    override convenience init() {
        self.init(backgroundEntityManager: nil, serverConnector: ServerConnector.shared())
    }

    func add(taskDefinition: TaskDefinitionProtocol) -> CancelableTask? {
        TaskManager.addTaskQueue.async {
            do {
                try self.add(task: taskDefinition, completionHandler: nil)
            }
            catch {
                DDLogError("Failed add task to queue \(error)")
            }

            self.spool()
        }
        
        assert(taskDefinition is TaskDefinition, "We always expect a `TaskDefinition`")
        
        // Only drop on disconnect tasks are cancelable
        if let task = taskDefinition as? TaskDefinition, task.type == .dropOnDisconnect {
            return CancelableDropOnDisconnectTask(taskDefinition: task, serverConnector: serverConnector)
        }
        else {
            return nil
        }
    }

    func add(
        taskDefinition: TaskDefinitionProtocol,
        completionHandler: @escaping TaskCompletionHandler
    ) -> CancelableTask? {
        TaskManager.addTaskQueue.async {
            do {
                try self.add(task: taskDefinition, completionHandler: completionHandler)
            }
            catch {
                DDLogError("Failed add task to queue \(error)")
            }

            self.spool()
        }
        
        assert(taskDefinition is TaskDefinition, "We always expect a `TaskDefinition`")
        
        // Only drop on disconnect tasks are cancelable
        if let task = taskDefinition as? TaskDefinition, task.type == .dropOnDisconnect {
            return CancelableDropOnDisconnectTask(taskDefinition: task, serverConnector: serverConnector)
        }
        else {
            return nil
        }
    }

    func add(taskDefinitionTuples: [(
        taskDefinition: TaskDefinitionProtocol,
        completionHandler: TaskCompletionHandler
    )]) -> [CancelableTask?] {
        TaskManager.addTaskQueue.async {
            do {
                for taskDefinitionTuple in taskDefinitionTuples {
                    try self.add(
                        task: taskDefinitionTuple.taskDefinition,
                        completionHandler: taskDefinitionTuple.completionHandler
                    )
                }
            }
            catch {
                DDLogError("Failed add task to queue \(error)")
            }

            self.spool()
        }
        
        var cancellableTasks = [CancelableTask?]()
        for taskDefinitionTuple in taskDefinitionTuples {
            
            assert(taskDefinitionTuple.taskDefinition is TaskDefinition, "We always expect a `TaskDefinition`")
            
            // Only drop on disconnect tasks are cancelable
            if let task = taskDefinitionTuple.taskDefinition as? TaskDefinition, task.type == .dropOnDisconnect {
                cancellableTasks.append(CancelableDropOnDisconnectTask(
                    taskDefinition: task,
                    serverConnector: serverConnector
                ))
            }
            else {
                cancellableTasks.append(nil)
            }
        }
        
        assert(cancellableTasks.count == taskDefinitionTuples.count)
        
        return cancellableTasks
    }

    private func add(task: TaskDefinitionProtocol, completionHandler: TaskCompletionHandler? = nil) throws {
        guard let queue = TaskManager.taskQueue, let task = task as? TaskDefinition else {
            throw TaskManagerError.noTaskQueueFound
        }
        
        try queue.enqueue(task: task, completionHandler: completionHandler)
    }

    @objc public static func interrupt() {
        TaskManager.taskQueue?.interrupt()
    }

    @objc public static func removeAllTasks() {
        TaskManager.taskQueue?.removeAll()
    }

    @objc public static func removeCurrentTask() {
        TaskManager.taskQueue?.removeCurrent()
    }

    @objc public static func isEmpty() -> Bool {
        TaskManager.taskQueue?.list.isEmpty ?? true
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
        TaskManager.taskQueue?.spool()
    }

    private func load() {
        TaskManager.addTaskQueue.async {
            if TaskManager.taskQueue == nil {
                TaskManager.taskQueue = TaskQueue(
                    frameworkInjectorResolver: FrameworkInjectorResolver(backgroundEntityManager: self.entityManager)
                )

                if let queuePath = TaskManager.taskQueue?.queuePath(),
                   FileUtility.shared.isExists(fileURL: queuePath) {
                    if let data = FileUtility.shared.read(fileURL: queuePath) {
                        FileUtility.shared.delete(at: queuePath)

                        TaskManager.taskQueue?.decode(data)
                    }
                }
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
