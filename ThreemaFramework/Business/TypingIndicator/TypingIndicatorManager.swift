import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials

@objcMembers public final class TypingIndicatorManager: NSObject {
    // MARK: - Public properties

    public static let sharedInstance = TypingIndicatorManager()

    // MARK: - Private properties

    private let resetQueue = DispatchQueue(label: TypingIndicatorConfig.resetQueueLabel)
    private var resetTimer: DispatchSourceTimer?
    private var timerSuspended = false

    // MARK: - Lifecycle

    override public init() {
        super.init()
        setupResetTimer()
    }

    deinit {
        resetTimer?.cancel()
    }

    // MARK: - Public methods

    public func startObserving() {
        guard timerSuspended else {
            return
        }
        
        resetTypingIndicators()
        
        resetTimer?.resume()
        timerSuspended = false
        DDLogVerbose("Typing indicator observing started")
    }

    public func stopObserving() {
        guard !timerSuspended else {
            return
        }
        resetTimer?.suspend()
        timerSuspended = true
        DDLogVerbose("Typing indicator observing stopped")
    }

    public func resetTypingIndicators() {
        DispatchQueue.main.async {
            DDLogInfo("Started resetting the typing indicators for all conversations.")

            // Fetch all Conversations that are currently typing, and reset the typing
            // indicator if it was received too long ago
            let timeoutDate = Date(timeIntervalSinceNow: -TypingIndicatorConfig.timeoutInterval)

            let entityManager = BusinessInjector.ui.entityManager
            let entityFetcher = entityManager.entityFetcher

            entityManager.performAndWaitSave {
                let conversations = entityFetcher.typingConversationEntities(timeoutDate: timeoutDate)
                guard !conversations.isEmpty else {
                    DDLogInfo("No conversations eligible for resetting the typing indicator.")
                    return
                }
                conversations.forEach { $0.typing = NSNumber(value: false) }
                DDLogInfo("Typing indicator has been successfully reset for \(conversations.count) conversation(s).")
            }
        }
    }

    public func setTypingIndicator(for identity: String, typing: Bool) {
        DDLogInfo(
            "Started setting typing indicator `\(typing ? "ON" : "OFF")` for conversation with contact identity \(identity)."
        )

        guard identity.count == ThreemaIdentity.length else {
            DDLogError("Invalid contact identity: \(identity).")
            return
        }

        DispatchQueue.main.async {
            let entityFetcher = BusinessInjector.ui.entityManager.entityFetcher

            guard let conversation = entityFetcher.conversationEntity(for: identity) else {
                DDLogError("No conversation found with contact identity \(identity).")
                return
            }

            conversation.typing = NSNumber(value: typing)
            DDLogInfo("Typing indicator for conversation with contact identity \(identity) successfully set.")
        }
    }

    // MARK: - Private methods

    private func setupResetTimer() {

        // Prevent duplicate timers

        guard resetTimer == nil else {
            return
        }

        resetTimer = DispatchSource.makeTimerSource(queue: resetQueue)

        resetTimer?.schedule(
            wallDeadline: .now() + TypingIndicatorConfig.resetCheckInterval,
            repeating: TypingIndicatorConfig.resetCheckInterval
        )

        resetTimer?.setEventHandler { [weak self] in
            self?.resetTypingIndicators()
        }
        resetTimer?.resume()
    }
}
