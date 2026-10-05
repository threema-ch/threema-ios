import AudioSessionManager
import CallKit
import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

protocol VoIPCallKitManagerDelegate: AnyObject {
    func currentCallPartnerIdentity() -> String
    func currentCallID() -> VoIPCallID
    func callKitDidActivateAudioSession(_ audioSession: AVAudioSession)
    func callKitDidDeactivateAudioSession(_ audioSession: AVAudioSession)
}

final class VoIPCallKitManager: NSObject {

    weak var delegate: VoIPCallKitManagerDelegate?

    /// CallKit's activation callbacks go through the manager,
    private let audioSessionManager: any AudioSessionManagerProtocol

    private let provider: CXProvider
    private let callController: CXCallController
    private let callIDService: CallIDService

    /// Identity of the caller from the most recent `reportIncomingCall`. Available immediately
    /// from the push payload — does not require the offer message or a `VoIPCallService`.
    private var reportedCallPartnerIdentity: String?

    /// ID of a call that was reported to CallKit and is ringing, but that the state machine does not
    /// know about yet.
    private(set) var reportedRingingCallID: VoIPCallID?

    private var answerAction: CXAnswerCallAction?

    /// When true, the hold/unhold cycle is being used to force CallKit to reactivate the audio
    /// session after an interruption. The CXSetHeldCallAction handler skips mute/unmute logic.
    private(set) var isRestoringAudioSession = false

    /// Set while an end call action requested in `endCall(with:)` is pending, i.e. the call was already ended by the
    /// app. CallKit reports every performed action, also our own, and that report must not end the call again.
    private var dismissCallKitDirectly = false
    
    private let isBusinessLayerUsable: () -> Bool
    
    private let businessLayerWaitTimeout: TimeInterval

    // MARK: - Lifecycle
    
    init(
        audioSessionManager: any AudioSessionManagerProtocol = BusinessInjector.sharedAudioSessionManager,
        isBusinessLayerUsable: @escaping (
        ) -> Bool = {
            RemoteSecretProvider.isRemoteSecretManagerSet && MyIdentityStore.shared().identity != nil
        },
        
        businessLayerWaitTimeout: TimeInterval = 3.0
    ) {
        self.audioSessionManager = audioSessionManager
        self.isBusinessLayerUsable = isBusinessLayerUsable
        self.businessLayerWaitTimeout = businessLayerWaitTimeout
        self.provider = CXProvider(configuration: VoIPCallKitManager.providerConfiguration())
        self.callController = CXCallController()
        self.callIDService = CallIDService()
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    class func providerConfiguration(ringtoneSound: String? = "default") -> CXProviderConfiguration {
        let providerConfiguration = CXProviderConfiguration()
        providerConfiguration.supportsVideo = true
        providerConfiguration.maximumCallGroups = 1
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.generic]
        providerConfiguration.includesCallsInRecents = UserSettings.shared().includeCallsInRecents
        providerConfiguration.ringtoneSound = ringtoneSound
        providerConfiguration.iconTemplateImageData = Colors.callKitLogo.pngData()
        return providerConfiguration
    }
}

extension VoIPCallKitManager {
    // MARK: Public functions
    
    /// Report new incoming call to CallKit.
    ///
    /// - Parameters:
    ///   - callID: Unique call ID
    ///   - callPartnerIdentity: Caller identity
    ///   - ringtoneSound: Filename of ringtone to be used
    ///   - businessInjector: BusinessInjector instance to get call partner display name
    ///   - completion: Completion handler returns nil if call successfully reported to CallKit
    func reportIncomingCall(
        with callID: VoIPCallID,
        callPartnerIdentity: String,
        ringtoneSound: String,
        businessInjector: BusinessInjectorProtocol,
        completion: @escaping (Error?) -> Void
    ) {
        reportIncomingCall(
            with: callID,
            callPartnerIdentity: callPartnerIdentity,
            callPartnerName: callPartnerName(for: callPartnerIdentity, businessInjector: businessInjector),
            ringtoneSound: ringtoneSound,
            completion: completion
        )
    }

