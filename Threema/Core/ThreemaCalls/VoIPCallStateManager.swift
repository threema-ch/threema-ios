import CallKit
import CocoaLumberjackSwift
import Collections
import Foundation
import ThreemaFramework
import ThreemaMacros
import UIKit
import UserNotifications

final class VoIPCallStateManager: NSObject {

    @objc static let shared = VoIPCallStateManager()

    private let callKitManager: VoIPCallKitManager

    /// Contains `VoIPCallMessage` and `VoIPCallUserAction`
    private var callQueue = Deque<VoIPCallIDProtocol>()
    private let callQueueQueue = DispatchQueue(label: "ch.threema.VoIPCallStateManager.callQueueQueue")
    private let callServiceQueue = DispatchQueue(label: "ch.threema.VoIPCallStateManager.callServiceQueue")

    private let endedDelay = 5.0

    private var callService: VoIPCallService? {
        didSet {
            if let callService {
                DDLogNotice("[Call:1to1:StateManager] [cid=\(callService.callID)]: Created new call service")
            }
            else if let oldValue {
                DDLogNotice("[Call:1to1:StateManager] [cid=\(oldValue.callID)]: Removed call service")
            }
        }
    }

    var onCallFinished: (() -> Void)?
    var onCallAnswered: ((String) -> Void)?
    var onCallConnected: (() -> Void)?
    var onCallViewHidden: (() -> Void)?

    /// Provides the view controller to present the 1-1 call view on (the new coordinator flow's
    /// `CallWindow` root). `nil` (legacy flow) falls back to the key window's root.
    var callViewPresenterProvider: (() -> UIViewController?)?

    // MARK: - Lifecycle

    override required init() {
        self.callKitManager = VoIPCallKitManager()
        super.init()
    }

    // MARK: - Public functions

    /// Get the current state of a call
    /// - Returns: CallState
    @objc func currentCallState() -> CallState {
        callService?.currentState() ?? .idle
    }

    func isCallServiceInitialized() -> Bool {
        callServiceQueue.sync {
            callService != nil
        }
    }

    /// Present the CallViewController
    func presentCallViewController() {
        callService?.presentCallViewController()
    }

    // MARK: - Local user actions

    /// Add a user action to the process queue
    /// - parameter action: VoIPCallUserAction
    func addActionToCallQueue(_ action: VoIPCallUserAction) {
        addElementToCallQueue(action)
    }
    
    // MARK: - Local call start
    
    /// Starts a 1:1 with the given identity. Assumes callee supports 1:1 calls.
    /// - Parameters:
    ///   - callee: Identity of the callee
    ///   - onCompletion: Completion handler
    func startCall(callee: String, onCompletion: (() -> Void)? = nil) {
        let callID = VoIPCallID.generate()
        let action = VoIPCallUserAction(
            action: .call,
            contactIdentity: callee,
            callID: callID,
            completion: onCompletion
        )
        DDLogNotice(
            "[Call:1to1:StateManager] [cid=\(callID)]: Handle new call with \(callee), we are the caller"
        )
        
        DDLogNotice(
            "[Call:1to1:StateManager] [cid=\(callID)]: Enqueuing start call action"
        )
        
        addElementToCallQueue(action)
    }

    // MARK: - Call message handling

