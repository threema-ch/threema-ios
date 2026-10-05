import AudioSessionManager
import CocoaLumberjackSwift
import Foundation
import Intents
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

protocol VoIPCallServiceDelegate: AnyObject {
    func prependCallQueueElement(_ element: VoIPCallIDProtocol)
    func finishedProcessingCallQueueElement()
    func callFinished()
    func callReadyForPresentation(callPartnerIdentity: String)
    /// The call reached the connected (`.calling`) state.
    func callDidConnect()
    /// View controller to present the call view on, or `nil` to use the key window's root (legacy flow).
    func callViewPresentingViewController() -> UIViewController?
}

final class VoIPCallService {

    private struct VoIPCallStateMachine {
        enum VoIPCallStateMachineError: Error {
            case elementTypeNotSupported
            case discardUserActionCallIDNotEqual(action: VoIPCallUserAction, callID: VoIPCallID)
            case discardMessageCallIDNotEqual(message: VoIPCallMessageProtocol, callID: VoIPCallID)
            case unknownVoIPCallMessageType
        }

        let callService: VoIPCallService

        func process(_ element: VoIPCallIDProtocol) throws {
            if let action = element as? VoIPCallUserAction {
                try process(action)
            }
            else if let message = element as? VoIPCallMessageProtocol {
                try process(message)
            }
            else {
                throw VoIPCallStateMachineError.elementTypeNotSupported
            }
        }

        private func process(_ action: VoIPCallUserAction) throws {
            guard action.callID == callService.callID else {
                return try processCallIDNotEqual(action)
            }

            switch action.action {
            case .call:
                log(expectedState: .idle, for: action)
                callService.processUserAction(action)
                
            case .accept, .acceptCallKit:
                log(expectedState: .incomingRinging, for: action)
                callService.processUserAction(action)
                
            case .reject, .rejectTimeout, .rejectUnknown:
                log(for: action)
                callService.processUserAction(action)
                
            case .end:
                log(for: action)
                callService.processUserAction(action)
                
            case .speakerOn:
                log(for: action)
                if callService.state != .idle {
                    callService.processUserAction(action)
                }
                else {
                    action.completion?()
                    callService.delegate?.callFinished()
                }
                
            case .speakerOff:
                log(for: action)
                if callService.state != .idle {
                    callService.processUserAction(action)
                }
                else {
                    action.completion?()
                    callService.delegate?.callFinished()
                }
                
            case .muteAudio:
                log(for: action)
                if callService.state != .idle {
                    callService.processUserAction(action)
                }
                else {
                    action.completion?()
                    callService.delegate?.callFinished()
                }
                 
            case .unmuteAudio:
                log(for: action)
                if callService.state != .idle {
                    callService.processUserAction(action)
                }
                else {
                    action.completion?()
                    callService.delegate?.callFinished()
                }
            }
        }

        private func process(_ message: VoIPCallMessageProtocol) throws {
            guard message.callID.callID == callService.callID.callID else {
                return try processCallIDNotEqual(message)
            }
            
            switch message {
            case let offer as VoIPCallOfferMessage:
                log(expectedStates: [.idle], for: offer)
                callService.processVoIPCallMessage(offer)
                
            case let answer as VoIPCallAnswerMessage:
                log(expectedStates: [.sendOffer, .outgoingRinging], for: answer)
                if callService.state != .idle {
                    callService.processVoIPCallMessage(answer)
                }
                else {
                    if answer.action == .reject, answer.receivedAsReflected ?? false {
                        CallSystemMessageHelper.addRejectMessage(answer: answer, on: callService.businessInjector)
                    }
                    
                    message.completion?()
                    callService.delegate?.callFinished()
                }
                
            case let ringing as VoIPCallRingingMessage:
                log(expectedStates: [.sendOffer], for: ringing)
                if callService.state != .idle {
                    callService.processVoIPCallMessage(ringing)
                }
                else {
                    message.completion?()
                    callService.delegate?.callFinished()
                }
                
            case let hangup as VoIPCallHangupMessage:
                log(expectedStates: nil, for: hangup)
                if callService.state != .idle {
                    callService.processVoIPCallMessage(hangup)
                }
                else {
                    if hangup.receivedAsReflected ?? false {
                        CallSystemMessageHelper.addHangupMessage(hangup: hangup, on: callService.businessInjector)
                    }
                    
                    message.completion?()
                    callService.delegate?.callFinished()
                }
                
            case let iceCandidates as VoIPCallIceCandidatesMessage:
                log(
                    expectedStates: [
                        .sendOffer,
                        .outgoingRinging,
                        .receivedAnswer,
                        .initializing,
                        .calling,
                        .reconnecting,
                        .receivedOffer,
                        .incomingRinging,
                        .sendAnswer,
                    ],
                    for: iceCandidates
                )
                if callService.state != .idle {
                    callService.processVoIPCallMessage(iceCandidates)
                }
                else {
                    message.completion?()
                    callService.delegate?.callFinished()
                }
                
            default:
                throw VoIPCallStateMachineError.unknownVoIPCallMessageType
            }
        }

        private func processCallIDNotEqual(_ action: VoIPCallUserAction) throws {
            throw VoIPCallStateMachineError.discardUserActionCallIDNotEqual(action: action, callID: callService.callID)
        }

        private func processCallIDNotEqual(_ message: VoIPCallMessageProtocol) throws {
            switch message {
            case let offer as VoIPCallOfferMessage:
                log(expectedStates: [.idle], for: offer)

                if offer.contactIdentity == callService.callPartnerIdentity,
                   callService.state == .reconnecting || callService.state == .calling {
                    DDLogNotice(
                        "[Call:1to1:VoIPCallService] [cid=\(callService.callID)]: Received offer from same identity \(callService.callPartnerIdentity) for different call with id \(offer.callID). Replacing call."
                    )
                    callService.cancelCall()
                    callService.delegate?.prependCallQueueElement(message)
                    callService.delegate?.callFinished()
                }
                else {
                    DDLogNotice(
                        "[Call:1to1:VoIPCallService] [cid=\(callService.callID)]: Received new offer, but we are in a call already, rejecting it silently "
                    )
                    let action = VoIPCallUserAction(
                        action: .reject(sendMessage: false),
                        contactIdentity: offer.contactIdentity!,
                        callID: offer.callID,
                        completion: offer.completion
                    )

                    callService.rejectCall(action: action)
                    offer.completion?()
                    
                    if offer.contactIdentity == callService.callPartnerIdentity {
                        callService.delegate?.callFinished()
                    }
                }

            case let answer as VoIPCallAnswerMessage:
                log(expectedStates: [.sendOffer, .outgoingRinging], for: answer)
                
                if answer.action == .reject, answer.contactIdentity != callService.callPartnerIdentity {
                    // Reject received for other call, we add a message if its from a different contact.
                    CallSystemMessageHelper.addRejectMessage(answer: answer, on: callService.businessInjector)
                }
                
                answer.completion?()
                
            case let iceCandidates as VoIPCallIceCandidatesMessage:
                log(
                    expectedStates: [
                        .sendOffer,
                        .outgoingRinging,
                        .receivedAnswer,
                        .initializing,
                        .calling,
                        .reconnecting,
                        .receivedOffer,
                        .incomingRinging,
                        .sendAnswer,
                    ],
                    for: iceCandidates
                )
                iceCandidates.completion?()
                
            case let hangup as VoIPCallHangupMessage:
                // Hangup message received for other call, we add a message if its from a different contact.
                guard hangup.contactIdentity != callService.callPartnerIdentity else {
                    return
                }
                CallSystemMessageHelper.addHangupMessage(hangup: hangup, on: callService.businessInjector)
                
            default:
                throw VoIPCallStateMachineError.discardMessageCallIDNotEqual(
                    message: message,
                    callID: callService.callID
                )
            }
        }

        private func log(expectedState: CallState? = nil, for action: VoIPCallUserAction) {
            if let expectedState, callService.state != expectedState {
                DDLogWarn(
                    "[Call:1to1:VoIPCallService] [cid=\(callService.callID)]: Wrong state \(callService.state) to process user action \(action)"
                )
            }
            else {
                DDLogNotice(
                    "[Call:1to1:VoIPCallService] [cid=\(callService.callID)]: Process action \(action.action) on actual state \(callService.state)"
                )
            }
        }

        private func log(expectedStates: [CallState]? = nil, for message: VoIPCallMessageProtocol) {
            if callService.callID != message.callID {
                DDLogError(
                    "[Call:1to1:VoIPCallService] [cid=\(callService.callID)]: Call ID is not equals with incoming message Call ID \(message.callID)"
                )
            }
            else if let expectedStates, !expectedStates.contains(callService.state) {
                DDLogWarn(
                    "[Call:1to1:VoIPCallService] [cid=\(callService.callID)]: Wrong state \(callService.state) to process message \(message)"
                )
            }
            else {
                DDLogNotice(
                    "[Call:1to1:VoIPCallService] [cid=\(callService.callID)]: Process message \(message) on actual state \(callService.state)"
                )
            }
        }
    }

    private let voIPCallSender: VoIPCallSender
    
    private let kIncomingCallTimeout = 60.0
    
    private let kOutgoingRingingCallTimeout = 50.0
    private let kInitializingCallTimeout = 60.0
    private let kCallFailedTimeout = 10.0
    private let kEndedDelay = 5.0
    
    weak var delegate: (any VoIPCallServiceDelegate)?
    
    private var peerConnectionClient: any VoIPCallPeerConnectionClientProtocol
    private let callKitManager: VoIPCallKitManager
    private var threemaVideoCallAvailable = false
    private var callViewController: CallViewController?

    private var state: CallState = .idle {
        didSet {
            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(callID)]: State changed from \(oldValue) to  \(state)"
            )
            
            if state.isUnansweredIncoming {
                RingingCallRecord.setRinging(callID)
            }
            else if oldValue.isUnansweredIncoming {
                RingingCallRecord.clear(callID)
            }

            invalidateTimers(state: state)
            callViewController?.voIPCallStatusChanged(state: state, oldState: oldValue)
            handleLocalNotification()

            if state == .calling, oldValue != .calling {
                delegate?.callDidConnect()
            }

            switch state {
            case .idle:
                localAddedIceCandidates.removeAll()
                localRelatedAddresses.removeAll()
                receivedIceCandidatesMessages.removeAll()
                
            case .initializing:
                handleLocalIceCandidates([])
                
            default:
                break
            }
            
            addCallMessageToConversation(oldCallState: oldValue)

