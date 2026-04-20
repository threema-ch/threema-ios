import CallKit
import CocoaLumberjackSwift
import Collections
import Foundation
import ThreemaFramework
import ThreemaMacros
import UserNotifications

@objc final class VoIPCallStateManager: NSObject {

    @objc static let shared = VoIPCallStateManager()

    private let callKitManager: VoIPCallKitManager

    /// Contains `VoIPCallMessage` and `VoIPCallUserAction`
    private var callQueue = Deque<VoIPCallIDProtocol>()
    private let callQueueQueue = DispatchQueue(label: "ch.threema.VoIPCallStateManager.callQueueQueue")
    private let callServiceQueue = DispatchQueue(label: "ch.threema.VoIPCallStateManager.callServiceQueue")

    private var callService: VoIPCallService? {
        didSet {
            if let callService {
                DDLogNotice("VoipCallService: [cid=\(callService.callID.callID)]: Created new call service")
            }
            else if let oldValue {
                DDLogNotice("VoipCallService: [cid=\(oldValue.callID.callID)]: Removed call service")
            }
        }
    }

    // MARK: - Lifecycle

    @objc override required init() {
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
    @objc func presentCallViewController() {
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
            "VoipCallService: [cid=\(callID.callID)]: Handle new call with \(callee), we are the caller"
        )
        
        DDLogNotice(
            "VoipCallService: [cid=\(callID.callID)]: Enqueuing start call action"
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
            "VoipCallService: [cid=\(offer.callID.callID)]: Handle new call with \(identity), we are the callee"
        )

        DDLogNotice(
            "VoipCallService: [cid=\(offer.callID.callID)]: Call offer received from \(identity)"
        )

        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPIncomCallBackgroundTask,
            timeout: Int(kAppVoIPIncomingCallBackgroundTaskTime)
        ) {
            offer.completion = completion
            offer.contactIdentity = identity
            DDLogNotice("VoipCallService: [cid=\(offer.callID.callID)]: Enqueuing call offer message")
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
            "VoipCallService: [cid=\(answer.callID.callID)]: Call answer received from \(identity): \(answer.description())"
        )

        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppPushBackgroundTaskTime)
        ) {
            answer.completion = completion
            answer.contactIdentity = identity
            DDLogNotice("VoipCallService: [cid=\(answer.callID.callID)]: Enqueuing call answer message")
            self.addElementToCallQueue(answer)
        }
    }

    /// Add a incoming ringing message to the process queue
    /// - parameter ringing: VoIPCallRingingMessage
    func incomingCallRinging(ringing: VoIPCallRingingMessage) {
        DDLogNotice(
            "VoipCallService: [cid=\(ringing.callID.callID)]: Call ringing message received from \(ringing.contactIdentity ?? "?")"
        )

        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppPushBackgroundTaskTime)
        ) {
            DDLogNotice("VoipCallService: [cid=\(ringing.callID.callID)]: Enqueuing call ringing message")
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
            "VoipCallService: [cid=\(candidates.callID.callID)]: Call ICE candidate message received from \(identity) (\(candidates.candidates.count) candidates)"
        )

        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppPushBackgroundTaskTime)
        ) {
            candidates.completion = completion
            candidates.contactIdentity = identity
            DDLogNotice("VoipCallService: [cid=\(candidates.callID.callID)]: Enqueuing ICE candidate message")
            self.addElementToCallQueue(candidates)
        }
    }

    /// Add a incoming hangup message to the process queue
    /// - parameter hangup: VoIPCallHangupMessage
    func incomingCallHangup(hangup: VoIPCallHangupMessage) {
        DDLogNotice(
            "VoipCallService: [cid=\(hangup.callID.callID)]: Call hangup message received from \(hangup.contactIdentity ?? "?")"
        )

        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppPushBackgroundTaskTime)
        ) {
            DDLogNotice("VoipCallService: [cid=\(hangup.callID.callID)]: Enqueuing hangup message")
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
    ///   - completion: Completion handler returns a task to update call
    func newIncomingCallFromBackground(
        with callID: VoIPCallID,
        callPartnerIdentity: String,
        callPartnerName: String?,
        ringtoneSound: String,
        completion: @escaping (@escaping () -> Void) -> Void
    ) {
        callKitManager.reportIncomingCall(
            with: callID,
            callPartnerIdentity: callPartnerIdentity,
            callPartnerName: callPartnerName,
            ringtoneSound: ringtoneSound
        ) { _ in
            // Task to update call when business is ready
            let task: (() -> Void) = {
                Task { @MainActor in
                    PersistenceManager(
                        appGroupID: AppGroup.groupID(),
                        userDefaults: AppGroup.userDefaults(),
                        remoteSecretManager: AppLaunchManager.remoteSecretManager
                    ).dirtyObjectManager.refreshDirtyObjects(reset: true)

                    if ServerConnector.shared().connectionState == .disconnected {
                        ServerConnector.shared().isAppInBackground = AppDelegate.shared().isAppInBackground()
                        ServerConnector.shared().connectWait(initiator: .threemaCall)
                    }

                    self.callServiceQueue.async {
                        // If another call already running, send reject busy
                        if let callService = self.callService, callService.callID.callID != callID.callID {
                            self.callKitManager.endCall(with: callID)
                            let action = VoIPCallUserAction(
                                action: .rejectBusy,
                                contactIdentity: callPartnerIdentity,
                                callID: callID,
                                completion: { }
                            )

                            BackgroundTaskManager.shared.newBackgroundTask(
                                key: kAppVoIPBackgroundTask,
                                timeout: Int(kAppPushBackgroundTaskTime)
                            ) {
                                DDLogNotice(
                                    "VoipCallService: [cid=\(callID.callID)]: Another call is active. Enqueuing reject message"
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
                "[CallStateManager] Tried to add element that is not VoIPCallUserAction or VoIPCallMessageProtocol to callQueue: \(element)"
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
        if let element, let contactIdentity = element.contactIdentity {
            callServiceQueue.async {
                if self.callService == nil {
                    DDLogNotice("VoipCallStateManager: [cid=\(element.callID.callID)]: Initialize VoIPCallService")
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
    }

    private func resetCallService() {
        callServiceQueue.async {
            self.callService = nil
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
        DDLogNotice("[CallStateManager] Call finished, resetting service")
        resetCallService()
        processNextElementInCallQueue()
    }
}
