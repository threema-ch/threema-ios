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

@objc public enum TaskQueueType: Int {
    case incoming
    case outgoing

    public static func queue(name: String) -> TaskQueueType {
        if name == "incoming" {
            return .incoming
        }
        else {
            return .outgoing
        }
    }

    public func name() -> String {
        switch self {
        case .incoming: return "incoming"
        case .outgoing: return "outgoing"
        }
    }
}

class TaskQueue {
    let queueType: TaskQueueType
    let supportedTypes: [TaskDefinition.Type]
    private let frameworkInjector: FrameworkInjectorProtocol
    private let renewFrameworkInjector: Bool

    class QueueItem {
        let taskDefinition: TaskDefinition
        
        init(taskDefinition: TaskDefinition, completionHandler: TaskCompletionHandler?) {
            self.taskDefinition = taskDefinition
            self.completionHandler = completionHandler
        }
        
        let completionHandler: TaskCompletionHandler?
    }

    private var queue = Queue<QueueItem>()
    private let dispatchQueue = DispatchQueue(label: "ch.threema.TaskQueue.dispatchQueue")
    private let taskScheduleQueue = DispatchQueue(label: "ch.threema.TaskQueue.taskScheduleQueue")

    enum TaskQueueError: Error {
        case notSupportedType
    }
    
    /// For testing reason
    var list: [QueueItem] {
        queue.list
    }

    /// Task queue to handle tasks for processing incoming or outgoing messages.
    /// - Parameters:
    ///     - queueType: Set type for incoming or outgoing queue
    ///     - frameworkInjector: Business injector will be used within task execution
    ///     - renewFrameworkInjector: Set to false only for testing reason to use the mock class
    required init(
        queueType: TaskQueueType,
        supportedTypes: [TaskDefinition.Type],
        frameworkInjector: FrameworkInjectorProtocol,
        renewFrameworkInjector: Bool = true
    ) {
        
        self.queueType = queueType
        self.supportedTypes = supportedTypes
        self.frameworkInjector = frameworkInjector
        self.renewFrameworkInjector = renewFrameworkInjector
    }
    
    func enqueue(task: TaskDefinition, completionHandler: TaskCompletionHandler?) throws {
        guard supportedTypes.contains(where: { $0 === type(of: task) }) else {
            throw TaskQueueError.notSupportedType
        }
        
        dispatchQueue.sync {
            queue.enqueue(QueueItem(taskDefinition: task, completionHandler: completionHandler))
            if task.isPersistent {
                save()
            }
        }
    }

    func interrupt() {
        dispatchQueue.sync {
            if let item = queue.peek(), item.taskDefinition.state == .executing {
                item.taskDefinition.state = .interrupted
            }
            save()
        }
    }
    
    func removeAll() {
        dispatchQueue.sync {
            queue.removeAll()
            save()
        }
    }

    func removeCurrent() {
        dispatchQueue.sync {
            if let item = queue.dequeue(), item.taskDefinition.isPersistent {
                save()
            }
        }
    }

