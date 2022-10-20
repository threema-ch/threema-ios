//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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
import ThreemaFramework

protocol VoIPCallServiceDelegate: AnyObject {
    func callServiceFinishedProcess()
}

class VoIPCallService: NSObject {
    
    private let voIPCallSender: VoIPCallSender
    
    private let kIncomingCallTimeout = 60.0
    private let kCallFailedTimeout = 15.0
    private let kEndedDelay = 5.0
    
    @objc public enum CallState: Int, RawRepresentable, Equatable {
        case idle
        case sendOffer
        case receivedOffer
        case outgoingRinging
        case incomingRinging
        case sendAnswer
        case receivedAnswer
        case initializing
        case calling
        case reconnecting
        case ended
        case remoteEnded
        case rejected
        case rejectedBusy
        case rejectedTimeout
        case rejectedDisabled
        case rejectedOffHours
        case rejectedUnknown
        case microphoneDisabled
        
        /// Return the string of the current state for the ValidationLogger
        /// - Returns: String of the current state
        func description() -> String {
            switch self {
            case .idle: return "IDLE"
            case .sendOffer: return "SENDOFFER"
            case .receivedOffer: return "RECEIVEDOFFER"
            case .outgoingRinging: return "RINGING"
            case .incomingRinging: return "RINGING"
            case .sendAnswer: return "SENDANSWER"
            case .receivedAnswer: return "RECEIVEDANSWER"
            case .initializing: return "INITIALIZING"
            case .calling: return "CALLING"
            case .reconnecting: return "RECONNECTING"
            case .ended: return "ENDED"
            case .remoteEnded: return "REMOTEENDED"
            case .rejected: return "REJECTED"
            case .rejectedBusy: return "REJECTEDBUSY"
            case .rejectedTimeout: return "REJECTEDTIMEOUT"
            case .rejectedDisabled: return "REJECTEDDISABLED"
            case .rejectedOffHours: return "REJECTEDOFFHOURS"
            case .rejectedUnknown: return "REJECTEDUNKNOWN"
            case .microphoneDisabled: return "MICROPHONEDISABLED"
            }
        }
        
        /// Get the localized string for the current state
        /// - Returns: Current localized call state string
        func localizedString() -> String {
            switch self {
            case .idle: return BundleUtil.localizedString(forKey: "call_status_idle")
            case .sendOffer: return BundleUtil.localizedString(forKey: "call_status_wait_ringing")
            case .receivedOffer: return BundleUtil.localizedString(forKey: "call_status_wait_ringing")
            case .outgoingRinging: return BundleUtil.localizedString(forKey: "call_status_ringing")
            case .incomingRinging: return BundleUtil.localizedString(forKey: "call_status_incom_ringing")
            case .sendAnswer: return BundleUtil.localizedString(forKey: "call_status_ringing")
            case .receivedAnswer: return BundleUtil.localizedString(forKey: "call_status_ringing")
            case .initializing: return BundleUtil.localizedString(forKey: "call_status_initializing")
            case .calling: return BundleUtil.localizedString(forKey: "call_status_calling")
            case .reconnecting: return BundleUtil.localizedString(forKey: "call_status_reconnecting")
            case .ended: return BundleUtil.localizedString(forKey: "call_end")
            case .remoteEnded: return BundleUtil.localizedString(forKey: "call_end")
            case .rejected: return BundleUtil.localizedString(forKey: "call_rejected")
            case .rejectedBusy: return BundleUtil.localizedString(forKey: "call_rejected_busy")
            case .rejectedTimeout: return BundleUtil.localizedString(forKey: "call_rejected_timeout")
            case .rejectedDisabled: return BundleUtil.localizedString(forKey: "call_rejected_disabled")
            case .rejectedOffHours: return BundleUtil.localizedString(forKey: "call_rejected")
            case .rejectedUnknown: return BundleUtil.localizedString(forKey: "call_rejected")
            case .microphoneDisabled: return BundleUtil.localizedString(forKey: "call_microphone_permission_title")
            }
        }
    }
    
    weak var delegate: VoIPCallServiceDelegate?
    
    private var peerConnectionClient: VoIPCallPeerConnectionClient?
    private var callKitManager: VoIPCallKitManager?
    private var threemaVideoCallAvailable = false
    private var callViewController: CallViewController?
    private var state: CallState = .idle {
        didSet {
            invalidateTimers(state: state)
            callViewController?.voIPCallStatusChanged(state: state, oldState: oldValue)
            handleLocalNotification()
            switch state {
            case .idle:
                localAddedIceCandidates.removeAll()
                localRelatedAddresses.removeAll()
                receivedIcecandidatesMessages.removeAll()
            case .initializing:
                handleLocalIceCandidates([])
            default:
                // do nothing
                break
            }
            addCallMessageToConversation(oldCallState: oldValue)
            handleTones(state: state, oldState: oldValue)
        }
    }

    private var audioPlayer: AVAudioPlayer?
    private var contactIdentity: String?
    private var callID: VoIPCallID?
    private var alreadyAccepted = false {
        didSet {
            callViewController?.alreadyAccepted = alreadyAccepted
        }
    }

    private var callInitiator = false {
        didSet {
            callViewController?.isCallInitiator = callInitiator
        }
    }

    private var audioMuted = false
    private var speakerActive = false
    private var videoActive = false
    private var isReceivingVideo = false {
        didSet {
            if callViewController != nil {
                callViewController?.isReceivingRemoteVideo = isReceivingVideo
            }
        }
    }

    private var shouldShowCellularCallWarning = false {
        didSet {
            if let callViewController = callViewController {
                DDLogDebug(
                    "VoipCallService: [cid=\(callID?.callID ?? 0)]: Should show cellular warning -> \(shouldShowCellularCallWarning)"
                )
                callViewController.shouldShowCellularCallWarning = shouldShowCellularCallWarning
            }
        }
    }
    
    private var initCallTimeoutTimer: Timer?
    private var incomingCallTimeoutTimer: Timer?
    private var callDurationTimer: Timer?
    private var callDurationTime = 0
    private var callFailedTimer: Timer?
    
    private var incomingOffer: VoIPCallOfferMessage?
    
    private var iceCandidatesLockQueue = DispatchQueue(label: "VoIPCallIceCandidatesLockQueue")
    private var iceCandidatesTimer: Timer?
    private var localAddedIceCandidates = [RTCIceCandidate]()
    private var localRelatedAddresses: Set<String> = []
    private var receivedIceCandidatesLockQueue = DispatchQueue(label: "VoIPCallReceivedIceCandidatesLockQueue")
    private var receivedIcecandidatesMessages = [VoIPCallIceCandidatesMessage]()
    private var receivedUnknowCallIcecandidatesMessages = [String: [VoIPCallIceCandidatesMessage]]()
    
    private var localRenderer: RTCVideoRenderer?
    private var remoteRenderer: RTCVideoRenderer?
    
    private var reconnectingTimer: Timer?
    private var iceWasConnected = false
    
    private var isModal: Bool {
        // Check whether our callViewController is currently in the state presented modally
        let a = callViewController?.presentingViewController?.presentedViewController == callViewController
        // Check whether our callViewController has a navigationController
        let b1 = callViewController?.navigationController != nil
        // Check whether our callViewController is in the state presented modally as part of a navigation controller
        let b2 = callViewController?.navigationController?.presentingViewController?
            .presentedViewController == callViewController?.navigationController
        let b = b1 && b2
        // Check whether our callViewController has a tabbarcontroller which has a tabbarcontroller. Nesting two
        // tabBarControllers is only possible in the state presented modally
        let c = callViewController?.tabBarController?.presentingViewController is UITabBarController
        return a || b || c
    }
    
    private var audioRouteChangeObserver: NSObjectProtocol?
    
    override required init() {
        self.voIPCallSender = VoIPCallSender(MyIdentityStore.shared())
        super.init()
        
        self.audioRouteChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] n in
            guard let self = self else {
                return
            }
            if self.state != .idle {
                var isBluetoothAvailable = false
                if let inputs = AVAudioSession.sharedInstance().availableInputs {
                    for input in inputs {
                        if input.portType == AVAudioSession.Port.bluetoothA2DP || input.portType == AVAudioSession.Port
                            .bluetoothHFP || input.portType == AVAudioSession.Port.bluetoothLE {
                            isBluetoothAvailable = true
                        }
                    }
                }
                guard let info = n.userInfo,
                      let value = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: value) else {
                    return
                }
                