            updateAudioSessionClaim(for: state, speakerActive: speakerActive)
            handleTones(state: state, oldState: oldValue)
        }
    }

    private var audioPlayer: AVAudioPlayer?
    let callPartnerIdentity: String
    let callID: VoIPCallID
    private var alreadyAccepted = false {
        didSet {
            callViewController?.alreadyAccepted = alreadyAccepted
        }
    }

    private var callStartedBySelf = false {
        didSet {
            callViewController?.callStartedBySelf = callStartedBySelf
        }
    }

    private var audioMuted = false
    private var speakerActive = false
    private var videoActive = false
    private var isReceivingVideo = false {
        didSet {
            guard oldValue != isReceivingVideo, let callViewController else {
                return
            }
            
            DDLogDebug(
                "[Call:1to1:VoIPCallService] [cid=\(callID)]: Change receiving video to \(isReceivingVideo)"
            )
            callViewController.isReceivingRemoteVideo = isReceivingVideo
        }
    }

    private var shouldShowCellularCallWarning = false {
        didSet {
            guard oldValue != shouldShowCellularCallWarning, let callViewController else {
                return
            }
   
            DDLogDebug(
                "[Call:1to1:VoIPCallService] [cid=\(callID)]: Change show cellular warning to \(shouldShowCellularCallWarning)"
            )
            callViewController.shouldShowCellularCallWarning = shouldShowCellularCallWarning
        }
    }
    
    private var initCallTimeoutTimer: Timer?
    private var incomingCallTimeoutTimer: Timer?
    private var outgoingRingingCallTimeoutTimer: Timer?
    private var callDurationTimer: Timer?
    private var callDurationTime = 0
    private var callFailedTimer: Timer?
    private var transportExpectedStableTimer: Timer?
    
    private var incomingOffer: VoIPCallOfferMessage?
    
    private var iceCandidatesLockQueue = DispatchQueue(label: "VoIPCallIceCandidatesLockQueue")
    private var iceCandidatesTimer: Timer?
    private var localAddedIceCandidates = [RTCIceCandidate]()
    private var localRelatedAddresses: Set<String> = []
    private var receivedIceCandidatesLockQueue = DispatchQueue(label: "VoIPCallReceivedIceCandidatesLockQueue")
    private var receivedIceCandidatesMessages = [VoIPCallIceCandidatesMessage]()
    private var receivedUnknownCallIceCandidatesMessages = [String: [VoIPCallIceCandidatesMessage]]()
    
    private var localRenderer: RTCVideoRenderer?
    private var remoteRenderer: RTCVideoRenderer?
    
    private var reconnectingTimer: Timer?
    private var peerWasConnected = false

    private let audioSessionManager: any AudioSessionManagerProtocol

    /// The call's claim on the audio session.
    private var audioSessionClaim: AudioSessionClaim?

    /// Where a state change posts its claim request. Drained in order by `audioSessionLifecycleTask`.
    private let audioSessionRequests: AsyncStream<AudioSessionRequest>.Continuation
    private var audioSessionLifecycleTask: Task<Void, Never>?
    private var audioSessionEventTask: Task<Void, Never>?
    
    private var isModal: Bool {
        // Check whether our callViewController is currently in the state presented modally
        let a = callViewController?.presentingViewController?.presentedViewController == callViewController
        // Check whether our callViewController has a navigationController
        let b1 = callViewController?.navigationController != nil
        // Check whether our callViewController is in the state presented modally as part of a navigation controller
        let b2 = callViewController?.navigationController?.presentingViewController?
            .presentedViewController == callViewController?.navigationController
        let b = b1 && b2
        // Check whether our callViewController has a tab bar controller which has a tab bar controller. Nesting two
        // tabBarControllers is only possible in the state presented modally
        let c = callViewController?.tabBarController?.presentingViewController is UITabBarController
        return a || b || c
    }
    
    private let businessInjector: any BusinessInjectorProtocol

    // MARK: - Lifecycle

    init(
        callPartnerIdentity: String,
        callID: VoIPCallID,
        delegate: (any VoIPCallServiceDelegate)?,
        callKitManager: VoIPCallKitManager,
        businessInjector: any BusinessInjectorProtocol = BusinessInjector.ui,
        peerConnectionClient: any VoIPCallPeerConnectionClientProtocol = VoIPCallPeerConnectionClient()
    ) {
        self.callPartnerIdentity = callPartnerIdentity
        self.callID = callID
        self.delegate = delegate
        self.callKitManager = callKitManager
       
        self.businessInjector = businessInjector
        self.voIPCallSender = VoIPCallSender(
            messageSender: businessInjector.messageSender,
            myIdentity: businessInjector.profileStore.profile.myIdentity,
            isMultiDeviceEnabled: businessInjector.userSettings.enableMultiDevice
        )
        self.peerConnectionClient = peerConnectionClient

        self.audioSessionManager = businessInjector.audioSessionManager

        let (requests, continuation) = AsyncStream<AudioSessionRequest>.makeStream()
        self.audioSessionRequests = continuation

        callKitManager.delegate = self

        startAudioSessionLifecycle(draining: requests)
    }

    deinit {
        audioSessionRequests.finish()
        audioSessionLifecycleTask?.cancel()
        audioSessionEventTask?.cancel()

        // Copied into locals: the `Task` outlives this object, so it must not capture `self`. Escaping `self`
        // from a `deinit` is a use-after-free, and an error in the Swift 6 language mode.
        guard let claim = audioSessionClaim else {
            return
        }
        let manager = audioSessionManager

        // The recovery hook goes with the claim, so there is nothing else to withdraw here.
        Task {
            await manager.release(claim)
        }
    }

    // MARK: - Public functions
    
    /// Processes an element from the call queue
    /// - parameter element: `VoIPCallUserAction` or `VoIPCallMessageProtocol`
    func processCallQueueElement(_ element: VoIPCallIDProtocol) {
        do {
            let callStateMachine = VoIPCallStateMachine(callService: self)
            try callStateMachine.process(element)
        }
        catch {
            DDLogError(
                "[Call:1to1:VoIPCallService] [cid=\(callID)]: State machine failed while processing element: \(element). Error: \(error)"
            )
            delegate?.finishedProcessingCallQueueElement()
        }
    }
    
    /// Get the current call state
    /// - Returns: CallState
    func currentState() -> CallState {
        state
    }
    
    func currentCallPartnerIdentity() -> String {
        callPartnerIdentity
    }

    /// Get the current callID
    /// - Returns: VoIPCallID or nil
    func currentCallID() -> VoIPCallID {
        callID
    }
    
    /// Is the current call muted
    /// - Returns: true or false
    func isCallMuted() -> Bool {
        audioMuted
    }
    
    /// Is the speaker for the current call active
    /// - Returns: true or false
    func isSpeakerActive() -> Bool {
        speakerActive
    }
    
    /// Present the CallViewController
    func presentCallViewController() {
        if alreadyAccepted || ProcessInfoHelper.isRunningForScreenshots {
            presentCallView(
                contactIdentity: callPartnerIdentity,
                alreadyAccepted: alreadyAccepted,
                callStartedBySelf: callStartedBySelf,
                isThreemaVideoCallAvailable: threemaVideoCallAvailable,
                videoActive: videoActive,
                receivingVideo: isReceivingVideo,
                viewWasHidden: false
            )
        }
    }
    
    /// CallKit activated the audio session.
    /// - parameter audioSession: AVAudioSession from CallKit
    func callKitDidActivateAudioSession(_ audioSession: AVAudioSession) {
        logAudioSessionState(after: "activation")

        // The outgoing dial tone can only start once CallKit has activated the session, so it is
        // driven from here (`handleTones`' `.sendOffer` case only fires when old and new state
        // match). No other state may re-enter `handleTones` on activation: mid-call it would
        // reconfigure the session behind `RTCAudioSession`'s back and replay the pickup sound.
        if state == .sendOffer || state == .outgoingRinging {
            handleTones(state: state, oldState: state)
        }
    }

    /// CallKit deactivated the audio session.
    /// - parameter audioSession: AVAudioSession from CallKit
    func callKitDidDeactivateAudioSession(_ audioSession: AVAudioSession) {
        logAudioSessionState(after: "deactivation")
    }

    private func logAudioSessionState(after event: String) {
        let manager = audioSessionManager
        let callID = callID

        Task {
            let state = await manager.diagnostics()
            DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(callID.callID)]: RTC audio after \(event): \(state)")
        }
    }

    // MARK: - Audio session claim

    /// States in which this call plays or captures audio.
    private static let audioActiveStates: Set<CallState> = [
        .sendOffer,
        .outgoingRinging,
        .sendAnswer,
        .receivedAnswer,
        .initializing,
        .calling,
        .reconnecting,
    ]

    /// One step of the claim's lifecycle.
    private enum AudioSessionRequest: Sendable {
        case acquire(speakerActive: Bool)
        case setOutput(speaker: Bool)
        case release
    }

    /// Acquire or release the call's claim as the state machine moves.
    private func updateAudioSessionClaim(for state: CallState, speakerActive: Bool) {
        let shouldHold = Self.audioActiveStates.contains(state)

        /// Release happens on `.idle` and not on the terminal states, because `.ended` and `.rejected*`
        /// still play the hangup and busy tones;
        guard shouldHold || state == .idle else {
            return
        }

        audioSessionRequests.yield(shouldHold ? .acquire(speakerActive: speakerActive) : .release)
    }

    /// Start the one consumer of `audioSessionRequests`.
    private func startAudioSessionLifecycle(draining requests: AsyncStream<AudioSessionRequest>) {
        audioSessionLifecycleTask = Task { @MainActor [weak self] in
            for await request in requests {
                guard let self else {
                    return
                }

                switch request {
                case let .acquire(speakerActive):
                    await acquireAudioSessionClaim(speakerActive: speakerActive)
                    
                case let .setOutput(speaker):
                    await updateAudioSessionOutput(speaker: speaker)
                    
                case .release:
                    await releaseAudioSessionClaim()
                }
            }
        }
    }

    @MainActor
    private func acquireAudioSessionClaim(speakerActive: Bool) async {
        guard audioSessionClaim == nil else {
            return
        }

        do {
            let claim = try await audioSessionManager.acquire(
                .call,
                output: speakerActive ? .speaker : .system
            )

            audioSessionClaim = claim

            // Named per call, so an interruption cannot be recovered against a call that has ended.
            await audioSessionManager.setRecovery(
                CallKitAudioSessionRecovery(callKitManager: callKitManager, callID: callID),
                for: claim
            )

            observeAudioSessionEvents(for: claim)

            DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(callID.callID)]: Acquired the call audio claim")
        }
        catch {
            DDLogError(
                "[Call:1to1:VoIPCallService] [cid=\(callID.callID)]: Acquiring the call audio claim failed: \(error)"
            )
        }
    }

    @MainActor
    private func releaseAudioSessionClaim() async {
        audioSessionEventTask?.cancel()
        audioSessionEventTask = nil

        guard let claim = audioSessionClaim else {
            return
        }
        audioSessionClaim = nil

        await audioSessionManager.release(claim)

        DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(callID.callID)]: Released the call audio claim")
    }

    @MainActor
    private func updateAudioSessionOutput(speaker: Bool) async {
        guard let claim = audioSessionClaim else {
            return
        }

        await audioSessionManager.update(claim, output: speaker ? .speaker : .system)
    }

    @MainActor
    private func observeAudioSessionEvents(for claim: AudioSessionClaim) {
        audioSessionEventTask?.cancel()

        audioSessionEventTask = Task { [weak self, manager = audioSessionManager] in
            for await event in await manager.events(for: claim) {
                await self?.handleAudioSessionEvent(event)
            }
        }
    }

    @MainActor
    /// `CallViewControllerDelegate`: the route as it is now, for a screen that has just appeared.
    func currentAudioRoute() async -> AudioSessionRouteSnapshot {
        await audioSessionManager.currentRoute()
    }

    @MainActor
    private func handleAudioSessionEvent(_ event: AudioSessionEvent) async {
        switch event {
        case .interrupted:
            DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(callID.callID)]: Audio session interrupted")

        case .subordinated:
            DDLogWarn(
                "[Call:1to1:VoIPCallService] [cid=\(callID.callID)]: Lost the audio session to another claim"
            )

        case let .interruptionEnded(shouldResume):
            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(callID.callID)]: Audio session interruption ended (shouldResume=\(shouldResume))"
            )

        case let .outputRouteChanged(reason, route):
            handleBluetoothAvailabilityChange(hasBluetoothInput: route.hasBluetoothInput)
            callViewController?.audioRouteChanged(to: route)

            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(callID.callID)]: Route changed (\(reason)) -> \(route.outputs.map(\.rawValue).joined(separator: "+"))"
            )
        }
    }
    
    @MainActor
    private func handleBluetoothAvailabilityChange(hasBluetoothInput: Bool) {
        guard hasBluetoothInput, speakerActive else {
            return
        }

        speakerActive = false
        audioSessionRequests.yield(.setOutput(speaker: false))
        callViewController?.voIPCallStatusChanged(state: state, oldState: state)
    }

    /// Start capture local video
    func startCaptureLocalVideo(renderer: RTCVideoRenderer, useBackCamera: Bool = false, switchCamera: Bool = false) {
        localRenderer = renderer
        videoActive = true
        peerConnectionClient.startCaptureLocalVideo(
            renderer: renderer,
            useBackCamera: useBackCamera,
            switchCamera: switchCamera
        )
    }
    
    /// End capture local video
    func endCaptureLocalVideo(switchCamera: Bool = false) {
        if !switchCamera {
            videoActive = false
        }
        if let renderer = localRenderer {
            peerConnectionClient.endCaptureLocalVideo(renderer: renderer, switchCamera: switchCamera)
            localRenderer = nil
        }
    }
    
    /// Get local video renderer
    func localVideoRenderer() -> RTCVideoRenderer? {
        localRenderer
    }
    
    /// Start render remote video
    func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        remoteRenderer = renderer
        peerConnectionClient.renderRemoteVideo(to: renderer)
    }
    
    /// End remote video
    func endRemoteVideo() {
        if let renderer = remoteRenderer {
            peerConnectionClient.endRemoteVideo(renderer: renderer)
            remoteRenderer = nil
        }
    }
    
    /// Get remote video renderer
    func remoteVideoRenderer() -> RTCVideoRenderer? {
        remoteRenderer
    }
    
    /// Get peer video quality profile
    func remoteVideoQualityProfile() -> CallsignalingProtocol.ThreemaVideoCallQualityProfile? {
        peerConnectionClient.remoteVideoQualityProfile
    }
    
    /// Get peer is using turn server
    func networkIsRelayed() -> Bool {
        peerConnectionClient.networkIsRelayed
    }

    // MARK: - Private functions

    private func processUserAction(_ action: VoIPCallUserAction) {
        switch action.action {
        case .call:
            if ProcessInfoHelper.isRunningForScreenshots {
                callStartedBySelf = true
                presentCallViewController()
                delegate?.finishedProcessingCallQueueElement()
                action.completion?()
                return
            }
            
            startCallAsInitiator(action: action) {
                self.delegate?.finishedProcessingCallQueueElement()
                action.completion?()
            }
        
        case .accept, .acceptCallKit:
            alreadyAccepted = true
            acceptIncomingCall(action: action) {
                self.delegate?.finishedProcessingCallQueueElement()
                action.completion?()
            }
        
        case .reject, .rejectTimeout, .rejectUnknown:
            rejectCall(action: action)
            delegate?.callFinished()
            action.completion?()
        
        case .end:
            if ProcessInfoHelper.isRunningForScreenshots {
                dismissCallView()
                delegate?.callFinished()
                action.completion?()
                return
            }

            DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(callID)]: Send hangup for end action")
            if state == .sendOffer ||
                state == .outgoingRinging ||
                state == .sendAnswer ||
                state == .receivedAnswer ||
                state == .initializing ||
                state == .calling ||
                state == .reconnecting {
                let hangupMessage = VoIPCallHangupMessage(
                    contactIdentity: action.contactIdentity,
                    callID: action.callID,
                    duration: callDurationTime != 0 ? UInt(callDurationTime) : nil,
                    isOutgoing: true,
                )
                voIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage)
                state = .ended
                callKitManager.endCall(with: action.callID)
                dismissCallView()
                disconnectPeerConnection()
            }

            delegate?.callFinished()
            action.completion?()
        
        case .speakerOn:
            peerConnectionClient(peerConnectionClient, speakerActive: true)
            delegate?.finishedProcessingCallQueueElement()
            action.completion?()
        
        case .speakerOff:
            peerConnectionClient(peerConnectionClient, speakerActive: false)
            delegate?.finishedProcessingCallQueueElement()
            action.completion?()
        
        case .muteAudio:
            peerConnectionClient.muteAudio {
                self.delegate?.finishedProcessingCallQueueElement()
                action.completion?()
            }
        
        case .unmuteAudio:
            peerConnectionClient.unmuteAudio {
                self.delegate?.finishedProcessingCallQueueElement()
                action.completion?()
            }
        }
    }
    
    private func processVoIPCallMessage(_ message: VoIPCallMessageProtocol) {
        switch message {
        case let offer as VoIPCallOfferMessage:
            handleOfferMessage(offer: offer) {
                offer.completion?()
                self.delegate?.finishedProcessingCallQueueElement()
            }
        case let answer as VoIPCallAnswerMessage:
            handleAnswerMessage(answer: answer) {
                answer.completion?()
                self.delegate?.finishedProcessingCallQueueElement()
            }
        case let ringing as VoIPCallRingingMessage:
            handleRingingMessage(ringing: ringing) {
                ringing.completion?()
                self.delegate?.finishedProcessingCallQueueElement()
            }
        case let hangup as VoIPCallHangupMessage:
            handleHangupMessage(hangup: hangup) {
                hangup.completion?()
                self.delegate?.finishedProcessingCallQueueElement()
            }
        case let ice as VoIPCallIceCandidatesMessage:
            handleIceCandidatesMessage(ice: ice) {
                ice.completion?()
                self.delegate?.finishedProcessingCallQueueElement()
            }
        default:
            DDLogError("[Call:1to1:VoIPCallService] [cid=\(message.callID)]: Unknown voice call message.")
        }
    }
    
    /// When the current call state is idle and the permission is granted to the microphone, it will create the peer
    /// client and add the offer.
    /// If the state is wrong, it will reject the call with the reason unknown.
    /// If the permission to the microphone is not granted, it will reject the call with the reason unknown.
    /// If Threema Calls are disabled, it will reject the call with the reason disabled.
    /// - parameter offer: VoIPCallOfferMessage
    /// - parameter completion: Completion block
    private func handleOfferMessage(offer: VoIPCallOfferMessage, completion: @escaping (() -> Void)) {

        DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(offer.callID)]: Processing offer message")
        
        guard !offer.isOutgoing else {
            DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(offer.callID)]: Offer is outgoing, we ignore it.")
            completion()
            return
        }
        
        // Store call in temporary call history
        storeCallInTempHistory(offer: offer)
        
        guard businessInjector.userSettings.enableThreemaCall else {
            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(offer.callID)]: Calls are disabled on this device, ignoring offer."
            )

            // Enable call is a synced setting. All devices adhere to it, so we send the reject in this case.
            let sendMessage = businessInjector.serverConnector.isRolePromotedToLeader
            let action = VoIPCallUserAction(
                action: .reject(sendMessage: sendMessage),
                contactIdentity: offer.contactIdentity!,
                callID: offer.callID,
                completion: offer.completion
            )
            
            rejectCall(action: action)
            completion()
            return
        }
        
        var appRunsInBackground = false
        DispatchQueue.main.sync {
            appRunsInBackground = SceneDelegate.isAppInBackground
        }

        DDLogNotice(
            "[Call:1to1:VoIPCallService] [cid=\(offer.callID)]: Update lastUpdate for conversation"
        )
        
        businessInjector.entityManager.performAndWaitSave {
            if let identity = offer.contactIdentity,
               let conversation = self.businessInjector.entityManager.entityFetcher
               .conversationEntity(for: identity) {
                conversation.lastUpdate = Date.now
            }
        }

        if state == .idle, !NavigationBarPromptHandler.isGroupCallActive {
            if !businessInjector.pushSettingManager.canMasterDndSendPush() {
                DDLogWarn("[Call:1to1:VoIPCallService] [cid=\(offer.callID)]: Master DND active, reject the call")
                completion()
                return
            }
                
            let pushSetting = businessInjector.pushSettingManager
                .find(forContact: ThreemaIdentity(offer.contactIdentity!))
            var ringtoneSound: String
            if pushSetting.canSendPush(), pushSetting.muted == false {
                ringtoneSound = UserSettings.shared()?.voIPSound ?? "default"
                if ringtoneSound != "default" {
                    ringtoneSound = "\(ringtoneSound).caf"
                }
            }
            else {
                ringtoneSound = "silent.mp3"
            }

            // The user can only be asked for microphone access while the app is in the foreground. Otherwise the call
            // is ended and the user is informed with a notification.
            let hasMicrophoneAccess = RecordPermission.isGranted
            let canAskForMicrophoneAccess = !appRunsInBackground && RecordPermission.access == .undetermined

            guard hasMicrophoneAccess || canAskForMicrophoneAccess else {
                if RecordPermission.access == .undetermined {
                    ThreemaUtility.sendMicrophonePermissionErrorLocalNotification(
                        entityManager: businessInjector.entityManager
                    )
                }

                endCallBecauseOfMissingMicrophoneAccess(
                    offer: offer,
                    showOpenSettingsAlert: !appRunsInBackground
                )
                completion()
                return
            }

            callKitManager.reportIncomingCall(
                with: offer.callID,
                callPartnerIdentity: offer.contactIdentity!,
                ringtoneSound: ringtoneSound,
                businessInjector: businessInjector,
                completion: { error in
                    if error != nil {
                        // Reporting call to CallKit failed. Do not send a reject, other devices can still pickup.
                        let action = VoIPCallUserAction(
                            action: .rejectUnknown(sendMessage: false),
                            contactIdentity: offer.contactIdentity!,
                            callID: offer.callID,
                            completion: offer.completion
                        )
                        self.rejectCall(action: action)
                    }

                    DispatchQueue.global().async {
                        completion()
                    }
                }
            )

            alreadyAccepted = false
            state = .receivedOffer
            incomingOffer = offer
            videoActive = false
            isReceivingVideo = false
            localRenderer = nil
            remoteRenderer = nil
            threemaVideoCallAvailable = offer.isVideoAvailable
            startIncomingCallTimeoutTimer()

            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(offer.callID)]: connectWait"
            )

            // Make sure that the connection is not prematurely disconnected when the app is put into the
            // background
            businessInjector.serverConnector.connectWait(initiator: .threemaCall)

            // New Call
            // Send ringing message, when the offer was not reflected
            
            // TODO: (IOS-6370) Re-add if/else once desktop can send ringing messages