    /// Execute next `pending` task.
    func spool() {
        guard frameworkInjector.serverConnector.connectionState == .loggedIn else {
            DDLogWarn("Task queue spool interrupt, because not logged in to server")
            return
        }
        
        var queueItem: QueueItem?
        dispatchQueue.sync {
            queueItem = queue.peek()
        }
        
        taskScheduleQueue.sync {
            guard let item = queueItem else {
                DDLogNotice("Task queue (\(queueType.name())) is empty")
                return
            }
            
            if item.taskDefinition.state == .pending || item.taskDefinition.state == .interrupted {
                DDLogNotice("Task \(item.taskDefinition) state '\(item.taskDefinition.state)' execute")
                
                item.taskDefinition.state = .executing
                
                // Caution:
                // - Use `self.frameworkInjector` only for testing reason! For every task to execute must be a new instance, because of using EntityManager in background (means it works on private DB context)!
                // - Do not use `self.frameworkInjector` for incoming message tasks `TaskDefinitionReceiveMessage` and `TaskDefinitionReceiveReflectedMessage`! Must be a new instance because when is running in Notification Extension process (see `NotificationService`) the database context is reseted and than the `EntityManager` could be invalid.
                let injector: FrameworkInjectorProtocol = renewFrameworkInjector ? BusinessInjector() :
                    frameworkInjector
                
                item.taskDefinition.create(frameworkInjector: injector).execute()
                    .done {
                        if let task = item.taskDefinition as? TaskDefinitionReceiveReflectedMessage {
                            try self.ackReflectedMessage(reflectID: task.reflectID)
                        }
                        
                        self.done(item: item)
                    }
                    .catch { error in
                        if (error as NSError).code == kBadMessageErrorCode ||
                            (error as NSError).code == kUnknownMessageTypeErrorCode ||
                            (error as NSError).code == kMessageAlreadyProcessedErrorCode {
                            if let task = item.taskDefinition as? TaskDefinitionReceiveMessage {
                                self.frameworkInjector.serverConnector.failedProcessingMessage(
                                    task.message,
                                    error: error
                                )
                            }
                            self.done(item: item)
                        }
                        else if (error as NSError).code == kPendingGroupMessageErrorCode {
                            // Means processed message is pending group message
                            DDLogWarn("Task \(item.taskDefinition) group not found for incoming message: \(error)")
                            self.done(item: item)
                        }
                        else if case MediatorReflectedProcessorError.messageWontProcessed(message: _) = error,
                                let task = item.taskDefinition as? TaskDefinitionReceiveReflectedMessage {
                            DDLogWarn("Task \(item.taskDefinition) incoming message wont processed: \(error)")
                            try? self.ackReflectedMessage(reflectID: task.reflectID)
                            
                            self.done(item: item)
                        }
                        else if case MediatorReflectedProcessorError.doNotAckIncomingVoIPMessage = error {
                            DDLogWarn("Task \(item.taskDefinition) incoming VoIP message wont not ack: \(error)")
                            self.done(item: item)
                        }
                        else if case TaskExecutionError.createAbsractMessageFailed = error {
                            DDLogError("Task \(item.taskDefinition) outgoing message failed: \(error)")
                            self.done(item: item)
                        }
                        else if case TaskExecutionError.messageReceiverBlockedOrUnknown = error {
                            DDLogError("Task \(item.taskDefinition) outgoing message failed: \(error)")
                            self.done(item: item)
                        }
                        else if let transactionError = error as? TaskExecutionTransactionError,
                                transactionError == .shouldSkip {
                            DDLogNotice("Task \(item.taskDefinition) skipped")
                            self.done(item: item)
                        }
                        else if case TaskExecutionError.invalidContact(message: _) = error {
                            DDLogNotice("Task \(item.taskDefinition) skipped. As the contact is invalid: \(error)")
                            self.done(item: item)
                        }
                        else if let task = item.taskDefinition as? TaskDefinitionReceiveReflectedMessage {
                            DDLogWarn("Task \(item.taskDefinition) discard incoming reflected message: \(error)")
                            try? self.ackReflectedMessage(reflectID: task.reflectID)
                            
                            self.done(item: item)
                        }
                        else {
                            self.failed(item: item, error: error)
                        }
                    }
            }
            else {
                DDLogNotice("Task queue (\(queueType.name())) task is still running")
            }
        }
    }
            
    func encode() -> Data? {
        guard !queue.list.isEmpty else {
            return nil
        }
        
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        
        // Encode type of each item
        let types: [String] = queue.list.map(\.taskDefinition.className)
        archiver.encodeRootObject(types)
        
        // Encode each task definition
        var i = 0
        queue.list.forEach { task in
            if task.taskDefinition.isPersistent {
                try? archiver.encodeEncodable(task.taskDefinition, forKey: "\(task.taskDefinition.className)_\(i)")
            }

            i += 1
        }
        
        archiver.finishEncoding()
        return archiver.encodedData
    }
    
    func decode(_ data: Data) {
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingWith: data)
            
