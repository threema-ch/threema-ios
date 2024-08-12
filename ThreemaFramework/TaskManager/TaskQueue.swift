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
            .incoming
        }
        else {
            .outgoing
        }
    }

    public func name() -> String {
        switch self {
        case .incoming: "incoming"
        case .outgoing: "outgoing"
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

    private let frameworkInjectorResolver: FrameworkInjectorResolverProtocol

    private var frameworkInjector: FrameworkInjectorProtocol {
        frameworkInjectorResolver.backgroundFrameworkInjector
    }

    /// Task queue to handle tasks for processing incoming or outgoing messages.
    /// - Parameters:
    ///     - queueType: Set type for incoming or outgoing queue
    ///     - supportedTypes: Supported TaskDefinition types to this queue
    ///     - frameworkInjectorResolver: Resolver to get new `BusinessInjector` for background process
    required init(
        queueType: TaskQueueType,
        supportedTypes: [TaskDefinition.Type],
        frameworkInjectorResolver: FrameworkInjectorResolverProtocol
    ) {
        self.queueType = queueType
        self.supportedTypes = supportedTypes
        self.frameworkInjectorResolver = frameworkInjectorResolver
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
                
                let injector = self.frameworkInjectorResolver.backgroundFrameworkInjector

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
                        switch error {
                            
                        case MessageProcessorError.unknownMessageType(session: _):
                            self.handleReceivingError(error, for: item)
                            
                        case let nsError as NSError where nsError.code == ThreemaProtocolError.badMessage.rawValue ||
                            nsError.code == ThreemaProtocolError.blockUnknownContact.rawValue ||
                            nsError.code == ThreemaProtocolError.messageAlreadyProcessed.rawValue ||
                            nsError.code == ThreemaProtocolError.messageBlobDecryptionFailed.rawValue ||
                            nsError.code == ThreemaProtocolError.messageNonceReuse.rawValue ||
                            nsError.code == ThreemaProtocolError.messageSenderMismatch.rawValue ||
                            nsError.code == ThreemaProtocolError.messageToDeleteNotFound.rawValue ||
                            nsError.code == ThreemaProtocolError.messageToEditNotFound.rawValue ||
                            nsError.code == ThreemaProtocolError.unknownMessageType.rawValue:
                            
                            self.handleReceivingError(error, for: item)
                            
                        case MediatorReflectedProcessorError.doNotAckIncomingVoIPMessage:
                            DDLogWarn("\(item.taskDefinition) \(error)")
                            self.done(item: item)
                            
                        case TaskExecutionError.conversationNotFound(for: _):
                            DDLogError("\(item.taskDefinition) failed: \(error)")
                            self.done(item: item)
                            
                        case TaskExecutionError.createAbstractMessageFailed:
                            DDLogError("\(item.taskDefinition) outgoing message failed: \(error)")
                            self.done(item: item)
                            
                        case TaskExecutionError.messageReceiverBlockedOrUnknown:
                            DDLogError("\(item.taskDefinition) outgoing message failed: \(error)")
                            self.done(item: item)
                            
                        case TaskExecutionTransactionError.shouldSkip:
                            DDLogNotice("\(item.taskDefinition) skipped: \(error)")
                            self.done(item: item)
                            
                        case TaskExecutionError.invalidContact(message: _),
                             TaskExecutionError.multiDeviceNotSupported,
                             TaskExecutionError.multiDeviceNotRegistered: // You need to relink anyway
                            DDLogWarn("\(item.taskDefinition) \(error)")
                            self.done(item: item)
                        
                        default:
                            if let task = item.taskDefinition as? TaskDefinitionReceiveReflectedMessage {
                                DDLogNotice("\(item.taskDefinition) discard reflected message: \(error)")
                                
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
            for task in queue.list {
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
                        case String(describing: type(of: TaskDefinitionRunForwardSecurityRefreshSteps.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionRunForwardSecurityRefreshSteps.self,
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
                        case String(describing: type(of: TaskDefinitionSendDeleteEditMessage.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionSendDeleteEditMessage.self,
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
        let path = FileUtility.shared.appDataDirectory
        return path?.appendingPathComponent("\(queueType.name())Queue", isDirectory: false)
    }

    // MARK: Private functions
    
    /// Handle receiving error
    ///
    /// Moved into extra function for better error handling readability
    ///
    /// - Parameters:
    ///   - error: Error to handle
    ///   - item: Item that threw error
    private func handleReceivingError(_ error: Error, for item: QueueItem) {
        if let task = item.taskDefinition as? TaskDefinitionReceiveMessage {
            DDLogNotice("\(task) discard incoming message: \(error)")
            
            frameworkInjector.serverConnector.completedProcessingMessage(task.message)
            try? frameworkInjector.nonceGuard.processed(boxedMessage: task.message)
            
            // Persist ratcheted if erroring message was received in a FS session
            // However don't persist new versions if any were negotiated, as we were unable to send an empty message to
            // establish this new FS version.
            if case let MessageProcessorError.unknownMessageType(session: session) = error, let session {
                try? frameworkInjector.dhSessionStore.updateDHSessionRatchets(session: session, peer: true)
            }
        }
        else if let task = item.taskDefinition as? TaskDefinitionReceiveReflectedMessage {
            DDLogNotice("\(task) discard reflected message: \(error)")
            
            try? frameworkInjector.nonceGuard.processed(reflectedEnvelope: task.reflectedEnvelope)
            
            if let reflectMessageError = frameworkInjector.serverConnector.reflectMessage(
                frameworkInjector.mediatorMessageProtocol.encodeReflectedAck(reflectID: task.reflectID)
            ) as? NSError {
                guard ThreemaProtocolError.notLoggedIn.rawValue != reflectMessageError.code else {
                    failed(item: item, error: reflectMessageError, enableSpoolingDelay: true)
                    return
                }
                
                DDLogError("\(item.taskDefinition) done \(reflectMessageError)")
            }
        }
        else {
            DDLogError("\(item.taskDefinition) \(error)")
        }
        
        done(item: item)
    }

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
            FileUtility.shared.delete(at: queuePath)
            if let queueData = encode(),
               !FileUtility.shared.write(fileURL: queuePath, contents: queueData) {
                DDLogError("Could not save queue into file")
            }
        }
    }
}