//            if !(offer.receivedAsReflected ?? false) {
            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(offer.callID)]: Send ringing message"
            )
            let ringingMessage = VoIPCallRingingMessage(
                contactIdentity: offer.contactIdentity!,
                callID: offer.callID,
                isOutgoing: true,
                completion: nil
            )

            voIPCallSender.sendVoIPCallRinging(ringingMessage: ringingMessage)
//            }
//            else {
//                DDLogNotice(
//                    "[Call:1to1:VoIPCallService] [cid=\(offer.callID)]: offer was reflected, do not send ringing"
//                )
//            }

            state = .incomingRinging

            // Prefetch ICE/TURN servers so they're likely to be already available when the user accepts the
            // call
            VoIPIceServerSource.prefetchIceServers()

            // Ask while the call is already ringing, the microphone is only needed when it is accepted. Waiting for
            // the answer would block accepting the call.
            if !hasMicrophoneAccess {
                RecordPermission.requestPermission { granted in
                    guard !granted else {
                        return
                    }

                    self.endCallBecauseOfMissingMicrophoneAccess(offer: offer, showOpenSettingsAlert: true)
                }
            }

            if !ThreemaEnvironment.supportsCallKit() {
                presentCallView(
                    contactIdentity: offer.contactIdentity!,
                    alreadyAccepted: false,
                    callStartedBySelf: false,
                    isThreemaVideoCallAvailable: threemaVideoCallAvailable,
                    videoActive: false,
                    receivingVideo: false,
                    viewWasHidden: false,
                    completion: completion
                )
            }
            else {
                completion()
            }
        }
        else {
            DDLogWarn(
                "[Call:1to1:VoIPCallService] [cid=\(offer.callID)]: Current state is not IDLE (\(state)"
            )
            if callPartnerIdentity == offer.contactIdentity, state == .incomingRinging {
                DDLogNotice("Threema call: handleOfferMessage -> same contact as the current call")
                if !businessInjector.pushSettingManager.canMasterDndSendPush(), appRunsInBackground {
                    DDLogNotice(
                        "[Call:1to1:VoIPCallService] [cid=\(offer.callID)]: Master DND active, silently rejecting call from \(String(describing: offer.contactIdentity))"
                    )
                    // Local DnD active. Other devices might be able to pickup, so we do not send the reject.
                    let action = VoIPCallUserAction(
                        action: .reject(sendMessage: false),
                        contactIdentity: offer.contactIdentity!,
                        callID: offer.callID,
                        completion: offer.completion
                    )
                    rejectCall(action: action)
                    completion()
                }
                else {
                    DDLogWarn(
                        "[Call:1to1:VoIPCallService] [cid=\(offer.callID)]: Same contact as the current call ((\(offer.contactIdentity ?? "?")), Master DND inactive, set the offer"
                    )
                    disconnectPeerConnection()
                    handleOfferMessage(offer: offer, completion: completion)
                }
            }
            else {
                // Reject call because it's the wrong state
                let reason: VoIPCallUserAction.Action = callPartnerIdentity == offer
                    .contactIdentity ? .rejectUnknown(sendMessage: false) : .reject(sendMessage: false)
                // Local state is wrong for offer message. Other devices might be able to pickup, so we do not send the
                // reject.
                let action = VoIPCallUserAction(
                    action: reason,
                    contactIdentity: offer.contactIdentity!,
                    callID: offer.callID,
                    completion: offer.completion
                )
                rejectCall(action: action)
                completion()
            }
        }
    }
    
    /// End an incoming call because there is no access to the microphone
    ///
    /// Other devices might be able to pick up the call, thus no reject is sent to the caller.
    /// - Parameters:
    ///   - offer: Offer of the call to end
    ///   - showOpenSettingsAlert: Show an alert to change the access in the settings
    private func endCallBecauseOfMissingMicrophoneAccess(offer: VoIPCallOfferMessage, showOpenSettingsAlert: Bool) {
        DDLogWarn("[Call:1to1:VoIPCallService] [cid=\(offer.callID)]: Audio is not granted")

        state = .microphoneDisabled
        state = .rejected

        let action = VoIPCallUserAction(
            action: .rejectUnknown(sendMessage: false),
            contactIdentity: offer.contactIdentity!,
            callID: offer.callID,
            completion: offer.completion
        )
        rejectCall(action: action, closeCallView: false)

        if showOpenSettingsAlert {
            DispatchQueue.main.async {
                guard let rootVC = SharedAppProvider.keyWindow?.rootViewController else {
                    return
                }

                UIAlertTemplate.showOpenSettingsAlert(owner: rootVC, noAccessAlertType: .microphone)
            }
        }

        disconnectPeerConnection()
        delegate?.callFinished()
    }

    private func startIncomingCallTimeoutTimer() {
        DispatchQueue.main.async {
            guard let offer = self.incomingOffer else {
                return
            }
            
            self.invalidateIncomingCallTimeout()
            self.incomingCallTimeoutTimer = Timer.scheduledTimer(
                withTimeInterval: self.kIncomingCallTimeout,
                repeats: false
            ) { _ in
                BackgroundTaskManager.shared.newBackgroundTask(
                    key: kAppVoIPBackgroundTask,
                    timeout: Int(kAppVoIPBackgroundTaskTime)
                ) { [weak self] in
                    guard let self else {
                        return
                    }
                        
                    guard offer.callID == incomingOffer?.callID else {
                        DDLogError(
                            "Trying to run background task for call with ID \(offer.callID), but current incoming offer call ID is \(incomingOffer?.callID ?? VoIPCallID(callID: 0))"
                        )
                        return
                    }
                        
                    businessInjector.serverConnector.connect(initiator: .threemaCall)

                    callKitManager.timeoutCall(with: offer.callID)
                    // Local timeout reached. Other devices might be able to pickup, so we do not send the reject.
                    let action = VoIPCallUserAction(
                        action: .rejectTimeout(sendMessage: false),
                        contactIdentity: offer.contactIdentity!,
                        callID: offer.callID,
                        completion: offer.completion
                    )
                    rejectCall(action: action)
                    invalidateIncomingCallTimeout()
                }
            }
        }
    }
    
    /// Handle the answer message if the contact in the answer message is the same as in the call service and call state
    /// is ringing.
    /// Call will cancel if it's rejected and CallViewController will close.
    /// - parameter answer: VoIPCallAnswerMessage
    /// - parameter completion: Completion block
    private func handleAnswerMessage(answer: VoIPCallAnswerMessage, completion: @escaping (() -> Void)) {
        
        DDLogNotice(
            "[Call:1to1:VoIPCallService] [cid=\(answer.callID)]: Processing answer message. Received as reflected: \(answer.receivedAsReflected ?? false)"
        )
        
        // We end the call if we get and outgoing answer, that means on of our other devices picked up.
        if answer.isOutgoing {
            self.callKitManager.endCall(with: answer.callID)
            self.disconnectPeerConnection()
            self.delegate?.callFinished()
            // Add reject to chat
            if answer.action == .reject {
                CallSystemMessageHelper.addRejectMessage(answer: answer, on: businessInjector)
            }
            completion()
            return
        }
        
        if state == .sendOffer || state == .outgoingRinging,
           callPartnerIdentity == answer.contactIdentity,
           callID.callID == answer.callID.callID {
            state = .receivedAnswer
            if answer.action == VoIPCallAnswerMessage.MessageAction.reject {
                // Call was rejected
                switch answer.rejectReason {
                case .reject?, .busy?, .disabled?, .offHours?, .none:
                    state = .rejected
                
                case .timeout?:
                    state = .rejectedTimeout
                    
                case .some(.unknown):
                    state = .rejectedUnknown
                }
                    
                dismissCallView(rejected: true) {
                    self.callKitManager.endCall(with: answer.callID)
                    self.disconnectPeerConnection()
                    self.delegate?.callFinished()
                    completion()
                }
            }
            else {
                // Handle answer
                state = .receivedAnswer
                if answer.isVideoAvailable, UserSettings.shared().enableVideoCall {
                    threemaVideoCallAvailable = true
                    callViewController?.enableThreemaVideoCall()
                }
                else {
                    threemaVideoCallAvailable = false
                    callViewController?.disableThreemaVideoCall()
                }
                if let remoteSdp = answer.answer {
                    peerConnectionClient.set(remoteSdp: remoteSdp) { error in
                        if error == nil {
                            switch self.state {
                            case .idle, .sendOffer, .receivedOffer, .outgoingRinging, .incomingRinging,
                                 .sendAnswer, .receivedAnswer:
                                self.state = .initializing
                            default:
                                break
                            }
                        }
                        else {
                            DDLogError(
                                "[Call:1to1:VoIPCallService] [cid=\(answer.callID)]: Can't add remote sdp to the peerConnection"
                            )
                            let hangupMessage = VoIPCallHangupMessage(
                                contactIdentity: self.callPartnerIdentity,
                                callID: self.callID,
                                duration: nil,
                                isOutgoing: true,
                                completion: nil
                            )
                            self.voIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage)
                            self.state = .rejectedUnknown
                            self.dismissCallView()
                            self.disconnectPeerConnection()
                            self.delegate?.callFinished()
                        }
                        completion()
                    }
                }
                else {
                    DDLogError("[Call:1to1:VoIPCallService] [cid=\(answer.callID)]: Remote sdp is empty")
                    let hangupMessage = VoIPCallHangupMessage(
                        contactIdentity: callPartnerIdentity,
                        callID: callID,
                        duration: nil,
                        isOutgoing: true
                    )
                    voIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage)
                    state = .rejectedUnknown
                    dismissCallView()
                    disconnectPeerConnection()
                    delegate?.callFinished()
                    completion()
                }
            }
        }
        else {
            if callPartnerIdentity == answer.contactIdentity {
                DDLogWarn(
                    "[Call:1to1:VoIPCallService] [cid=\(answer.callID)]: Current state is wrong (\(state) or callID is different to \(callID)"
                )
            }
            else {
                DDLogWarn(
                    "[Call:1to1:VoIPCallService] [cid=\(answer.callID)]: Answer contact (\(answer.contactIdentity ?? "?") is different to current call contact (\(callPartnerIdentity)"
                )
            }
            completion()
        }
    }
    
    /// Handle the ringing message if the contact in the answer message is the same as in the call service and call
    /// state is sendOffer.
    /// CallViewController will play the ringing tone
    /// - parameter ringing: VoIPCallRingingMessage
    /// - parameter completion: Completion block
    private func handleRingingMessage(ringing: VoIPCallRingingMessage, completion: @escaping (() -> Void)) {
        DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(ringing.callID)]: Processing ringing message")
        
        guard !ringing.isOutgoing else {
            DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(ringing.callID)]: Do not process outgoing ringing message.")
            completion()
            return
        }
        
        guard callPartnerIdentity == ringing.contactIdentity,
              callID.callID == ringing.callID.callID else {
            DDLogWarn(
                "[Call:1to1:VoIPCallService] [cid=\(ringing.callID)]: Ringing contact (\(ringing.contactIdentity ?? "?") is different to current call contact (\(callPartnerIdentity)"
            )
            completion()
            return
        }
        
        switch state {
        case .sendOffer:
            state = .outgoingRinging
            startOutgoingRingingCallTimeoutTimer()
        
        default:
            DDLogWarn(
                "[Call:1to1:VoIPCallService] [cid=\(ringing.callID)]: Wrong state (\(state) to handle ringing message"
            )
        }
        
        completion()
    }
    
    private func startOutgoingRingingCallTimeoutTimer() {
        guard state == .outgoingRinging else {
            return
        }
        
        DispatchQueue.main.async {
            self.invalidateOutgoingRingingCallTimeout()
            self.outgoingRingingCallTimeoutTimer = Timer.scheduledTimer(
                withTimeInterval: self.kOutgoingRingingCallTimeout,
                repeats: false
            ) { [weak self] _ in
                guard let self else {
                    return
                }
                BackgroundTaskManager.shared.newBackgroundTask(
                    key: kAppVoIPBackgroundTask,
                    timeout: Int(kOutgoingRingingCallTimeout)
                ) {
                        
                    DispatchQueue.global(qos: .userInitiated).async {
                            
                        DDLogNotice(
                            "[Call:1to1:VoIPCallService] [cid=\(self.callID)]: Call ringing timeout"
                        )
                        let hangupMessage = VoIPCallHangupMessage(
                            contactIdentity: self.callPartnerIdentity,
                            callID: self.callID,
                            duration: self.callDurationTime != 0 ? UInt(self.callDurationTime) : nil,
                            isOutgoing: true
                        )
                        self.voIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage)
                            
                        self.state = .ended
                        self.disconnectPeerConnection()
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                            self.dismissCallView(rejected: false) {
                                self.callKitManager.endCall(with: self.callID)
                                self.invalidateInitCallTimeout()
                                self.delegate?.callFinished()
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Handle add or remove received remote ice candidates (IpV6 candidates will be removed)
    /// - parameter ice: VoIPCallIceCandidatesMessage
    /// - parameter completion: Completion block
    private func handleIceCandidatesMessage(ice: VoIPCallIceCandidatesMessage, completion: @escaping (() -> Void)) {
        DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(ice.callID)]: Processing ICE candidate message")
        
        guard !ice.isOutgoing else {
            DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(ice.callID)]: Ignore outgoing ICE message.")
            completion()
            return
        }
        
        for candidate in ice.candidates {
            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(ice.callID)]: Incoming ICE candidate: \(candidate.sdp)"
            )
        }
        
        guard callPartnerIdentity == ice.contactIdentity,
              callID.callID == ice.callID.callID else {
            addUnknownCallIceCandidatesMessages(message: ice)
            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(ice.callID)]: ICE candidates contact (\(ice.contactIdentity ?? "?") is different to current call contact (\(callPartnerIdentity)"
            )
            completion()
            return
        }
        
        switch state {
        case .sendOffer, .outgoingRinging, .sendAnswer, .receivedAnswer, .initializing, .calling, .reconnecting:
            if !ice.removed {
                for candidate in ice.candidates {
                    if shouldAdd(candidate: candidate, local: false) == (true, nil) {
                        peerConnectionClient.set(addRemoteCandidate: candidate)
                    }
                }
                completion()
            }
            else {
                // ICE candidate messages are currently allowed to have a "removed" flag. However, this is
                // non-standard.
                // When receiving an VoIP ICE Candidate (0x62) message with removed set to true, discard the
                // message
                completion()
            }
                
        case .receivedOffer, .incomingRinging:
            // add to local array
            receivedIceCandidatesLockQueue.sync {
                receivedIceCandidatesMessages.append(ice)
                completion()
            }
            
        case .idle, .ended, .remoteEnded, .rejected, .rejectedTimeout, .rejectedUnknown, .microphoneDisabled:
            DDLogWarn(
                "[Call:1to1:VoIPCallService] [cid=\(ice.callID)]: Wrong state (\(state) to handle ICE candidates message"
            )
            completion()
        }
    }
    
    /// Handle the hangup message if the contact in the answer message is the same as in the call service and call state
    /// is receivedOffer, ringing, sendAnswer, initializing, calling or reconnecting.
    /// / If we receive a hangup message without having had a call with this callID in any state, we assume that it
    /// belonged to a missed call whose other messages were already dropped by the server.
    /// It will dismiss the CallViewController after the call was ended.
    /// - parameter hangup: VoIPCallHangupMessage
    /// - parameter completion: Completion block
    private func handleHangupMessage(hangup: VoIPCallHangupMessage, completion: @escaping (() -> Void)) {
        DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(hangup.callID)]: Processing hangup message")
        
        guard callPartnerIdentity == hangup.contactIdentity, callID.callID == hangup.callID.callID else {
            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(hangup.callID)]: Hangup contact (\(hangup.contactIdentity ?? "?") is different to current call contact (\(callPartnerIdentity)"
            )
            delegate?.callFinished()
            completion()
            return
        }
        
        switch state {
        case .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer, .initializing, .calling, .reconnecting:
            cancelCall()
            
        case .idle, .sendOffer, .receivedAnswer, .ended, .remoteEnded, .rejected, .rejectedTimeout, .rejectedUnknown, .microphoneDisabled:
            DDLogWarn(
                "[Call:1to1:VoIPCallService] [cid=\(hangup.callID)]: Wrong state (\(state) to handle hangup message"
            )
            delegate?.callFinished()
        }

        completion()
    }

    private func cancelCall() {
        state = .remoteEnded
        callKitManager.endCall(with: callID)
        dismissCallView()
        disconnectPeerConnection()
        delegate?.callFinished()
    }

    /// Handle a new outgoing call if Threema calls are enabled and permission for microphone is granted.
    /// It will present the CallViewController.
    /// - parameter action: VoIPCallUserAction
    /// - parameter completion: Completion block
    private func startCallAsInitiator(action: VoIPCallUserAction, completion: @escaping (() -> Void)) {
        
        guard !NavigationBarPromptHandler.isGroupCallActive else {
            showCallActiveAlert()
            completion()
            return
        }
        
        guard UserSettings.shared().enableThreemaCall else {
            // Do nothing because Threema calls are disabled or unavailable
            completion()
            return
        }
        
        guard state == .idle else {
            // Do nothing because it's the wrong state
            DDLogWarn(
                "[Call:1to1:VoIPCallService] [cid=\(action.callID)]: Wrong state (\(state) to start call as initiator"
            )
            showCallActiveAlert()
            completion()
            return
        }
        
        RecordPermission.requestPermission { granted in
            if granted {
                self.callStartedBySelf = true
                        
                let entityManager = self.businessInjector.entityManager
                        
                entityManager.performAndWaitSave {
                    if let conversation = entityManager.entityFetcher
                        .conversationEntity(for: action.contactIdentity) {
                        conversation.lastUpdate = Date.now
                    }
                }
                        
                ServerConnectorHelper.connectAndWaitUntilConnected(initiator: .threemaCall, timeout: 20) {
                    self.createPeerConnectionForInitiator(action: action, completion: completion)
                } onTimeout: {
                    // No special handling required. If there is no connection and peer connection
                    // cannot be established, a toast message is displayed to the user.
                    self.createPeerConnectionForInitiator(action: action, completion: completion)
                }
            }
            else {
                DispatchQueue.main.async {
                    // No access to microphone, stop call
                    guard let rootVC = SharedAppProvider.keyWindow?.rootViewController else {
                        return
                    }
                        
                    UIAlertTemplate.showOpenSettingsAlert(
                        owner: rootVC,
                        noAccessAlertType: .microphone
                    )
                }
                    
                completion()
            }
        }
    }
    
    /// Accept a incoming call if state is ringing. Will send a answer message to initiator and update
    /// CallViewController.
    /// It will present the CallViewController.
    /// - parameter action: VoIPCallUserAction
    /// - parameter completion: Completion block
    private func acceptIncomingCall(action: VoIPCallUserAction, completion: @escaping (() -> Void)) {
        createPeerConnectionForIncomingCall {
            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(self.callID)] acceptIncomingCall completion: state=\(self.state), isGroupCallActive=\(NavigationBarPromptHandler.isGroupCallActive)"
            )
            
            guard self.state == .incomingRinging, !NavigationBarPromptHandler.isGroupCallActive else {
                // Dismiss call view because it's the wrong state
                DDLogWarn(
                    "[Call:1to1:VoIPCallService] [cid=\(action.callID)]: Wrong state (\(self.state) to accept incoming call action"
                )
                self.callKitManager.answerFailed()
                self.dismissCallView()
                self.disconnectPeerConnection()
                self.delegate?.callFinished()
                completion()
                return
            }
            
            /// Make sure that the connection is not prematurely disconnected when the app is put into the
            /// background
            self.businessInjector.serverConnector.connect(initiator: .threemaCall)
            self.state = .sendAnswer
            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(self.callID)] about to call callReadyForPresentation"
            )
            self.delegate?.callReadyForPresentation(callPartnerIdentity: self.callPartnerIdentity)
            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(self.callID)] callReadyForPresentation returned, calling presentCallViewController"
            )
            self.presentCallViewController()

            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(self.callID)] calling peerConnectionClient.answer()"
            )
            self.peerConnectionClient.answer { sdp, sdpError in
                DDLogNotice(
                    "[Call:1to1:VoIPCallService] [cid=\(self.callID)] peerConnectionClient.answer completed, error=\(String(describing: sdpError))"
                )
                
                guard sdpError == nil else {
                    // Something went wrong during call setup. Other devices might be able to pickup, so we do not
                    // send the reject.
                    let action = VoIPCallUserAction(
                        action: .reject(sendMessage: false),
                        contactIdentity: action.contactIdentity,
                        callID: action.callID,
                        completion: action.completion
                    )
                    self.rejectCall(action: action)
                    completion()
                    return
                }
                    
                if self.threemaVideoCallAvailable, UserSettings.shared().enableVideoCall {
                    self.callViewController?.enableThreemaVideoCall()
                }
                else {
                    self.threemaVideoCallAvailable = false
                    self.callViewController?.disableThreemaVideoCall()
                }
                    
                let answerMessage = VoIPCallAnswerMessage(
                    action: .call,
                    answer: sdp,
                    rejectReason: nil,
                    features: nil,
                    isVideoAvailable: self.threemaVideoCallAvailable,
                    isUserInteraction: true,
                    callID: self.callID,
                    isOutgoing: true,
                    completion: nil
                )
                answerMessage.contactIdentity = action.contactIdentity
                    
                self.voIPCallSender.sendVoIPCall(answer: answerMessage)
                    
                if action.action != .acceptCallKit {
                    self.callKitManager.callAccepted(with: self.callID)
                }
                
                self.receivedIceCandidatesLockQueue.sync {
                    if let receivedCandidatesBeforeCall = self
                        .receivedUnknownCallIceCandidatesMessages[action.contactIdentity] {
                        for ice in receivedCandidatesBeforeCall {
                            if ice.callID.callID == self.callID.callID {
                                self.receivedIceCandidatesMessages.append(ice)
                            }
                        }
                        self.receivedUnknownCallIceCandidatesMessages.removeAll()
                    }
                        
                    for message in self.receivedIceCandidatesMessages {
                        if !message.removed {
                            for candidate in message.candidates {
                                if self.shouldAdd(candidate: candidate, local: false) == (true, nil) {
                                    self.peerConnectionClient.set(addRemoteCandidate: candidate)
                                }
                            }
                        }
                    }
                    self.receivedIceCandidatesMessages.removeAll()
                }
                completion()
            }
        }
    }
    
    /// Creates the peer connection for the initiator and set the offer.
    /// After this, it will present the CallViewController.
    /// - parameter action: VoIPCallUserAction
    /// - parameter completion: Completion block
    private func createPeerConnectionForInitiator(action: VoIPCallUserAction, completion: @escaping (() -> Void)) {
        let entityManager = businessInjector.entityManager
        entityManager.perform {
            guard let contact = entityManager.entityFetcher.contactEntity(for: self.callPartnerIdentity) else {
                completion()
                return
            }
            
            FeatureMask
                .check(
                    identities: [self.callPartnerIdentity],
                    for: Int(FEATURE_MASK_VOIP_VIDEO)
                ) { unsupportedContacts in
                    self.threemaVideoCallAvailable = false
                    
                    if unsupportedContacts.isEmpty, UserSettings.shared().enableVideoCall {
                        self.threemaVideoCallAvailable = true
                    }
                    
                    self.peerConnectionClient.close()
                    LocalNetworkPermissionChecker().checkLocalNetworkPermission { granted in
                        
                        let forceTurn = !granted ||
                            contact.contactVerificationLevel == .unverified ||
                            UserSettings.shared()?.alwaysRelayCalls == true
                        
                        let peerConnectionParameters = PeerConnectionParameters(
                            isVideoCallAvailable: self.threemaVideoCallAvailable,
                            videoCodecHwAcceleration: self.threemaVideoCallAvailable,
                            forceTurn: forceTurn,
                            gatherContinually: true,
                            allowIpv6: UserSettings.shared().enableIPv6,
                            isDataChannelAvailable: false
                        )
                        
                        // Store call in temporary call history
                        Task { @MainActor in
                            await CallHistoryManager(
                                identity: action.contactIdentity,
                                businessInjector: self.businessInjector
                            ).store(callID: self.callID, date: Date())
                        }
                        
                        DDLogNotice(
                            "[Call:1to1:VoIPCallService] [cid=\(self.callID)]: Handle new call with \(self.callPartnerIdentity), we are the caller"
                        )
                        
                        if contact.contactVerificationLevel == .unverified {
                            DDLogNotice(
                                "[Call:1to1:VoIPCallService] [cid=\(self.callID)]: Force TURN since contact is unverified"
                            )
                        }
                        if let userSettings = UserSettings.shared(), userSettings.alwaysRelayCalls == true {
                            DDLogNotice(
                                "[Call:1to1:VoIPCallService] [cid=\(self.callID)]: Force TURN as requested by user"
                            )
                        }
                        
                        guard ServerConnector.shared().connectionState == .connected || ServerConnector.shared()
                            .connectionState == .loggedIn else {
                            self.noInternetConnectionError()
                            completion()
                            return
                        }
                        
                        self.peerConnectionClient.initialize(
                            contactIdentity: self.callPartnerIdentity,
                            isInitiator: true,
                            callID: self.callID,
                            peerConnectionParameters: peerConnectionParameters,
                            delegate: self
                        ) { error in
                            if let error {
                                self.callCantCreateOffer(error: error)
                                completion()
                                return
                            }
                            
                            // TODO: (IOS-5856) Handle much higher in hierarchy
                            if !ThreemaEnvironment.supportsCallKit() {
                                return
                            }
                            
                            self.peerConnectionClient.offer { sdp, sdpError in
                                if sdpError != nil {
                                    self.callCantCreateOffer(error: error)
                                    completion()
                                    return
                                }
                                guard let sdp else {
                                    self.callCantCreateOffer(error: nil)
                                    completion()
                                    return
                                }
                                
                                let offerMessage = VoIPCallOfferMessage(
                                    offer: sdp,
                                    features: nil,
                                    isVideoAvailable: self.threemaVideoCallAvailable,
                                    callID: self.callID,
                                    isOutgoing: true,
                                    completion: nil
                                )
                                offerMessage.contactIdentity = self.callPartnerIdentity
                                
                                self.voIPCallSender.sendVoIPCall(offer: offerMessage)
                                self.state = .sendOffer
                                DispatchQueue.main.async {
                                    self.initCallTimeoutTimer = Timer.scheduledTimer(
                                        withTimeInterval: self.kInitializingCallTimeout,
                                        repeats: false
                                    ) { _ in
                                        BackgroundTaskManager.shared.newBackgroundTask(
                                            key: kAppVoIPBackgroundTask,
                                            timeout: Int(kAppPushBackgroundTaskTime)
                                        ) {
                                            DispatchQueue.global(qos: .userInitiated).async {
                                                
                                                DDLogNotice(
                                                    "[Call:1to1:VoIPCallService] [cid=\(self.callID)]: Call initializing timeout"
                                                )
                                                let hangupMessage = VoIPCallHangupMessage(
                                                    contactIdentity: self.callPartnerIdentity,
                                                    callID: self.callID,
                                                    duration: self.callDurationTime != 0 ? UInt(self.callDurationTime) : nil,
                                                    isOutgoing: true
                                                )
                                                self.voIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage)
                                                
                                                self.state = .ended
                                                self.disconnectPeerConnection()
                                                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                                                    self.dismissCallView(rejected: false) {
                                                        self.callKitManager.endCall(with: self.callID)
                                                        self.invalidateInitCallTimeout()
                                                        self.delegate?.callFinished()
                                                        
                                                        guard let rootVC = SharedAppProvider.keyWindow?.rootViewController
                                                        else {
                                                            return
                                                        }
                                                        
                                                        UIAlertTemplate.showAlert(
                                                            owner: rootVC,
                                                            title: String.localizedStringWithFormat(
                                                                #localize("call_voip_not_supported_title"),
                                                                TargetManager.localizedAppName
                                                            ),
                                                            message: #localize("call_contact_not_reachable"),
                                                            titleOk: #localize("try_again"), actionOk: { _ in
                                                                VoIPCallStateManager.shared
                                                                    .startCall(callee: self.callPartnerIdentity)
                                                            }
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                self.alreadyAccepted = true
                                self.presentCallView(
                                    contactIdentity: self.callPartnerIdentity,
                                    alreadyAccepted: true,
                                    callStartedBySelf: true,
                                    isThreemaVideoCallAvailable: self.threemaVideoCallAvailable,
                                    videoActive: false,
                                    receivingVideo: false,
                                    viewWasHidden: false
                                )
                                self.callKitManager.startCall(
                                    with: self.callID,
                                    for: self.callPartnerIdentity,
                                    businessInjector: self.businessInjector
                                )
                                completion()
                            }
                        }
                    }
                }
        }
    }
    
    /// Creates the peer connection for the incoming call and set the offer if contact is set in the offer.
    /// After this, it will present the CallViewController.
    /// - parameter action: VoIPCallUserAction
    /// - parameter completion: Completion block
    private func createPeerConnectionForIncomingCall(completion: @escaping () -> Void) {
        peerConnectionClient.close()

        let entityManager = businessInjector.entityManager
        entityManager.perform {
            
            guard let offer = self.incomingOffer,
                  let identity = offer.contactIdentity,
                  let contact = entityManager.entityFetcher.contactEntity(for: identity) else {
                self.state = .idle
                completion()
                return
            }
            
            FeatureMask.check(identities: Set([identity]), for: Int(FEATURE_MASK_VOIP_VIDEO)) { _ in
                if self.incomingOffer?.isVideoAvailable ?? false, UserSettings.shared().enableVideoCall {
                    self.threemaVideoCallAvailable = true
                    self.callViewController?.enableThreemaVideoCall()
                }
                else {
                    self.threemaVideoCallAvailable = false
                    self.callViewController?.disableThreemaVideoCall()
                }
                
                LocalNetworkPermissionChecker().checkLocalNetworkPermission { granted in
                    let forceTurn = !granted ||
                        contact.contactVerificationLevel == .unverified ||
                        UserSettings.shared().alwaysRelayCalls
                    
                    let peerConnectionParameters = PeerConnectionParameters(
                        isVideoCallAvailable: self.threemaVideoCallAvailable,
                        videoCodecHwAcceleration: self.threemaVideoCallAvailable,
                        forceTurn: forceTurn,
                        gatherContinually: true,
                        allowIpv6: UserSettings.shared().enableIPv6,
                        isDataChannelAvailable: false
                    )
                    
                    self.peerConnectionClient.initialize(
                        contactIdentity: identity,
                        isInitiator: false,
                        callID: offer.callID,
                        peerConnectionParameters: peerConnectionParameters,
                        delegate: self
                    ) { error in
                        if let error {
                            DDLogError("Can't instantiate client: \(error)")
                            return
                        }
                        
                        self.peerConnectionClient.set(remoteSdp: offer.offer!) { error in
                            if let error {
                                // Something went wrong during call setup. Other devices might be able to pickup, so we
                                // do not send the reject.
                                DDLogError("We can't add the offer \(error))")
                                let action = VoIPCallUserAction(
                                    action: .reject(sendMessage: false),
                                    contactIdentity: identity,
                                    callID: offer.callID,
                                    completion: offer.completion
                                )
                                self.rejectCall(action: action)
                            }
                            
                            completion()
                        }
                    }
                }
            }
        }
    }
    
    /// Removes the peer connection, reset the call state and reset all other values
    private func disconnectPeerConnection() {
        // remove peerConnection
        
        func reset() {
            audioPlayer?.stop()
            peerConnectionClient.close()
            
            DispatchQueue.main.async {
                NavigationBarPromptHandler.isCallActiveInBackground = false
                NavigationBarPromptHandler.name = nil
                NotificationCenter.default.post(
                    name: NSNotification.Name(kNotificationNavigationItemPromptShouldChange),
                    object: nil
                )
            }
            
            state = .idle
            DispatchQueue.main.async {
                Timer.scheduledTimer(
                    withTimeInterval: self.kEndedDelay,
                    repeats: false,
                    block: { [weak self] _ in
                        guard let self, state == .idle else {
                            return
                        }

                        threemaVideoCallAvailable = false
                        alreadyAccepted = false
                        callStartedBySelf = false
                        audioMuted = false
                        speakerActive = false
                        videoActive = false
                        isReceivingVideo = false
                        incomingOffer = nil
                        localRenderer = nil
                        remoteRenderer = nil
                    }
                )
            }
        }
        
        peerConnectionClient.stopVideoCall()
        peerConnectionClient.logDebugEndStats {
            reset()
        }
    }
    
    /// Present the CallViewController on the main thread.
    /// - parameter contact: Contact of the call
    /// - parameter alreadyAccepted: Set to true if the call was already accepted
    /// - parameter callStartedBySelf: If user is the call initiator
    private func presentCallView(
        contactIdentity: String,
        alreadyAccepted: Bool,
        callStartedBySelf: Bool,
        isThreemaVideoCallAvailable: Bool,
        videoActive: Bool,
        receivingVideo: Bool,
        viewWasHidden: Bool,
        completion: (() -> Void)? = nil
    ) {
        DispatchQueue.main.async {
            var viewWasHidden = viewWasHidden
            if self.callViewController == nil {
                let callStoryboard = UIStoryboard(name: "CallStoryboard", bundle: nil)
                let callVC = callStoryboard.instantiateInitialViewController() as! CallViewController
                callVC.delegate = self
                self.callViewController = callVC
                viewWasHidden = false
            }
            
            let rootVC = self.delegate?.callViewPresentingViewController()
                ?? SharedAppProvider.keyWindow?.rootViewController
            var presentingVC = (rootVC?.presentedViewController ?? rootVC)
            
            if let navController = presentingVC as? UINavigationController {
                presentingVC = navController.viewControllers.last
            }
            
            if !(presentingVC?.isKind(of: CallViewController.self) ?? false) {
                if let presentedVC = presentingVC?.presentedViewController {
                    if presentedVC.isKind(of: CallViewController.self) {
                        return
                    }
                }
                self.showCallViewIfActive(
                    presentingVC: presentingVC,
                    viewWasHidden: viewWasHidden,
                    callStartedBySelf: callStartedBySelf,
                    isThreemaVideoCallAvailable: isThreemaVideoCallAvailable,
                    receivingVideo: receivingVideo,
                    completion: completion
                )
            }
            else {
                completion?()
            }
        }
    }
    
    private func showCallActiveAlert() {
        Task { @MainActor in
            guard let vc = SharedAppProvider.keyWindow?.rootViewController else {
                return
            }
            
            UIAlertTemplate.showOKAlert(
                owner: vc,
                title: #localize("group_call_error_already_in_call_title"),
                message: #localize("group_call_error_already_in_call_message")
            )
        }
    }
    
    private func showCallViewIfActive(
        presentingVC: UIViewController?,
        viewWasHidden: Bool,
        callStartedBySelf: Bool,
        isThreemaVideoCallAvailable: Bool,
        receivingVideo: Bool,
        completion: (() -> Void)? = nil
    ) {
        // Skip the `.active` check when presenting on a dedicated CallWindow — it sits above
        // all other windows, so presenting while the app is inactive (e.g. during biometric auth
        // or lock-screen transition) is safe and avoids delays.
        let isOnCallWindow = presentingVC?.view.window is CallWindow
        if isOnCallWindow || UIApplication.shared.applicationState == .active,
           !callViewController!.isBeingPresented,
           !isModal {
            callViewController!.viewWasHidden = viewWasHidden
            callViewController!.voIPCallStatusChanged(state: state, oldState: state)
            callViewController!.contactIdentity = callPartnerIdentity
            callViewController!.alreadyAccepted = alreadyAccepted
            callViewController!.callStartedBySelf = callStartedBySelf
            callViewController!.threemaVideoCallAvailable = isThreemaVideoCallAvailable
            callViewController!.isLocalVideoActive = videoActive
            callViewController!.isReceivingRemoteVideo = receivingVideo
            if ProcessInfoHelper.isRunningForScreenshots {
                callViewController!.isTesting = true
            }
            callViewController!.modalPresentationStyle = .overFullScreen
            presentingVC?.present(callViewController!, animated: false) {
                // need to check is fresh start, then we have to set isReceivingRemoteVideo again to show the video of
                // the remote
                if !viewWasHidden, !callStartedBySelf {
                    self.callViewController!.isReceivingRemoteVideo = receivingVideo
                }
                completion?()
            }
        }
        else {
            completion?()
        }
    }
    
    /// Dismiss the CallViewController in the main thread.
    private func dismissCallView(rejected: Bool? = false, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            guard let callVC = self.callViewController else {
                completion?()
                return
            }
            
            self.callViewController?.resetStatsTimer()
            
            if rejected == true {
                if let callViewController = self.callViewController {
                    callViewController.endButton?.isEnabled = false
                    callViewController.speakerButton?.isEnabled = false
                    callViewController.muteButton?.isEnabled = false
                }
                Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
                    callVC.dismiss(animated: true) {
                        switch self.state {
                        case .sendOffer, .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer,
                             .receivedAnswer, .initializing, .calling, .reconnecting:
                            break
                           
                        case .idle, .ended, .remoteEnded, .rejected, .rejectedTimeout, .rejectedUnknown, .microphoneDisabled:
                            self.callViewController = nil
                        }
                            
                        if SharedAppProvider.isAppLocked {
                            SharedAppProvider.presentPasscodeView()
                        }
                        completion?()
                    }
                }
            }
            else {
                callVC.dismiss(animated: true) {
                    switch self.state {
                    case .sendOffer, .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer,
                         .receivedAnswer, .initializing, .calling, .reconnecting:
                        break
                            
                    case .idle, .ended, .remoteEnded, .rejected, .rejectedTimeout, .rejectedUnknown, .microphoneDisabled:
                        self.callViewController = nil
                    }
                        
                    if SharedAppProvider.isAppLocked {
                        SharedAppProvider.presentPasscodeView()
                    }
                    completion?()
                }
            }
                
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationNavigationItemPromptShouldChange),
                object: self.callDurationTime
            )
        }
    }
    
    /// Reject the call with the reason given in the action.
    /// Will end call and dismiss the CallViewController.
    /// - parameter action: VoIPCallUserAction with the given reject reason
    /// - parameter closeCallView: Default is true. If set false, it will not disconnect the peer connection and will
    /// not close the call view
    private func rejectCall(action: VoIPCallUserAction, closeCallView: Bool? = true) {
        let reason: VoIPCallAnswerMessage.MessageRejectReason
        
        var sendMessage = false
        switch action.action {
        case .rejectUnknown:
            reason = .unknown
            if action.contactIdentity == callPartnerIdentity {
                state = .rejectedUnknown
            }
        case .rejectTimeout:
            reason = .timeout
            if action.contactIdentity == callPartnerIdentity {
                state = .rejectedTimeout
            }
        case let .reject(sendMessage: send):
            reason = .reject
            if action.contactIdentity == callPartnerIdentity {
                state = .rejectedTimeout
            }
            sendMessage = send
        default:
            reason = .reject
            if action.contactIdentity == callPartnerIdentity {
                state = .rejected
            }
        }
        
        if sendMessage {
            let answer = VoIPCallAnswerMessage(
                action: .reject,
                answer: nil,
                rejectReason: reason,
                features: nil,
                isVideoAvailable: UserSettings.shared().enableVideoCall,
                isUserInteraction: false,
                callID: action.callID,
                isOutgoing: true,
                completion: nil
            )
            answer.contactIdentity = action.contactIdentity
            voIPCallSender.sendVoIPCall(answer: answer)
        }
        
        if callPartnerIdentity == action.contactIdentity {
            callKitManager.endCall(with: callID)
            if closeCallView == true {
                // Remove peerConnection
                dismissCallView()
                disconnectPeerConnection()
            }
        }
        else {
            addRejectedMessageToConversation(for: action.contactIdentity, reason: .callMissed)
        }
    }
    
    /// Checks the current call state and play the correct tone if it's needed
    private func handleTones(state: CallState, oldState: CallState) {
        guard ProcessInfoHelper.isRunningForScreenshots == false else {
            return
        }
        
        switch state {
        case .outgoingRinging, .incomingRinging:
            guard callStartedBySelf else {
                return
            }
            
            let soundFilePath = BundleUtil.path(forResource: "ringing-tone-ch-fade", ofType: "mp3")
            let soundURL = URL(fileURLWithPath: soundFilePath!)
            playSound(soundURL: soundURL, loops: -1)
            
        case .sendOffer:
            guard callStartedBySelf else {
                return
            }
            
            // We only play the call sound after CallKit activated the audio session
            if state == .sendOffer, oldState != .sendOffer {
                break
            }
            
            let soundFilePath = BundleUtil.path(forResource: "threema_initializing", ofType: "mp3")
            let soundURL = URL(fileURLWithPath: soundFilePath!)
            playSound(soundURL: soundURL, loops: -1)
            
        case .rejected, .rejectedTimeout, .rejectedUnknown:
            if !businessInjector.pushSettingManager.canMasterDndSendPush() || !callStartedBySelf {
                // Do not play sound if dnd mode is active and user is not the call initiator
                audioPlayer?.stop()
            }
            else {
                let soundFilePath = BundleUtil.path(forResource: "busy-4x", ofType: "mp3")
                let soundURL = URL(fileURLWithPath: soundFilePath!)
                playSound(soundURL: soundURL, loops: 0)
            }
            
        case .ended, .remoteEnded:
            guard oldState != .incomingRinging else {
                audioPlayer?.stop()
                break
            }
            
            let soundFilePath = BundleUtil.path(forResource: "threema_hangup", ofType: "mp3")
            let soundURL = URL(fileURLWithPath: soundFilePath!)
            playSound(soundURL: soundURL, loops: 0)
            
        case .reconnecting:
            let soundFilePath = BundleUtil.path(forResource: "threema_problem", ofType: "mp3")
            let soundURL = URL(fileURLWithPath: soundFilePath!)
            // No `setupAudioSession()` here: this fires mid-call, where the session is already
            // configured and active, and reconfiguring it restarts the running audio unit.
            playSound(soundURL: soundURL, loops: -1)
            
        case .calling:
            let soundFilePath = BundleUtil.path(forResource: "threema_pickup", ofType: "mp3")
            let soundURL = URL(fileURLWithPath: soundFilePath!)
            // No `setupAudioSession()` here either, for the reason given under `.reconnecting`. This
            // fires at connect, so the audio unit it restarts is the one the call is about to use.
            playSound(soundURL: soundURL, loops: 0)
            
        case .idle, .receivedAnswer:
            audioPlayer?.stop()
            
        case .receivedOffer, .sendAnswer, .microphoneDisabled, .initializing:
            // Do nothing
            break
        }
    }
    
    /// Will play the given sound
    /// - parameter soundURL: URL of the sound file
    /// - parameter loop: -1 for endless
    /// - parameter playOnSpeaker: True or false if should play the tone over the speaker
    /// - Note: Some CallKit functions interfere with playing sounds.
    private func playSound(soundURL: URL, loops: Int) {
        // Do not override if we are already playing given url
        if let audioPlayer, audioPlayer.url == soundURL, audioPlayer.isPlaying {
            return
        }
        
        audioPlayer?.stop()
        
        do {
            let player = try AVAudioPlayer(contentsOf: soundURL, fileTypeHint: AVFileType.mp3.rawValue)
            player.prepareToPlay()
            player.numberOfLoops = loops
            audioPlayer = player
            player.play()
        }
        catch {
            DDLogError("[Call:1to1:VoIPCallService] [cid=\(self.callID)]: Playing sound failed with error: \(error)")
        }
    }
    
    /// Invalidate the timers per call state
    /// - parameter state: new set state of the call state
    private func invalidateTimers(state: CallState) {
        switch state {
        case .idle:
            invalidateIncomingCallTimeout()
            invalidateInitCallTimeout()
            invalidateCallDuration()
            invalidateCallFailedTimer()
            invalidateTransportExpectedStableTimer()
            invalidateOutgoingRingingCallTimeout()
            
        case .sendOffer:
            invalidateCallFailedTimer()
            invalidateOutgoingRingingCallTimeout()
            
        case .receivedOffer:
            invalidateInitCallTimeout()
            invalidateCallFailedTimer()
            invalidateOutgoingRingingCallTimeout()
            
        case .outgoingRinging:
            invalidateInitCallTimeout()
            invalidateCallFailedTimer()
            
        case .incomingRinging:
            invalidateInitCallTimeout()
            invalidateCallFailedTimer()
            invalidateOutgoingRingingCallTimeout()
            
        case .sendAnswer:
            invalidateInitCallTimeout()
            invalidateIncomingCallTimeout()
            invalidateCallFailedTimer()
            invalidateOutgoingRingingCallTimeout()
            
        case .receivedAnswer:
            invalidateInitCallTimeout()
            invalidateCallFailedTimer()
            invalidateOutgoingRingingCallTimeout()
            
        case .initializing:
            invalidateInitCallTimeout()
            invalidateIncomingCallTimeout()
            invalidateOutgoingRingingCallTimeout()
            
        case .calling:
            invalidateInitCallTimeout()
            invalidateIncomingCallTimeout()
            invalidateCallFailedTimer()
            invalidateTransportExpectedStableTimer()
            invalidateOutgoingRingingCallTimeout()
            
        case .reconnecting:
            invalidateInitCallTimeout()
            invalidateIncomingCallTimeout()
            invalidateOutgoingRingingCallTimeout()
            
        case .ended, .remoteEnded:
            invalidateInitCallTimeout()
            invalidateIncomingCallTimeout()
            invalidateCallFailedTimer()
            invalidateTransportExpectedStableTimer()
            invalidateOutgoingRingingCallTimeout()
            
        case .rejected, .rejectedTimeout, .rejectedUnknown:
            invalidateInitCallTimeout()
            invalidateCallDuration()
            invalidateIncomingCallTimeout()
            invalidateCallFailedTimer()
            invalidateTransportExpectedStableTimer()
            invalidateOutgoingRingingCallTimeout()
            
        case .microphoneDisabled:
            invalidateInitCallTimeout()
            invalidateCallDuration()
            invalidateIncomingCallTimeout()
            invalidateCallFailedTimer()
            invalidateTransportExpectedStableTimer()
            
        @unknown default:
            break
        }
    }
    
    /// Invalidate the incoming call timer
    private func invalidateIncomingCallTimeout() {
        guard let timer = incomingCallTimeoutTimer else {
            return
        }
        DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(callID)]: Invalidating incoming call timer")
        timer.invalidate()
        incomingCallTimeoutTimer = nil
    }
    
    /// Invalidate the incoming call timer
    private func invalidateOutgoingRingingCallTimeout() {
        guard let timer = outgoingRingingCallTimeoutTimer else {
            return
        }
        DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(callID)]: Invalidating outgoing ringing call timer")
        timer.invalidate()
        outgoingRingingCallTimeoutTimer = nil
    }
    
    /// Invalidate the init call timer
    private func invalidateInitCallTimeout() {
        guard let timer = initCallTimeoutTimer else {
            return
        }
        
        DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(callID)]: Invalidating init call timer")
        timer.invalidate()
        initCallTimeoutTimer = nil
    }
    
    /// Invalidate the call duration timer and set the callDurationTime to 0
    private func invalidateCallDuration() {
        guard let timer = callDurationTimer else {
            return
        }
        DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(callID)]: Invalidating call duration timer")
        timer.invalidate()
        callDurationTimer = nil
        callDurationTime = 0
    }
    
    /// Invalidate the call failed timer
    private func invalidateCallFailedTimer() {
        guard let timer = callFailedTimer else {
            return
        }
        DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(callID)]: Invalidating call failed timer")
        timer.invalidate()
        callFailedTimer = nil
    }
    
    /// Invalidate the transport expected stable
    private func invalidateTransportExpectedStableTimer() {
        guard let timer = transportExpectedStableTimer else {
            return
        }
        DDLogNotice("[Call:1to1:VoIPCallService] [cid=\(callID)]: Invalidating call stable timer")
        timer.invalidate()
        transportExpectedStableTimer = nil
    }
    
    /// Add ice candidate to local array if it's in the correct state. Start a timer to send candidates as packets all
    /// 0.05 seconds
    /// - parameter candidate: RTCIceCandidate
    private func handleLocalIceCandidates(_ candidates: [RTCIceCandidate]) {
        func addCandidateToLocalArray(_ addedCadidates: [RTCIceCandidate]) {
            iceCandidatesLockQueue.sync {
                for (_, candidate) in addedCadidates.enumerated() {
                    if shouldAdd(candidate: candidate, local: true) == (true, nil) {
                        localAddedIceCandidates.append(candidate)
                    }
                }
            }
        }
        
        switch state {
        case .sendOffer, .outgoingRinging, .receivedAnswer, .initializing, .calling, .reconnecting:
            addCandidateToLocalArray(candidates)
            let separatedCandidates = localAddedIceCandidates.take(localAddedIceCandidates.count)
            if !separatedCandidates.isEmpty {
                let message = VoIPCallIceCandidatesMessage(
                    removed: false,
                    candidates: separatedCandidates,
                    callID: callID,
                    isOutgoing: true,
                    completion: nil
                )
                message.contactIdentity = callPartnerIdentity
                voIPCallSender.sendVoIPCall(iceCandidates: message)
            }
            localAddedIceCandidates.removeAll()
            
        case .idle, .receivedOffer, .incomingRinging, .sendAnswer:
            addCandidateToLocalArray(candidates)
            
        case .ended, .remoteEnded, .rejected, .rejectedTimeout, .rejectedUnknown, .microphoneDisabled:
            // Do nothing
            break
        }
    }
    
    /// Check if should add a ice candidate
    /// - parameter candidate: RTCIceCandidate
    /// - Returns: true or false, reason
    private func shouldAdd(candidate: RTCIceCandidate, local: Bool) -> (Bool, String?) {
        let parts = candidate.sdp.components(separatedBy: CharacterSet(charactersIn: " "))
        
        // Invalid candidate but who knows what they're doing, so we'll just eat it...
        if parts.count < 8 {
            return (true, nil)
        }
        
        // Discard loopback
        let ip = parts[4]
        if ip == "127.0.0.1" || ip == "::1" {
            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(callID)]: Discarding loopback candidate: \(candidate.sdp)"
            )
            return (false, "loopback")
        }
        
        // Discard IPv6 if disabled
        if UserSettings.shared()?.enableIPv6 == false && ip.contains(":") {
            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(callID)]: Discarding local IPv6 candidate: \(candidate.sdp)"
            )
            return (false, "ipv6_disabled")
        }
        
        // Always add if not relay
        let type = parts[7]
        if type != "relay" || parts.count < 10 {
            return (true, nil)
        }
        
        // Always add if related address is any
        let relatedAddress = parts[9]
        if relatedAddress == "0.0.0.0" {
            return (true, nil)
        }
        
        if local {
            // Discard only local relay candidates with the same related address
            // Important: This only works as long as we don't do ICE restarts and don't add further relay transport types!
            if localRelatedAddresses.contains(relatedAddress) {
                DDLogNotice(
                    "[Call:1to1:VoIPCallService] [cid=\(callID)]: Discarding local relay candidate (duplicate related address: \(relatedAddress)): \(candidate.sdp)"
                )
                return (false, "duplicate_related_addr")
            }
            else {
                localRelatedAddresses.insert(relatedAddress)
            }
        }
        
        // Add it!
        return (true, nil)
    }
    
    /// Check if an IP address is IPv6
    /// - parameter ipToValidate: String of the ip
    /// - Returns: true or false
    private func isIPv6Address(_ ipToValidate: String) -> Bool {
        var sin6 = sockaddr_in6()
        if ipToValidate.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
            return true
        }
        
        return false
    }
    
    // MARK: - Missed Call

    /// Handle notification if needed
    private func handleLocalNotification() {
        switch state {
        case .idle, .sendOffer, .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer, .receivedAnswer,
             .initializing, .calling, .reconnecting, .ended, .rejected, .rejectedUnknown, .microphoneDisabled:
            break
        case .remoteEnded, .rejectedTimeout:
            addMissedCall()
        }
    }
    
    private func addMissedCall() {
        DispatchQueue.main.async {
            guard SceneDelegate.isAppInBackground,
                  !self.callStartedBySelf,
                  self.callDurationTime == 0 else {
                return
            }

            let pushSetting = self.businessInjector.pushSettingManager
                .find(forContact: ThreemaIdentity(self.callPartnerIdentity))
            let canSendPush = pushSetting.canSendPush()
            
            guard canSendPush else {
                return
            }
            
            let notification = UNMutableNotificationContent()
            notification.categoryIdentifier = NotificationActionProvider.Category.callCategory.rawValue
            
            if self.businessInjector.userSettings.pushSound != "none", !pushSetting.muted {
                notification.sound = UNNotificationSound(
                    named: UNNotificationSoundName(
                        rawValue: UserSettings
                            .shared().pushSound! + ".caf"
                    )
                )
            }
            
            let notificationType = self.businessInjector.settingsStore.notificationType
            var contact: ContactEntity?
            
            self.businessInjector.entityManager.performAndWait {
                contact = self.businessInjector.entityManager.entityFetcher.contactEntity(for: self.callPartnerIdentity)
            }
            guard let contact else {
                return
            }
            notification.userInfo = ["threema": ["cmd": "missedcall", "from": self.callPartnerIdentity]]
            
            if case .restrictive = notificationType {
                if let publicNickname = contact.publicNickname,
                   !publicNickname.isEmpty {
                    notification.title = publicNickname
                }
                else {
                    notification.title = self.callPartnerIdentity
                }
            }
            else {
                notification.title = contact.displayName
            }
            
            notification.body = #localize("call_missed")
            
            // Group notification together with others from the same contact
            notification.threadIdentifier = "SINGLE-\(self.callPartnerIdentity)"
            
            if case .complete = notificationType,
               let interaction = IntentCreator(
                   myIdentity: self.businessInjector.profileStore.profile.myIdentity,
                   userSettings: self.businessInjector.userSettings,
                   entityManager: self.businessInjector.entityManager
               ).inSendMessageIntentInteraction(
                   for: self.callPartnerIdentity,
                   direction: .incoming
               ) {
                self.showRichMissedCallNotification(
                    interaction: interaction,
                    identifier: self.callPartnerIdentity,
                    content: notification
                )
            }
            else {
                self.showRegularMissedCallNotification(with: self.callPartnerIdentity, content: notification)
            }
        }
    }
    
    private func showRegularMissedCallNotification(with identifier: String, content: UNNotificationContent) {
        let notificationRequest = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(notificationRequest)
    }
    
    private func showRichMissedCallNotification(
        interaction: INInteraction,
        identifier: String,
        content: UNNotificationContent
    ) {
        
        interaction.donate { error in
            guard error == nil else {
                self.showRegularMissedCallNotification(with: identifier, content: content)
                return
            }
            
            do {
                let updated = try content.updating(from: interaction.intent as! UNNotificationContentProviding)
                let notificationRequest = UNNotificationRequest(
                    identifier: identifier,
                    content: updated,
                    trigger: nil
                )
                
                UNUserNotificationCenter.current().add(notificationRequest, withCompletionHandler: { _ in
                })
            }
            catch {
                self.showRegularMissedCallNotification(with: identifier, content: content)
            }
        }
    }
    
    /// Add call message to conversation
    private func addCallMessageToConversation(oldCallState: CallState) {
        
        let entityManager = businessInjector.entityManager
        let utilities = ConversationActions(businessInjector: businessInjector)
        
        switch state {
        case .idle, .sendOffer, .receivedOffer, .incomingRinging, .outgoingRinging, .sendAnswer, .receivedAnswer, .initializing, .calling, .reconnecting:
            break
        case .ended, .remoteEnded:
            guard ProcessInfoHelper.isRunningForScreenshots == false else {
                return
            }
            
            // If remoteEnded is incoming at the same time like user tap on end call button
            if oldCallState == .ended || oldCallState == .remoteEnded {
                return
            }
            
            var messageRead = true
            var systemMessage: SystemMessageEntity?
            
            entityManager.performAndWaitSave {
                guard let conversation = entityManager
                    .conversation(for: self.callPartnerIdentity, createIfNotExisting: true) else {
                    DDLogError(
                        "[VoipCallService] Conversation not found for callID: \(self.callID)"
                    )
                    return
                }
                
                systemMessage = entityManager.entityCreator.systemMessageEntity(
                    for: .callEnded,
                    in: conversation
                )
                
                var callInfo = [
                    "DateString": DateFormatter.shortStyleTimeNoDate(Date()),
                    "CallInitiator": NSNumber(booleanLiteral: self.callStartedBySelf),
                ] as [String: Any]
                if self.callDurationTime > 0 {
                    callInfo["CallTime"] = DateFormatter.timeFormatted(self.callDurationTime)
                }
                
                if !self.callStartedBySelf,
                   self.callDurationTime == 0 {
                    messageRead = false
                    conversation.lastUpdate = Date.now
                }
                
                do {
                    let callInfoData = try JSONSerialization.data(withJSONObject: callInfo, options: .prettyPrinted)
                    systemMessage?.arg = callInfoData
                    systemMessage?.isOwn = NSNumber(booleanLiteral: self.callStartedBySelf)
                    
                    if let contact = entityManager.entityFetcher.contactEntity(for: self.callPartnerIdentity) {
                        let cont = Contact(contactEntity: contact)
                        systemMessage?.forwardSecurityMode = NSNumber(value: cont.forwardSecurityMode.rawValue)
                    }
                    
                    if messageRead {
                        systemMessage?.read = NSNumber(booleanLiteral: true)
                        systemMessage?.readDate = Date()
                    }

                    utilities.unarchive(conversation)
                }
                catch {
                    DDLogError(
                        "[Call:1to1:VoIPCallService] [cid=\(self.callID)]: Can't add call info to system message"
                    )
                }
            }
            if !messageRead {
                DispatchQueue.main.async {
                    let notificationManager = NotificationManager(businessInjector: BusinessInjector.ui)
                    notificationManager.updateUnreadMessagesCount(baseMessage: systemMessage)
                }
            }
        case .rejected:
            entityManager.performAndWait {
                guard let conversation = entityManager
                    .conversation(for: self.callPartnerIdentity, createIfNotExisting: true) else {
                    return
                }
                self.addRejectedMessageToConversation(for: self.callPartnerIdentity, reason: .callRejected)
                utilities.unarchive(conversation)
            }
        case .rejectedTimeout:
            entityManager.performAndWait {
                guard let conversation = entityManager
                    .conversation(for: self.callPartnerIdentity, createIfNotExisting: true) else {
                    return
                }
                let reason: SystemMessageEntity.SystemMessageEntityType = self
                    .callStartedBySelf ? .callRejectedTimeout : .callMissed
                self.addRejectedMessageToConversation(for: self.callPartnerIdentity, reason: reason)
                utilities.unarchive(conversation)
            }
        case .rejectedUnknown:
            entityManager.performAndWait {
                guard let conversation = entityManager
                    .conversation(for: self.callPartnerIdentity, createIfNotExisting: true) else {
                    return
                }
                let reason: SystemMessageEntity.SystemMessageEntityType = self
                    .callStartedBySelf ? .callRejectedUnknown : .callMissed
                self.addRejectedMessageToConversation(for: self.callPartnerIdentity, reason: reason)
                utilities.unarchive(conversation)
            }
        case .microphoneDisabled:
            entityManager.performAndWait {
                guard let conversation = entityManager
                    .conversation(for: self.callPartnerIdentity, createIfNotExisting: true) else {
                    return
                }
                utilities.unarchive(conversation)
            }
        }
    }
    
    private func addRejectedMessageToConversation(
        for callPartnerIdentity: String,
        reason: SystemMessageEntity.SystemMessageEntityType
    ) {
        var systemMessage: SystemMessageEntity?
        
        let entityManager = businessInjector.entityManager
        entityManager.performAndWaitSave {
            guard let conversation = entityManager.conversation(for: callPartnerIdentity, createIfNotExisting: true),
                  let contact = entityManager.entityFetcher.contactEntity(for: callPartnerIdentity) else {
                DDLogError(
                    "[Call:1to1:VoIPCallService] [cid=\(self.callID)]: Can't add rejected message because conversation is nil"
                )
                return
            }
            
            systemMessage = entityManager.entityCreator.systemMessageEntity(
                for: reason,
                in: conversation
            )
            
            let callInfo = [
                "DateString": DateFormatter.shortStyleTimeNoDate(Date()),
                "CallInitiator": NSNumber(booleanLiteral: self.callStartedBySelf),
            ] as [String: Any]
                
            do {
                let callInfoData = try JSONSerialization.data(withJSONObject: callInfo, options: .prettyPrinted)
                systemMessage?.arg = callInfoData
                systemMessage?.isOwn = NSNumber(booleanLiteral: self.callStartedBySelf)
                    
                let cont = Contact(contactEntity: contact)
                systemMessage?.forwardSecurityMode = NSNumber(value: cont.forwardSecurityMode.rawValue)
                    
                if reason != .callMissed,
                   reason != .callRejectedBusy,
                   reason != .callRejectedTimeout,
                   reason != .callRejectedDisabled {
                    systemMessage?.read = true
                    systemMessage?.readDate = Date()
                }
                    
                if reason == .callMissed {
                    conversation.lastUpdate = Date.now
                }
            }
            catch {
                DDLogError(
                    "[Call:1to1:VoIPCallService] [cid=\(self.callID)]: Deserialize call info failed with: \(error)"
                )
            }
        }
        
        if reason == .callMissed ||
            reason == .callRejectedBusy ||
            reason == .callRejectedTimeout ||
            reason == .callRejectedDisabled {
            DispatchQueue.main.async {
                let notificationManager = NotificationManager(businessInjector: BusinessInjector.ui)
                notificationManager.updateUnreadMessagesCount(baseMessage: systemMessage)
            }
        }
    }
    
    private func addUnknownCallIceCandidatesMessages(message: VoIPCallIceCandidatesMessage) {
        receivedIceCandidatesLockQueue.sync {
            guard let identity = message.contactIdentity else {
                return
            }
            
            if var contactCandidates = receivedUnknownCallIceCandidatesMessages[identity] {
                contactCandidates.append(message)
            }
            else {
                receivedUnknownCallIceCandidatesMessages[identity] = [message]
            }
        }
    }
    
    private func callFailed() {
        if !peerWasConnected {
            // Show error as notification
            let hangupMessage = VoIPCallHangupMessage(
                contactIdentity: callPartnerIdentity,
                callID: callID,
                duration: self.callDurationTime != 0 ? UInt(self.callDurationTime) : nil,
                isOutgoing: true
            )
            voIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage, wait: false)

            NotificationPresenterWrapper.shared.present(type: .connectedCallError)
        }
        
        invalidateCallFailedTimer()
        invalidateTransportExpectedStableTimer()
        handleTones(state: .ended, oldState: .reconnecting)
        dismissCallView {
            self.callKitManager.endCall(with: self.callID)
            guard
                self.peerWasConnected,
                let rootVC = MainActor.assumeIsolated({
                    SharedAppProvider.keyWindow?.rootViewController
                })
            else {
                return
            }
        
            UIAlertTemplate.showAlert(
                owner: rootVC,
                title: String.localizedStringWithFormat(
                    #localize("call_voip_not_supported_title"),
                    TargetManager.localizedAppName
                ),
                message: #localize("call_disconnected"),
                titleOk: #localize("try_again"), actionOk: { _ in
                    VoIPCallStateManager.shared
                        .startCall(callee: self.callPartnerIdentity)
                }
            )
        }
        disconnectPeerConnection()
        delegate?.callFinished()
    }
    
    private func callCantCreateOffer(error: Error?) {
        DDLogNotice(
            "[Call:1to1:VoIPCallService] [cid=\(callID)]: Can't create offer (\(error?.localizedDescription ?? "error is missing")"
        )
        NotificationPresenterWrapper.shared.present(type: .callCreationError)
        invalidateCallFailedTimer()
        invalidateTransportExpectedStableTimer()
        handleTones(state: .ended, oldState: .reconnecting)
        dismissCallView {
            self.callKitManager.endCall(with: self.callID)
        }
        disconnectPeerConnection()
        delegate?.callFinished()
    }
    
    /// Displays a no internet message and cancels the call
    private func noInternetConnectionError() {
        DDLogNotice(
            "[Call:1to1:VoIPCallService] [cid=\(callID)]: Can't create offer (no internet connection)"
        )
        NotificationPresenterWrapper.shared.present(type: .noConnection)
        invalidateCallFailedTimer()
        invalidateTransportExpectedStableTimer()
        dismissCallView {
            self.callKitManager.endCall(with: self.callID)
        }
        handleTones(state: .ended, oldState: .reconnecting)
        disconnectPeerConnection()
        delegate?.callFinished()
    }
}