                switch reason {
                case .categoryChange:
                    let currentRoute = AVAudioSession.sharedInstance().currentRoute
                    
                    for output in currentRoute.outputs {
                        switch output.portType {
                        case .builtInReceiver:
                            if isBluetoothAvailable {
                                self.speakerActive = false
                                try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                            }
                            if self.speakerActive {
                                try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                            }
                        case .builtInSpeaker:
                            if isBluetoothAvailable {
                                self.speakerActive = true
                                try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                            }
                            if !self.speakerActive {
                                try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                            }
                        case .headphones:
                            try? AVAudioSession.sharedInstance()
                                .overrideOutputAudioPort(self.speakerActive ? .speaker : .none)
                        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                            break
                        default: break
                        }
                    }
                default: break
                }
            }
        }
    }
    
    deinit {
        if let observer = audioRouteChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

extension VoIPCallService {
    // MARK: Public functions
    
    /// Start process to handle the message
    /// - parameter element: Message
    func startProcess(element: Any) {
        if let action = element as? VoIPCallUserAction {
            switch action.action {
            case .call:
                if UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT") {
                    callInitiator = true
                    contactIdentity = action.contactIdentity
                    presentCallViewController()
                    delegate?.callServiceFinishedProcess()
                    action.completion?()
                    return
                }
                
                startCallAsInitiator(action: action, completion: {
                    self.delegate?.callServiceFinishedProcess()
                    action.completion?()
                })
            case .callWithVideo:
                startCallAsInitiator(action: action, completion: {
                    self.delegate?.callServiceFinishedProcess()
                    action.completion?()
                })
            case .accept, .acceptCallKit:
                alreadyAccepted = true
                acceptIncomingCall(action: action) {
                    self.delegate?.callServiceFinishedProcess()
                    action.completion?()
                }
            case .reject, .rejectDisabled, .rejectTimeout, .rejectBusy, .rejectOffHours, .rejectUnknown:
                rejectCall(action: action)
                action.completion?()
                delegate?.callServiceFinishedProcess()
            case .end:
                if UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT") {
                    dismissCallView()
                    delegate?.callServiceFinishedProcess()
                    action.completion?()
                    return
                }
                DDLogNotice("Threema call: HangupBug -> Send hangup for end action")
                if state == .sendOffer || state == .outgoingRinging || state == .sendAnswer || state ==
                    .receivedAnswer ||
                    state == .initializing || state == .calling || state == .reconnecting {
                    RTCAudioSession.sharedInstance().isAudioEnabled = false
                    let hangupMessage = VoIPCallHangupMessage(
                        contactIdentity: action.contactIdentity,
                        callID: action.callID!,
                        completion: nil
                    )
                    voIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage)
                    state = .ended
                    callKitManager?.endCall()
                    dismissCallView()
                    disconnectPeerConnection()
                }
                delegate?.callServiceFinishedProcess()
                action.completion?()
            case .speakerOn:
                speakerActive = true
                peerConnectionClient?.speakerOn()
                delegate?.callServiceFinishedProcess()
                action.completion?()
            case .speakerOff:
                speakerActive = false
                peerConnectionClient?.speakerOff()
                delegate?.callServiceFinishedProcess()
                action.completion?()
            case .muteAudio:
                peerConnectionClient?.muteAudio(completion: {
                    self.delegate?.callServiceFinishedProcess()
                    action.completion?()
                })
            case .unmuteAudio:
                peerConnectionClient?.unmuteAudio(completion: {
                    self.delegate?.callServiceFinishedProcess()
                    action.completion?()
                })
            case .hideCallScreen:
                dismissCallView()
                delegate?.callServiceFinishedProcess()
                action.completion?()
            }
        }
        else if let offer = element as? VoIPCallOfferMessage {
            handleOfferMessage(offer: offer, completion: {
                offer.completion?()
                self.delegate?.callServiceFinishedProcess()
            })
        }
        else if let answer = element as? VoIPCallAnswerMessage {
            handleAnswerMessage(answer: answer, completion: {
                answer.completion?()
                self.delegate?.callServiceFinishedProcess()
            })
        }
        else if let ringing = element as? VoIPCallRingingMessage {
            handleRingingMessage(ringing: ringing, completion: {
                ringing.completion?()
                self.delegate?.callServiceFinishedProcess()
            })
        }
        else if let hangup = element as? VoIPCallHangupMessage {
            handleHangupMessage(hangup: hangup, completion: {
                hangup.completion?()
                self.delegate?.callServiceFinishedProcess()
            })
        }
        else if let ice = element as? VoIPCallIceCandidatesMessage {
            handleIceCandidatesMessage(ice: ice) {
                ice.completion?()
                self.delegate?.callServiceFinishedProcess()
            }
        }
        else {
            delegate?.callServiceFinishedProcess()
        }
    }
    
    /// Get the current call state
    /// - Returns: CallState
    func currentState() -> CallState {
        state
    }
    
    /// Get the current call contact
    /// - Returns: Contact or nil
    func currentContactIdentity() -> String? {
        contactIdentity
    }

    /// Get the current callID
    /// - Returns: VoIPCallID or nil
    func currentCallID() -> VoIPCallID? {
        callID
    }
    
    /// Is initiator of the current call
    /// - Returns: true or false
    func isCallInitiator() -> Bool {
        callInitiator
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
    
    /// Is the current call already accepted
    /// - Returns: true or false
    func isCallAlreadyAccepted() -> Bool {
        alreadyAccepted
    }
    
    /// Present the CallViewController
    func presentCallViewController() {
        if let identity = contactIdentity,
           alreadyAccepted || UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT") {
            presentCallView(
                contactIdentity: identity,
                alreadyAccepted: alreadyAccepted,
                isCallInitiator: callInitiator,
                isThreemaVideoCallAvailable: threemaVideoCallAvailable,
                videoActive: videoActive,
                receivingVideo: isReceivingVideo,
                viewWasHidden: false
            )
        }
    }
        
    /// Dismiss the CallViewController
    func dismissCallViewController() {
        dismissCallView()
    }
    
    /// Set the RTC audio session from CallKit
    /// - parameter callKitAudioSession: AVAudioSession from callkit
    func setRTCAudioSession(_ callKitAudioSession: AVAudioSession) {
        handleTones(state: .calling, oldState: .calling)
        RTCAudioSession.sharedInstance().audioSessionDidActivate(callKitAudioSession)
    }
    
    /// Configure the audio session and set RTC audio active
    func activateRTCAudio() {
        peerConnectionClient?.activateRTCAudio(speakerActive: speakerActive)
    }
    
    /// Reports a new call to CallKit with an unknown caller
    func reportInitialCall() {
        if let callKitManager = callKitManager {
            if callKitManager.currentUUID() != nil {
                callKitManager.endCall()
            }
        }
        else {
            callKitManager = VoIPCallKitManager()
        }
        
        guard let callKitManager = callKitManager else {
            // CallKitManager must have been initialized before we continue execution
            fatalError()
        }
        
        reportInitialCall(on: callKitManager)
    }
    
    private func reportInitialCall(on callKitManager: VoIPCallKitManager) {
        VoIPCallStateManager.shared.preCallHandling = true
        
        callKitManager.reportIncomingCall(
            uuid: UUID(),
            contactIdentity: BundleUtil.localizedString(forKey: "identity_not_found_title")
        )
    }
    
    /// Start capture local video
    func startCaptureLocalVideo(renderer: RTCVideoRenderer, useBackCamera: Bool, switchCamera: Bool = false) {
        localRenderer = renderer
        videoActive = true
        peerConnectionClient?.startCaptureLocalVideo(
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
            peerConnectionClient?.endCaptureLocalVideo(renderer: renderer, switchCamera: switchCamera)
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
        peerConnectionClient?.renderRemoteVideo(to: renderer)
    }
    
    /// End remote video
    func endRemoteVideo() {
        if let renderer = remoteRenderer {
            peerConnectionClient?.endRemoteVideo(renderer: renderer)
            remoteRenderer = nil
        }
    }
    
    /// Get remote video renderer
    func remoteVideoRenderer() -> RTCVideoRenderer? {
        remoteRenderer
    }
    
    /// Get peer video quality profile
    func remoteVideoQualityProfile() -> CallsignalingProtocol.ThreemaVideoCallQualityProfile? {
        peerConnectionClient?.remoteVideoQualityProfile
    }
    
    /// Get peer is using turn server
    func networkIsRelayed() -> Bool {
        peerConnectionClient?.networkIsRelayed ?? false
    }
}

extension VoIPCallService {
    // MARK: private functions
    
