import CocoaLumberjackSwift
import Foundation
import ThreemaFramework

final class BackgroundTaskManager {
    
    static let shared = BackgroundTaskManager()
    
    private var backgroundTasks: [String: UIBackgroundTaskIdentifier]
    private var backgroundTaskIdentifierCounter = AtomicInteger()
    private var backgroundTaskQueue: DispatchQueue
    
    private init() {
        self.backgroundTasks = [String: UIBackgroundTaskIdentifier]()
        self.backgroundTaskQueue = DispatchQueue(label: "ch.threema.backgroundTaskQueue", attributes: [])
    }
    
    // MARK: Public functions
    
    /// Create a new (or renew if exists already) background task. The completion handler is called on the main thread.
    func newBackgroundTask(key: String, timeout: Int, completionHandler: (() -> Void)?) {
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
    
    func cancelBackgroundTask(key: String) {
        DDLogVerbose("Background task cancel \(key)")
        backgroundTaskQueue.async {
            if let item = self.backgroundTasks.first(where: { $0.key.hasPrefix(key) }) {
                self.endBackgroundTaskWithDisconnect(item.key)
            }
        }
    }

    /// Extents key with postffix count.
    func counter(identifier: String) -> String {
        identifier + String(backgroundTaskIdentifierCounter.incrementAndGet())
    }
    
    func isBackgroundTaskRunning(key: String) -> Bool {
        backgroundTasks.first(where: { $0.key.hasPrefix(key) }) != nil
    }
    
    // MARK: Private functions
    
    private func endBackgroundTaskWithDisconnect(_ internalKey: String) {
        guard let identifier: UIBackgroundTaskIdentifier = backgroundTasks[internalKey] else {
            return
        }
        
        if internalKey.hasPrefix(kAppPushReplyBackgroundTask) {
            // The reply is done, so is its claim. Also in the foreground, where the socket is kept by `.app`,
            // otherwise a reply handled there keeps the claim for the rest of the process lifetime
            ServerConnector.shared().disconnect(initiator: .notificationHandler)
        }
        else if SceneDelegate.isAppInBackground {
            if internalKey.hasPrefix(kAppClosedByUserBackgroundTask) {
                tearDownConnectionForSuspension()
            }
            else if internalKey.hasPrefix(kAppVoIPBackgroundTask) ||
                internalKey.hasPrefix(kAppVoIPIncomCallBackgroundTask) {
                // Do not disconnect if we are still in an active call
                if !VoIPCallStateManager.shared.currentCallState().active {
                    ServerConnector.shared().disconnect(initiator: .threemaCall)
                }
            }
        }

        endBackgroundTask(identifier: identifier, internalKey: internalKey)
    }

    /// Close everything down before the system suspends us.
    ///
    /// Last point with execution time, so every claim has to go, otherwise we are suspended with an open socket and
    /// end up with "Another connection". `.app` is released last, it triggers the actual disconnect.
    private func tearDownConnectionForSuspension() {
        // Sessions are resumed on the next foreground, the claim goes in any case
        if WCSessionManager.shared.isRunningWCSession() {
            DDLogNotice("Close WebClient and server connection")
            WCSessionManager.shared.pauseAllRunningSessions()
        }
        ServerConnector.shared().disconnect(initiator: .threemaWeb)

        // Safety net, a reply in flight releases the claim itself when its own task ends
        if !isBackgroundTaskRunning(key: kAppPushReplyBackgroundTask) {
            ServerConnector.shared().disconnect(initiator: .notificationHandler)
        }

        ServerConnector.shared().disconnect(initiator: .app)

        // Hand over to the extensions. Not before, without IPC this flag also gates incoming message processing
        if !UserSettings.shared().ipcCommunicationEnabled {
            AppGroup.setActive(false, for: AppGroupTypeApp)
        }
    }

    private func endBackgroundTask(identifier: UIBackgroundTaskIdentifier, internalKey: String) {
        backgroundTasks.removeValue(forKey: internalKey)

        // Ending the last background task allows the system to suspend us right away. Get the log messages of the just
        // finished background work onto disk before that happens, otherwise they are lost and a write in flight during
        // suspension risks a `0xdead10cc` termination for holding a lock in the app group container.
        if backgroundTasks.isEmpty {
            LogManager.flushLogs()
        }

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