            // Decode type of items
            if let types: [String] = try unarchiver.decodeTopLevelObject() as? [String] {
                
                // Decode task definition items
                var i = 0
                types.forEach { className in
                    var taskDefinition: TaskDefinition?
                    switch "\(className).Type" {
                    case String(describing: type(of: TaskDefinitionGroupDissolve.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionGroupDissolve.self,
                            forKey: "\(className)_\(i)"
                        )
                    case String(describing: type(of: TaskDefinitionSendAbstractMessage.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionSendAbstractMessage.self,
                            forKey: "\(className)_\(i)"
                        )
                    case String(describing: type(of: TaskDefinitionSendBallotVoteMessage.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionSendBallotVoteMessage.self,
                            forKey: "\(className)_\(i)"
                        )
                    case String(describing: type(of: TaskDefinitionSendBaseMessage.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionSendBaseMessage.self,
                            forKey: "\(className)_\(i)"
                        )
                    case String(describing: type(of: TaskDefinitionSendIncomingMessageUpdate.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionSendIncomingMessageUpdate.self,
                            forKey: "\(className)_\(i)"
                        )
                    case String(describing: type(of: TaskDefinitionSendLocationMessage.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionSendLocationMessage.self,
                            forKey: "\(className)_\(i)"
                        )
                    case String(describing: type(of: TaskDefinitionSendVideoMessage.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionSendVideoMessage.self,
                            forKey: "\(className)_\(i)"
                        )
                    case String(describing: type(of: TaskDefinitionSendGroupCreateMessage.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionSendGroupCreateMessage.self,
                            forKey: "\(className)_\(i)"
                        )
                    case String(describing: type(of: TaskDefinitionSendGroupLeaveMessage.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionSendGroupLeaveMessage.self,
                            forKey: "\(className)_\(i)"
                        )
                    case String(describing: type(of: TaskDefinitionSendGroupRenameMessage.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionSendGroupRenameMessage.self,
                            forKey: "\(className)_\(i)"
                        )
                    case String(describing: type(of: TaskDefinitionSendGroupSetPhotoMessage.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionSendGroupSetPhotoMessage.self,
                            forKey: "\(className)_\(i)"
                        )
                    case String(describing: type(of: TaskDefinitionSendGroupDeletePhotoMessage.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionSendGroupDeletePhotoMessage.self,
                            forKey: "\(className)_\(i)"
                        )
                    case String(describing: type(of: TaskDefinitionSendGroupDeliveryReceiptsMessage.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionSendGroupDeliveryReceiptsMessage.self,
                            forKey: "\(className)_\(i)"
                        )
                    case String(describing: type(of: TaskDefinitionUpdateContactSync.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionUpdateContactSync.self,
                            forKey: "\(className)_\(i)"
                        )
                    case String(describing: type(of: TaskDefinitionDeleteContactSync.self)):
                        taskDefinition = unarchiver.decodeDecodable(
                            TaskDefinitionDeleteContactSync.self,
                            forKey: "\(className)_\(i)"
                        )
                    default:
                        break
                    }
                    i += 1
                    
                    taskDefinition?.state = .interrupted
                    
                    if let taskDefinition = taskDefinition {
                        queue.enqueue(QueueItem(taskDefinition: taskDefinition, completionHandler: nil))
                    }
                }
            }
        }
        catch {
            DDLogError("Decode task queue failed: \(error)")
        }
    }

    func queuePath() -> URL? {
        let path = FileUtility.appDataDirectory
        return path?.appendingPathComponent("\(queueType.name())Queue", isDirectory: false)
    }

    // MARK: Private functions

    /// Processing of queue item is successfully done, task will be dequeued and execute next task.
    /// - Parameter item: Queue item
    private func done(item: QueueItem) {
        dispatchQueue.sync {
            DDLogNotice("Task \(item.taskDefinition) done")

            guard item === queue.peek() else {
                DDLogError("Task \(item.taskDefinition) wrong spooling order")
                return
            }

            if item.taskDefinition.state != .pending {
                _ = queue.dequeue()
                if item.taskDefinition.isPersistent {
                    save()
                }
            }

            if queue.list.isEmpty {
                self.frameworkInjector.serverConnector.taskQueueEmpty(queueType.name())
            }
        }

        item.completionHandler?(item.taskDefinition, nil)
        spool()
    }

    /// Processing queue item is failed, retry or dequeue it.
    /// - Parameter item: Queue item
    /// - Parameter error: Task failed with error
    private func failed(item: QueueItem, error: Error) {
        var retry = false

        dispatchQueue.sync {
            DDLogError("Task \(item.taskDefinition) failed \(error)")

            retry = false

            guard item === queue.peek() else {
                DDLogError("Task \(item.taskDefinition) wrong spooling order")
                return
            }

            if item.taskDefinition.state != .pending {
                item.taskDefinition.state = .pending

                if item.taskDefinition.retry, item.taskDefinition.retryCount == 0 {
                    DDLogNotice("Retry of task \(item.taskDefinition) after execution failing")
                    item.taskDefinition.retryCount += 1
                    retry = true
                }
                else if queueType == .incoming {
                    // Remove/chancel task processing of failed incoming message, try again with next server connection!
                    _ = queue.dequeue()
                }

                if item.taskDefinition.isPersistent {
                    save()
                }
            }

            if queue.list.isEmpty {
                self.frameworkInjector.serverConnector.taskQueueEmpty(queueType.name())
            }
        }

        if !retry {
            item.completionHandler?(item.taskDefinition, error)
        }

        if queueType == .incoming || retry {
            spool()
        }
    }

    private func save() {
        if let queuePath = queuePath() {
            FileUtility.delete(at: queuePath)
            if let queueData = encode(),
               !FileUtility.write(fileURL: queuePath, contents: queueData) {
                DDLogError("Could not save queue into file")
            }
        }
    }

    private func ackReflectedMessage(reflectID: Data) throws {
        if frameworkInjector.serverConnector.isMultiDeviceActivated {
            if !frameworkInjector.serverConnector
                .reflectMessage(
                    frameworkInjector.mediatorMessageProtocol
                        .encodeReflectedAck(reflectID: reflectID)
                ) {
                throw TaskExecutionError.reflectMessageFailed(message: "(reflect ID: \(reflectID.hexString))")
            }
        }
        else {
            throw TaskExecutionError.noDeviceGroupPathKey
        }
    }
}