// MARK: - VoIPCallPeerConnectionClientDelegate

extension VoIPCallService: VoIPCallPeerConnectionClientDelegate {
    func peerconnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, startTransportExpectedStableTimer: Bool) {
        DispatchQueue.main.async {
            // Schedule to expect the transport to be 'stable' after 10s. This is a workaround
            // for intermittent FAILED states.
            if self.transportExpectedStableTimer != nil {
                DDLogError(
                    "[Call:1to1:VoIPCallService] [cid=\(self.callID)]: transportExpectedStableTimer was already running!"
                )
                self.transportExpectedStableTimer?.invalidate()
                self.transportExpectedStableTimer = nil
            }
            
            self.transportExpectedStableTimer = Timer.scheduledTimer(
                withTimeInterval: self.kCallFailedTimeout,
                repeats: false,
                block: { _ in
                    self.callFailed()
                }
            )
        }
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, removedCandidates: [RTCIceCandidate]) {
        // ICE candidate messages are currently allowed to have a "removed" flag. However, this is non-standard.
        // Ignore generated ICE candidates with removed set to true coming from libwebrtc
        
        for candidate in removedCandidates {
            let reason = shouldAdd(candidate: candidate, local: true).1 ?? "unknown"
            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(callID)]: Ignoring local ICE candidate (\(reason)): \(candidate.sdp)"
            )
        }
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, addedCandidate: RTCIceCandidate) {
        handleLocalIceCandidates([addedCandidate])
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, changeState: CallState) {
        state = changeState
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, audioMuted: Bool) {
        self.audioMuted = audioMuted
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, speakerActive: Bool) {
        self.speakerActive = speakerActive
        audioSessionRequests.yield(.setOutput(speaker: speakerActive))
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, receivingVideo: Bool) {
        if isReceivingVideo != receivingVideo {
            isReceivingVideo = receivingVideo
        }
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, shouldShowCellularCallWarning: Bool) {
        self.shouldShowCellularCallWarning = shouldShowCellularCallWarning
    }
    
    func peerConnectionClient(
        _ client: VoIPCallPeerConnectionClientProtocol,
        didChangeConnectionState state: RTCPeerConnectionState
    ) {
        let oldState = self.state
        
        switch state {
        case .connecting:
            if self.state != .sendOffer, self.state != .outgoingRinging, self.state != .incomingRinging {
                self.state = .initializing
            }
            
        case .connected:
            invalidateCallFailedTimer()
            invalidateTransportExpectedStableTimer()
            
            peerWasConnected = true
            if self.state != .reconnecting {
                self.state = .calling
                DispatchQueue.main.async {
                    self.callDurationTime = 0
                    self.callDurationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                        self.callDurationTime = self.callDurationTime + 1
                        if self.state == .calling {
                            self.callViewController?.voIPCallDurationChanged(self.callDurationTime)
                        }
                        else {
                            self.callViewController?.voIPCallStatusChanged(state: self.state, oldState: self.state)
                            DDLogWarn(
                                "[Call:1to1:VoIPCallService] [cid=\(self.callID)]: State is connected, but shows something different \(self.state)"
                            )
                        }
                        if NavigationBarPromptHandler.isCallActiveInBackground == true {
                            NotificationCenter.default.post(
                                name: NSNotification.Name(kNotificationNavigationItemPromptShouldChange),
                                object: self.callDurationTime
                            )
                        }
                    }
                }
                callViewController?.startDebugMode(connection: client.peerConnection)
                callKitManager.callConnected(with: callID)
            }
            else {
                self.state = .calling
            }
            
        case .failed:
            if callFailedTimer != nil {
                invalidateCallFailedTimer()
                invalidateTransportExpectedStableTimer()
            }
            
            if transportExpectedStableTimer == nil {
                DDLogError(
                    "[Call:1to1:VoIPCallService] [cid=\(callID)]: transportExpectedStableFuture is nil as transport connection state moved into FAILED"
                )
                callFailed()
            }
            
        case .disconnected:
            if callFailedTimer == nil {
                self.state = .reconnecting
                
                // start timer and wait if state change back to connected
                DispatchQueue.main.async {
                    self.invalidateCallFailedTimer()
                    self.callFailedTimer = Timer.scheduledTimer(
                        withTimeInterval: self.kCallFailedTimeout,
                        repeats: false,
                        block: { _ in
                            self.callFailed()
                        }
                    )
                }
            }
            
        case .new, .closed:
            break
            
        @unknown default:
            break
        }
        
        if oldState != self.state {
            DDLogNotice(
                "[Call:1to1:VoIPCallService] [cid=\(callID)]: Call state change from \(oldState) to \(self.state)"
            )
        }
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, didReceiveData: Data) {
        let threemaVideoCallSignalingMessage = CallsignalingProtocol
            .decodeThreemaVideoCallSignalingMessage(didReceiveData)
        
        if let videoQualityProfile = threemaVideoCallSignalingMessage.videoQualityProfile {
            peerConnectionClient.remoteVideoQualityProfile = videoQualityProfile
        }
        
        if let captureState = threemaVideoCallSignalingMessage.captureStateChange {
            switch captureState.device {
            case .camera:
                switch captureState.state {
                case .off:
                    peerConnectionClient.isRemoteVideoActivated = false
                case .on:
                    peerConnectionClient.isRemoteVideoActivated = true
                }
            default: break
            }
        }
        
        debugPrint(threemaVideoCallSignalingMessage)
    }
    
    private func storeCallInTempHistory(offer: VoIPCallOfferMessage) {
        Task {
            if let contactIdentity = offer.contactIdentity {
                DDLogNotice(
                    "[Call:1to1:VoIPCallService] [cid=\(offer.callID)]: Start add callID to CallHistory"
                )
                await CallHistoryManager(identity: contactIdentity, businessInjector: businessInjector)
                    .store(callID: offer.callID, date: Date())
                DDLogNotice(
                    "[Call:1to1:VoIPCallService] [cid=\(offer.callID)]: End add callID to CallHistory"
                )
            }
        }
    }
}

// MARK: - VoIPCallKitManagerDelegate

extension VoIPCallService: VoIPCallKitManagerDelegate { }

// MARK: - CallViewControllerDelegate

extension VoIPCallService: CallViewControllerDelegate { }

extension Array {
    func take(_ elementsCount: Int) -> [Element] {
        let min = Swift.min(elementsCount, count)
        return Array(self[0..<min])
    }
}
