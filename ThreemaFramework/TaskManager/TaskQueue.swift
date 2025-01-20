//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

/// Queue to run tasks on
///
/// - Note: This should be internal to the task management system. `TaskManager` should provide the public interface.
///
/// # How does dropping work?
///
/// Gather around and let me explain... Tasks have 3 types: persistent, volatile & drop on disconnect (`TaskType`). If
/// the connection is lost all drop on disconnect tasks are marked as dropped (`TaskDefinition.isDropped`) and removed
/// form the queue, if they are not executing. Because we cannot actually stop executing tasks such task are just marked
/// as dropped (`TaskQueue.interrupt()`). We expect executing tasks to cooperatively check for dropping and throw a
/// `TaskExecutionError.taskDropped` if the task is marked as dropped (`TaskDefinition.checkDropping()` can be used for
/// that). If a task successfully completes we accept that and do nothing special. If a task fails with an error and is
/// not marked as done we will check for a dropping and handle it as such instead of a failure that might lead to a
/// retry.
final class TaskQueue {
    static let retriesOfFailedTasks = 1

    private var spoolingDelay = false
    private var spoolingDelayAttempts = 0
    private let spoolingDelayBaseInterval: Float = 2
    private let spoolingDelayMaxInterval: Float = 10
    private var isWaitingForSpooling = false

    class QueueItem {
        let taskDefinition: TaskDefinition
        let completionHandler: TaskCompletionHandler?

        init(taskDefinition: TaskDefinition, completionHandler: TaskCompletionHandler?) {
            self.taskDefinition = taskDefinition
            self.completionHandler = completionHandler
        }
    }

    private var queue = Queue<QueueItem>()
    private let taskQueueQueue = DispatchQueue(label: "ch.threema.TaskQueue.taskQueueQueue")
    private let taskScheduleQueue = DispatchQueue(label: "ch.threema.TaskQueue.taskScheduleQueue")
    private let spoolingDelayQueue = DispatchQueue(label: "ch.threema.TaskQueue.spoolingDelayQueue")

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
    ///     - frameworkInjectorResolver: Resolver to get new `BusinessInjector` for background process
    required init(frameworkInjectorResolver: FrameworkInjectorResolverProtocol) {
        self.frameworkInjectorResolver = frameworkInjectorResolver
    }

    func enqueue(task: TaskDefinition, completionHandler: TaskCompletionHandler?) throws {
        taskQueueQueue.sync {
            queue.enqueue(QueueItem(taskDefinition: task, completionHandler: completionHandler))
            if task.type == .persistent {
                save()
            }
        }
    }