    /// Report new incoming call to CallKit.
    ///
    /// - Parameters:
    ///   - callID: Unique call ID
    ///   - callPartnerIdentity: Caller identity
    ///   - callPartnerName: Caller name
    ///   - ringtoneSound: Filename of ringtone to be used
    ///   - fromPush: Whether we report from the NSE
    ///   - completion: Completion handler returns error or nil
    func reportIncomingCall(
        with callID: VoIPCallID,
        callPartnerIdentity: String,
        callPartnerName: String?,
        ringtoneSound: String,
        fromPush: Bool = false,
        completion: @escaping (Error?) -> Void
    ) {
        guard ThreemaEnvironment.supportsCallKit() else {
            DDLogError("[Call:1to1:CallKit] [cid=\(callID)]: CallKit is not supported in this environment.")
            fatalError("VoIPCallKitManager is not supported in this environment.")
        }
        
        if ringtoneSound != "default" {
            provider.configuration = VoIPCallKitManager.providerConfiguration(ringtoneSound: ringtoneSound)
        }
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callPartnerIdentity)
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
        update.supportsDTMF = false
        update.hasVideo = false
        update.localizedCallerName = callPartnerName ?? callPartnerIdentity

        reportedCallPartnerIdentity = callPartnerIdentity
        reportedRingingCallID = callID