    /// Add a incoming call offer to the process queue
    /// - parameter offer: VoIPCallOfferMessage
    /// - parameter identity: Identity from the offer
    /// - parameter completion: Completion block
    func incomingCallOffer(offer: VoIPCallOfferMessage, identity: String, completion: (() -> Void)?) {
        DDLogNotice(
            "[Call:1to1:StateManager] [cid=\(offer.callID)]: Handle new call with \(identity), we are the callee"
        )

        DDLogNotice(
            "[Call:1to1:StateManager] [cid=\(offer.callID)]: Call offer received from \(identity)"
        )

        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPIncomCallBackgroundTask,
            timeout: Int(kAppVoIPIncomingCallBackgroundTaskTime)
        ) {
            offer.completion = completion
            offer.contactIdentity = identity
            DDLogNotice("[Call:1to1:StateManager] [cid=\(offer.callID)]: Enqueuing call offer message")
            self.addElementToCallQueue(offer)
        }
    }

    /// Add a incoming call answer to the process queue
    /// - parameter answer: VoIPCallAnswerMessage
    /// - parameter identity: Identity from the answer
    /// - parameter completion: Completion block
    func incomingCallAnswer(
        answer: VoIPCallAnswerMessage,
        identity: String,
        completion: @escaping () -> Void
    ) {
        DDLogNotice(
            "[Call:1to1:StateManager] [cid=\(answer.callID)]: Call answer received from \(identity): \(answer.description())"
        )

        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppPushBackgroundTaskTime)
        ) {
            answer.completion = completion
            answer.contactIdentity = identity
            DDLogNotice("[Call:1to1:StateManager] [cid=\(answer.callID)]: Enqueuing call answer message")
            self.addElementToCallQueue(answer)
        }
    }

    /// Add a incoming ringing message to the process queue
    /// - parameter ringing: VoIPCallRingingMessage
    func incomingCallRinging(ringing: VoIPCallRingingMessage) {
        DDLogNotice(
            "[Call:1to1:StateManager] [cid=\(ringing.callID)]: Call ringing message received from \(ringing.contactIdentity ?? "?")"
        )

        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppPushBackgroundTaskTime)
        ) {
            DDLogNotice("[Call:1to1:StateManager] [cid=\(ringing.callID)]: Enqueuing call ringing message")
            self.addElementToCallQueue(ringing)
        }
    }

    /// Add a incoming ice candidates message to the process queue
    /// - parameter candidates: VoIPCallIceCandidatesMessage
    /// - parameter identity: Identity from the ice candidates
    /// - parameter completion: Completion block
    func incomingIceCandidates(
        candidates: VoIPCallIceCandidatesMessage,
        identity: String,
        completion: (() -> Void)?
    ) {
        DDLogNotice(
            "[Call:1to1:StateManager] [cid=\(candidates.callID)]: Call ICE candidate message received from \(identity) (\(candidates.candidates.count) candidates)"
        )

        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppPushBackgroundTaskTime)
        ) {
            candidates.completion = completion
            candidates.contactIdentity = identity
            DDLogNotice("[Call:1to1:StateManager] [cid=\(candidates.callID)]: Enqueuing ICE candidate message")
            self.addElementToCallQueue(candidates)
        }
    }

    /// Add a incoming hangup message to the process queue
    /// - parameter hangup: VoIPCallHangupMessage
    func incomingCallHangup(hangup: VoIPCallHangupMessage) {
        DDLogNotice(
            "[Call:1to1:StateManager] [cid=\(hangup.callID)]: Call hangup message received from \(hangup.contactIdentity ?? "?")"
        )

        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppPushBackgroundTaskTime)
        ) {
            DDLogNotice("[Call:1to1:StateManager] [cid=\(hangup.callID)]: Enqueuing hangup message")
            self.addElementToCallQueue(hangup)
        }
    }

    // MARK: - CallKit

    /// Incoming from background
    /// - Parameters:
    ///   - callID: Unique call ID
    ///   - callPartnerIdentity: Caller identity
    ///   - callPartnerName: Caller name
    ///   - ringtoneSound: Filename of ringtone to be used
    ///   - fromPush: Whether we report from the NSE
    ///   - completion: Completion handler returns a task to update call
    func newIncomingCallFromBackground(
        with callID: VoIPCallID,
        callPartnerIdentity: String,
        callPartnerName: String?,
        ringtoneSound: String,
        fromPush: Bool = false,
        completion: @escaping (@escaping () -> Void) -> Void
    ) {
        callKitManager.reportIncomingCall(
            with: callID,
            callPartnerIdentity: callPartnerIdentity,
            callPartnerName: callPartnerName,
            ringtoneSound: ringtoneSound,
            fromPush: fromPush
        ) { _ in
            // Task to update call when business is ready
            let task: (() -> Void) = {
                Task { @MainActor in
                    PersistenceManager(
                        appGroupID: AppGroup.groupID(),
                        userDefaults: AppGroup.userDefaults(),
                        remoteSecretManager: RemoteSecretProvider.remoteSecretManager
                    ).dirtyObjectManager.refreshDirtyObjects(reset: true)

                    if ServerConnector.shared().connectionState == .disconnected {
                        ServerConnector.shared().isAppInBackground = SceneDelegate.isAppInBackground
                        ServerConnector.shared().connectWait(initiator: .threemaCall)
                    }

                    self.callServiceQueue.async {
                        // If another call already running (1-to-1 or group), reject call
                        if let callService = self.callService, callService.callID.callID != callID.callID
                            || NavigationBarPromptHandler.isGroupCallActive {
                            self.callKitManager.endCall(with: callID)
                            
                            // We are in a different call already. Other devices might be able to pickup, so we do not
                            // send the reject.
                            let action = VoIPCallUserAction(
                                action: .reject(sendMessage: false),
                                contactIdentity: callPartnerIdentity,
                                callID: callID,
                                completion: { }
                            )

                            BackgroundTaskManager.shared.newBackgroundTask(
                                key: kAppVoIPBackgroundTask,
                                timeout: Int(kAppPushBackgroundTaskTime)
                            ) {
                                DDLogNotice(
                                    "[Call:1to1:StateManager] [cid=\(callID)]: Another call is active. Enqueuing reject message"
                                )
                                self.addElementToCallQueue(action)
                            }
                        }
                    }
                }
            }

            completion(task)
        }
    }

    /// Start and cancel call (for deprecated/invalid VoIP pushes) over CallKit, because for any VoIP received,
    /// `CXProvider.reportNewIncomingCall` must be called
    func startAndCancelCall(from localizedName: String, completion: @escaping () -> Void) {
        callKitManager.startAndCancelCall(from: localizedName, completion: completion)
    }

    // MARK: - State machine management

    /// Add a message to the process queue and start process
    /// - parameter element: `VoIPCallUserAction` or `VoIPCallMessageProtocol`
    private func addElementToCallQueue(_ element: VoIPCallIDProtocol) {

        guard element is VoIPCallUserAction || element is VoIPCallMessageProtocol else {
            DDLogError(
                "[Call:StateManager] Tried to add element that is not VoIPCallUserAction or VoIPCallMessageProtocol to callQueue: \(element)"
            )
            assertionFailure()
            return
        }

        let callQueueCount = callQueueQueue.sync {
            callQueue.append(element)
            return callQueue.count
        }
        if callQueueCount == 1 {
            processNextElementInCallQueue()
        }
    }

    private func processNextElementInCallQueue() {
        let element = callQueueQueue.sync {
            callQueue.popFirst()
        }
        
        guard let element,
              let contactIdentity = element.contactIdentity
        else {
            return
        }
        
        callServiceQueue.async {
            if self.callService == nil {
                DDLogNotice("[Call:1to1:StateManager] [cid=\(element.callID)]: Initialize VoIPCallService")
                self.callService = VoIPCallService(
                    callPartnerIdentity: contactIdentity,
                    callID: element.callID,
                    delegate: self,
                    callKitManager: self.callKitManager
                )
            }
            self.callService?.processCallQueueElement(element)
        }
    }

    private func resetCallService() {
        callServiceQueue.async {
            self.callService = nil
        }
    }

    /// Release the connection that was claimed for the call
    ///
    /// Delayed, because after a disconnect no further (VoIP) messages of this call are processed. A new call claims
    /// the connection before its state leaves `idle` (it waits for the connection first), thus the service and not
    /// the state decides whether the claim is still needed.
    private func releaseConnectionAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + endedDelay) { [weak self] in
            guard let self, callService == nil else {
                return
            }

            ServerConnector.shared().disconnect(initiator: .threemaCall)
        }
    }
}