    /// When the current call state is idle and the permission is granted to the microphone, it will create the peer client and add the offer.
    /// If the state is wrong, it will reject the call with the reason unknown.
    /// If the permission to the microphone is not granted, it will reject the call with the reason unknown.
    /// If Threema Calls are disabled, it will reject the call with the reason disabled.
    /// - parameter offer: VoIPCallOfferMessage
    /// - parameter completion: Completion block
    private func handleOfferMessage(offer: VoIPCallOfferMessage, completion: @escaping (() -> Void)) {
        // We're logging this twice as a quick fix for compatibility with Android style logging
        DDLogNotice(
            "VoipCallService: [cid=\(offer.callID.callID)]: Handle new call with \(offer.contactIdentity ?? "?"), we are the callee"
        )
        DDLogNotice(
            "VoipCallService: [cid=\(offer.callID.callID)]: Call offer received from \(offer.contactIdentity ?? "?")"
        )

        if UserSettings.shared().enableThreemaCall, is64Bit == 1 {
            var appRunsInBackground = false
            DispatchQueue.main.sync {
                appRunsInBackground = AppDelegate.shared().isAppInBackground()
            }

            let pushSettingManager = PushSettingManager(UserSettings.shared(), LicenseStore.requiresLicenseKey())

            if state == .idle {
                if !pushSettingManager.canMasterDndSendPush() {
                    DDLogWarn("VoipCallService: [cid=\(offer.callID.callID)]: Master DND active, reject the call")
                    contactIdentity = offer.contactIdentity
                    let action = VoIPCallUserAction(
                        action: .rejectOffHours,
                        contactIdentity: offer.contactIdentity!,
                        callID: offer.callID,
                        completion: offer.completion
                    )
                    rejectCall(action: action, closeCallView: true)
                    completion()
                    return
                }
                
                if callKitManager == nil {
                    callKitManager = VoIPCallKitManager()
                }
                
                // If a call was already reported, it was the initial call launched when the app was in background. So we update the caller.
                if let uuid = callKitManager?.currentUUID() {
                    callKitManager?.updateReportedIncomingCall(
                        uuid: uuid,
                        contactIdentity: offer.contactIdentity!
                    )
                }
                else {
                    callKitManager?.reportIncomingCall(
                        uuid: UUID(),
                        contactIdentity: offer.contactIdentity!
                    )
                }
                
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    if granted {
                        self.contactIdentity = offer.contactIdentity
                        self.alreadyAccepted = false
                        self.state = .receivedOffer
                        self.incomingOffer = offer
                        self.callID = offer.callID
                        self.videoActive = false
                        self.isReceivingVideo = false
                        self.localRenderer = nil
                        self.remoteRenderer = nil
                        self.threemaVideoCallAvailable = offer.isVideoAvailable
                        self.startIncomingCallTimeoutTimer()
                        
                        /// Make sure that the connection is not prematurely disconnected when the app is put into the background
                        ServerConnector.shared()?.connectWait(initiator: .threemaCall)
                        
                        // New Call
                        // Send ringing message
                        let ringingMessage = VoIPCallRingingMessage(
                            contactIdentity: offer.contactIdentity!,
                            callID: offer.callID,
                            completion: nil
                        )
                        self.voIPCallSender.sendVoIPCallRinging(ringingMessage: ringingMessage)
                        
                        self.state = .incomingRinging
                        
                        // Prefetch ICE/TURN servers so they're likely to be already available when the user accepts the call
                        VoIPIceServerSource.prefetchIceServers()
                        
                        completion()
                    }
                    else {
                        DDLogWarn("VoipCallService: [cid=\(offer.callID.callID)]: Audio is not granted")
                        self.contactIdentity = offer.contactIdentity
                        self.state = .microphoneDisabled
                        // reject call because there is no permission for the microphone
                        self.state = .rejectedDisabled
                        let action = VoIPCallUserAction(
                            action: .rejectUnknown,
                            contactIdentity: offer.contactIdentity!,
                            callID: offer.callID,
                            completion: offer.completion
                        )
                        self.rejectCall(action: action, closeCallView: false)
                        
                        if appRunsInBackground {
                            // show notification that incoming call can't connect because mic is not granted
                            NotificationManager.showNoMicrophonePermissionNotification()
                            self.disconnectPeerConnection()
                            completion()
                        }
                        else {
                            self.presentCallView(
                                contactIdentity: offer.contactIdentity!,
                                alreadyAccepted: false,
                                isCallInitiator: false,
                                isThreemaVideoCallAvailable: self.threemaVideoCallAvailable,
                                videoActive: false,
                                receivingVideo: false,
                                viewWasHidden: false,
                                completion: {
                                    // no access to microphone, stopp call
                                    let alertTitle = BundleUtil
                                        .localizedString(forKey: "call_microphone_permission_title")
                                    let alertMessage = BundleUtil
                                        .localizedString(forKey: "call_microphone_permission_text")
                                    let alert = UIAlertController(
                                        title: alertTitle,
                                        message: alertMessage,
                                        preferredStyle: .alert
                                    )
                                    alert
                                        .addAction(UIAlertAction(
                                            title: BundleUtil.localizedString(forKey: "settings"),
                                            style: .default,
                                            handler: { _ in
                                                self.dismissCallView()
                                                self.disconnectPeerConnection()
                                                UIApplication.shared.open(
                                                    NSURL(string: UIApplication.openSettingsURLString)! as URL,
                                                    options: [:],
                                                    completionHandler: nil
                                                )
                                            }
                                        ))
                                    alert
                                        .addAction(UIAlertAction(
                                            title: BundleUtil.localizedString(forKey: "ok"),
                                            style: .default,
                                            handler: { _ in
                                                self.dismissCallView()
                                                self.disconnectPeerConnection()
                                            }
                                        ))
                                
                                    let rootVC = self.callViewController != nil ? self
                                        .callViewController! : UIApplication
                                        .shared.windows.first!.rootViewController!
                                    DispatchQueue.main.async {
                                        rootVC.present(alert, animated: true, completion: nil)
                                    }
                                
                                    completion()
                                }
                            )
                        }
                    }
                }
            }
            else {
                DDLogWarn(
                    "VoipCallService: [cid=\(offer.callID.callID)]: Current state is not IDLE (\(state.description()))"
                )
                if contactIdentity == offer.contactIdentity, state == .incomingRinging {
                    DDLogNotice("Threema call: handleOfferMessage -> same contact as the current call")
                    if !pushSettingManager.canMasterDndSendPush(), appRunsInBackground {
                        DDLogNotice(
                            "Threema call: handleOfferMessage -> Master DND active -> reject call from \(String(describing: offer.contactIdentity))"
                        )
                        let action = VoIPCallUserAction(
                            action: .rejectOffHours,
                            contactIdentity: offer.contactIdentity!,
                            callID: offer.callID,
                            completion: offer.completion
                        )
                        rejectCall(action: action, closeCallView: true)
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
                    let reason: VoIPCallUserAction.Action = contactIdentity == offer
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
        else {
            // reject call because Threema Calls are disabled or unavailable
            let action = VoIPCallUserAction(
                action: .rejectDisabled,
                contactIdentity: offer.contactIdentity!,
                callID: offer.callID,
                completion: offer.completion
            )
            rejectCall(action: action)
            completion()
        }
    }
    
    private func startIncomingCallTimeoutTimer() {
        DispatchQueue.main.async {
            if let offer = self.incomingOffer {
                self.invalidateIncomingCallTimeout()
                self.incomingCallTimeoutTimer = Timer.scheduledTimer(
                    withTimeInterval: self.kIncomingCallTimeout,
                    repeats: false,
                    block: { _ in
                        BackgroundTaskManager.shared.newBackgroundTask(
                            key: kAppVoIPBackgroundTask,
                            timeout: Int(kAppVoIPBackgroundTaskTime)
                        ) {
                            ServerConnector.shared()?.connect(initiator: .threemaCall)
                            
                            self.callKitManager?.timeoutCall()
                            let action = VoIPCallUserAction(
                                action: .rejectTimeout,
                                contactIdentity: offer.contactIdentity!,
                                callID: offer.callID,
                                completion: offer.completion
                            )
                            self.rejectCall(action: action)
                            self.invalidateIncomingCallTimeout()
                        }
                    }
                )
            }
        }
    }
    
    /// Handle the answer message if the contact in the answer message is the same as in the call service and call state is ringing.
    /// Call will cancel if it's rejected and CallViewController will close.
    /// - parameter answer: VoIPCallAnswerMessage
    /// - parameter completion: Completion block
    private func handleAnswerMessage(answer: VoIPCallAnswerMessage, completion: @escaping (() -> Void)) {
        let logString =
            "VoipCallService: [cid=\(answer.callID.callID)]: Call answer received from \(answer.contactIdentity ?? "?"): \(answer.action.description())"
        if answer.action == .call {
            DDLogNotice(logString)
        }
        else {
            DDLogNotice(logString + "/\(answer.rejectReason?.description() ?? "unknown")")
        }
        
        if let identity = contactIdentity {
            if callInitiator {
                if let callID = callID, state == .sendOffer || state == .outgoingRinging,
                   identity == answer.contactIdentity, callID.isSame(answer.callID) {
                    state = .receivedAnswer
                    if answer.action == VoIPCallAnswerMessage.MessageAction.reject {
                        // call is rejected
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
                        callKitManager?.rejectCall()
                        dismissCallView(rejected: true, completion: {
                            self.disconnectPeerConnection()
                            completion()
                        })
                    }
                    else {
                        // handle answer
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
                            peerConnectionClient?.set(remoteSdp: remoteSdp, completion: { error in
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
                                        contactIdentity: self.contactIdentity!,
                                        callID: self.callID!,
                                        completion: nil
                                    )
                                    self.voIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage)
                                    self.state = .rejectedUnknown
                                    self.dismissCallView()
                                    self.disconnectPeerConnection()
                                }
                                completion()
                            })
                        }
                        else {
                            DDLogError("VoipCallService: [cid=\(answer.callID.callID)]: Remote sdp is empty")
                            let hangupMessage = VoIPCallHangupMessage(
                                contactIdentity: contactIdentity!,
                                callID: self.callID!,
                                completion: nil
                            )
                            voIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage)
                            state = .rejectedUnknown
                            dismissCallView()
                            disconnectPeerConnection()
                            completion()
                        }
                    }
                }
                else {
                    if identity == answer.contactIdentity {
                        DDLogWarn(
                            "VoipCallService: [cid=\(answer.callID.callID)]: Current state is wrong (\(state.description())) or callId is different to \(callID?.callID ?? 0)"
                        )
                    }
                    else {
                        DDLogWarn(
                            "VoipCallService: [cid=\(answer.callID.callID)]: Answer contact (\(answer.contactIdentity ?? "?") is different to current call contact (\(identity)"
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
        else {
            DDLogWarn("VoipCallService: [cid=\(answer.callID.callID)]: No contact set for currenct call")
            completion()
        }
    }
    
    /// Handle the ringing message if the contact in the answer message is the same as in the call service and call state is sendOffer.
    /// CallViewController will play the ringing tone
    /// - parameter ringing: VoIPCallRingingMessage
    /// - parameter completion: Completion block
    private func handleRingingMessage(ringing: VoIPCallRingingMessage, completion: @escaping (() -> Void)) {
        DDLogNotice(
            "VoipCallService: [cid=\(ringing.callID.callID)]: Call ringing message received from \(ringing.contactIdentity ?? "?")"
        )
        if let identity = contactIdentity {
            if let callID = callID, identity == ringing.contactIdentity, callID.isSame(ringing.callID) {
                switch state {
                case .sendOffer:
                    state = .outgoingRinging
                default:
                    DDLogWarn(
                        "VoipCallService: [cid=\(ringing.callID.callID)]: Wrong state (\(state.description())) to handle ringing message"
                    )
                }
            }
            else {
                DDLogWarn(
                    "VoipCallService: [cid=\(ringing.callID.callID)]: Ringing contact (\(ringing.contactIdentity ?? "?") is different to current call contact (\(identity)"
                )
            }
        }
        else {
            DDLogWarn("VoipCallService: [cid=\(ringing.callID.callID)]: No contact set for currenct call")
        }
        completion()
    }
    
    /// Handle add or remove received remote ice candidates (IpV6 candidates will be removed)
    /// - parameter ice: VoIPCallIceCandidatesMessage
    /// - parameter completion: Completion block
    private func handleIceCandidatesMessage(ice: VoIPCallIceCandidatesMessage, completion: @escaping (() -> Void)) {
        DDLogNotice(
            "VoipCallService: [cid=\(ice.callID.callID)]: Call ICE candidate message received from \(ice.contactIdentity ?? "?") (\(ice.candidates.count) candidates)"
        )
        
        for candidate in ice.candidates {
            DDLogNotice("VoipCallService: [cid=\(ice.callID.callID)]: Incoming ICE candidate: \(candidate.sdp)")
        }
        if let identity = contactIdentity {
            if let callID = callID, identity == ice.contactIdentity, callID.isSame(ice.callID) {
                switch state {
                case .sendOffer, .outgoingRinging, .sendAnswer, .receivedAnswer, .initializing, .calling, .reconnecting:
                    if !ice.removed {
                        for candidate in ice.candidates {
                            if shouldAdd(candidate: candidate, local: false) == (true, nil) {
                                peerConnectionClient?.set(addRemoteCandidate: candidate)
                            }
                        }
                        completion()
                    }
                    else {
                        // ICE candidate messages are currently allowed to have a "removed" flag. However, this is non-standard.
                        // When receiving an VoIP ICE Candidate (0x62) message with removed set to true, discard the message
                        completion()
                    }
                case .receivedOffer, .incomingRinging:
                    // add to local array
                    receivedIceCandidatesLockQueue.sync {
                        receivedIcecandidatesMessages.append(ice)
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
                addUnknownCallIcecandidatesMessages(message: ice)
                DDLogNotice(
                    "VoipCallService: [cid=\(ice.callID.callID)]: ICE candidates contact (\(ice.contactIdentity ?? "?") is different to current call contact (\(identity)"
                )
                completion()
            }
        }
        else {
            addUnknownCallIcecandidatesMessages(message: ice)
            DDLogWarn("VoipCallService: [cid=\(ice.callID.callID)]: No contact set for currenct call")
            completion()
        }
    }
    
    /// Handle the hangup message if the contact in the answer message is the same as in the call service and call state is receivedOffer, ringing, sendAnswer, initializing, calling or reconnecting.
    /// It will dismiss the CallViewController after the call was ended.
    /// - parameter hangup: VoIPCallHangupMessage
    /// - parameter completion: Completion block
    private func handleHangupMessage(hangup: VoIPCallHangupMessage, completion: @escaping (() -> Void)) {
        DDLogNotice(
            "VoipCallService: [cid=\(hangup.callID.callID)]: Call hangup message received from \(hangup.contactIdentity ?? "?")"
        )
        
        if let identity = contactIdentity {
            if let callID = callID, identity == hangup.contactIdentity, callID.isSame(hangup.callID) {
                switch state {
                case .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer, .initializing, .calling,
                     .reconnecting:
                    RTCAudioSession.sharedInstance().isAudioEnabled = false
                    state = .remoteEnded
                    callKitManager?.endCall()
                    dismissCallView()
                    disconnectPeerConnection()
                default:
                    DDLogWarn(
                        "VoipCallService: [cid=\(hangup.callID.callID)]: Wrong state (\(state.description())) to handle hangup message"
                    )
                }
            }
            else {
                DDLogNotice(
                    "VoipCallService: [cid=\(hangup.callID.callID)]: Hangup contact (\(hangup.contactIdentity ?? "?") is different to current call contact (\(identity)"
                )
            }
        }
        else {
            DDLogWarn("VoipCallService: [cid=\(hangup.callID.callID)]: No contact set for currenct call")
        }
        completion()
    }
    
    /// Handle a new outgoing call if Threema calls are enabled and permission for microphone is granted.
    /// It will present the CallViewController.
    /// - parameter action: VoIPCallUserAction
    /// - parameter completion: Completion block
    private func startCallAsInitiator(action: VoIPCallUserAction, completion: @escaping (() -> Void)) {
        if UserSettings.shared().enableThreemaCall, is64Bit == 1 {
            RTCAudioSession.sharedInstance().useManualAudio = true
            if state == .idle {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    if granted {
                        self.callInitiator = true
                        self.contactIdentity = action.contactIdentity
                        self.createPeerConnectionForInitiator(action: action, completion: completion)
                        ServerConnector.shared().connect(initiator: .threemaCall)
                    }
                    else {
                        // no access to microphone, stop call
                        let alertTitle = BundleUtil.localizedString(forKey: "call_microphone_permission_title")
                        let alertMessage = BundleUtil.localizedString(forKey: "call_microphone_permission_text")
                        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
                        alert
                            .addAction(UIAlertAction(
                                title: BundleUtil.localizedString(forKey: "settings"),
                                style: .default,
                                handler: { _ in
                                    UIApplication.shared.open(
                                        NSURL(string: UIApplication.openSettingsURLString)! as URL,
                                        options: [:],
                                        completionHandler: nil
                                    )
                                }
                            ))
                        alert
                            .addAction(UIAlertAction(
                                title: BundleUtil.localizedString(forKey: "ok"),
                                style: .default,
                                handler: nil
                            ))
                        DispatchQueue.main.async {
                            let rootVC = UIApplication.shared.windows.first!.rootViewController!
                            rootVC.present(alert, animated: true, completion: nil)
                        }
                        completion()
                    }
                }
            }
            else {
                // do nothing because it's the wrong state
                DDLogWarn(
                    "VoipCallService: [cid=\(action.callID?.callID ?? 0)]: Wrong state (\(state.description())) to start call as initiator"
                )
                completion()
            }
        }
        else {
            // do nothing because Threema calls are disabled or unavailable
            completion()
        }
    }
    
    /// Accept a incoming call if state is ringing. Will send a answer message to initiator and update CallViewController.
    /// It will present the CallViewController.
    /// - parameter action: VoIPCallUserAction
    /// - parameter completion: Completion block
    private func acceptIncomingCall(action: VoIPCallUserAction, completion: @escaping (() -> Void)) {
        createPeerConnectionForIncomingCall {
            RTCAudioSession.sharedInstance().useManualAudio = true
            if self.state == .incomingRinging {
                /// Make sure that the connection is not prematurely disconnected when the app is put into the background
                ServerConnector.shared().connect(initiator: .threemaCall)
                self.state = .sendAnswer
                if #available(iOS 14.0, *) {
                    self.presentCallViewController()
                }
                self.peerConnectionClient?.answer(completion: { sdp in
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
                        contactIdentity: action.contactIdentity,
                        answer: sdp,
                        rejectReason: nil,
                        features: nil,
                        isVideoAvailable: self.threemaVideoCallAvailable,
                        callID: self.callID!,
                        completion: nil
                    )
                    self.voIPCallSender.sendVoIPCall(answer: answerMessage)
                    
                    if action.action != .acceptCallKit {
                        self.callKitManager?.callAccepted()
                    }
                    self.receivedIceCandidatesLockQueue.sync {
                        if let receivedCandidatesBeforeCall = self
                            .receivedUnknowCallIcecandidatesMessages[action.contactIdentity] {
                            for ice in receivedCandidatesBeforeCall {
                                if ice.callID.callID == self.callID?.callID {
                                    self.receivedIcecandidatesMessages.append(ice)
                                }
                            }
                            self.receivedUnknowCallIcecandidatesMessages.removeAll()
                        }
                        
                        for message in self.receivedIcecandidatesMessages {
                            if !message.removed {
                                for candidate in message.candidates {
                                    if self.shouldAdd(candidate: candidate, local: false) == (true, nil) {
                                        self.peerConnectionClient?.set(addRemoteCandidate: candidate)
                                    }
                                }
                            }
                        }
                        self.receivedIcecandidatesMessages.removeAll()
                    }
                    completion()
                })
            }
            else {
                // dismiss call view because it's the wrong state
                DDLogWarn(
                    "VoipCallService: [cid=\(action.callID?.callID ?? 0)]: Wrong state (\(self.state.description())) to accept incoming call action"
                )
                self.callKitManager?.answerFailed()
                self.dismissCallView()
                self.disconnectPeerConnection()
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
        let entityManager = BusinessInjector().entityManager
        
        entityManager.performBlockAndWait {
            guard let contact = entityManager.entityFetcher.contact(for: self.contactIdentity) else {
                return
            }
            
            FeatureMask.check(Int(FEATURE_MASK_VOIP_VIDEO), forContacts: [contact]) { unsupportedContacts in
                self.threemaVideoCallAvailable = false
                if unsupportedContacts!.isEmpty && UserSettings.shared().enableVideoCall {
                    self.threemaVideoCallAvailable = true
                }
                self.peerConnectionClient?.peerConnection.close()
                self.peerConnectionClient = nil
                let forceTurn: Bool = Int(truncating: contact.verificationLevel) == kVerificationLevelUnverified ||
                    UserSettings.shared()?.alwaysRelayCalls == true
                let peerConnectionParameters = VoIPCallPeerConnectionClient.PeerConnectionParameters(
                    isVideoCallAvailable: self.threemaVideoCallAvailable,
                    videoCodecHwAcceleration: self.threemaVideoCallAvailable,
                    forceTurn: forceTurn,
                    gatherContinually: true,
                    allowIpv6: UserSettings.shared().enableIPv6,
                    isDataChannelAvailable: false
                )
                self.callID = VoIPCallID.generate()
                
                DDLogNotice(
                    "VoipCallService: [cid=\(self.callID!.callID)]: Handle new call with \(contact.identity), we are the caller"
                )
                
                if Int(truncating: contact.verificationLevel) == kVerificationLevelUnverified {
                    DDLogNotice("VoipCallService: [cid=\(self.callID!.callID)]: Force TURN since contact is unverified")
                }
                if let userSettings = UserSettings.shared(), userSettings.alwaysRelayCalls == true {
                    DDLogNotice("VoipCallService: [cid=\(self.callID!.callID)]: Force TURN as requested by user")
                }
                
                VoIPCallPeerConnectionClient.instantiate(
                    contactIdentity: contact.identity,
                    callID: self.callID,
                    peerConnectionParameters: peerConnectionParameters
                ) { result in
                    do {
                        self.peerConnectionClient = try result.get()
                    }
                    catch {
                        self.callID = nil
                        self.callCantCreateOffer(error: error)
                        return
                    }
                    self.peerConnectionClient?.delegate = self

                    if self.callKitManager == nil {
                        self.callKitManager = VoIPCallKitManager()
                    }

                    self.peerConnectionClient?.offer(completion: { sdp, sdpError in
                        if let error = sdpError {
                            self.callID = nil
                            self.callCantCreateOffer(error: error)
                            return
                        }
                        guard let sdp = sdp else {
                            self.callID = nil
                            self.callCantCreateOffer(error: nil)
                            return
                        }

                        let offerMessage = VoIPCallOfferMessage(
                            offer: sdp,
                            contactIdentity: self.contactIdentity,
                            features: nil,
                            isVideoAvailable: self.threemaVideoCallAvailable,
                            callID: self.callID!,
                            completion: nil
                        )
                        self.voIPCallSender.sendVoIPCall(offer: offerMessage)
                        self.state = .sendOffer
                        DispatchQueue.main.async {
                            self.initCallTimeoutTimer = Timer.scheduledTimer(
                                withTimeInterval: self.kIncomingCallTimeout,
                                repeats: false,
                                block: { _ in
                                    BackgroundTaskManager.shared.newBackgroundTask(
                                        key: kAppVoIPBackgroundTask,
                                        timeout: Int(kAppPushBackgroundTaskTime)
                                    ) {
                                        DispatchQueue.global(qos: .userInitiated).async {
                                            RTCAudioSession.sharedInstance().isAudioEnabled = false
                                            DDLogNotice("VoipCallService: [cid=\(self.callID!)]: Call ringing timeout")
                                            let hangupMessage = VoIPCallHangupMessage(
                                                contactIdentity: contact.identity,
                                                callID: self.callID!,
                                                completion: nil
                                            )
                                            self.voIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage)
                                            self.state = .ended
                                            self.disconnectPeerConnection()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                                                self.dismissCallView(rejected: false, completion: {
                                                    self.callKitManager?.endCall()
                                                    self.invalidateInitCallTimeout()
                                                
                                                    let rootVC = UIApplication.shared.windows.first!.rootViewController!
                                                    UIAlertTemplate.showAlert(
                                                        owner: rootVC,
                                                        title: BundleUtil
                                                            .localizedString(forKey: "call_voip_not_supported_title"),
                                                        message: BundleUtil
                                                            .localizedString(forKey: "call_contact_not_reachable")
                                                    )
                                                })
                                            }
                                        }
                                    }
                                }
                            )
                        }
                        self.alreadyAccepted = true
                        self.presentCallView(
                            contactIdentity: self.contactIdentity!,
                            alreadyAccepted: true,
                            isCallInitiator: true,
                            isThreemaVideoCallAvailable: self.threemaVideoCallAvailable,
                            videoActive: action.action == .callWithVideo,
                            receivingVideo: false,
                            viewWasHidden: false
                        )
                        self.callKitManager?.startCall(for: self.contactIdentity!)
                        completion()
                    })
                }
            }
        }
    }
    
    /// Creates the peer connection for the incoming call and set the offer if contact is set in the offer.
    /// After this, it will present the CallViewController.
    /// - parameter action: VoIPCallUserAction
    /// - parameter completion: Completion block
    private func createPeerConnectionForIncomingCall(completion: @escaping (() -> Void)) {
        peerConnectionClient?.peerConnection.close()
        peerConnectionClient = nil
        
        let entityManager = BusinessInjector().entityManager
        
        guard let offer = incomingOffer,
              let identity = offer.contactIdentity,
              let contact = entityManager.entityFetcher.contact(for: identity) else {
            state = .idle
            completion()
            return
        }
        
        FeatureMask.check(Int(FEATURE_MASK_VOIP_VIDEO), forContacts: [contact]) { _ in
            if self.incomingOffer?.isVideoAvailable ?? false && UserSettings.shared().enableVideoCall {
                self.threemaVideoCallAvailable = true
                self.callViewController?.enableThreemaVideoCall()
            }
            else {
                self.threemaVideoCallAvailable = false
                self.callViewController?.disableThreemaVideoCall()
            }
            
            let forceTurn = Int(truncating: contact.verificationLevel) == kVerificationLevelUnverified || UserSettings
                .shared().alwaysRelayCalls
            let peerConnectionParameters = VoIPCallPeerConnectionClient.PeerConnectionParameters(
                isVideoCallAvailable: self.threemaVideoCallAvailable,
                videoCodecHwAcceleration: self.threemaVideoCallAvailable,
                forceTurn: forceTurn,
                gatherContinually: true,
                allowIpv6: UserSettings.shared().enableIPv6,
                isDataChannelAvailable: false
            )
            
            VoIPCallPeerConnectionClient.instantiate(
                contactIdentity: contact.identity,
                callID: offer.callID,
                peerConnectionParameters: peerConnectionParameters
            ) { result in
                do {
                    self.peerConnectionClient = try result.get()
                }
                catch {
                    print("Can't instantiate client: \(error)")
                }
                self.peerConnectionClient?.delegate = self
                
                self.peerConnectionClient?.set(remoteSdp: offer.offer!, completion: { error in
                    if error == nil {
                        completion()
                    }
                    else {
                        // reject because we can't add offer
                        print("We can't add the offer \(String(describing: error))")
                        let action = VoIPCallUserAction(
                            action: .reject,
                            contactIdentity: contact.identity,
                            callID: offer.callID,
                            completion: offer.completion
                        )
                        self.rejectCall(action: action)
                    }
                })
            }
        }
    }
    
    /// Removes the peer connection, reset the call state and reset all other values
    private func disconnectPeerConnection() {
        // remove peerConnection
        
        func reset() {
            peerConnectionClient?.peerConnection.close()
            peerConnectionClient = nil
            contactIdentity = nil
            callID = nil
            threemaVideoCallAvailable = false
            alreadyAccepted = false
            callInitiator = false
            audioMuted = false
            speakerActive = false
            videoActive = false
            isReceivingVideo = false
            incomingOffer = nil
            localRenderer = nil
            remoteRenderer = nil
            audioPlayer?.pause()

            do {
                RTCAudioSession.sharedInstance().lockForConfiguration()
                try RTCAudioSession.sharedInstance().setActive(false)
                RTCAudioSession.sharedInstance().unlockForConfiguration()
            }
            catch {
                DDLogError("Could not set shared session to not active. Error: \(error)")
            }
            
            DispatchQueue.main.async {
                VoIPHelper.shared()?.isCallActiveInBackground = false
                VoIPHelper.shared()?.contactName = nil
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
                    block: { _ in
                        if self.state == .idle {
                            ServerConnector.shared().disconnect(initiator: .threemaCall)
                        }
                    }
                )
            }
        }
        
        if peerConnectionClient != nil {
            peerConnectionClient!.stopVideoCall()
            peerConnectionClient?.logDebugEndStats {
                reset()
            }
        }
        else {
            reset()
        }
    }
    
    /// Present the CallViewController on the main thread.
    /// - parameter contact: Contact of the call
    /// - parameter alreadyAccepted: Set to true if the call was already accepted
    /// - parameter isCallInitiator: If user is the call initiator
    private func presentCallView(
        contactIdentity: String,
        alreadyAccepted: Bool,
        isCallInitiator: Bool,
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
                self.callViewController = callVC
                viewWasHidden = false
            }
            
            let rootVC = UIApplication.shared.windows.first!.rootViewController
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
                    isCallInitiator: isCallInitiator,
                    isThreemaVideoCallAvailable: isThreemaVideoCallAvailable,
                    receivingVideo: receivingVideo,
                    completion: completion
                )
            }
        }
    }
    
    private func showCallViewIfActive(
        presentingVC: UIViewController?,
        viewWasHidden: Bool,
        isCallInitiator: Bool,
        isThreemaVideoCallAvailable: Bool,
        receivingVideo: Bool,
        completion: (() -> Void)? = nil
    ) {
        if UIApplication.shared.applicationState == .active,
           !callViewController!.isBeingPresented,
           !isModal {
            callViewController!.viewWasHidden = viewWasHidden
            callViewController!.voIPCallStatusChanged(state: state, oldState: state)
            callViewController!.contactIdentity = contactIdentity
            callViewController!.alreadyAccepted = alreadyAccepted
            callViewController!.isCallInitiator = isCallInitiator
            callViewController!.threemaVideoCallAvailable = isThreemaVideoCallAvailable
            callViewController!.isLocalVideoActive = videoActive
            callViewController!.isReceivingRemoteVideo = receivingVideo
            if UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT") {
                callViewController!.isTesting = true
            }
            callViewController!.modalPresentationStyle = .overFullScreen
            presentingVC?.present(callViewController!, animated: false, completion: {
                // need to check is fresh start, then we have to set isReceivingRemotVideo again to show the video of the remote
                if !viewWasHidden, !isCallInitiator {
                    self.callViewController!.isReceivingRemoteVideo = receivingVideo
                }
                if completion != nil {
                    completion!()
                }
            })
        }
    }
    
    /// Dismiss the CallViewController in the main thread.
    private func dismissCallView(rejected: Bool? = false, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            if let callVC = self.callViewController {
                self.callViewController?.resetStatsTimer()
                if rejected == true {
                    if let callViewController = self.callViewController {
                        callViewController.endButton.isEnabled = false
                        callViewController.speakerButton.isEnabled = false
                        callViewController.muteButton.isEnabled = false
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
            }
        }
    }
    
    /// Reject the call with the reason given in the action.
    /// Will end call and dismiss the CallViewController.
    /// - parameter action: VoIPCallUserAction with the given reject reason
    /// - parameter closeCallView: Default is true. If set false, it will not disconnect the peer connection and will not close the call view
    private func rejectCall(action: VoIPCallUserAction, closeCallView: Bool? = true) {
        var reason: VoIPCallAnswerMessage.MessageRejectReason = .reject
        
        switch action.action {
        case .rejectDisabled:
            reason = .disabled
            if action.contactIdentity == contactIdentity {
                state = .rejectedDisabled
            }
        case .rejectTimeout:
            reason = .timeout
            if action.contactIdentity == contactIdentity {
                state = .rejectedTimeout
            }
        case .rejectBusy:
            reason = .busy
            if action.contactIdentity == contactIdentity {
                state = .rejectedBusy
            }
        case .rejectOffHours:
            reason = .offHours
            if action.contactIdentity == contactIdentity {
                state = .rejectedOffHours
            }
        case .rejectUnknown:
            reason = .unknown
            if action.contactIdentity == contactIdentity {
                state = .rejectedUnknown
            }
        default:
            if action.contactIdentity == contactIdentity {
                state = .rejected
            }
        }
        
        let answer = VoIPCallAnswerMessage(
            action: .reject,
            contactIdentity: action.contactIdentity,
            answer: nil,
            rejectReason: reason,
            features: nil,
            isVideoAvailable: UserSettings.shared().enableVideoCall,
            callID: action.callID!,
            completion: nil
        )
        voIPCallSender.sendVoIPCall(answer: answer)
        if contactIdentity == action.contactIdentity {
            callKitManager?.rejectCall()
            if closeCallView == true {
                // remove peerConnection
                dismissCallView()
                disconnectPeerConnection()
            }
        }
        else {
            addRejectedMessageToConversation(contactIdentity: action.contactIdentity, reason: kSystemMessageCallMissed)
        }
    }
        
    /// It will check the current call state and play the correct tone if it's needed
    private func handleTones(state: VoIPCallService.CallState, oldState: VoIPCallService.CallState) {
        if UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT") {
            return
        }
        switch state {
        case .outgoingRinging, .incomingRinging:
            if callInitiator {
                let soundFilePath = BundleUtil.path(forResource: "ringing-tone-ch-fade", ofType: "mp3")
                let soundURL = URL(fileURLWithPath: soundFilePath!)
                setupAudioSession()
                playSound(soundURL: soundURL, loops: -1)
            }
        case .rejected, .rejectedBusy, .rejectedTimeout, .rejectedOffHours, .rejectedUnknown, .rejectedDisabled:
            let pushSettingManager = PushSettingManager(UserSettings.shared(), LicenseStore.requiresLicenseKey())
            if !pushSettingManager.canMasterDndSendPush() || !isCallInitiator() {
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
            if oldState != .incomingRinging {
                let soundFilePath = BundleUtil.path(forResource: "threema_hangup", ofType: "mp3")
                let soundURL = URL(fileURLWithPath: soundFilePath!)
                setupAudioSession()
                playSound(soundURL: soundURL, loops: 0)
            }
            else {
                audioPlayer?.stop()
            }
        case .calling:
            if oldState != .reconnecting {
                let soundFilePath = BundleUtil.path(forResource: "threema_pickup", ofType: "mp3")
                let soundURL = URL(fileURLWithPath: soundFilePath!)
                setupAudioSession()
                playSound(soundURL: soundURL, loops: 0)
            }
            else {
                audioPlayer?.stop()
            }
        case .reconnecting:
            let soundFilePath = BundleUtil.path(forResource: "threema_problem", ofType: "mp3")
            let soundURL = URL(fileURLWithPath: soundFilePath!)
            setupAudioSession()
            playSound(soundURL: soundURL, loops: -1)
        case .idle:
            break
        case .sendOffer, .receivedOffer, .sendAnswer, .receivedAnswer, .initializing:
            // do nothing
            break
        case .microphoneDisabled:
            // do nothing
            break
        }
    }
    
    private func setupAudioSession(_ soloAmbient: Bool = false) {
        let audioSession = AVAudioSession.sharedInstance()
        if soloAmbient {
            do {
                try audioSession.setCategory(
                    .soloAmbient,
                    mode: .default,
                    options: [.allowBluetooth, .allowBluetoothA2DP]
                )
                try audioSession.overrideOutputAudioPort(speakerActive ? .speaker : .none)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            }
            catch {
                print(error.localizedDescription)
            }
        }
        else {
            do {
                try audioSession.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP]
                )
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
    private func playSound(soundURL: URL, loops: Int) {
        audioPlayer?.stop()
        do {
            let player = try AVAudioPlayer(contentsOf: soundURL, fileTypeHint: AVFileType.mp3.rawValue)
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
        case .sendOffer:
            invalidateCallFailedTimer()
        case .receivedOffer:
            invalidateInitCallTimeout()
            invalidateCallFailedTimer()
        case .outgoingRinging, .incomingRinging:
            invalidateInitCallTimeout()
            invalidateCallFailedTimer()
        case .sendAnswer:
            invalidateInitCallTimeout()
            invalidateIncomingCallTimeout()
            invalidateCallFailedTimer()
        case .receivedAnswer:
            invalidateInitCallTimeout()
            invalidateCallFailedTimer()
        case .initializing:
            invalidateInitCallTimeout()
            invalidateIncomingCallTimeout()
        case .calling:
            invalidateInitCallTimeout()
            invalidateIncomingCallTimeout()
            invalidateCallFailedTimer()
        case .reconnecting:
            invalidateInitCallTimeout()
            invalidateIncomingCallTimeout()
        case .ended, .remoteEnded:
            invalidateInitCallTimeout()
            invalidateIncomingCallTimeout()
            invalidateCallFailedTimer()
        case .rejected, .rejectedBusy, .rejectedTimeout, .rejectedDisabled, .rejectedOffHours, .rejectedUnknown:
            invalidateInitCallTimeout()
            invalidateCallDuration()
            invalidateIncomingCallTimeout()
            invalidateCallFailedTimer()
        case .microphoneDisabled:
            invalidateInitCallTimeout()
            invalidateCallDuration()
            invalidateIncomingCallTimeout()
            invalidateCallFailedTimer()
        @unknown default:
            break
        }
    }
    
    /// Invalidate the incoming call timer
    private func invalidateIncomingCallTimeout() {
        incomingCallTimeoutTimer?.invalidate()
        incomingCallTimeoutTimer = nil
    }
    
    /// Invalidate the init call timer
    private func invalidateInitCallTimeout() {
        initCallTimeoutTimer?.invalidate()
        initCallTimeoutTimer = nil
    }
    
    /// Invalidate the call duration timer and set the callDurationTime to 0
    private func invalidateCallDuration() {
        callDurationTimer?.invalidate()
        callDurationTimer = nil
        callDurationTime = 0
    }
    
    /// Invalidate the call duration timer and set the callDurationTime to 0
    private func invalidateCallFailedTimer() {
        callFailedTimer?.invalidate()
        callFailedTimer = nil
    }
    
    /// Add icecandidate to local array if it's in the correct state. Start a timer to send candidates as packets all 0.05 seconds
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
            let seperatedCandidates = localAddedIceCandidates.take(localAddedIceCandidates.count)
            if !seperatedCandidates.isEmpty {
                let message = VoIPCallIceCandidatesMessage(
                    removed: false,
                    candidates: seperatedCandidates,
                    contactIdentity: contactIdentity,
                    callID: callID!,
                    completion: nil
                )
                voIPCallSender.sendVoIPCall(iceCandidates: message)
            }
            localAddedIceCandidates.removeAll()
        case .idle, .receivedOffer, .incomingRinging, .sendAnswer:
            addCandidateToLocalArray(candidates)
        case .ended, .remoteEnded, .rejected, .rejectedBusy, .rejectedTimeout, .rejectedOffHours, .rejectedUnknown,
             .rejectedDisabled, .microphoneDisabled:
            // do nothing
            
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
                "VoipCallService: [cid=\(callID?.callID ?? 0)]: Discarding loopback candidate: \(candidate.sdp)"
            )
            return (false, "loopback")
        }
        
        // Discard IPv6 if disabled
        if UserSettings.shared()?.enableIPv6 == false && ip.contains(":") {
            DDLogNotice(
                "VoipCallService: [cid=\(callID?.callID ?? 0)]: Discarding local IPv6 candidate: \(candidate.sdp)"
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
                    "VoipCallService: [cid=\(callID?.callID ?? 0)]: Discarding local relay candidate (duplicate related address: \(relatedAddress)): \(candidate.sdp)"
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
    
    /// Handle notification if needed
    private func handleLocalNotification() {
        
        func addMissedCall() {
            if let identity = contactIdentity {
                DispatchQueue.main.async {
                    if AppDelegate.shared().isAppInBackground(),
                       !self.isCallInitiator(),
                       self.callDurationTime == 0 {
                        let pushSetting = PushSetting(forThreemaID: identity)
                        let canSendPush = pushSetting.canSendPush()
                        
                        if canSendPush {
                            // callkit is disabled --> show missed notification
                            
                            let notification = UNMutableNotificationContent()
                            notification.categoryIdentifier = "CALL"
                            
                            if UserSettings.shared().pushSound != "none" {
                                if !pushSetting.silent {
                                    notification
                                        .sound =
                                        UNNotificationSound(named: UNNotificationSoundName(
                                            rawValue: UserSettings
                                                .shared().pushSound! + ".caf"
                                        ))
                                }
                            }
                                
                            let entityManager = BusinessInjector().entityManager
                            let contact = entityManager.entityFetcher.contact(for: self.contactIdentity)
                            notification.userInfo = ["threema": ["cmd": "missedcall", "from": identity]]
                            if !UserSettings.shared().pushShowNickname,
                               let displayName = contact?.displayName {
                                notification.title = displayName
                            }
                            else {
                                if let publicNickname = contact?.publicNickname,
                                   !publicNickname.isEmpty {
                                    notification.title = publicNickname
                                }
                                else {
                                    notification.title = identity
                                }
                            }
                            notification.body = BundleUtil.localizedString(forKey: "call_missed")
                            
                            // Group notification together with others from the same contact
                            notification.threadIdentifier = "SINGLE-\(self.contactIdentity ?? "")"
                            
                            let notificationRequest = UNNotificationRequest(
                                identifier: identity,
                                content: notification,
                                trigger: nil
                            )
                            UNUserNotificationCenter.current().add(notificationRequest, withCompletionHandler: { _ in
                            })
                        }
                    }
                }
            }
        }
        
        switch state {
        case .idle:
            break
        case .sendOffer:
            break
        case .receivedOffer:
            break
        case .outgoingRinging:
            break
        case .incomingRinging:
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
        case .ended:
            break
        case .remoteEnded:
            addMissedCall()
        case .rejected, .rejectedOffHours, .rejectedUnknown, .rejectedDisabled:
            break
        case .rejectedBusy, .rejectedTimeout:
            addMissedCall()
        case .microphoneDisabled:
            break
        }
    }
    
    /// Add call message to conversation
    private func addCallMessageToConversation(oldCallState: CallState) {
        
        let entityManager = BusinessInjector().entityManager
        let utilities = ConversationActions(entityManager: entityManager)

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
            if UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT") {
                return
            }
            
            // if remoteEnded is incoming at the same time like user tap on end call button
            if oldCallState == .ended || oldCallState == .remoteEnded {
                return
            }

            guard let identity = contactIdentity else {
                return
            }
            
            var messageRead = true
            var systemMessage: SystemMessage?
            
            entityManager.performSyncBlockAndSafe {
                let conversation = entityManager.conversation(for: identity, createIfNotExisting: true)
                systemMessage = entityManager.entityCreator.systemMessage(for: conversation)
                                
                systemMessage?.type = NSNumber(value: kSystemMessageCallEnded)
                
                var callInfo = [
                    "DateString": DateFormatter.shortStyleTimeNoDate(Date()),
                    "CallInitiator": NSNumber(booleanLiteral: self.isCallInitiator()),
                ] as [String: Any]
                if self.callDurationTime > 0 {
                    callInfo["CallTime"] = DateFormatter.timeFormatted(self.callDurationTime)
                }
                
                if !self.isCallInitiator(),
                   self.callDurationTime == 0 {
                    messageRead = false
                }
                                
                do {
                    let callInfoData = try JSONSerialization.data(withJSONObject: callInfo, options: .prettyPrinted)
                    systemMessage?.arg = callInfoData
                    systemMessage?.isOwn = NSNumber(booleanLiteral: self.isCallInitiator())
                    systemMessage?.conversation = conversation
                    if messageRead {
                        systemMessage?.read = NSNumber(booleanLiteral: true)
                        systemMessage?.readDate = Date()
                    }
                    conversation?.lastMessage = systemMessage
                    conversation?.lastUpdate = Date()
                    utilities.unarchive(conversation!)
                }
                catch {
                    DDLogError(
                        "VoipCallService: [cid=\(self.currentCallID()?.callID ?? 0)]: Can't add call info to system message"
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
            entityManager.performBlockAndWait {
                guard let identity = self.contactIdentity,
                      let conversation = entityManager.conversation(for: identity, createIfNotExisting: true) else {
                    return
                }
                self.addRejectedMessageToConversation(contactIdentity: identity, reason: kSystemMessageCallRejected)
                utilities.unarchive(conversation)
            }
        case .rejectedTimeout:
            // add call message
            guard let identity = contactIdentity,
                  let conversation = entityManager.conversation(for: identity, createIfNotExisting: true) else {
                return
            }
            let reason = isCallInitiator() ? kSystemMessageCallRejectedTimeout : kSystemMessageCallMissed
            addRejectedMessageToConversation(contactIdentity: identity, reason: reason)
            utilities.unarchive(conversation)

        case .rejectedBusy:
            // add call message
            guard let identity = contactIdentity,
                  let conversation = entityManager.conversation(for: identity, createIfNotExisting: true) else {
                return
            }
            let reason = isCallInitiator() ? kSystemMessageCallRejectedBusy : kSystemMessageCallMissed
            addRejectedMessageToConversation(contactIdentity: identity, reason: reason)
            utilities.unarchive(conversation)

        case .rejectedOffHours:
            // add call message
            guard let identity = contactIdentity,
                  let conversation = entityManager.conversation(for: identity, createIfNotExisting: true) else {
                return
            }
            let reason = isCallInitiator() ? kSystemMessageCallRejectedOffHours : kSystemMessageCallMissed
            addRejectedMessageToConversation(contactIdentity: identity, reason: reason)
            utilities.unarchive(conversation)

        case .rejectedUnknown:
            // add call message
            guard let identity = contactIdentity,
                  let conversation = entityManager.conversation(for: identity, createIfNotExisting: true) else {
                return
            }
            let reason = isCallInitiator() ? kSystemMessageCallRejectedUnknown : kSystemMessageCallMissed
            addRejectedMessageToConversation(contactIdentity: identity, reason: reason)
            utilities.unarchive(conversation)

        case .rejectedDisabled:
            // add call message
            if callInitiator {
                guard let identity = contactIdentity,
                      let conversation = entityManager.conversation(for: identity, createIfNotExisting: true) else {
                    return
                }
                addRejectedMessageToConversation(contactIdentity: identity, reason: kSystemMessageCallRejectedDisabled)
                utilities.unarchive(conversation)
            }
            
        case .microphoneDisabled:
            guard let identity = contactIdentity,
                  let conversation = entityManager.conversation(for: identity, createIfNotExisting: true) else {
                return
            }
            utilities.unarchive(conversation)
        }
    }
    
    private func addRejectedMessageToConversation(contactIdentity: String, reason: Int) {
        var systemMessage: SystemMessage?

        let entityManager = BusinessInjector().entityManager
        entityManager.performSyncBlockAndSafe {
            if let conversation = entityManager.conversation(for: contactIdentity, createIfNotExisting: true) {
                systemMessage = entityManager.entityCreator.systemMessage(for: conversation)
                systemMessage?.type = NSNumber(value: reason)
                let callInfo = [
                    "DateString": DateFormatter.shortStyleTimeNoDate(Date()),
                    "CallInitiator": NSNumber(booleanLiteral: self.isCallInitiator()),
                ] as [String: Any]
                do {
                    let callInfoData = try JSONSerialization.data(withJSONObject: callInfo, options: .prettyPrinted)
                    systemMessage?.arg = callInfoData
                    systemMessage?.isOwn = NSNumber(booleanLiteral: self.isCallInitiator())
                    systemMessage?.conversation = conversation
                    conversation.lastMessage = systemMessage
                    conversation.lastUpdate = Date()
                    if reason == kSystemMessageCallMissed || reason == kSystemMessageCallRejectedBusy || reason ==
                        kSystemMessageCallRejectedTimeout || reason == kSystemMessageCallRejectedDisabled { }
                    else {
                        systemMessage?.read = true
                        systemMessage?.readDate = Date()
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
        if reason == kSystemMessageCallMissed || reason == kSystemMessageCallRejectedBusy || reason ==
            kSystemMessageCallRejectedTimeout || reason == kSystemMessageCallRejectedDisabled {
            DispatchQueue.main.async {
                let notificationManager = NotificationManager()
                notificationManager.updateUnreadMessagesCount(baseMessage: systemMessage)
            }
        }
    }
    
    private func addUnknownCallIcecandidatesMessages(message: VoIPCallIceCandidatesMessage) {
        receivedIceCandidatesLockQueue.sync {
            guard let identity = message.contactIdentity else {
                return
            }
            if var contactCandidates = receivedUnknowCallIcecandidatesMessages[identity] {
                contactCandidates.append(message)
            }
            else {
                receivedUnknowCallIcecandidatesMessages[identity] = [message]
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
        var message = BundleUtil.localizedString(forKey: "call_status_failed_connected_message")
        if !iceWasConnected {
            // show error as notification
            if let identity = contactIdentity {
                let hangupMessage = VoIPCallHangupMessage(contactIdentity: identity, callID: callID!, completion: nil)
                voIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage)
            }
            message = BundleUtil.localizedString(forKey: "call_status_failed_initializing_message")
        }
        NotificationBannerHelper.newErrorToast(
            title: BundleUtil.localizedString(forKey: "call_status_failed_title"),
            body: message
        )
        invalidateCallFailedTimer()
        handleTones(state: .ended, oldState: .reconnecting)
        callKitManager?.endCall()
        dismissCallView()
        disconnectPeerConnection()
    }

    private func callCantCreateOffer(error: Error?) {
        DDLogNotice(
            "VoipCallService: [cid=\(callID?.callID ?? 0)]: Can't create offer (\(error?.localizedDescription ?? "error is missing")"
        )
        let message = BundleUtil.localizedString(forKey: "call_status_failed_sdp_patch_message")
        NotificationBannerHelper.newErrorToast(
            title: BundleUtil.localizedString(forKey: "call_status_failed_title"),
            body: message
        )
        invalidateCallFailedTimer()
        handleTones(state: .ended, oldState: .reconnecting)
        callKitManager?.endCall()
        dismissCallView()
        disconnectPeerConnection()
    }
}

// MARK: - VoIPCallPeerConnectionClientDelegate

extension VoIPCallService: VoIPCallPeerConnectionClientDelegate {
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, removedCandidates: [RTCIceCandidate]) {
        // ICE candidate messages are currently allowed to have a "removed" flag. However, this is non-standard.
        // Ignore generated ICE candidates with removed set to true coming from libwebrtc
        
        for candidate in removedCandidates {
            let reason = shouldAdd(candidate: candidate, local: true).1 ?? "unknown"
            DDLogNotice(
                "VoipCallService: [cid=\(callID?.callID ?? 0)]: Ignoring local ICE candidate (\(reason)): \(candidate.sdp)"
            )
        }
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, addedCandidate: RTCIceCandidate) {
        if contactIdentity != nil {
            handleLocalIceCandidates([addedCandidate])
        }
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, changeState: CallState) {
        state = changeState
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, audioMuted: Bool) {
        self.audioMuted = audioMuted
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, speakerActive: Bool) {
        self.speakerActive = speakerActive
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: speakerActive ? .videoChat : .voiceChat,
                options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.overrideOutputAudioPort(speakerActive ? .speaker : .none)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, receivingVideo: Bool) {
        if isReceivingVideo != receivingVideo {
            isReceivingVideo = receivingVideo
        }
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, shouldShowCellularCallWarning: Bool) {
        self.shouldShowCellularCallWarning = shouldShowCellularCallWarning
    }
    
    func peerConnectionClient(
        _ client: VoIPCallPeerConnectionClient,
        didChangeConnectionState state: RTCIceConnectionState
    ) {
        let oldState = self.state
        
        switch state {
        case .new:
            break
        case .checking:
            self.state = .initializing
        case .connected:
            invalidateCallFailedTimer()
            iceWasConnected = true
            if self.state != .reconnecting {
                self.state = .calling
                DispatchQueue.main.async {
                    self.callDurationTime = 0
                    self.callDurationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { _ in
                        self.callDurationTime = self.callDurationTime + 1
                        if self.state == .calling {
                            self.callViewController?.voIPCallDurationChanged(self.callDurationTime)
                        }
                        else {
                            self.callViewController?.voIPCallStatusChanged(state: self.state, oldState: self.state)
                            DDLogWarn(
                                "VoipCallService: [cid=\(self.callID?.callID ?? 0)]: State is connected, but shows something different \(self.state.description())"
                            )
                        }
                        if VoIPHelper.shared()?.isCallActiveInBackground == true {
                            NotificationCenter.default.post(
                                name: NSNotification.Name(kNotificationNavigationItemPromptShouldChange),
                                object: self.callDurationTime
                            )
                        }
                    })
                }
                callViewController?.startDebugMode(connection: client.peerConnection)
                callKitManager?.callConnected()
            }
            else {
                self.state = .calling
            }
            activateRTCAudio()
        case .completed:
            break
        case .failed:
            if self.state == .reconnecting {
                callFailed()
            }
            else {
                if iceWasConnected {
                    self.state = .reconnecting
                    DDLogNotice(
                        "VoipCallService: [cid=\(callID?.callID ?? 0)]: PeerConnection failed, set state to reconnecting and start callFailedTimer"
                    )
                }
                else {
                    self.state = .initializing
                    DDLogNotice(
                        "VoipCallService: [cid=\(callID?.callID ?? 0)]: PeerConnection failed, set state to initializing and start callFailedTimer"
                    )
                }
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
        case .disconnected:
            if self.state == .calling || self.state == .initializing {
                self.state = .reconnecting
            }
        case .closed:
            break
        case .count:
            break
        @unknown default:
            break
        }
        if oldState != self.state {
            DDLogNotice(
                "VoipCallService: [cid=\(callID?.callID ?? 0)]: Call state change from \(oldState.description()) to \(self.state.description())"
            )
        }
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, didReceiveData: Data) {
        let threemaVideoCallSignalingMessage = CallsignalingProtocol
            .decodeThreemaVideoCallSignalingMessage(didReceiveData)
        
        if let videoQualityProfile = threemaVideoCallSignalingMessage.videoQualityProfile {
            peerConnectionClient?.remoteVideoQualityProfile = videoQualityProfile
        }
        
        if let captureState = threemaVideoCallSignalingMessage.captureStateChange {
            switch captureState.device {
            case .camera:
                switch captureState.state {
                case .off:
                    peerConnectionClient?.isRemoteVideoActivated = false
                case .on:
                    peerConnectionClient?.isRemoteVideoActivated = true
                }
            default: break
            }
        }
        
        debugPrint(threemaVideoCallSignalingMessage)
    }
}

extension Array {
    func take(_ elementsCount: Int) -> [Element] {
        let min = Swift.min(elementsCount, count)
        return Array(self[0..<min])
    }
}
