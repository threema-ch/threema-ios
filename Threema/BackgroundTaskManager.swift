//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

import Foundation

@objc class BackgroundTaskManager: NSObject {
    
    @objc static let shared = BackgroundTaskManager()
    
    private var backgroundTasks: [String: UIBackgroundTaskIdentifier]
    private var backgroundTaskIdentifierCounter = AtomicInteger()
    private var backgroundTaskQueue:DispatchQueue
    
    private override init() {
        backgroundTasks = [String: UIBackgroundTaskIdentifier]()
        backgroundTaskQueue = DispatchQueue(label: "ch.threema.backgroundTaskQueue", attributes: [])
    }
    
    // MARK: Public functions
    
    // Create a new background task. The completion handler is called on the main thread.
    @objc func newBackgroundTask(key: String, timeout: Int, completionHandler: (() -> Void)?) {        
        backgroundTaskQueue.async {
            // remove already existing background task first
            if let foundBackgroundTask = self.backgroundTasks[key] {
                self.cancelBackgroundTaskWithoutDisconnect(identifier: foundBackgroundTask, key: key)
            }
            var bgTask: UIBackgroundTaskIdentifier? = nil
            bgTask = UIApplication.shared.beginBackgroundTask(withName: key, expirationHandler: {
                self.backgroundTaskQueue.async {
                    let identifier: UIBackgroundTaskIdentifier? = self.backgroundTasks[key]
                    if identifier != nil {
                        self.backgroundTasks.removeValue(forKey: key)
                    }
                    self.disconnectFromServer(completionHandler: {
                        PendingMessagesManager.shared.save()
                        if identifier != nil {
                            UIApplication.shared.endBackgroundTask(identifier!)
                        }
                    })
                }
            })
            self.backgroundTasks.updateValue(bgTask!, forKey: key)
            
            self.backgroundTaskQueue.asyncAfter(deadline: .now() + Double(timeout)) {
                let identifier: UIBackgroundTaskIdentifier? = self.backgroundTasks[key]
                if identifier != nil {
                    self.backgroundTasks.removeValue(forKey: key)
                    self.disconnectFromServer(completionHandler: {
                        PendingMessagesManager.shared.save()
                        if identifier != nil {
                            UIApplication.shared.endBackgroundTask(identifier!)
                        }
                    })
                }
            }
            
            if completionHandler != nil {
                DispatchQueue.main.async {
                    completionHandler!();
                }
            }
        }
    }
    
    @objc func cancelBackgroundTask(key: String) {
        backgroundTaskQueue.async {
            if let identifier: UIBackgroundTaskIdentifier = self.backgroundTasks[key] {
                self.backgroundTasks.removeValue(forKey: key)
                self.disconnectFromServer(completionHandler: {
                    UIApplication.shared.endBackgroundTask(identifier)
                })
            } else {
                self.disconnectFromServer(completionHandler: nil)
            }
        }
    }
    
    @objc func counter(identifier: String) -> String {
        return identifier + String(backgroundTaskIdentifierCounter.incrementAndGet())
    }
    
    private func cancelBackgroundTaskWithoutDisconnect(identifier: UIBackgroundTaskIdentifier, key: String) {
        self.backgroundTasks.removeValue(forKey: key)
        UIApplication.shared.endBackgroundTask(identifier)
    }
    
    private func disconnectFromServer(completionHandler: (() -> Void)?) {
        if self.backgroundTasks.count != 0 || VoIPCallStateManager.shared.currentCallState() != .idle {
            if completionHandler != nil {
                completionHandler!()
            }
            return
        }
        DispatchQueue.main.async {
            if AppDelegate.shared().isAppInBackground() {
                ValidationLogger.shared()?.logString("Background Task: There is no running background task")
                if WCSessionManager.shared.isRunningWCSession() == true {                    
                    ValidationLogger.shared()?.logString("Threema Web: Disconnect webclient disconnectFromServer")
                    WCSessionManager.shared.pauseAllRunningSessions()
                }
                ServerConnector.shared().disconnectWait()
                MessageQueue.shared().save()
                PendingMessagesManager.shared.save()
            }
            if completionHandler != nil {
                self.backgroundTaskQueue.async {
                    completionHandler!()
                    return
                }
            }
        }
    }
}

public final class AtomicInteger {
    
    private let lock = DispatchSemaphore(value: 1)
    private var _value: Int
    
    public init(value initialValue: Int = 0) {
        _value = initialValue
    }
    
    public var value: Int {
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
    
    public func decrementAndGet() -> Int {
        lock.wait()
        defer { lock.signal() }
        _value -= 1
        return _value
    }
    
    public func incrementAndGet() -> Int {
        lock.wait()
        defer { lock.signal() }
        _value += 1
        return _value
    }
}