// MARK: - VoIPCallServiceDelegate

extension VoIPCallStateManager: VoIPCallServiceDelegate {
    func prependCallQueueElement(_ element: VoIPCallIDProtocol) {
        callQueueQueue.sync {
            callQueue.prepend(element)
        }
    }

    func finishedProcessingCallQueueElement() {
        processNextElementInCallQueue()
    }

    func callFinished() {
        DDLogNotice("[Call:StateManager] Call finished, resetting service")
        // `onCallFinished` drives UI (`CallCoordinator.finish`), must run on main.
        // Must be async: callers may originate from the main thread via
        // LocalNetworkPermissionChecker → WebRTC, so DispatchQueue.main.sync would deadlock.
        DispatchQueue.main.async {
            self.onCallFinished?()
        }
        resetCallService()
        releaseConnectionAfterDelay()
        processNextElementInCallQueue()
    }

    func callReadyForPresentation(callPartnerIdentity: String) {
        // Invoked from the WebRTC signaling thread (SetRemoteDescription completion). `onCallAnswered`
        // builds the call UI (`CallWindow`/`UIWindow`), which must run on main — else NSInternalInconsistency.
        // Must be async: the call chain originates on the main thread (LocalNetworkPermissionChecker
        // dispatches its completion to DispatchQueue.main), so DispatchQueue.main.sync would deadlock.
        DispatchQueue.main.async {
            self.onCallAnswered?(callPartnerIdentity)
        }
    }

    func callDidConnect() {
        // `onCallConnected` drives UI (call activity), must run on main.
        // Must be async: callers may originate from the main thread via
        // LocalNetworkPermissionChecker → WebRTC, so DispatchQueue.main.sync would deadlock.
        DispatchQueue.main.async {
            self.onCallConnected?()
        }
    }

    func callViewPresentingViewController() -> UIViewController? {
        MainActor.assumeIsolated {
            self.callViewPresenterProvider?()
        }
    }
}