    func interrupt() {
        var droppedItems = [TaskQueue.QueueItem]()
        
        taskQueueQueue.sync {
            
            var interruptedTask: TaskDefinition?
            
            if let item = queue.peek(), item.taskDefinition.state == .executing {
                item.taskDefinition.state = .interrupted
                interruptedTask = item.taskDefinition
                
                // A running (drop on disconnect) task is just marked as such because we cannot really stop it from
                // executing. It should cooperatively check if it was dropped and stop execution with a droppedTask
                // error. We also won't call the completion handler as this will be done in the drop handler or
                // done handler if it completes anyway.
                // This prevents that a new task is run on reconnect and this one is still running.
                // TODO: (IOS-4854) Unfortunately this doesn't seem to work correctly in all cases. See TODO below.
                // Compared to desktop we don't have an error on the connection if we reconnect, because the connection
                // & connection state are a singleton. This makes races after a fast reconnect way more likely if we
                // would remove the task immediately from the queue.
                if item.taskDefinition.type == .dropOnDisconnect {
                    DDLogNotice("\(item.taskDefinition) interrupted and marked as dropped")
                    item.taskDefinition.isDropped = true
                }
            }

            // Remove all tasks with `TaskType.dropOnDisconnect` that are not the interrupted task from above
            // If we would filter all `interrupted` or "dropped" tasks we might not drop some tasks that weren't just
            // interrupted/dropped above and thus still `executing`
            // TODO: (IOS-4854) In some cases `$0.taskDefinition !== interruptedTask` doesn't seem to match the top task. Maybe we should add unique identifiers to tasks.
            droppedItems = queue.removeAll(where: {
                $0.taskDefinition.type == .dropOnDisconnect && $0.taskDefinition !== interruptedTask
            })
            
            // This is probably not needed, but just to be save we immediately mark them as dropped
            for droppedItem in droppedItems {
                droppedItem.taskDefinition.isDropped = true
            }
            
            save()
        }
        
        // Inform completion handler of dropped tasks
        for droppedItem in droppedItems {
            DDLogNotice("\(droppedItem.taskDefinition) dropped on disconnect")
            droppedItem.completionHandler?(droppedItem.taskDefinition, TaskExecutionError.taskDropped)
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
            if let item = queue.dequeue(), item.taskDefinition.type == .persistent {
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
        
        var item: QueueItem?
        let shouldExecute = taskQueueQueue.sync {
            item = queue.peek()
            
            guard let item else {
                DDLogNotice("Task queue is empty")
                return false
            }
            
            guard item.taskDefinition.state == .pending || item.taskDefinition.state == .interrupted else {
                DDLogNotice("\(item.taskDefinition) is still running")
                return false
            }
            
            guard !item.taskDefinition.isDropped else {
                DDLogNotice("\(item.taskDefinition) state '\(item.taskDefinition.state)' was dropped. Don't execute")
                // For now we assume that only a drop on disconnect task can be dropped and if one is marked as
                // "dropped" & "interrupted" at the same time (but still in the queue) it is still executing. Thus it
                // will either complete or fail with an error where the the dropping handling happens.
                assert(item.taskDefinition.type == .dropOnDisconnect)
                if item.taskDefinition.state != .interrupted {
                    DDLogError(
                        "This should never happen as dropped tasks are immediately removed from the queue if the are not interrupted"
                    )
                    assertionFailure()
                }
                return false
            }
            
            DDLogNotice("\(item.taskDefinition) state '\(item.taskDefinition.state)' execute")
            
            // Update to state should always happen on the `taskQueueQueue` otherwise we can have a race
            item.taskDefinition.state = .executing
            
            return true
        }
        
        guard shouldExecute else {
            return
        }
        
        taskScheduleQueue.async {
            guard let item else {
                DDLogNotice("Task queue is empty")
                return
            }
            
            let injector = self.frameworkInjectorResolver.backgroundFrameworkInjector
            
            item.taskDefinition.create(frameworkInjector: injector).execute()
                .done {
                    self.done(item: item)
                }
                .catch(on: .global()) { error in
                    // Note: Setting a breakpoint on the next line might not actually stop when an error is caught
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
                        
                    case TaskExecutionError.invalidContact(message: _),
                         TaskExecutionError.multiDeviceNotSupported,
                         TaskExecutionError.multiDeviceNotRegistered: // You need to relink anyway
                        DDLogWarn("\(item.taskDefinition) \(error)")
                        self.done(item: item)
                        
                    case TaskExecutionError.taskDropped:
                        DDLogNotice("\(item.taskDefinition) reported dropped error")
                        self.dropped(item: item)
                        
                    case let nsError as NSError where nsError.code == ThreemaProtocolError.notLoggedIn.rawValue:
                        self.failed(item: item, error: nsError, enableSpoolingDelay: true)

                    default:
                        self.failed(item: item, error: error, enableSpoolingDelay: false)
                    }
                }
        }
    }
            
    func encode() -> Data? {
        guard !queue.list.isEmpty else {
            return nil
        }
        
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)

        do {
            // Encode each task definition if they should be persisted and are not dropped
            // (for now no persistent dropped tasks should exist)
            var types = [String]()
            var i = 0
            for task in queue.list {
                if task.taskDefinition.type == .persistent, !task.taskDefinition.isDropped {
                    let type = task.taskDefinition.className

                    try? archiver.encodeEncodable(task.taskDefinition, forKey: "\(type)_\(i)")

                    types.append(type)

                    i += 1
                }
            }

            // Encode type of each item
            try archiver.encodeEncodable(types, forKey: "types")
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
                        case String(describing: type(of: TaskDefinitionSendDeleteEditMessage.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionSendDeleteEditMessage.self,
                                forKey: "\(className)_\(i)"
                            )
                        case String(describing: type(of: TaskDefinitionSendReactionMessage.self)):
                            taskDefinition = try unarchiver.decodeTopLevelDecodable(
                                TaskDefinitionSendReactionMessage.self,
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
        return path?.appendingPathComponent("taskQueue", isDirectory: false)
    }

    // MARK: - Private functions
    
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
            // Most of the time a task that is marked dropped should not successfully complete. However this can happen
            // in the following cases if a task is marked as dropped during execution:
            // 1. The task never checks if it is dropped. Dropping is a cooperative action during execution
            // 2. The task already run so close to completion that dropping doesn't make sense anymore
            // 3. The task completed with an error, but the error handling leads to the task being marked as done
            DDLogNotice("\(item.taskDefinition) done\(item.taskDefinition.isDropped ? " (marked dropped)" : "")")

            guard item === queue.peek() else {
                DDLogError(
                    "\(item.taskDefinition) not in front of task queue but \(queue.peek()?.taskDefinition ?? "none")"
                )
                return
            }

            if item.taskDefinition.state != .pending {
                DDLogVerbose("\(item.taskDefinition) removed from queue")
                _ = queue.dequeue()
                if item.taskDefinition.type == .persistent {
                    save()
                }
            }

            if queue.list.isEmpty {
                self.frameworkInjector.serverConnector.taskQueueEmpty()
            }
        }

        item.completionHandler?(item.taskDefinition, nil)
        spool()
    }
    
    /// Processing of queue item that was dropped
    ///
    /// - Note: Only dropping of drop on disconnect tasks is supported
    ///
    /// - Parameter item: Dropped queue item
    private func dropped(item: QueueItem) {
        assert(
            item.taskDefinition.type == .dropOnDisconnect,
            "Dropping is only supported for dropped on disconnect tasks"
        )
        
        if !item.taskDefinition.isDropped {
            DDLogError("\(item.taskDefinition) dropped but not marked as such. This should only happen in tests")
        }
        
        spoolingDelayQueue.sync {
            spoolingDelay = false
            spoolingDelayAttempts = 0
        }
        
        taskQueueQueue.sync {
            DDLogNotice("\(item.taskDefinition) dropped")
            
            guard item === queue.peek() else {
                DDLogError(
                    "\(item.taskDefinition) not in front of task queue but \(queue.peek()?.taskDefinition ?? "none")"
                )
                return
            }
            
            DDLogVerbose("\(item.taskDefinition) removed from queue")
            _ = queue.dequeue()
            if item.taskDefinition.type == .persistent {
                save()
            }
            
            if queue.list.isEmpty {
                self.frameworkInjector.serverConnector.taskQueueEmpty()
            }
        }
        
        item.completionHandler?(item.taskDefinition, TaskExecutionError.taskDropped)
        spool()
    }
    
    /// Processing queue item is failed. Drop, retry or dequeue it
    /// - Parameter item: Queue item
    /// - Parameter error: Task failed with error
    private func failed(item: QueueItem, error: Error, enableSpoolingDelay: Bool) {
        guard !item.taskDefinition.isDropped else {
            DDLogNotice("\(item.taskDefinition) failed and marked as dropped")
            dropped(item: item)
            return
        }
        
        var retry = false
        var dequeued = false

        taskQueueQueue.sync {
            DDLogError("\(item.taskDefinition) failed \(error)")

            guard item === queue.peek() else {
                DDLogError(
                    "\(item.taskDefinition) not in front of task queue but \(queue.peek()?.taskDefinition ?? "none")"
                )
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
                else if item.taskDefinition is TaskDefinitionReceiveMessage ||
                    item.taskDefinition is TaskDefinitionReceiveReflectedMessage ||
                    item.taskDefinition is TaskDefinitionNewDeviceSync,
                    !spoolingDelay {

                    // Remove/chancel task processing of failed incoming message, try again with next server connection!
                    DDLogVerbose("\(item.taskDefinition) removed from queue")
                    _ = queue.dequeue()
                    
                    dequeued = true
                }

                if item.taskDefinition.type == .persistent {
                    save()
                }
            }

            if queue.list.isEmpty {
                self.frameworkInjector.serverConnector.taskQueueEmpty()
            }
        }

        if !retry, !spoolingDelay {
            if !dequeued {
                DDLogWarn(
                    "\(item.taskDefinition) This should never be reached expect for tests, because these task are not removed they will block the queue and/or the completion handler will be called multiple times"
                )
            }
            // TODO: (IOS-4854) This contributes to the fact that sometimes the completion handler is called multiple times, because not all of these tasks are actually dequeued
            item.completionHandler?(item.taskDefinition, error)
        }

        if item.taskDefinition is TaskDefinitionReceiveMessage ||
            item.taskDefinition is TaskDefinitionReceiveReflectedMessage ||
            retry {
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