        let (uuid, isNew) = callIDService.uuid(for: callID)
        if isNew {
            DDLogNotice("[Call:1to1:CallKit] [cid=\(callID)]: Report new incoming call -> (callUUUID=\(uuid)")
            provider.reportNewIncomingCall(with: uuid, update: update) { error in
                if let error {
                    DDLogError(
                        "[Call:1to1:CallKit] [cid=\(callID)]: Report new incoming call failed (CallKit UUID: \(uuid): \(error)"
                    )
                }
                completion(error)
            }
        }
        else if fromPush {
            // This is a safeguard to report the call anyways when we are reporting it via the NSE.
            DDLogNotice(
                "[Call:1to1:CallKit] [cid=\(callID)]: Push arrived after server connection, re-reporting call (callUUID=\(uuid))"
            )
            provider.reportNewIncomingCall(with: uuid, update: update) { error in
                if let error {
                    DDLogWarn(
                        "[Call:1to1:CallKit] [cid=\(callID)]: Re-report for push returned expected error (callUUID=\(uuid)): \(error)"
                    )
                }
                completion(nil)
            }
        }
        else {
            DDLogNotice("[Call:1to1:CallKit] [cid=\(callID)]: Report incoming call -> (callUUUID=\(uuid)")
            provider.reportCall(with: uuid, updated: update)
            completion(nil)
        }
    }
    
    func startCall(
        with callID: VoIPCallID,
        for callPartnerIdentity: String,
        businessInjector: BusinessInjectorProtocol
    ) {
        guard ThreemaEnvironment.supportsCallKit() else {
            DDLogError("[Call:1to1:CallKit] [cid=\(callID)]: CallKit is not supported in this environment.")
            fatalError("VoIPCallKitManager is not supported in this environment.")
        }
        
        let handle = CXHandle(type: .generic, value: callPartnerIdentity)

        let (uuid, isNew) = callIDService.uuid(for: callID)
        assert(isNew)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        let transaction = CXTransaction(action: startCallAction)
        callController.request(transaction) { error in
            
            if let error {
                DDLogError(
                    "[Call:1to1:CallKit] [cid=\(callID)]: Start call action failed (CallKit UUID: \(uuid): \(error)"
                )
                return
            }
            
            let update = CXCallUpdate()
            update.remoteHandle = CXHandle(type: .generic, value: callPartnerIdentity)
            update.hasVideo = false
            update.localizedCallerName = self.callPartnerName(
                for: callPartnerIdentity,
                businessInjector: businessInjector
            )

            self.provider.reportCall(with: uuid, updated: update)
        }
    }
    
    func callAccepted(with callID: VoIPCallID) {
        guard ThreemaEnvironment.supportsCallKit() else {
            assertionFailure()
            DDLogWarn("[Call:1to1:CallKit] [cid=\(callID)]: CallKit is not supported in this environment.")
            return
        }
        
        let (uuid, isNew) = callIDService.uuid(for: callID)
        assert(!isNew)
        provider.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
    }
    
    func callConnected(with callID: VoIPCallID) {
        guard ThreemaEnvironment.supportsCallKit() else {
            assertionFailure()
            DDLogWarn("[Call:1to1:CallKit] [cid=\(callID)]: CallKit is not supported in this environment.")
            return
        }
        
        let (uuid, isNew) = callIDService.uuid(for: callID)
        assert(!isNew)
        provider.reportOutgoingCall(with: uuid, connectedAt: Date())
        answerAction?.fulfill()
    }
    
    func answerFailed() {
        answerAction?.fail()
    }
    
    func endCall(with callID: VoIPCallID) {
        guard ThreemaEnvironment.supportsCallKit() else {
            DDLogWarn("[Call:1to1:CallKit] [cid=\(callID)]: CallKit is not supported in this environment.")
            return
        }

        reportedCallPartnerIdentity = nil
        reportedRingingCallID = nil
        let (uuid, isNew) = callIDService.uuid(for: callID)

        guard !isNew else {
            return
        }

        // Only set when the action is really requested, otherwise the next end call action of CallKit is skipped
        dismissCallKitDirectly = true

        let action = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        callController.request(transaction) { error in
            if let error {
                self.dismissCallKitDirectly = false

                DDLogError(
                    "[Call:1to1:CallKit] [cid=\(callID)]: End call action failed (CallKit UUID: \(uuid): \(error)"
                )
            }
        }
    }
    
    func timeoutCall(with callID: VoIPCallID) {
        guard ThreemaEnvironment.supportsCallKit() else {
            assertionFailure()
            DDLogWarn("[Call:1to1:CallKit] [cid=\(callID)]: CallKit is not supported in this environment.")
            return
        }
        
        let (uuid, isNew) = callIDService.uuid(for: callID)
        assert(!isNew)
        let action = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        callController.request(transaction) { error in
            if let error {
                DDLogError(
                    "[Call:1to1:CallKit] [cid=\(callID)]: Timeout call action failed (CallKit UUID: \(uuid): \(error)"
                )
            }
        }
    }

    /// Report CallKit for unknown call push.
    func startAndCancelCall(from localizedName: String, completion: @escaping () -> Void) {
        guard ThreemaEnvironment.supportsCallKit() else {
            assertionFailure()
            DDLogWarn("[Call:1to1:CallKit] CallKit is not supported in this environment.")
            return
        }
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: localizedName)
        update.supportsDTMF = false
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.hasVideo = false

        let uuid = UUID()

        provider.reportNewIncomingCall(with: uuid, update: update) { _ in
            Task { @MainActor in
                let localizedMessage = #localize("call_missed")
                NotificationManager.showThreemaWebError(title: TargetManager.appName, body: localizedMessage)
            }

            self.provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
            completion()
        }

        // Prevent ringing
        provider.reportCall(with: uuid, endedAt: .now, reason: .failed)
    }

    /// Force CallKit to go through a didDeactivate → didActivate cycle by requesting a
    /// hold/unhold transaction. This is the only way to restore the audio session input route
    /// after a system alarm interruption, since CallKit owns the audio session activation.
    func requestAudioSessionReactivation(for callID: VoIPCallID) {
        guard !isRestoringAudioSession else {
            return
        }

        let (uuid, _) = callIDService.uuid(for: callID)

        DDLogNotice(
            "[Call:1to1:CallKit] [cid=\(callID)]: Requesting audio session reactivation via hold/unhold"
        )

        // Temporarily enable holding so the hold action is accepted
        let holdUpdate = CXCallUpdate()
        holdUpdate.supportsHolding = true
        provider.reportCall(with: uuid, updated: holdUpdate)

        isRestoringAudioSession = true

        // Request hold → triggers didDeactivate
        let holdAction = CXSetHeldCallAction(call: uuid, onHold: true)
        let holdTransaction = CXTransaction(action: holdAction)
        callController.request(holdTransaction) { [weak self] error in
            guard let self else {
                return
            }
            if let error {
                DDLogError(
                    "[Call:1to1:CallKit] [cid=\(callID)]: Hold action for audio restoration failed: \(error)"
                )
                isRestoringAudioSession = false
                return
            }

            // Minimal delay to let CallKit process the hold before we unhold.
            // didDeactivate fires within ~100ms of hold fulfillment.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let unholdAction = CXSetHeldCallAction(call: uuid, onHold: false)
                let unholdTransaction = CXTransaction(action: unholdAction)
                self.callController.request(unholdTransaction) { [weak self] error in
                    guard let self else {
                        return
                    }
                    // Don't reset isRestoringAudioSession here — the CXSetHeldCallAction
                    // delegate handler fires AFTER this completion and needs the flag to
                    // still be true. Reset it after a short delay instead.
                    if let error {
                        DDLogError(
                            "[Call:1to1:CallKit] [cid=\(callID)]: Unhold action for audio restoration failed: \(error)"
                        )
                        isRestoringAudioSession = false
                    }
                    else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.isRestoringAudioSession = false
                        }
                    }

                    // Disable holding again
                    let restoreUpdate = CXCallUpdate()
                    restoreUpdate.supportsHolding = false
                    provider.reportCall(with: uuid, updated: restoreUpdate)
                }
            }
        }
    }

    // MARK: - Private functions

    private func callPartnerName(for identity: String, businessInjector: BusinessInjectorProtocol) -> String {
        let entityManager = businessInjector.entityManager
        return entityManager.performAndWait {
            if let contact = entityManager.entityFetcher.contactEntity(for: identity) {
                contact.displayName
            }
            else {
                identity
            }
        }
    }

    func waitForBusinessLayer(callID: VoIPCallID) async -> Bool {
        var totalWait = 0.0
        let waitDuration = 0.1

        while !isBusinessLayerUsable() {
            if totalWait > businessLayerWaitTimeout {
                return false
            }

            DDLogNotice(
                "[Call:1to1:CallKit] [cid=\(callID)]: Waiting for the business layer, total wait time: \(totalWait)s"
            )

            try? await Task.sleep(seconds: waitDuration)
            totalWait += waitDuration
        }

        return true
    }

    private func removePendingActions(for callID: UUID) {
        let pendingActions = provider.pendingCallActions(of: CXCallAction.self, withCall: callID)
        guard let actionCallID = callIDService.callID(for: callID), !pendingActions.isEmpty else {
            return
        }
        
        for action in pendingActions {
            DDLogNotice(
                "[Call:1to1:CallKit] [cid=\(actionCallID)] Failing pending action \(action) for call with UUID \(callID)"
            )
            action.fail()
        }
    }
}

