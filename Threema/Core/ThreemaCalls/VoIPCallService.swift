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
                
            case .reject, .rejectDisabled, .rejectTimeout, .rejectBusy, .rejectOffHours, .rejectUnknown:
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

            if let offer = message as? VoIPCallOfferMessage {
                log(expectedStates: [.idle], for: offer)
                callService.processVoIPCallMessage(offer)
            }
            else if let answer = message as? VoIPCallAnswerMessage {
                log(expectedStates: [.sendOffer, .outgoingRinging], for: answer)
                if callService.state != .idle {
                    callService.processVoIPCallMessage(answer)
                }
                else {
                    message.completion?()
                    callService.delegate?.callFinished()
                }
            }
            else if let ringing = message as? VoIPCallRingingMessage {
                log(expectedStates: [.sendOffer], for: ringing)
                if callService.state != .idle {
                    callService.processVoIPCallMessage(ringing)
                }
                else {
                    message.completion?()
                    callService.delegate?.callFinished()
                }
            }
            else if let hangup = message as? VoIPCallHangupMessage {
                log(expectedStates: nil, for: hangup)
                if callService.state != .idle {
                    callService.processVoIPCallMessage(hangup)
                }
                else {
                    message.completion?()
                    callService.delegate?.callFinished()
                }
            }
            else if let ice = message as? VoIPCallIceCandidatesMessage {
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
                    for: ice
                )
                if callService.state != .idle {
                    callService.processVoIPCallMessage(ice)
                }
                else {
                    message.completion?()
                    callService.delegate?.callFinished()
                }
            }
            else {
                throw VoIPCallStateMachineError.unknownVoIPCallMessageType
            }
        }

        private func processCallIDNotEqual(_ action: VoIPCallUserAction) throws {
            throw VoIPCallStateMachineError.discardUserActionCallIDNotEqual(action: action, callID: callService.callID)
        }

        private func processCallIDNotEqual(_ message: VoIPCallMessageProtocol) throws {
            if let offer = message as? VoIPCallOfferMessage {
                log(expectedStates: [.idle], for: offer)

                if offer.contactIdentity == callService.callPartnerIdentity,
                   callService.state == .reconnecting || callService.state == .calling {
                    DDLogNotice(
                        "VoipCallService: [cid=\(callService.callID.callID)]: Received offer from same identity \(callService.callPartnerIdentity) for different call with id \(offer.callID.callID). Replacing call."
                    )
                    callService.cancelCall()
                    callService.delegate?.prependCallQueueElement(message)
                    callService.delegate?.callFinished()
                }
                else {
                    let action = VoIPCallUserAction(
                        action: .rejectBusy,
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
            }
            else if let answer = message as? VoIPCallAnswerMessage {
                log(expectedStates: [.sendOffer, .outgoingRinging], for: answer)
                answer.completion?()
            }
            else if let ice = message as? VoIPCallIceCandidatesMessage {
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
                    for: ice
                )
                ice.completion?()
            }
            else {
                throw VoIPCallStateMachineError.discardMessageCallIDNotEqual(
                    message: message,
                    callID: callService.callID
                )
            }
        }

        private func log(expectedState: CallState? = nil, for action: VoIPCallUserAction) {
            if let expectedState, callService.state != expectedState {
                DDLogWarn(
                    "VoipCallService: [cid=\(callService.callID.callID)]: Wrong state \(callService.state.description()) to process user action \(action)"
                )
            }
            else {
                DDLogNotice(
                    "VoipCallService: [cid=\(callService.callID.callID)]: Process action \(action.action) on actual state \(callService.state.description())"
                )
            }
        }

        private func log(expectedStates: [CallState]? = nil, for message: VoIPCallMessageProtocol) {
            if callService.callID != message.callID {
                DDLogError(
                    "VoipCallService: [cid=\(callService.callID.callID)]: Call ID is not equals with incoming message Call ID \(message.callID.callID)"
                )
            }
            else if let expectedStates, !expectedStates.contains(callService.state) {
                DDLogWarn(
                    "VoipCallService: [cid=\(callService.callID.callID)]: Wrong state \(callService.state.description()) to process message \(message)"
                )
            }
            else {
                DDLogNotice(
                    "VoipCallService: [cid=\(callService.callID.callID)]: Process message \(message) on actual state \(callService.state.description())"
                )
            }
        }
    }

    private let voIPCallSender: VoIPCallSender
    
    private let kIncomingCallTimeout = 60.0
    private let kOutgoingRingingCallTimeout = 65.0
    private let kInitializingCallTimeout = 60.0
    private let kCallFailedTimeout = 10.0
    private let kEndedDelay = 5.0
    
    weak var delegate: VoIPCallServiceDelegate?
    
    private var peerConnectionClient: VoIPCallPeerConnectionClientProtocol
    private let callKitManager: VoIPCallKitManager
    private var threemaVideoCallAvailable = false
    private var callViewController: CallViewController?

    private var state: CallState = .idle {
        didSet {
            DDLogNotice(
                "VoipCallService: [cid=\(callID)]: State changed from \(oldValue.description()) to  \(state.description())"
            )
            
            invalidateTimers(state: state)
            callViewController?.voIPCallStatusChanged(state: state, oldState: oldValue)
            handleLocalNotification()
            
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
            handleTones(state: state, oldState: oldValue)
        }
    }

    private var audioPlayer: AVAudioPlayer?
    private let callPartnerIdentity: String
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
                "VoipCallService: [cid=\(callID.callID)]: Change receiving video to \(isReceivingVideo)"
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
                "VoipCallService: [cid=\(callID.callID)]: Change show cellular warning to \(shouldShowCellularCallWarning)"
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
    
    private let businessInjector: BusinessInjectorProtocol

    // MARK: - Lifecycle

    init(
        callPartnerIdentity: String,
        callID: VoIPCallID,
        delegate: VoIPCallServiceDelegate?,
        callKitManager: VoIPCallKitManager,
        businessInjector: BusinessInjectorProtocol = BusinessInjector.ui,
        peerConnectionClient: VoIPCallPeerConnectionClientProtocol = VoIPCallPeerConnectionClient()
    ) {
        self.callPartnerIdentity = callPartnerIdentity
        self.callID = callID
        self.delegate = delegate
        self.callKitManager = callKitManager
       
        self.businessInjector = businessInjector
        self.voIPCallSender = VoIPCallSender(
            messageSender: businessInjector.messageSender,
            myIdentityStore: businessInjector.myIdentityStore
        )
        self.peerConnectionClient = peerConnectionClient

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(observeAudioRoutes),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        callKitManager.delegate = self
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
                "VoipCallService: [cid=\(callID.callID)]: State machine failed while processing element: \(element). Error: \(error)"
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
    
    /// Set the RTC audio session from CallKit
    /// - parameter audioSession: AVAudioSession from CallKit
    func setRTCAudio(_ audioSession: AVAudioSession) {
        handleTones(state: state, oldState: state)
        RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
    }
    
    /// Configure the audio session and set RTC audio active
    func activateRTCAudio() {
        peerConnectionClient.activateRTCAudio(speakerActive: speakerActive)
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
    
    @objc private func observeAudioRoutes(_ notification: Notification) {
        guard state != .idle else {
            return
        }
        
        guard let info = notification.userInfo,
              let value = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: value) else {
            return
        }
        
        var isBluetoothAvailable = false
        if let inputs = AVAudioSession.sharedInstance().availableInputs {
            for input in inputs {
                if input.portType == AVAudioSession.Port.bluetoothA2DP ||
                    input.portType == AVAudioSession.Port.bluetoothHFP ||
                    input.portType == AVAudioSession.Port.bluetoothLE {
                    isBluetoothAvailable = true
                    continue
                }
            }
        }
            
        switch reason {
        case .categoryChange:
            let currentRoute = AVAudioSession.sharedInstance().currentRoute
                
            for output in currentRoute.outputs {
                switch output.portType {
                case .builtInReceiver:
                    if isBluetoothAvailable {
                        speakerActive = false
                        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                    }
                    if speakerActive {
                        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                    }
                    
                case .builtInSpeaker:
                    if isBluetoothAvailable {
                        speakerActive = true
                        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                    }
                    if !speakerActive {
                        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                    }
                    
                case .headphones:
                    try? AVAudioSession.sharedInstance()
                        .overrideOutputAudioPort(speakerActive ? .speaker : .none)

                case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                    break
                    
                default:
                    break
                }
            }
            
        default:
            break
        }
    }

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
        
        case .reject, .rejectDisabled, .rejectTimeout, .rejectBusy, .rejectOffHours, .rejectUnknown:
            rejectCall(action: action)
            delegate?.callFinished()
            action.completion?()
        
        case .end:
            if ProcessInfoHelper.isRunningForScreenshots {
                dismissCallView()
                delegate?.finishedProcessingCallQueueElement()
                action.completion?()
                return
            }

            DDLogNotice("VoipCallService: [cid=\(callID.callID)]: Send hangup for end action")
            if state == .sendOffer || state == .outgoingRinging || state == .sendAnswer || state ==
                .receivedAnswer ||
                state == .initializing || state == .calling || state == .reconnecting {
                RTCAudioSession.sharedInstance().isAudioEnabled = false
                let hangupMessage = VoIPCallHangupMessage(
                    contactIdentity: action.contactIdentity,
                    callID: action.callID,
                    completion: nil
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
            speakerActive = true
            peerConnectionClient.speakerOn()
            delegate?.finishedProcessingCallQueueElement()
            action.completion?()
        
        case .speakerOff:
            speakerActive = false
            peerConnectionClient.speakerOff()
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
        if let offer = message as? VoIPCallOfferMessage {
            handleOfferMessage(offer: offer) {
                offer.completion?()
                self.delegate?.finishedProcessingCallQueueElement()
            }
        }
        else if let answer = message as? VoIPCallAnswerMessage {
            handleAnswerMessage(answer: answer) {
                answer.completion?()
                self.delegate?.finishedProcessingCallQueueElement()
            }
        }
        else if let ringing = message as? VoIPCallRingingMessage {
            handleRingingMessage(ringing: ringing) {
                ringing.completion?()
                self.delegate?.finishedProcessingCallQueueElement()
            }
        }
        else if let hangup = message as? VoIPCallHangupMessage {
            handleHangupMessage(hangup: hangup) {
                hangup.completion?()
                self.delegate?.finishedProcessingCallQueueElement()
            }
        }
        else if let ice = message as? VoIPCallIceCandidatesMessage {
            handleIceCandidatesMessage(ice: ice) {
                ice.completion?()
                self.delegate?.finishedProcessingCallQueueElement()
            }
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

        DDLogNotice("VoipCallService: [cid=\(offer.callID.callID)]: Processing offer message")
        
        // Store call in temporary call history
        storeCallInTempHistory(offer: offer)
        
        guard businessInjector.userSettings.enableThreemaCall else {
            // Reject call because Threema Calls are disabled or unavailable
            let action = VoIPCallUserAction(
                action: .rejectDisabled,
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
            appRunsInBackground = AppDelegate.shared().isAppInBackground()
        }

        DDLogNotice(
            "VoipCallService: [cid=\(offer.callID.callID)]: Update lastUpdate for conversation"
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
                DDLogWarn("VoipCallService: [cid=\(offer.callID.callID)]: Master DND active, reject the call")
                let action = VoIPCallUserAction(
                    action: .rejectOffHours,
                    contactIdentity: offer.contactIdentity!,
                    callID: offer.callID,
                    completion: offer.completion
                )
                rejectCall(action: action)
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

            callKitManager.reportIncomingCall(
                with: offer.callID,
                callPartnerIdentity: offer.contactIdentity!,
                ringtoneSound: ringtoneSound,
                businessInjector: businessInjector,
                completion: { error in
                    if error != nil {
                        // Reporting call to call kit failed, we reject with an unknown reason.
                        let action = VoIPCallUserAction(
                            action: .rejectUnknown,
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

            AVAudioApplication.requestRecordPermission { granted in
                if granted {
                    self.alreadyAccepted = false
                    self.state = .receivedOffer
                    self.incomingOffer = offer
                    self.videoActive = false
                    self.isReceivingVideo = false
                    self.localRenderer = nil
                    self.remoteRenderer = nil
                    self.threemaVideoCallAvailable = offer.isVideoAvailable
                    self.startIncomingCallTimeoutTimer()
                        
                    DDLogNotice(
                        "VoipCallService: [cid=\(offer.callID.callID)]: connectWait"
                    )
                        
                    // Make sure that the connection is not prematurely disconnected when the app is put into the
                    // background
                    self.businessInjector.serverConnector.connectWait(initiator: .threemaCall)

                    DDLogNotice(
                        "VoipCallService: [cid=\(offer.callID.callID)]: Send ringing message"
                    )
                        
                    // New Call
                    // Send ringing message
                    let ringingMessage = VoIPCallRingingMessage(
                        contactIdentity: offer.contactIdentity!,
                        callID: offer.callID,
                        completion: nil
                    )
                    self.voIPCallSender.sendVoIPCallRinging(ringingMessage: ringingMessage)
                        
                    self.state = .incomingRinging
                        
                    // Prefetch ICE/TURN servers so they're likely to be already available when the user accepts the
                    // call
                    VoIPIceServerSource.prefetchIceServers()
                        
                    if !ThreemaEnvironment.supportsCallKit() {
                        self.presentCallView(
                            contactIdentity: offer.contactIdentity!,
                            alreadyAccepted: false,
                            callStartedBySelf: false,
                            isThreemaVideoCallAvailable: self.threemaVideoCallAvailable,
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
                    DDLogWarn("VoipCallService: [cid=\(offer.callID.callID)]: Audio is not granted")
                    self.state = .microphoneDisabled
                    // Reject call because there is no permission for the microphone
                    self.state = .rejectedDisabled
                    let action = VoIPCallUserAction(
                        action: .rejectUnknown,
                        contactIdentity: offer.contactIdentity!,
                        callID: offer.callID,
                        completion: offer.completion
                    )
                    self.rejectCall(action: action, closeCallView: false)
                    
                    // Show alert if mic permission is not granted
                    if let rootVC = AppDelegate.keyWindow?.rootViewController {
                        UIAlertTemplate.showOpenSettingsAlert(owner: rootVC, noAccessAlertType: .microphone)
                    }
                    
                    self.disconnectPeerConnection()
                    self.delegate?.callFinished()
                    completion()
                }
            }
        }
        else {
            DDLogWarn(
                "VoipCallService: [cid=\(offer.callID.callID)]: Current state is not IDLE (\(state.description()))"
            )
            if callPartnerIdentity == offer.contactIdentity, state == .incomingRinging {
                DDLogNotice("Threema call: handleOfferMessage -> same contact as the current call")
                if !businessInjector.pushSettingManager.canMasterDndSendPush(), appRunsInBackground {
                    DDLogNotice(
                        "Threema call: handleOfferMessage -> Master DND active -> reject call from \(String(describing: offer.contactIdentity))"
                    )
                    let action = VoIPCallUserAction(
                        action: .rejectOffHours,
                        contactIdentity: offer.contactIdentity!,
                        callID: offer.callID,
                        completion: offer.completion
                    )
                    rejectCall(action: action)
                    completion()
                }
                else {
                    DDLogWarn(
                        "VoipCallService: [cid=\(offer.callID.callID)]: Same contact as the current call ((\(offer.contactIdentity ?? "?")), Master DND inactive, set the offer"
                    )
                    disconnectPeerConnection()
                    handleOfferMessage(offer: offer, completion: completion)
                }
            }
            else {
                // reject call because it's the wrong state
                let reason: VoIPCallUserAction.Action = callPartnerIdentity == offer
                    .contactIdentity ? .rejectUnknown : .rejectBusy
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
                    let action = VoIPCallUserAction(
                        action: .rejectTimeout,
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
        
        DDLogNotice("VoipCallService: [cid=\(answer.callID.callID)]: Processing answer message")
        
        if callStartedBySelf {
            if state == .sendOffer || state == .outgoingRinging,
               callPartnerIdentity == answer.contactIdentity,
               callID.callID == answer.callID.callID {
                state = .receivedAnswer
                if answer.action == VoIPCallAnswerMessage.MessageAction.reject {
                    // Call was rejected
                    switch answer.rejectReason {
                    case .busy?:
                        state = .rejectedBusy
                    case .timeout?:
                        state = .rejectedTimeout
                    case .reject?:
                        state = .rejected
                    case .disabled?:
                        state = .rejectedDisabled
                    case .offHours?:
                        state = .rejectedOffHours
                    case .none:
                        state = .rejected
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
                                    "VoipCallService: [cid=\(answer.callID.callID)]: Can't add remote sdp to the peerConnection"
                                )
                                let hangupMessage = VoIPCallHangupMessage(
                                    contactIdentity: self.callPartnerIdentity,
                                    callID: self.callID,
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
                        DDLogError("VoipCallService: [cid=\(answer.callID.callID)]: Remote sdp is empty")
                        let hangupMessage = VoIPCallHangupMessage(
                            contactIdentity: callPartnerIdentity,
                            callID: callID,
                            completion: nil
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
                        "VoipCallService: [cid=\(answer.callID.callID)]: Current state is wrong (\(state.description())) or callID is different to \(callID.callID)"
                    )
                }
                else {
                    DDLogWarn(
                        "VoipCallService: [cid=\(answer.callID.callID)]: Answer contact (\(answer.contactIdentity ?? "?") is different to current call contact (\(callPartnerIdentity)"
                    )
                }
                completion()
            }
        }
        else {
            // We are not the initiator so we can ignore this message
            DDLogWarn("VoipCallService: [cid=\(answer.callID.callID)]: No initiator, ignore this answer")
            completion()
        }
    }
    
    /// Handle the ringing message if the contact in the answer message is the same as in the call service and call
    /// state is sendOffer.
    /// CallViewController will play the ringing tone
    /// - parameter ringing: VoIPCallRingingMessage
    /// - parameter completion: Completion block
    private func handleRingingMessage(ringing: VoIPCallRingingMessage, completion: @escaping (() -> Void)) {
        DDLogNotice("VoipCallService: [cid=\(ringing.callID.callID)]: Processing ringing message")
        
        if callPartnerIdentity == ringing.contactIdentity,
           callID.callID == ringing.callID.callID {
            switch state {
            case .sendOffer:
                state = .outgoingRinging
                startOutgoingRingingCallTimeoutTimer()
            default:
                DDLogWarn(
                    "VoipCallService: [cid=\(ringing.callID.callID)]: Wrong state (\(state.description())) to handle ringing message"
                )
            }
        }
        else {
            DDLogWarn(
                "VoipCallService: [cid=\(ringing.callID.callID)]: Ringing contact (\(ringing.contactIdentity ?? "?") is different to current call contact (\(callPartnerIdentity)"
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
                        RTCAudioSession.sharedInstance().isAudioEnabled = false
                            
                        DDLogNotice(
                            "VoipCallService: [cid=\(self.callID)]: Call ringing timeout"
                        )
                        let hangupMessage = VoIPCallHangupMessage(
                            contactIdentity: self.callPartnerIdentity,
                            callID: self.callID,
                            completion: nil
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
        DDLogNotice("VoipCallService: [cid=\(ice.callID.callID)]: Processing ICE candidate message")
        
        for candidate in ice.candidates {
            DDLogNotice("VoipCallService: [cid=\(ice.callID.callID)]: Incoming ICE candidate: \(candidate.sdp)")
        }
        if callPartnerIdentity == ice.contactIdentity,
           callID.callID == ice.callID.callID {
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
                
            default:
                DDLogWarn(
                    "VoipCallService: [cid=\(ice.callID.callID)]: Wrong state (\(state.description())) to handle ICE candidates message"
                )
                completion()
            }
        }
        else {
            addUnknownCallIceCandidatesMessages(message: ice)
            DDLogNotice(
                "VoipCallService: [cid=\(ice.callID.callID)]: ICE candidates contact (\(ice.contactIdentity ?? "?") is different to current call contact (\(callPartnerIdentity)"
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
        DDLogNotice("VoipCallService: [cid=\(hangup.callID.callID)]: Processing hangup message")
        
        if callPartnerIdentity == hangup.contactIdentity, callID.callID == hangup.callID.callID {
            switch state {
            case .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer, .initializing, .calling,
                 .reconnecting:
                cancelCall()
            default:
                DDLogWarn(
                    "VoipCallService: [cid=\(hangup.callID.callID)]: Wrong state (\(state.description())) to handle hangup message"
                )
                delegate?.callFinished()
            }
        }
        else {
            DDLogNotice(
                "VoipCallService: [cid=\(hangup.callID.callID)]: Hangup contact (\(hangup.contactIdentity ?? "?") is different to current call contact (\(callPartnerIdentity)"
            )
            delegate?.callFinished()
        }

        completion()
    }

    private func cancelCall() {
        RTCAudioSession.sharedInstance().isAudioEnabled = false
        state = .remoteEnded
        callKitManager.endCall(with: callID)
        dismissCallView()
        disconnectPeerConnection()
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
        
        if UserSettings.shared().enableThreemaCall {
            RTCAudioSession.sharedInstance().useManualAudio = true
            if state == .idle {
                AVAudioApplication.requestRecordPermission { granted in
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
                            guard let rootVC = AppDelegate.keyWindow?.rootViewController else {
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
            else {
                // do nothing because it's the wrong state
                DDLogWarn(
                    "VoipCallService: [cid=\(action.callID.callID)]: Wrong state (\(state.description())) to start call as initiator"
                )
                showCallActiveAlert()
                completion()
            }
        }
        else {
            // do nothing because Threema calls are disabled or unavailable
            completion()
        }
    }
    
    /// Accept a incoming call if state is ringing. Will send a answer message to initiator and update
    /// CallViewController.
    /// It will present the CallViewController.
    /// - parameter action: VoIPCallUserAction
    /// - parameter completion: Completion block
    private func acceptIncomingCall(action: VoIPCallUserAction, completion: @escaping (() -> Void)) {
        createPeerConnectionForIncomingCall {
            RTCAudioSession.sharedInstance().useManualAudio = true
            if self.state == .incomingRinging, !NavigationBarPromptHandler.isGroupCallActive {
                /// Make sure that the connection is not prematurely disconnected when the app is put into the
                /// background
                self.businessInjector.serverConnector.connect(initiator: .threemaCall)
                self.state = .sendAnswer
                self.presentCallViewController()
                
                self.peerConnectionClient.answer(completion: { sdp, sdpError in
                    if sdpError != nil {
                        let action = VoIPCallUserAction(
                            action: .reject,
                            contactIdentity: action.contactIdentity,
                            callID: action.callID,
                            completion: action.completion
                        )
                        self.rejectCall(action: action)
                        completion()
                        return
                    }
                    
                    if self.threemaVideoCallAvailable, UserSettings.shared().enableVideoCall {
                        self.threemaVideoCallAvailable = true
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
                })
            }
            else {
                // dismiss call view because it's the wrong state
                DDLogWarn(
                    "VoipCallService: [cid=\(action.callID.callID)]: Wrong state (\(self.state.description())) to accept incoming call action"
                )
                self.callKitManager.answerFailed()
                self.dismissCallView()
                self.disconnectPeerConnection()
                self.delegate?.callFinished()
                completion()
                return
            }
        }
    }
    
    /// Creates the peer connection for the initiator and set the offer.
    /// After this, it will present the CallViewController.
    /// - parameter action: VoIPCallUserAction
    /// - parameter completion: Completion block
    private func createPeerConnectionForInitiator(action: VoIPCallUserAction, completion: @escaping (() -> Void)) {
        let entityManager = businessInjector.entityManager
        entityManager.performBlock {
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
                            ).store(callID: self.callID.callID, date: Date())
                        }
                        
                        DDLogNotice(
                            "VoipCallService: [cid=\(self.callID.callID)]: Handle new call with \(self.callPartnerIdentity), we are the caller"
                        )
                        
                        if contact.contactVerificationLevel == .unverified {
                            DDLogNotice(
                                "VoipCallService: [cid=\(self.callID.callID)]: Force TURN since contact is unverified"
                            )
                        }
                        if let userSettings = UserSettings.shared(), userSettings.alwaysRelayCalls == true {
                            DDLogNotice("VoipCallService: [cid=\(self.callID.callID)]: Force TURN as requested by user")
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
                            
                            self.peerConnectionClient.offer {
                                sdp,
                                    sdpError in
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
                                                RTCAudioSession.sharedInstance().isAudioEnabled = false
                                                
                                                DDLogNotice(
                                                    "VoipCallService: [cid=\(self.callID)]: Call initalizing timeout"
                                                )
                                                let hangupMessage = VoIPCallHangupMessage(
                                                    contactIdentity: self.callPartnerIdentity,
                                                    callID: self.callID,
                                                    completion: nil
                                                )
                                                self.voIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage)
                                                
                                                self.state = .ended
                                                self.disconnectPeerConnection()
                                                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                                                    self.dismissCallView(rejected: false) {
                                                        self.callKitManager.endCall(with: self.callID)
                                                        self.invalidateInitCallTimeout()
                                                        self.delegate?.callFinished()
                                                        
                                                        guard let rootVC = AppDelegate.keyWindow?.rootViewController
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
        entityManager.performBlock {
            
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
                        
                        self.peerConnectionClient.set(remoteSdp: offer.offer!, completion: { error in
                            if let error {
                                // reject because we can't add offer
                                DDLogError("We can't add the offer \(error))")
                                let action = VoIPCallUserAction(
                                    action: .reject,
                                    contactIdentity: identity,
                                    callID: offer.callID,
                                    completion: offer.completion
                                )
                                self.rejectCall(action: action)
                            }
                            
                            completion()
                        })
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

                        // Maybe is better not do a disconnect here, because after a possible disconnect
                        // no further (VoIP) messages will be processed
                        businessInjector.serverConnector.disconnect(initiator: .threemaCall)
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
            
            let rootVC = AppDelegate.keyWindow?.rootViewController
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
            guard let vc = AppDelegate.keyWindow?.rootViewController else {
                return
            }
            
            UIAlertTemplate.showAlert(
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
        if UIApplication.shared.applicationState == .active,
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
            presentingVC?.present(callViewController!, animated: false, completion: {
                // need to check is fresh start, then we have to set isReceivingRemotVideo again to show the video of
                // the remote
                if !viewWasHidden, !callStartedBySelf {
                    self.callViewController!.isReceivingRemoteVideo = receivingVideo
                }
                completion?()
            })
        }
        else {
            completion?()
        }
    }
    
    /// Dismiss the CallViewController in the main thread.
    private func dismissCallView(rejected: Bool? = false, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            if let callVC = self.callViewController {
                self.callViewController?.resetStatsTimer()
                if rejected == true {
                    if let callViewController = self.callViewController {
                        callViewController.endButton?.isEnabled = false
                        callViewController.speakerButton?.isEnabled = false
                        callViewController.muteButton?.isEnabled = false
                    }
                    Timer.scheduledTimer(withTimeInterval: 4, repeats: false, block: { _ in
                        callVC.dismiss(animated: true, completion: {
                            switch self.state {
                            case .sendOffer, .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer,
                                 .receivedAnswer, .initializing, .calling, .reconnecting: break
                            case .idle, .ended, .remoteEnded, .rejected, .rejectedBusy, .rejectedTimeout,
                                 .rejectedDisabled, .rejectedOffHours, .rejectedUnknown, .microphoneDisabled:
                                self.callViewController = nil
                            }
                            if AppDelegate.shared()?.isAppLocked == true {
                                AppDelegate.shared()?.presentPasscodeView()
                            }
                            completion?()
                        })
                    })
                }
                else {
                    callVC.dismiss(animated: true, completion: {
                        switch self.state {
                        case .sendOffer, .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer,
                             .receivedAnswer, .initializing, .calling, .reconnecting: break
                        case .idle, .ended, .remoteEnded, .rejected, .rejectedBusy, .rejectedTimeout, .rejectedDisabled,
                             .rejectedOffHours, .rejectedUnknown, .microphoneDisabled:
                            self.callViewController = nil
                        }
                        if AppDelegate.shared()?.isAppLocked == true {
                            AppDelegate.shared()?.presentPasscodeView()
                        }
                        completion?()
                    })
                }
                
                NotificationCenter.default.post(
                    name: NSNotification.Name(rawValue: kNotificationNavigationItemPromptShouldChange),
                    object: self.callDurationTime
                )
            }
            else {
                completion?()
            }
        }
    }
    
    /// Reject the call with the reason given in the action.
    /// Will end call and dismiss the CallViewController.
    /// - parameter action: VoIPCallUserAction with the given reject reason
    /// - parameter closeCallView: Default is true. If set false, it will not disconnect the peer connection and will
    /// not close the call view
    private func rejectCall(action: VoIPCallUserAction, closeCallView: Bool? = true) {
        var reason: VoIPCallAnswerMessage.MessageRejectReason = .reject
        
        switch action.action {
        case .rejectDisabled:
            reason = .disabled
            if action.contactIdentity == callPartnerIdentity {
                state = .rejectedDisabled
            }
        case .rejectTimeout:
            reason = .timeout
            if action.contactIdentity == callPartnerIdentity {
                state = .rejectedTimeout
            }
        case .rejectBusy:
            reason = .busy
            if action.contactIdentity == callPartnerIdentity {
                state = .rejectedBusy
            }
        case .rejectOffHours:
            reason = .offHours
            if action.contactIdentity == callPartnerIdentity {
                state = .rejectedOffHours
            }
        case .rejectUnknown:
            reason = .unknown
            if action.contactIdentity == callPartnerIdentity {
                state = .rejectedUnknown
            }
        default:
            if action.contactIdentity == callPartnerIdentity {
                state = .rejected
            }
        }
        
        let answer = VoIPCallAnswerMessage(
            action: .reject,
            answer: nil,
            rejectReason: reason,
            features: nil,
            isVideoAvailable: UserSettings.shared().enableVideoCall,
            isUserInteraction: false,
            callID: action.callID,
            completion: nil
        )
        answer.contactIdentity = action.contactIdentity
        voIPCallSender.sendVoIPCall(answer: answer)
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
    
    /// It will check the current call state and play the correct tone if it's needed
    private func handleTones(state: CallState, oldState: CallState) {
        if ProcessInfoHelper.isRunningForScreenshots {
            return
        }
        
        switch state {
        case .outgoingRinging, .incomingRinging:
            guard callStartedBySelf else {
                return
            }
            
            let soundFilePath = BundleUtil.path(forResource: "ringing-tone-ch-fade", ofType: "mp3")
            let soundURL = URL(fileURLWithPath: soundFilePath!)
            setupAudioSession()
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
            setupAudioSession()
            playSound(soundURL: soundURL, loops: -1)
            
        case .rejected, .rejectedBusy, .rejectedTimeout, .rejectedOffHours, .rejectedUnknown, .rejectedDisabled:
            if !businessInjector.pushSettingManager.canMasterDndSendPush() || !callStartedBySelf {
                // do not play sound if dnd mode is active and user is not the call initiator
                audioPlayer?.stop()
            }
            else {
                let soundFilePath = BundleUtil.path(forResource: "busy-4x", ofType: "mp3")
                let soundURL = URL(fileURLWithPath: soundFilePath!)
                setupAudioSession()
                playSound(soundURL: soundURL, loops: 0)
            }
            
        case .ended, .remoteEnded:
            guard oldState != .incomingRinging else {
                audioPlayer?.stop()
                break
            }
            
            let soundFilePath = BundleUtil.path(forResource: "threema_hangup", ofType: "mp3")
            let soundURL = URL(fileURLWithPath: soundFilePath!)
            setupAudioSession()
            playSound(soundURL: soundURL, loops: 0)
            
        case .reconnecting:
            let soundFilePath = BundleUtil.path(forResource: "threema_problem", ofType: "mp3")
            let soundURL = URL(fileURLWithPath: soundFilePath!)
            setupAudioSession()
            playSound(soundURL: soundURL, loops: -1)
            
        case .calling:
            let soundFilePath = BundleUtil.path(forResource: "threema_pickup", ofType: "mp3")
            let soundURL = URL(fileURLWithPath: soundFilePath!)
            setupAudioSession()
            playSound(soundURL: soundURL, loops: 0)
            
        case .idle, .receivedAnswer:
            audioPlayer?.stop()
            
        case .receivedOffer, .sendAnswer, .microphoneDisabled, .initializing:
            // Do nothing
            break
        }
    }
    
    private func setupAudioSession(_ soloAmbient: Bool = false) {
        let audioSession = AVAudioSession.sharedInstance()
        if soloAmbient {
            do {
                try audioSession.setCategory(.soloAmbient, mode: .default, options: .threemaCategoryOptions)
                try audioSession.overrideOutputAudioPort(speakerActive ? .speaker : .none)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            }
            catch {
                print(error.localizedDescription)
            }
        }
        else {
            do {
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: .threemaCategoryOptions)
                try audioSession.overrideOutputAudioPort(speakerActive ? .speaker : .none)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            }
            catch {
                print(error.localizedDescription)
            }
        }
    }
    
    /// It will play the given sound
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
            print(error.localizedDescription)
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
            
        case .rejected, .rejectedBusy, .rejectedTimeout, .rejectedDisabled, .rejectedOffHours, .rejectedUnknown:
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
        DDLogNotice("VoipCallService: [cid=\(callID)]: Invalidating incoming call timer")
        timer.invalidate()
        incomingCallTimeoutTimer = nil
    }
    
    /// Invalidate the incoming call timer
    private func invalidateOutgoingRingingCallTimeout() {
        guard let timer = outgoingRingingCallTimeoutTimer else {
            return
        }
        DDLogNotice("VoipCallService: [cid=\(callID)]: Invalidating outgoing ringing call timer")
        timer.invalidate()
        outgoingRingingCallTimeoutTimer = nil
    }
    
    /// Invalidate the init call timer
    private func invalidateInitCallTimeout() {
        guard let timer = initCallTimeoutTimer else {
            return
        }
        DDLogNotice("VoipCallService: [cid=\(callID)]: Invalidating init call timer")
        timer.invalidate()
        initCallTimeoutTimer = nil
    }
    
    /// Invalidate the call duration timer and set the callDurationTime to 0
    private func invalidateCallDuration() {
        guard let timer = callDurationTimer else {
            return
        }
        DDLogNotice("VoipCallService: [cid=\(callID)]: Invalidating call duration timer")
        timer.invalidate()
        callDurationTimer = nil
        callDurationTime = 0
    }
    
    /// Invalidate the call failed timer
    private func invalidateCallFailedTimer() {
        guard let timer = callFailedTimer else {
            return
        }
        DDLogNotice("VoipCallService: [cid=\(callID)]: Invalidating call failed timer")
        timer.invalidate()
        callFailedTimer = nil
    }
    
    /// Invalidate the transport expected stable
    private func invalidateTransportExpectedStableTimer() {
        guard let timer = transportExpectedStableTimer else {
            return
        }
        DDLogNotice("VoipCallService: [cid=\(callID)]: Invalidating call stable timer")
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
                    completion: nil
                )
                message.contactIdentity = callPartnerIdentity
                voIPCallSender.sendVoIPCall(iceCandidates: message)
            }
            localAddedIceCandidates.removeAll()
            
        case .idle, .receivedOffer, .incomingRinging, .sendAnswer:
            addCandidateToLocalArray(candidates)
            
        case .ended, .remoteEnded, .rejected, .rejectedBusy, .rejectedTimeout, .rejectedOffHours, .rejectedUnknown,
             .rejectedDisabled, .microphoneDisabled:
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
                "VoipCallService: [cid=\(callID.callID)]: Discarding loopback candidate: \(candidate.sdp)"
            )
            return (false, "loopback")
        }
        
        // Discard IPv6 if disabled
        if UserSettings.shared()?.enableIPv6 == false && ip.contains(":") {
            DDLogNotice(
                "VoipCallService: [cid=\(callID.callID)]: Discarding local IPv6 candidate: \(candidate.sdp)"
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
                    "VoipCallService: [cid=\(callID.callID)]: Discarding local relay candidate (duplicate related address: \(relatedAddress)): \(candidate.sdp)"
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
             .initializing, .calling, .reconnecting, .ended, .rejected, .rejectedOffHours, .rejectedUnknown,
             .rejectedDisabled, .microphoneDisabled:
            break
        case .remoteEnded, .rejectedBusy, .rejectedTimeout:
            addMissedCall()
        }
    }
    
    private func addMissedCall() {
        DispatchQueue.main.async {
            guard AppDelegate.shared().isAppInBackground(),
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
        case .idle:
            break
        case .sendOffer:
            break
        case .receivedOffer:
            break
        case .incomingRinging:
            break
        case .outgoingRinging:
            break
        case .sendAnswer:
            break
        case .receivedAnswer:
            break
        case .initializing:
            break
        case .calling:
            break
        case .reconnecting:
            break
        case .ended, .remoteEnded:
            // add call message
            if ProcessInfoHelper.isRunningForScreenshots {
                return
            }
            
            // if remoteEnded is incoming at the same time like user tap on end call button
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
                        "VoipCallService: [cid=\(self.callID)]: Can't add call info to system message"
                    )
                }
            }
            if !messageRead {
                DispatchQueue.main.async {
                    let notificationManager = NotificationManager()
                    notificationManager.updateUnreadMessagesCount(baseMessage: systemMessage)
                }
            }
        case .rejected:
            // add call message
            entityManager.performAndWait {
                guard let conversation = entityManager
                    .conversation(for: self.callPartnerIdentity, createIfNotExisting: true) else {
                    return
                }
                self.addRejectedMessageToConversation(for: self.callPartnerIdentity, reason: .callRejected)
                utilities.unarchive(conversation)
            }
        case .rejectedTimeout:
            // add call message
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
        case .rejectedBusy:
            entityManager.performAndWait {
                // add call message
                guard let conversation = entityManager
                    .conversation(for: self.callPartnerIdentity, createIfNotExisting: true) else {
                    return
                }
                let reason: SystemMessageEntity.SystemMessageEntityType = self
                    .callStartedBySelf ? .callRejectedBusy : .callMissed
                self.addRejectedMessageToConversation(for: self.callPartnerIdentity, reason: reason)
                utilities.unarchive(conversation)
            }
        case .rejectedOffHours:
            entityManager.performAndWait {
                // add call message
                guard let conversation = entityManager
                    .conversation(for: self.callPartnerIdentity, createIfNotExisting: true) else {
                    return
                }
                let reason: SystemMessageEntity.SystemMessageEntityType = self
                    .callStartedBySelf ? .callRejectedOffHours : .callMissed
                self.addRejectedMessageToConversation(for: self.callPartnerIdentity, reason: reason)
                utilities.unarchive(conversation)
            }
        case .rejectedUnknown:
            entityManager.performAndWait {
                // add call message
                guard let conversation = entityManager
                    .conversation(for: self.callPartnerIdentity, createIfNotExisting: true) else {
                    return
                }
                let reason: SystemMessageEntity.SystemMessageEntityType = self
                    .callStartedBySelf ? .callRejectedUnknown : .callMissed
                self.addRejectedMessageToConversation(for: self.callPartnerIdentity, reason: reason)
                utilities.unarchive(conversation)
            }
        case .rejectedDisabled:
            // add call message
            entityManager.performAndWait {
                if self.callStartedBySelf {
                    guard let conversation = entityManager.conversation(
                        for: self.callPartnerIdentity,
                        createIfNotExisting: true
                    ) else {
                        return
                    }
                    self.addRejectedMessageToConversation(
                        for: self.callPartnerIdentity,
                        reason: .callRejectedDisabled
                    )
                    utilities.unarchive(conversation)
                }
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
            if let conversation = entityManager.conversation(for: callPartnerIdentity, createIfNotExisting: true),
               let contact = entityManager.entityFetcher.contactEntity(for: callPartnerIdentity) {
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
                    print(error)
                }
            }
            else {
                DDLogNotice("Threema Calls: Can't add rejected message because conversation is nil")
            }
        }
        if reason == .callMissed || reason == .callRejectedBusy || reason ==
            .callRejectedTimeout || reason == .callRejectedDisabled {
            DispatchQueue.main.async {
                let notificationManager = NotificationManager()
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
    
    private func sdpContainsVideo(sdp: RTCSessionDescription?) -> Bool {
        guard sdp != nil else {
            return false
        }
        return sdp!.sdp.contains("m=video")
    }
    
    private func callFailed() {
        if !peerWasConnected {
            // show error as notification
            let hangupMessage = VoIPCallHangupMessage(
                contactIdentity: callPartnerIdentity,
                callID: callID,
                completion: nil
            )
            voIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage, wait: false)

            NotificationPresenterWrapper.shared.present(type: .connectedCallError)
        }
        
        invalidateCallFailedTimer()
        invalidateTransportExpectedStableTimer()
        handleTones(state: .ended, oldState: .reconnecting)
        dismissCallView {
            self.callKitManager.endCall(with: self.callID)
            guard self.peerWasConnected, let rootVC = AppDelegate.keyWindow?.rootViewController else {
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
            "VoipCallService: [cid=\(callID.callID)]: Can't create offer (\(error?.localizedDescription ?? "error is missing")"
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
            "VoipCallService: [cid=\(callID.callID)]: Can't create offer (no internet connection)"
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
                    "VoipCallService: [cid=\(self.callID.callID)]: transportExpectedStableTimer was already running!"
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
                "VoipCallService: [cid=\(callID.callID)]: Ignoring local ICE candidate (\(reason)): \(candidate.sdp)"
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
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            let mode: AVAudioSession.Mode = speakerActive ? .videoChat : .voiceChat
            try audioSession.setCategory(.playAndRecord, mode: mode, options: .threemaCategoryOptions)
            try audioSession.overrideOutputAudioPort(speakerActive ? .speaker : .none)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        }
        catch {
            print(error.localizedDescription)
        }
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
                                "VoipCallService: [cid=\(self.callID.callID)]: State is connected, but shows something different \(self.state.description())"
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
            activateRTCAudio()
            
        case .failed:
            if callFailedTimer != nil {
                invalidateCallFailedTimer()
                invalidateTransportExpectedStableTimer()
            }
            
            if transportExpectedStableTimer == nil {
                DDLogError(
                    "VoipCallService: [cid=\(callID.callID)]: transportExpectedStableFuture is nil as transport connection state moved into FAILED"
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
                "VoipCallService: [cid=\(callID.callID)]: Call state change from \(oldState.description()) to \(self.state.description())"
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
                    "VoipCallService: [cid=\(offer.callID.callID)]: Start add callID to CallHistory"
                )
                await CallHistoryManager(identity: contactIdentity, businessInjector: businessInjector)
                    .store(callID: offer.callID.callID, date: Date())
                DDLogNotice(
                    "VoipCallService: [cid=\(offer.callID.callID)]: End add callID to CallHistory"
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
