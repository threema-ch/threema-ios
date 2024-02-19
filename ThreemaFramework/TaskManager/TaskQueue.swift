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

final class TaskQueue {
    let queueType: TaskQueueType
    let supportedTypes: [TaskDefinition.Type]
    static let retriesOfFailedTasks = 1

    private var spoolingDelay = false
    private var spoolingDelayAttempts = 0
    private let spoolingDelayBaseInterval: Float = 2
    private let spoolingDelayMaxInterval: Float = 10
    private var isWaitingForSpooling = false

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
    private let taskQueueQueue = DispatchQueue(label: "ch.threema.TaskQueue.taskQueueQueue")
    private let taskScheduleQueue = DispatchQueue(label: "ch.threema.TaskQueue.taskScheduleQueue")
    private let spoolingDelayQueue = DispatchQueue(label: "ch.threema.TaskQueue.spoolingDelayQueue")

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
        
        taskQueueQueue.sync {
            queue.enqueue(QueueItem(taskDefinition: task, completionHandler: completionHandler))
            if task.isPersistent {
                save()
            }
        }
    }

    func interrupt() {
        taskQueueQueue.sync {
            if let item = queue.peek(), item.taskDefinition.state == .executing {
                item.taskDefinition.state = .interrupted
            }
            save()
        }
    }
    
    func removeAll() {
        taskQueueQueue.sync {
            queue.removeAll()
            save()
        }
    }

    func removeCurrent() {
        taskQueueQueue.sync {
            if let item = queue.dequeue(), item.taskDefinition.isPersistent {
                save()

                DDLogWarn("\(item.taskDefinition) flushed")
                item.completionHandler?(item.taskDefinition, TaskManagerError.flushedTask)
            }
        }
    }

    func spool() {
        guard spoolingDelay else {
            executeNext()
            return
        }

        spoolingDelayQueue.async {
            guard !self.isWaitingForSpooling else {
                return
            }

            self.isWaitingForSpooling = true

            var delay = powf(self.spoolingDelayBaseInterval, Float(min(self.spoolingDelayAttempts - 1, 10)))
            if delay > self.spoolingDelayMaxInterval {
                delay = self.spoolingDelayMaxInterval
            }

            self.spoolingDelayAttempts += 1

            DDLogNotice("Waiting \(delay) seconds before execute next task")

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .milliseconds(Int(delay * 1000))) {
                self.isWaitingForSpooling = false
                self.executeNext()
            }
        }
    }

    /// Execute next `pending` task.
    func executeNext() {
        guard frameworkInjector.serverConnector.connectionState == .loggedIn else {
            DDLogWarn("Task queue spool interrupt, because not logged in to server")
            return
        }
        
        var queueItem: QueueItem?
        taskQueueQueue.sync {
            queueItem = queue.peek()
        }
        
        taskScheduleQueue.async {
            guard let item = queueItem else {
                DDLogNotice("Task queue (\(self.queueType.name())) is empty")
                return
            }
            
            if item.taskDefinition.state == .pending || item.taskDefinition.state == .interrupted {
                DDLogNotice("\(item.taskDefinition) state '\(item.taskDefinition.state)' execute")
                
                item.taskDefinition.state = .executing
                
                // Caution:
                // - Use `self.frameworkInjector` only for testing reason! For every task to execute must be a new
                //   instance, because of using EntityManager in background (means it works on private DB context)!
                // - Do not use `self.frameworkInjector` for incoming message tasks `TaskDefinitionReceiveMessage` and
                //   `TaskDefinitionReceiveReflectedMessage`! Must be a new instance because when is running in
                //   Notification Extension process (see `NotificationService`) the database context is reseted and than
                //   the `EntityManager` could be invalid.
                let injector: FrameworkInjectorProtocol = self.renewFrameworkInjector ? BusinessInjector() :
                    self.frameworkInjector
                
                item.taskDefinition.create(frameworkInjector: injector).execute()
                    .done {
                        if let task = item.taskDefinition as? TaskDefinitionReceiveReflectedMessage {
                            if let reflectMessageError = self.frameworkInjector.serverConnector
                                .reflectMessage(
                                    self.frameworkInjector.mediatorMessageProtocol
                                        .encodeReflectedAck(reflectID: task.reflectID)
                                ) as? NSError {

                                guard ThreemaProtocolError.notLoggedIn.rawValue != reflectMessageError.code else {
                                    self.failed(item: item, error: reflectMessageError, enableSpoolingDelay: true)
                                    return
                                }

                                DDLogError(
                                    "\(item.taskDefinition) sending server ack of incoming reflected message failed: \(reflectMessageError)"
                                )
                            }
                        }

                        self.done(item: item)
                    }
                    .catch(on: .global()) { error in
                        if (error as NSError).code == ThreemaProtocolError.badMessage.rawValue ||
                            (error as NSError).code == ThreemaProtocolError.blockUnknownContact.rawValue ||
                            (error as NSError).code == ThreemaProtocolError.messageAlreadyProcessed.rawValue ||
                            (error as NSError).code == ThreemaProtocolError.messageBlobDecryptionFailed.rawValue ||
                            (error as NSError).code == ThreemaProtocolError.messageNonceReuse.rawValue ||
                            (error as NSError).code == ThreemaProtocolError.unknownMessageType.rawValue {

                            if let task = item.taskDefinition as? TaskDefinitionReceiveMessage {
                                DDLogNotice("\(task) discard incoming message: \(error)")

                                try? self.frameworkInjector.nonceGuard.processed(boxedMessage: task.message)
                                self.frameworkInjector.serverConnector.completedProcessingMessage(task.message)
                            }
                            else if let task = item.taskDefinition as? TaskDefinitionReceiveReflectedMessage {
                                DDLogNotice("\(task) discard reflected message: \(error)")

                                try? self.frameworkInjector.nonceGuard
                                    .processed(reflectedEnvelope: task.reflectedEnvelope)

                                if let reflectMessageError = self.frameworkInjector.serverConnector
                                    .reflectMessage(
                                        self.frameworkInjector.mediatorMessageProtocol
                                            .encodeReflectedAck(reflectID: task.reflectID)
                                    ) as? NSError {

                                    guard ThreemaProtocolError.notLoggedIn.rawValue != reflectMessageError.code else {
                                        self.failed(item: item, error: reflectMessageError, enableSpoolingDelay: true)
                                        return
                                    }

                                    DDLogError("\(item.taskDefinition) done \(reflectMessageError)")
                                }
                            }
                            else {
                                DDLogError("\(item.taskDefinition) \(error)")
                            }

                            self.done(item: item)
                        }
                        else if case ThreemaProtocolError.pendingGroupMessage = error {
                            // Means processed message is pending group message
                            DDLogWarn("\(item.taskDefinition) \(error)")
                            self.done(item: item)
                        }
                        else if case MediatorReflectedProcessorError.doNotAckIncomingVoIPMessage = error {
                            DDLogWarn("\(item.taskDefinition) \(error)")
                            self.done(item: item)
                        }
                        else if case TaskExecutionError.conversationNotFound(for: _) = error {
                            DDLogError("\(item.taskDefinition) failed: \(error)")
                            self.done(item: item)
                        }
                        else if case TaskExecutionError.createAbstractMessageFailed = error {
                            DDLogError("\(item.taskDefinition) outgoing message failed: \(error)")
                            self.done(item: item)
                        }
                        else if case TaskExecutionError.messageReceiverBlockedOrUnknown = error {
                            DDLogError("\(item.taskDefinition) outgoing message failed: \(error)")
                            self.done(item: item)
                        }
                        else if let transactionError = error as? TaskExecutionTransactionError,
                                transactionError == .shouldSkip {
                            DDLogNotice("\(item.taskDefinition) skipped: \(error)")
                            self.done(item: item)
                        }
                        else if case TaskExecutionError.invalidContact(message: _) = error {
                            DDLogWarn("\(item.taskDefinition) \(error)")
                            self.done(item: item)
                        }
                        else if let task = item.taskDefinition as? TaskDefinitionReceiveReflectedMessage {
                            DDLogNotice("\(item.taskDefinition) discard reflected message: \(error)")

                            try? self.frameworkInjector.nonceGuard.processed(reflectedEnvelope: task.reflectedEnvelope)

                            if let reflectMessageError = self.frameworkInjector.serverConnector
                                .reflectMessage(
                                    self.frameworkInjector.mediatorMessageProtocol
                                        .encodeReflectedAck(reflectID: task.reflectID)
                                ) as? NSError {

                                guard ThreemaProtocolError.notLoggedIn.rawValue != reflectMessageError.code else {
                                    self.failed(item: item, error: reflectMessageError, enableSpoolingDelay: true)
                                    return
                                }

                                DDLogError(
                                    "\(item.taskDefinition) sending server ack of incoming reflected message failed: \(reflectMessageError)"
                                )
                            }

                            self.done(item: item)
                        }
                        else {
                            self.failed(item: item, error: error, enableSpoolingDelay: false)
                        }
                    }
            }
            else {
                DDLogNotice("Task queue (\(self.queueType.name())) task is still running")
            }
        }
    }
            
    func encode() -> Data? {
        guard !queue.list.isEmpty else {
            return nil
        }
        
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)

        do {
            // Encode type of each item
            let types: [String] = queue.list.map(\.taskDefinition.className)
            try archiver.encodeEncodable(types, forKey: "types")

            // Encode each task definition
            var i = 0
            queue.list.forEach { task in
                if task.taskDefinition.isPersistent {
                    try? archiver.encodeEncodable(task.taskDefinition, forKey: "\(task.taskDefinition.className)_\(i)")
                }

                i += 1
            }
        }
        catch {
            DDLogError("Encoding of tasks failed")
        }
        
        archiver.finishEncoding()
        return archiver.encodedData
    }
    
    func decode(_ data: Data) {
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)

            // Decode type of items
            if let types = try unarchiver.decodeTopLevelDecodable([String].self, forKey: "types") {
                
                // Decode task definition items
                var i = 0
                for className in types {
                    var taskDefinition: TaskDefinition?

                    do {
                        switch "\(className).Type" {
                        case String(describing: type(of: TaskDefinitionGroupDissolve.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionGroupDissolve.self,
                                forKey: "\(className)_\(i)"
                            )
                        case String(describing: type(of: TaskDefinitionSendAbstractMessage.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionSendAbstractMessage.self,
                                forKey: "\(className)_\(i)"
                            )
                        case String(describing: type(of: TaskDefinitionSendBallotVoteMessage.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionSendBallotVoteMessage.self,
                                forKey: "\(className)_\(i)"
                            )
                        case String(describing: type(of: TaskDefinitionSendBaseMessage.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionSendBaseMessage.self,
                                forKey: "\(className)_\(i)"
                            )
                        case String(describing: type(of: TaskDefinitionSendDeliveryReceiptsMessage.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionSendDeliveryReceiptsMessage.self,
                                forKey: "\(className)_\(i)"
                            )
                        case String(describing: type(of: TaskDefinitionSendLocationMessage.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionSendLocationMessage.self,
                                forKey: "\(className)_\(i)"
                            )
                        case String(describing: type(of: TaskDefinitionSendGroupCreateMessage.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionSendGroupCreateMessage.self,
                                forKey: "\(className)_\(i)"
                            )
                        case String(describing: type(of: TaskDefinitionSendGroupLeaveMessage.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionSendGroupLeaveMessage.self,
                                forKey: "\(className)_\(i)"
                            )
                        case String(describing: type(of: TaskDefinitionSendGroupRenameMessage.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionSendGroupRenameMessage.self,
                                forKey: "\(className)_\(i)"
                            )
                        case String(describing: type(of: TaskDefinitionSendGroupSetPhotoMessage.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionSendGroupSetPhotoMessage.self,
                                forKey: "\(className)_\(i)"
                            )
                        case String(describing: type(of: TaskDefinitionSendGroupDeletePhotoMessage.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionSendGroupDeletePhotoMessage.self,
                                forKey: "\(className)_\(i)"
                            )
                        case String(describing: type(of: TaskDefinitionSendGroupDeliveryReceiptsMessage.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionSendGroupDeliveryReceiptsMessage.self,
                                forKey: "\(className)_\(i)"
                            )
                        case String(describing: type(of: TaskDefinitionUpdateContactSync.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionUpdateContactSync.self,
                                forKey: "\(className)_\(i)"
                            )
                        case String(describing: type(of: TaskDefinitionDeleteContactSync.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionDeleteContactSync.self,
                                forKey: "\(className)_\(i)"
                            )
                        default:
                            DDLogError("Can't decode unknown task type \(className)")
                        }
                    }
                    catch {
                        DDLogError("Decoding of \(className) failed: \(error)")
                    }

                    i += 1

                    if let taskDefinition {
                        taskDefinition.state = .interrupted
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
        spoolingDelayQueue.sync {
            spoolingDelay = false
            spoolingDelayAttempts = 0
        }

        taskQueueQueue.sync {
            DDLogNotice("\(item.taskDefinition) done")

            guard item === queue.peek() else {
                DDLogError("\(item.taskDefinition) wrong spooling order")
                return
            }

            if item.taskDefinition.state != .pending {
                DDLogVerbose("\(item.taskDefinition) dequeue")
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
    private func failed(item: QueueItem, error: Error, enableSpoolingDelay: Bool) {
        var retry = false

        taskQueueQueue.sync {
            DDLogError("\(item.taskDefinition) failed \(error)")

            guard item === queue.peek() else {
                DDLogError("\(item.taskDefinition) wrong spooling order")
                return
            }

            spoolingDelayQueue.sync {
                spoolingDelay = enableSpoolingDelay
                if !enableSpoolingDelay {
                    spoolingDelayAttempts = 0
                }
            }

            if item.taskDefinition.state != .pending {
                item.taskDefinition.state = .pending

                if item.taskDefinition.retry, item.taskDefinition.retryCount < TaskQueue.retriesOfFailedTasks {
                    if case TaskExecutionError.reflectMessageTimeout(message: _) = error {
                        DDLogNotice("Retry of \(item.taskDefinition) after reflecting timeout")
                    }
                    else if case TaskExecutionError.sendMessageTimeout(message: _) = error {
                        DDLogNotice("Retry of \(item.taskDefinition) after sending timeout")
                    }
                    else {
                        DDLogNotice("Retry of \(item.taskDefinition) after execution failing")
                        item.taskDefinition.retryCount += 1
                    }
                    retry = true
                }
                else if queueType == .incoming, !spoolingDelay {
                    // Remove/chancel task processing of failed incoming message, try again with next server connection!
                    DDLogVerbose("\(item.taskDefinition) dequeue")
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

        if !retry, !spoolingDelay {
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
}
