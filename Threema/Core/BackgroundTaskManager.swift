//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2024 Threema GmbH
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

@objc class BackgroundTaskManager: NSObject {
    
    @objc static let shared = BackgroundTaskManager()
    
    private var backgroundTasks: [String: UIBackgroundTaskIdentifier]
    private var backgroundTaskIdentifierCounter = AtomicInteger()
    private var backgroundTaskQueue: DispatchQueue
    
    override private init() {
        self.backgroundTasks = [String: UIBackgroundTaskIdentifier]()
        self.backgroundTaskQueue = DispatchQueue(label: "ch.threema.backgroundTaskQueue", attributes: [])
    }
    
    // MARK: Public functions
    
    /// Create a new (or renew if exists already) background task. The completion handler is called on the main thread.
    @objc func newBackgroundTask(key: String, timeout: Int, completionHandler: (() -> Void)?) {
        DDLogVerbose("Background task new \(key) with timeout of \(timeout) seconds")
        backgroundTaskQueue.async {
            // Remove already existing background task first
            if let item = self.backgroundTasks.first(where: { $0.key.hasPrefix(key) }) {
                self.endBackgroundTask(identifier: item.value, internalKey: item.key)
            }

            // Creates internal key (unique), to prevent execution of old time out routine for renewed background task
            let internalKey = self.counter(identifier: key)

            // New background task
            var bgTask: UIBackgroundTaskIdentifier?
            bgTask = UIApplication.shared.beginBackgroundTask(withName: internalKey, expirationHandler: {
                
                self.backgroundTaskQueue.async {
                    self.endBackgroundTaskWithDisconnect(internalKey)
                }
            })
            self.backgroundTasks.updateValue(bgTask!, forKey: internalKey)
            
            // Initialize time out routine for background task
            self.backgroundTaskQueue.asyncAfter(deadline: .now() + Double(timeout)) {
                self.endBackgroundTaskWithDisconnect(internalKey)
            }
            
            DispatchQueue.main.async {
                completionHandler?()
            }
        }
    }
    
    @objc func cancelBackgroundTask(key: String) {
        DDLogVerbose("Background task cancel \(key)")
        backgroundTaskQueue.async {
            if let item = self.backgroundTasks.first(where: { $0.key.hasPrefix(key) }) {
                self.endBackgroundTaskWithDisconnect(item.key)
            }
        }
    }

    /// Extents key with postffix count.
    @objc func counter(identifier: String) -> String {
        identifier + String(backgroundTaskIdentifierCounter.incrementAndGet())
    }
    
    @objc func isBackgroundTaskRunning(key: String) -> Bool {
        backgroundTasks.first(where: { $0.key.hasPrefix(key) }) != nil
    }
    
    // MARK: Private functions
    
    private func endBackgroundTaskWithDisconnect(_ internalKey: String) {
        guard let identifier: UIBackgroundTaskIdentifier = backgroundTasks[internalKey] else {
            return
        }
        
        if AppDelegate.shared().isAppInBackground() {
            if internalKey.hasPrefix(kAppClosedByUserBackgroundTask) {
                ServerConnector.shared().disconnect(initiator: .app)
            }
            else if internalKey.hasPrefix(kAppVoIPBackgroundTask) {
                // Do not disconnect if we are still in an active call
                if !VoIPCallStateManager.shared.currentCallState().active {
                    ServerConnector.shared().disconnect(initiator: .threemaCall)
                }
            }
            else if internalKey.hasPrefix(kAppPushReplyBackgroundTask) {
                ServerConnector.shared().disconnect(initiator: .notificationHandler)
            }
            else if internalKey.hasPrefix(kAppWCBackgroundTask) {
                ServerConnector.shared().disconnect(initiator: .app)

                if WCSessionManager.shared.isRunningWCSession() {
                    DDLogVerbose("Close WebClient and Server connection")
                    WCSessionManager.shared.pauseAllRunningSessions()
                    ServerConnector.shared().disconnect(initiator: .threemaWeb)
                }
            }
        }

        endBackgroundTask(identifier: identifier, internalKey: internalKey)
    }

    private func endBackgroundTask(identifier: UIBackgroundTaskIdentifier, internalKey: String) {
        backgroundTasks.removeValue(forKey: internalKey)
        UIApplication.shared.endBackgroundTask(identifier)
    }
}

final class AtomicInteger {
    
    private let lock = DispatchSemaphore(value: 1)
    private var _value: Int
    
    init(value initialValue: Int = 0) {
        self._value = initialValue
    }
    
    var value: Int {
        get {
            lock.wait()
            defer { lock.signal() }
            return _value
        }
        set {
            lock.wait()
            defer { lock.signal() }
            _value = newValue
        }
    }
    
    func decrementAndGet() -> Int {
        lock.wait()
        defer { lock.signal() }
        _value -= 1
        return _value
    }
    
    func incrementAndGet() -> Int {
        lock.wait()
        defer { lock.signal() }
        _value += 1
        return _value
    }
}