// MARK: - CXProviderDelegate

extension VoIPCallKitManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        guard let callID = delegate?.currentCallID(),
              let callPartnerIdentity = delegate?.currentCallPartnerIdentity() else {
            DDLogError("[Call:1to1:CallKit] Did not handle provider reset due to missing call state")
            return
        }
        
        let state = VoIPCallStateManager.shared.currentCallState()
        guard state == .incomingRinging || state == .calling || state == .reconnecting else {
            DDLogError(
                "[Call:1to1:CallKit] [cid=\(callID)]: Did not handle provider reset due to being in wrong call state: \(state.rawValue)"
            )
            return
        }
        
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppVoIPBackgroundTaskTime)
        ) {
            ServerConnector.shared().connectWait(initiator: .threemaCall)
            let userAction =
                if VoIPCallStateManager.shared.currentCallState() == .incomingRinging {
                    // Local CallKit provider did reset. Other devices might be able to pickup, so we do not send the
                    // reject.
                    VoIPCallUserAction(
                        action: .reject(sendMessage: false),
                        contactIdentity: callPartnerIdentity,
                        callID: callID,
                        completion: nil
                    )
                }
                else {
                    VoIPCallUserAction(
                        action: .end,
                        contactIdentity: callPartnerIdentity,
                        callID: callID,
                        completion: nil
                    )
                }

            VoIPCallStateManager.shared.addActionToCallQueue(userAction)
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        guard let actionCallID = callIDService.callID(for: action.callUUID) else {
            action.fail()
            return
        }

        DDLogNotice("[Call:1to1:CallKit] [cid=\(actionCallID)]: Start call action")

        assert(delegate?.currentCallID().callID == actionCallID.callID)

        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task {
            guard let actionCallID = callIDService.callID(for: action.callUUID) else {
                action.fulfill()
                return
            }

            DDLogNotice("[Call:1to1:CallKit] [cid=\(actionCallID)]: Answer call action")

            // The call partner identity is known from the push payload (stored at
            // `reportIncomingCall` time), so we don't need the delegate for that.
            // But we must still wait for the offer message to arrive and create the
            // VoIPCallService — otherwise the accept action creates a fresh service
            // with no offer and immediately fails with "Wrong state IDLE".
            guard let contactIdentity = reportedCallPartnerIdentity else {
                DDLogError(
                    "[Call:1to1:CallKit] [cid=\(actionCallID)]: Fail answer call action, call partner identity not available"
                )
                action.fail()
                return
            }

            var totalWait = 0.0
            let waitDuration = 0.1
            let maxWaitDuration = 10.0

            while delegate?.currentCallPartnerIdentity() == nil || delegate?.currentCallID() == nil {
                DDLogNotice(
                    "[Call:1to1:CallKit] [cid=\(actionCallID)]: Waiting for offer to arrive, total wait time: \(totalWait)s"
                )

                try? await Task.sleep(seconds: waitDuration)
                totalWait += waitDuration

                if totalWait > maxWaitDuration {
                    DDLogError(
                        "[Call:1to1:CallKit] [cid=\(actionCallID)]: Timeout waiting for offer. Failing call."
                    )
                    action.fail()
                    return
                }
            }

            let currentCallID = delegate?.currentCallID() ?? actionCallID

            reportedRingingCallID = nil

            BackgroundTaskManager.shared.newBackgroundTask(
                key: kAppVoIPBackgroundTask,
                timeout: Int(kAppPushBackgroundTaskTime)
            ) {
                ServerConnector.shared().connectWait(initiator: .threemaCall)
                self.answerAction = action

                let action = VoIPCallUserAction(
                    action: .acceptCallKit,
                    contactIdentity: contactIdentity,
                    callID: currentCallID,
                    completion: {
                        action.fulfill()
                    }
                )

                VoIPCallStateManager.shared.addActionToCallQueue(action)
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task {
            guard let actionCallID = callIDService.callID(for: action.callUUID) else {
                dismissCallKitDirectly = false
                action.fulfill()
                removePendingActions(for: action.callUUID)
                return
            }

            DDLogNotice("[Call:1to1:CallKit] [cid=\(actionCallID)]: End call action")

            guard !dismissCallKitDirectly else {
                DDLogNotice("[Call:1to1:CallKit] [cid=\(actionCallID)]: End call action was requested by us")
                dismissCallKitDirectly = false
                action.fulfill()
                removePendingActions(for: action.callUUID)
                return
            }

            // Use the identity stored at reportIncomingCall time (from push payload).
            // Falls back to the delegate (VoIPCallService) if available.
            guard let contactIdentity = reportedCallPartnerIdentity
                ?? delegate?.currentCallPartnerIdentity() else {
                DDLogError(
                    "[Call:1to1:CallKit] [cid=\(actionCallID)]: Fulfill end call action, but call partner identity not available"
                )
                dismissCallKitDirectly = false
                action.fulfill()
                removePendingActions(for: action.callUUID)
                return
            }
            let currentCallID = delegate?.currentCallID() ?? actionCallID
            dismissCallKitDirectly = false

            let isDeclineOfReportedCall = reportedRingingCallID?.callID == currentCallID.callID
            reportedRingingCallID = nil

            let state = VoIPCallStateManager.shared.currentCallState()
            switch state {
            case .ended, .remoteEnded, .rejected, .rejectedTimeout, .rejectedUnknown, .microphoneDisabled:
                let userAction = VoIPCallUserAction(
                    action: .end,
                    contactIdentity: contactIdentity,
                    callID: currentCallID,
                    completion: {
                        action.fulfill()
                        self.removePendingActions(for: action.callUUID)
                    }
                )
                VoIPCallStateManager.shared.addActionToCallQueue(userAction)
                return
                
            case .idle, .sendOffer, .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer, .receivedAnswer,
                 .initializing, .calling, .reconnecting:
                // do nothing
                break
            }
            
            guard await waitForBusinessLayer(callID: actionCallID) else {
                DDLogError(
                    "[Call:1to1:CallKit] [cid=\(actionCallID)]: No business layer, ending the call locally only"
                )
                action.fulfill()
                removePendingActions(for: action.callUUID)
                return
            }

            BackgroundTaskManager.shared.newBackgroundTask(
                key: kAppVoIPBackgroundTask,
                timeout: Int(kAppPushBackgroundTaskTime)
            ) {
                ServerConnector.shared().connectWait(initiator: .threemaCall)

                // The reported call only counts as long as no call is running: when answered before the offer was
                // processed, the offer reports the call again after the answer cleared it
                let currentState = VoIPCallStateManager.shared.currentCallState()
                let isDeclineWhileRinging = currentState == .receivedOffer ||
                    currentState == .incomingRinging ||
                    (currentState == .idle && isDeclineOfReportedCall)

                let userAction =
                    if isDeclineWhileRinging {
                        // User tapped end call in CallKit. We send the reject message, so the other devices stop
                        // ringing.
                        VoIPCallUserAction(
                            action: .reject(sendMessage: true),
                            contactIdentity: contactIdentity,
                            callID: currentCallID,
                            completion: {
                                action.fulfill()
                                self.removePendingActions(for: action.callUUID)
                            }
                        )
                    }
                    else {
                        VoIPCallUserAction(
                            action: .end,
                            contactIdentity: contactIdentity,
                            callID: currentCallID,
                            completion: {
                                action.fulfill()
                                self.removePendingActions(for: action.callUUID)
                            }
                        )
                    }
                
                VoIPCallStateManager.shared.addActionToCallQueue(userAction)
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        let callID = callIDService.callID(for: action.callUUID)
        assert(delegate?.currentCallID().callID == callID?.callID)

        DDLogNotice(
            "[Call:1to1:CallKit] [cid=\(String(describing: callID?.callID))]: Muted call action, set muted: \(action.isMuted)"
        )

        guard let callID = delegate?.currentCallID(),
              let callPartnerIdentity = delegate?.currentCallPartnerIdentity() else {
            DDLogError(
                "[Call:1to1:CallKit] [cid=\(callID?.callID ?? "unknown")]: Fail mute call action due to missing call state"
            )
            action.fail()
            return
        }
        
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppVoIPBackgroundTaskTime)
        ) {
            ServerConnector.shared().connectWait(initiator: .threemaCall)
            let actionType: VoIPCallUserAction.Action = action.isMuted ? .muteAudio : .unmuteAudio
            let userAction = VoIPCallUserAction(
                action: actionType,
                contactIdentity: callPartnerIdentity,
                callID: callID,
                completion: {
                    action.fulfill()
                }
            )
            
            VoIPCallStateManager.shared.addActionToCallQueue(userAction)
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        let callID = callIDService.callID(for: action.callUUID)
        assert(delegate?.currentCallID().callID == callID?.callID)

        DDLogNotice(
            "[Call:1to1:CallKit] [cid=\(String(describing: callID?.callID))]: Held call action, is on hold: \(action.isOnHold)"
        )

        // When restoring audio after an interruption, the hold/unhold cycle is only used
        // to trigger CallKit's didDeactivate/didActivate. Skip mute/unmute to avoid
        // side effects (e.g. sending a mute signal to the remote peer).
        if isRestoringAudioSession {
            action.fulfill()
            return
        }

        guard let callID = delegate?.currentCallID(),
              let callPartnerIdentity = delegate?.currentCallPartnerIdentity() else {
            DDLogError(
                "[Call:1to1:CallKit] [cid=\(callID?.callID ?? "unknown")]: Fail hold call action due to missing call state"
            )
            action.fail()
            return
        }
        
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppVoIPBackgroundTaskTime)
        ) {
            ServerConnector.shared().connectWait(initiator: .threemaCall)
            let actionType: VoIPCallUserAction.Action = action.isOnHold ? .muteAudio : .unmuteAudio
            let action = VoIPCallUserAction(
                action: actionType,
                contactIdentity: callPartnerIdentity,
                callID: callID,
                completion: {
                    action.fulfill()
                }
            )
            
            VoIPCallStateManager.shared.addActionToCallQueue(action)
        }
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        guard let callID = delegate?.currentCallID(),
              let callPartnerIdentity = delegate?.currentCallPartnerIdentity() else {
            DDLogError("[Call:1to1:CallKit] Fail time out action due to missing call state")
            action.fail()
            return
        }
        
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppVoIPBackgroundTaskTime)
        ) {
            ServerConnector.shared().connectWait(initiator: .threemaCall)
            
            switch VoIPCallStateManager.shared.currentCallState() {
            case .idle, .ended, .remoteEnded, .rejected, .rejectedTimeout, .rejectedUnknown, .microphoneDisabled:
                action.fulfill()
                
            case .sendOffer, .outgoingRinging, .sendAnswer, .receivedAnswer, .initializing, .calling, .reconnecting:
                let userAction = VoIPCallUserAction(
                    action: .end,
                    contactIdentity: callPartnerIdentity,
                    callID: callID,
                    completion: {
                        action.fulfill()
                    }
                )
                VoIPCallStateManager.shared.addActionToCallQueue(userAction)

            case .receivedOffer, .incomingRinging:
                // Local call ran into timeout. Other devices might be able to pickup, so we do not send the reject.
                let userAction = VoIPCallUserAction(
                    action: .rejectUnknown(sendMessage: false),
                    contactIdentity: callPartnerIdentity,
                    callID: callID,
                    completion: {
                        action.fulfill()
                    }
                )
                VoIPCallStateManager.shared.addActionToCallQueue(userAction)
            }
        }
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        let callID = delegate?.currentCallID()
        DDLogNotice("[Call:1to1:CallKit] [cid=\(String(describing: callID?.callID))]: Did activate audio session")

        // WebRTC has to observe the activation before the outgoing dial tone touches the session.
        audioSessionManager.sessionWasActivatedExternally(audioSession)

        delegate?.callKitDidActivateAudioSession(audioSession)
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        let callID = delegate?.currentCallID()
        DDLogNotice("[Call:1to1:CallKit] [cid=\(String(describing: callID?.callID))]: Did deactivate audio session")

        audioSessionManager.sessionWasDeactivatedExternally(audioSession)

        delegate?.callKitDidDeactivateAudioSession(audioSession)
    }
}
