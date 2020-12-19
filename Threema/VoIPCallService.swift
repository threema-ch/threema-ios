//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2020 Threema GmbH
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
import CocoaLumberjackSwift

protocol VoIPCallServiceDelegate: class {
    func callServiceFinishedProcess()
}

class VoIPCallService: NSObject {
    
    private let kIncomingCallTimeout = 60.0
    private let kCallFailedTimeout = 15.0
    
    @objc public enum CallState: Int, RawRepresentable, Equatable {
        case idle
        case sendOffer
        case receivedOffer
        case outgoingRinging
        case incomingRinging
        case sendAnswer
        case receivedAnswer
        case initalizing
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
    }
    
    weak var delegate: VoIPCallServiceDelegate?
    
    private var peerConnectionClient: VoIPCallPeerConnectionClient?
    private var callKitManager: VoIPCallKitManager?
    private var threemaVideoCallAvailable: Bool = false
    private var callViewController: CallViewController?
    private var state: CallState = .idle {
        didSet {
            self.invalidateTimers(state: state)
            callViewController?.voIPCallStatusChanged(state: state, oldState: oldValue)
            self.handleLocalNotification()
            switch state {
            case .idle:
                localAddedIceCandidates.removeAll()
                localRelatedAddresses.removeAll()
                receivedIcecandidatesMessages.removeAll()
            case .initalizing:
                handleLocalIceCandidates([])
            default:
                // do nothing
                break
            }
            self.addCallMessageToConversation(oldCallState: oldValue)
            handleTones(state: state, oldState: oldValue)
        }
    }
    private var audioPlayer: AVAudioPlayer?
    private var contact: Contact?
    private var callId: VoIPCallId?
    private var alreadyAccepted: Bool = false {
        didSet {
            callViewController?.alreadyAccepted = alreadyAccepted
        }
    }
    private var callInitiator: Bool = false {
        didSet {
            callViewController?.isCallInitiator = callInitiator
        }
    }
    private var audioMuted: Bool = false
    private var speakerActive: Bool = false
    private var videoActive: Bool = false
    private var isReceivingVideo: Bool = false {
        didSet {
            if callViewController != nil {
                callViewController?.isReceivingRemoteVideo = self.isReceivingVideo
            }
        }
    }
    
    private var initCallTimeoutTimer: Timer?
    private var incomingCallTimeoutTimer: Timer?
    private var callDurationTimer: Timer?
    private var callDurationTime: Int = 0
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
    private var iceWasConnected: Bool = false
    
    private var isModal : Bool {
        // Check whether our callViewController is currently in the state presented modally
        let a = self.callViewController?.presentingViewController?.presentedViewController == self.callViewController
        // Check whether our callViewController has a navigationController
        let b1 = self.callViewController?.navigationController != nil
        // Check whether our callViewController is in the state presented modally as part of a navigation controller
        let b2 = self.callViewController?.navigationController?.presentingViewController?.presentedViewController == self.callViewController?.navigationController
        let b = b1 && b2
        // Check whether our callViewController has a tabbarcontroller which has a tabbarcontroller. Nesting two
        // tabBarControllers is only possible in the state presented modally
        let c = self.callViewController?.tabBarController?.presentingViewController is UITabBarController
        return a || b || c
    }
    
    required override init() {
        super.init()
        
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) { (n) in
            if self.state != .idle {
                var isBluetoothAvailable = false
                if let inputs = AVAudioSession.sharedInstance().availableInputs {
                    for input in inputs {
                        if input.portType == AVAudioSession.Port.bluetoothA2DP || input.portType == AVAudioSession.Port.bluetoothHFP || input.portType == AVAudioSession.Port.bluetoothLE {
                            isBluetoothAvailable = true
                        }
                    }
                }
                guard let info = n.userInfo,
                    let value = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                    let reason = AVAudioSession.RouteChangeReason(rawValue: value) else { return }
                
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
                            break
                        case .builtInSpeaker:
                            if isBluetoothAvailable {
                                self.speakerActive = true
                                try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                            }
                            if !self.speakerActive {
                                try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                            }
                            break
                        case .headphones:
                            try? AVAudioSession.sharedInstance().overrideOutputAudioPort(self.speakerActive ? .speaker : .none)
                            break
                        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                            break
                        default:break
                        }
                    }
                    break
                default: break
                }
            }
        }
    }
}

extension VoIPCallService {
    // MARK: class functions
    
}

extension VoIPCallService {
    // MARK: public functions
    
    /**
     Return the string of the current state for the ValidationLogger
     - Returns: String of the current state
     */
    func callStateString() -> String {
        switch state {
        case .idle: return "idle"
        case .sendOffer: return "sendOffer"
        case .receivedOffer: return "receivedOffer"
        case .outgoingRinging: return "outgoingRinging"
        case .incomingRinging: return "incomingRinging"
        case .sendAnswer: return "sendAnswer"
        case .receivedAnswer: return "receivedAnswer"
        case .initalizing: return "initalizing"
        case .calling: return "calling"
        case .reconnecting: return "reconnecting"
        case .ended: return "ended"
        case .remoteEnded: return "remoteEnded"
        case .rejected: return "rejected"
        case .rejectedBusy: return "rejectedBusy"
        case .rejectedTimeout: return "rejectedTimeout"
        case .rejectedDisabled: return "rejectedDisabled"
        case .rejectedOffHours: return "rejectedOffHours"
        case .rejectedUnknown: return "rejectedUnknown"
        case .microphoneDisabled: return "microphoneDisabled"
        }
    }
    
    /**
     Get the localized string for the current state
     - Returns: Current localized call state string
     */
    func callStateLocalizedString() -> String {
        switch state {
        case .idle: return BundleUtil.localizedString(forKey: "call_status_idle")
        case .sendOffer: return BundleUtil.localizedString(forKey: "call_status_wait_ringing")
        case .receivedOffer: return BundleUtil.localizedString(forKey: "call_status_wait_ringing")
        case .outgoingRinging: return BundleUtil.localizedString(forKey: "call_status_ringing")
        case .incomingRinging: return BundleUtil.localizedString(forKey: "call_status_incom_ringing")
        case .sendAnswer: return BundleUtil.localizedString(forKey: "call_status_ringing")
        case .receivedAnswer: return BundleUtil.localizedString(forKey: "call_status_ringing")
        case .initalizing: return BundleUtil.localizedString(forKey: "call_status_initializing")
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
    
    /**
     Start process to handle the message
     - parameter element: Message
     */
    func startProcess(element: Any) {
        if let action = element as? VoIPCallUserAction {
            switch action.action {
            case .call:
                startCallAsInitiator(action: action, completion: {
                    self.delegate?.callServiceFinishedProcess()
                    action.completion?()
                })
                break
            case .callWithVideo:
                startCallAsInitiator(action: action, completion: {
                    self.delegate?.callServiceFinishedProcess()
                    action.completion?()
                })
                break
            case .accept:
                self.alreadyAccepted = true
                self.acceptIncomingCall(action: action) {
                    self.delegate?.callServiceFinishedProcess()
                    action.completion?()
                }
                break
            case .acceptCallKit:
                self.alreadyAccepted = true
                self.acceptIncomingCall(action: action) {
                    self.delegate?.callServiceFinishedProcess()
                    action.completion?()
                }
                break
            case .reject:
                rejectCall(action: action)
                action.completion?()
                self.delegate?.callServiceFinishedProcess()
                break
            case .rejectDisabled:
                rejectCall(action: action)
                action.completion?()
                self.delegate?.callServiceFinishedProcess()
                break
            case .rejectTimeout:
                rejectCall(action: action)
                action.completion?()
                self.delegate?.callServiceFinishedProcess()
                break
            case .rejectBusy:
                rejectCall(action: action)
                action.completion?()
                self.delegate?.callServiceFinishedProcess()
                break
            case .rejectOffHours:
                rejectCall(action: action)
                action.completion?()
                self.delegate?.callServiceFinishedProcess()
                break
            case .rejectUnknown:
                rejectCall(action: action)
                action.completion?()
                self.delegate?.callServiceFinishedProcess()
                break
            case .end:
                DDLogNotice("Threema call: HangupBug -> Send hangup for end action")
                if state == .sendOffer || state == .outgoingRinging || state == .sendAnswer || state == .receivedAnswer || state == .initalizing || state == .calling || state == .reconnecting {
                    RTCAudioSession.sharedInstance().isAudioEnabled = false
                    let hangupMessage = VoIPCallHangupMessage(contact: action.contact, callId: action.callId!, completion: nil)
                    VoIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage, wait: false)
                    state = .ended
                    callKitManager?.endCall()
                    dismissCallView()
                    disconnectPeerConnection()
                }
                self.delegate?.callServiceFinishedProcess()
                action.completion?()
                break
            case .speakerOn:
                speakerActive = true
                peerConnectionClient?.speakerOn()
                self.delegate?.callServiceFinishedProcess()
                action.completion?()
                break
            case .speakerOff:
                speakerActive = false
                peerConnectionClient?.speakerOff()
                self.delegate?.callServiceFinishedProcess()
                action.completion?()
                break
            case .muteAudio:
                peerConnectionClient?.muteAudio(completion: {
                    self.delegate?.callServiceFinishedProcess()
                    action.completion?()
                })
                break
            case .unmuteAudio:
                peerConnectionClient?.unmuteAudio(completion: {
                    self.delegate?.callServiceFinishedProcess()
                    action.completion?()
                })
                break
            case .showCallScreen:
                if contact != nil {
                    presentCallView(contact: contact!, alreadyAccepted:alreadyAccepted , isCallInitiator: callInitiator, isThreemaVideoCallAvailable: threemaVideoCallAvailable, videoActive: videoActive, receivingVideo: isReceivingVideo, viewWasHidden: true)
                }
                self.delegate?.callServiceFinishedProcess()
                action.completion?()
                break
            case .hideCallScreen:
                dismissCallView()
                self.delegate?.callServiceFinishedProcess()
                action.completion?()
                break
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
            self.delegate?.callServiceFinishedProcess()
        }
    }
    
    /**
     Get the current call state
     - Returns: CallState
     */
    func currentState() -> CallState {
        return state
    }
    
    /**
     Get the current call contact
     - Returns: Contact or nil
     */
    func currentContact() -> Contact? {
        return contact
    }
    /**
    Get the current callId
    - Returns: VoIPCallId or nil
    */
    func currentCallId() -> VoIPCallId? {
        return callId
    }
    
    /**
     Is initiator of the current call
     - Returns: true or false
     */
    func isCallInitiator() -> Bool {
        return callInitiator
    }
    
    /**
     Is the current call muted
     - Returns: true or false
     */
    func isCallMuted() -> Bool {
        return audioMuted
    }
    
    /**
     Is the speaker for the current call active
     - Returns: true or false
     */
    func isSpeakerActive() -> Bool {
        return speakerActive
    }
    
    /**
     Is the current call already accepted
     - Returns: true or false
     */
    func isCallAlreadyAccepted() -> Bool {
        return alreadyAccepted
    }
    
    /**
     Present the CallViewController
     */
    func presentCallViewController() {
        if contact != nil {
            presentCallView(contact: contact!, alreadyAccepted: alreadyAccepted, isCallInitiator: callInitiator, isThreemaVideoCallAvailable: threemaVideoCallAvailable, videoActive: videoActive, receivingVideo: isReceivingVideo, viewWasHidden: alreadyAccepted)
        }
    }
    
    /**
     Dismiss the CallViewController
     */
    func dismissCallViewController() {
        dismissCallView()
    }
    
    
    /**
     Set the RTC audio session from CallKit
     - parameter callKitAudioSession: AVAudioSession from callkit
     */
    func setRTCAudioSession(_ callKitAudioSession: AVAudioSession) {
        handleTones(state: .calling, oldState: .calling)
        RTCAudioSession.sharedInstance().audioSessionDidActivate(callKitAudioSession)
    }
    
    /**
     Configure the audio session and set RTC audio active
     */
    func activateRTCAudio() {
        peerConnectionClient?.activateRTCAudio(speakerActive: speakerActive)
    }
    
    /**
     Start capture local video
     */
    func startCaptureLocalVideo(renderer: RTCVideoRenderer, useBackCamera: Bool, switchCamera: Bool = false) {
        localRenderer = renderer
        videoActive = true
        peerConnectionClient?.startCaptureLocalVideo(renderer: renderer, useBackCamera: useBackCamera, switchCamera: switchCamera)
    }
        
    /**
     End capture local video
     */
    func endCaptureLocalVideo(switchCamera: Bool = false) {
        if !switchCamera {
            videoActive = false
        }
        if let renderer = localRenderer {
            peerConnectionClient?.endCaptureLocalVideo(renderer: renderer, switchCamera: switchCamera)
            localRenderer = nil
        }
    }
    
    /**
    Get local video renderer
    */
    func localVideoRenderer() -> RTCVideoRenderer? {
        return localRenderer
    }
    
    /**
     Start render remote video
     */
    func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        remoteRenderer = renderer
        peerConnectionClient?.renderRemoteVideo(to: renderer)
    }
    
    /**
     End remote video
     */
    func endRemoteVideo() {
        if let renderer = remoteRenderer {
            peerConnectionClient?.endRemoteVideo(renderer: renderer)
            remoteRenderer = nil
        }
    }
    
    /**
    Get remote video renderer
    */
    func remoteVideoRenderer() -> RTCVideoRenderer? {
        return remoteRenderer
    }
    
    /**
     Get peer video quality profile
     */
    func remoteVideoQualityProfile() -> CallsignalingProtocol.ThreemaVideoCallQualityProfile? {
        return peerConnectionClient?.remoteVideoQualityProfile
    }
    
    /**
     Get peer is using turn server
     */
    func networkIsRelayed() -> Bool {
        return peerConnectionClient?.networkIsRelayed ?? false
    }
}

extension VoIPCallService {
    // MARK: private functions
    
    /**
     When the current call state is idle and the permission is granted to the microphone, it will create the peer client and add the offer.
     If the state is wrong, it will reject the call with the reason unknown.
     If the permission to the microphone is not granted, it will reject the call with the reason unknown.
     If Threema Calls are disabled, it will reject the call with the reason disabled.
     - parameter offer: VoIPCallOfferMessage
     - parameter completion: Completion block
     */
    private func handleOfferMessage(offer: VoIPCallOfferMessage, completion: @escaping (() -> Void)) {
        DDLogNotice("Threema call: handle incomming offer from \(offer.contact?.identity ?? "?") with callId \(offer.callId.callId)")
        if UserSettings.shared().enableThreemaCall == true && is64Bit == 1 {
            var appRunsInBackground = false
            DispatchQueue.main.sync {
                appRunsInBackground = AppDelegate.shared().isAppInBackground()
            }
            if state == .idle {
                if PendingMessagesManager.canMasterDndSendPush() == false {
                    DDLogNotice("Threema call: handleOfferMessage -> Master DND active -> reject call from \(String(describing: offer.contact?.identity))");
                    self.contact = offer.contact
                    let action = VoIPCallUserAction.init(action: .rejectOffHours, contact: offer.contact!, callId: offer.callId, completion: offer.completion)
                    self.rejectCall(action: action, closeCallView: true)
                    completion()
                    return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
                    if granted == true {
                        DDLogNotice("Threema call: handleOfferMessage -> Add offer -> set contact to service \(String(describing: offer.contact?.identity))");
                        self.contact = offer.contact
                        self.alreadyAccepted = false
                        self.state = .receivedOffer
                        self.incomingOffer = offer
                        self.callId = offer.callId
                        self.videoActive = false
                        self.isReceivingVideo = false
                        self.localRenderer = nil
                        self.remoteRenderer = nil
                        self.threemaVideoCallAvailable = offer.isVideoAvailable
                        self.startIncomingCallTimeoutTimer()
                        if UserSettings.shared()?.enableCallKit == true && Locale.current.regionCode != "CN" {
                            if self.callKitManager == nil {
                                self.callKitManager = VoIPCallKitManager.init()
                            }
                        } else {
                            self.callKitManager = nil
                        }
                        
                        // send ringing message
                        let ringingMessage = VoIPCallRingingMessage(contact: offer.contact!, callId: offer.callId, completion: nil)
                        VoIPCallSender.sendVoIPCallRinging(ringingMessage: ringingMessage)
                        self.callKitManager?.reportIncomingCall(uuid: UUID.init(), contact: offer.contact!)
                        if self.callKitManager == nil {
                            self.presentCallView(contact: offer.contact!, alreadyAccepted: false, isCallInitiator: false, isThreemaVideoCallAvailable: self.threemaVideoCallAvailable, videoActive: false, receivingVideo: false, viewWasHidden: false)
                        }
                        self.state = .incomingRinging
                        
                        // Prefetch ICE/TURN servers so they're likely to be already available when the user accepts the call
                        VoIPIceServerSource.prefetchIceServers()
                        
                        completion()
                    } else {
                        DDLogNotice("Threema call: handleOfferMessage -> Audio is not granted -> reject call from \(String(describing: offer.contact?.identity))");
                        self.contact = offer.contact
                        self.state = .microphoneDisabled
                        // reject call because there is no permission for the microphone
                        self.state = .rejectedDisabled
                        let action = VoIPCallUserAction.init(action: .rejectUnknown, contact: offer.contact!, callId: offer.callId, completion: offer.completion)
                        self.rejectCall(action: action, closeCallView: false)
                        
                        if appRunsInBackground == true {
                            // show notification that incoming call can't process because mic is not granted
                            self.disconnectPeerConnection()
                            completion()
                        } else {
                            self.presentCallView(contact: offer.contact!, alreadyAccepted: false, isCallInitiator: false, isThreemaVideoCallAvailable: self.threemaVideoCallAvailable, videoActive: false, receivingVideo: false, viewWasHidden: false, completion: {
                                // no access to microphone, stopp call
                                let alertTitle = BundleUtil.localizedString(forKey: "call_microphone_permission_title")
                                let alertMessage = BundleUtil.localizedString(forKey: "call_microphone_permission_text")
                                let alert = UIAlertController.init(title:alertTitle , message: alertMessage, preferredStyle: .alert)
                                alert.addAction(UIAlertAction.init(title: BundleUtil.localizedString(forKey: "settings"), style: .default, handler: { (action) in
                                    self.dismissCallView()
                                    self.disconnectPeerConnection()
                                    UIApplication.shared.open(NSURL.init(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil)
                                }))
                                alert.addAction(UIAlertAction.init(title: BundleUtil.localizedString(forKey: "ok"), style: .default, handler: { (action) in
                                    self.dismissCallView()
                                    self.disconnectPeerConnection()
                                }))
                                
                                let rootVC = self.callViewController != nil ? self.callViewController! : UIApplication.shared.keyWindow?.rootViewController!
                                DispatchQueue.main.async {
                                    rootVC?.present(alert, animated: true, completion: nil)
                                }
                                
                                completion()
                            })
                        }
                    }
                }
            } else {
                DDLogNotice("Threema call: handleOfferMessage -> State is not idle");
                if contact == offer.contact && state == .incomingRinging {
                    DDLogNotice("Threema call: handleOfferMessage -> same contact as the current call");
                    if PendingMessagesManager.canMasterDndSendPush() == false && appRunsInBackground == true{
                        DDLogNotice("Threema call: handleOfferMessage -> Master DND active -> reject call from \(String(describing: offer.contact?.identity))");
                        let action = VoIPCallUserAction.init(action: .rejectOffHours, contact: offer.contact!, callId: offer.callId, completion: offer.completion)
                        self.rejectCall(action: action, closeCallView: true)
                        completion()
                    } else {
                        DDLogNotice("Threema call: handleOfferMessage -> Master DND inactive -> set offer \(String(describing: offer.contact?.identity))");
                        disconnectPeerConnection()
                        handleOfferMessage(offer: offer, completion: completion)
                    }
                } else {
                    DDLogNotice("Threema call: handleOfferMessage -> reject call, it's the wrong state");
                    // reject call because it's the wrong state
                    let reason: VoIPCallUserAction.Action = contact == offer.contact ? .rejectUnknown : .rejectBusy
                    let action = VoIPCallUserAction.init(action: reason, contact: offer.contact!, callId: offer.callId, completion: offer.completion)
                    rejectCall(action: action)
                    completion()
                }
            }
        } else {
            DDLogNotice("Threema call: handleOfferMessage -> reject all, threema call is disabled");
            // reject call because Threema Calls are disabled or unavailable
            let action = VoIPCallUserAction.init(action: .rejectDisabled, contact: offer.contact!, callId: offer.callId, completion: offer.completion)
            rejectCall(action: action)
            completion()
        }
    }
    
    private func startIncomingCallTimeoutTimer() {
        DispatchQueue.main.async {
            if let offer = self.incomingOffer {
                self.invalidateIncomingCallTimeout()
                self.incomingCallTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.kIncomingCallTimeout, repeats: false, block: { (timeout) in
                    BackgroundTaskManager.shared.newBackgroundTask(key: kAppVoIPBackgroundTask, timeout: Int(kAppVoIPBackgroundTaskTime)) {
                        ServerConnector.shared()?.connectWait()
                        let action = VoIPCallUserAction.init(action: .rejectTimeout, contact: offer.contact!, callId: offer.callId, completion: offer.completion)
                        self.state = .rejectedTimeout
                        self.callKitManager?.timeoutCall()
                        self.rejectCall(action: action)
                        self.invalidateIncomingCallTimeout()
                    }
                })
            }
        }
    }
    
    /**
     Handle the answer message if the contact in the answer message is the same as in the call service and call state is ringing.
     Call will cancel if it's rejected and CallViewController will close.
     - parameter answer: VoIPCallAnswerMessage
     - parameter completion: Completion block
     */
    private func handleAnswerMessage(answer: VoIPCallAnswerMessage, completion: @escaping (() -> Void)) {
        DDLogNotice("Threema call: handle incomming answer from \(answer.contact?.identity ?? "?") with callId \(answer.callId.callId)")
        if contact != nil {
            if callInitiator == true {
                if let callId = callId, (state == .sendOffer || state == .outgoingRinging) && contact!.identity == answer.contact?.identity && callId.isSame(answer.callId) {
                    state = .receivedAnswer
                    if answer.action == VoIPCallAnswerMessage.MessageAction.reject {
                        // call is rejected
                        switch answer.rejectReason {
                        case .busy?:
                            state = .rejectedBusy
                            break
                        case .timeout?:
                            state = .rejectedTimeout
                            break
                        case .reject?:
                            state = .rejected
                            break
                        case .disabled?:
                            state = .rejectedDisabled
                            break
                        case .offHours?:
                            state = .rejectedOffHours
                            break
                        case .none:
                            state = .rejected
                        case .some(.unknown):
                            state = .rejectedUnknown
                        }
                        callKitManager?.rejectCall()
                        self.dismissCallView(rejected: true, completion: {
                            self.disconnectPeerConnection()
                            completion()
                        })
                    } else {
                        // handle answer
                        state = .receivedAnswer
                        if answer.isVideoAvailable && UserSettings.shared().enableVideoCall {
                            self.threemaVideoCallAvailable = true
                            callViewController?.enableThreemaVideoCall()
                        } else {
                            self.threemaVideoCallAvailable = false
                            callViewController?.disableThreemaVideoCall()
                        }
                        if let remoteSdp = answer.answer {
                            peerConnectionClient?.set(remoteSdp: remoteSdp, completion: { (error) in
                                if error == nil {
                                    switch self.state {
                                    case .idle, .sendOffer, .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer, .receivedAnswer:
                                        self.state = .initalizing
                                    default:
                                        break
                                    }
                                } else {
                                    // can't set remote sdp --> end call
                                    DDLogNotice("Threema call: HangupBug -> Can't set remote sdp -> hangup")
                                    let hangupMessage = VoIPCallHangupMessage(contact: self.contact!, callId: self.callId!, completion: nil)
                                    VoIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage, wait: false)
                                    self.state = .rejectedUnknown
                                    self.dismissCallView()
                                    self.disconnectPeerConnection()
                                }
                                completion()
                            })
                            
                        } else {
                            // remote sdp is empty --> end call
                            DDLogNotice("Threema call: HangupBug -> Remote sdp is empty -> hangup")
                            let hangupMessage = VoIPCallHangupMessage(contact: self.contact!, callId: self.callId!, completion: nil)
                            VoIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage, wait: false)
                            self.state = .rejectedUnknown
                            self.dismissCallView()
                            self.disconnectPeerConnection()
                            completion()
                        }
                    }
                } else {
                    if contact!.identity == answer.contact?.identity {
                        ValidationLogger.shared().logString("Threema call with \(String(describing: contact!.identity)): Can't handle answer message, because \(callStateString()) is the wrong state or answer callId \(answer.callId.callId) is different to \(callId?.callId ?? 0)")
                    } else {
                        ValidationLogger.shared().logString("Threema call with \(String(describing: contact!.identity)): Contact in manager is different to answer message \(String(describing: answer.contact?.identity))")
                    }
                    completion()
                }
            } else {
                // We are not the initiator so we can ignore this message
                ValidationLogger.shared().logString("Threema call: Not initiator, ignore this message -> answer message from contact \(String(describing: answer.contact?.identity))")
                completion()
            }
        } else {
            ValidationLogger.shared().logString("Threema call: No contact set in manager -> answer message from contact \(String(describing: answer.contact?.identity))")
            completion()
        }
    }
    
    /**
     Handle the ringing message if the contact in the answer message is the same as in the call service and call state is sendOffer.
     CallViewController will play the ringing tone
     - parameter ringing: VoIPCallRingingMessage
     - parameter completion: Completion block
     */
    private func handleRingingMessage(ringing: VoIPCallRingingMessage, completion: @escaping (() -> Void)) {
        DDLogNotice("Threema call: handle incoming ringing from \(ringing.contact.identity ?? "?") with callId \(ringing.callId.callId)")
        if contact != nil {
            if let callId = callId, contact!.identity == ringing.contact.identity && callId.isSame(ringing.callId) {
                switch state {
                case .sendOffer:
                    state = .outgoingRinging
                    break
                default:
                    ValidationLogger.shared().logString("Threema call with \(String(describing: contact!.identity)): Can't handle ringing message, because \(callStateString()) is the wrong state")
                }
            } else {
                ValidationLogger.shared().logString("Threema call with \(String(describing: contact!.identity)) (\(callId?.callId ?? 0): Contact in manager is different to ringing message \(String(describing: ringing.contact.identity)) (\(ringing.callId.callId)")
            }
        } else {
            ValidationLogger.shared().logString("Threema call: No contact set in manager -> ringing message from contact \(String(describing: ringing.contact.identity))")
        }
        completion()
    }
    
    
    /**
     Handle add or remove received remote ice candidates (IpV6 candidates will be removed)
     - parameter ice: VoIPCallIceCandidatesMessage
     - parameter completion: Completion block
     */
    private func handleIceCandidatesMessage(ice: VoIPCallIceCandidatesMessage, completion: @escaping (() -> Void)) {
        DDLogNotice("Threema call: handle incoming ice candidates from \(ice.contact?.identity ?? "?") with callId \(ice.callId.callId)")
        if contact != nil {
            if let callId = callId, contact!.identity == ice.contact?.identity && callId.isSame(ice.callId)  {
                switch state {
                case .sendOffer, .outgoingRinging, .sendAnswer, .receivedAnswer, .initalizing, .calling, .reconnecting:
                    if ice.removed == false {
                        for candidate in ice.candidates {
                            if shouldAddLocalCandidate(candidate) == true {
                                peerConnectionClient?.set(addRemoteCandidate: candidate)
                            }
                        }
                        completion()
                    } else {
                        // ICE candidate messages are currently allowed to have a "removed" flag. However, this is non-standard.
                        // When receiving an VoIP ICE Candidate (0x62) message with removed set to true, discard the message
                        completion()
                    }
                    break
                case .receivedOffer, .incomingRinging:
                    // add to local array
                    receivedIceCandidatesLockQueue.sync {
                        receivedIcecandidatesMessages.append(ice)
                        completion()
                    }
                    break
                default:
                    ValidationLogger.shared().logString("Threema call with \(String(describing: contact!.identity)): Can't handle ice candidates message, because \(callStateString()) is the wrong state")
                    completion()
                }
            } else {
                addUnknownCallIcecandidatesMessages(message: ice)
                ValidationLogger.shared().logString("Threema call with \(String(describing: contact!.identity)): Contact in manager is different to ice candidates message \(String(describing: ice.contact?.identity))")
                completion()
            }
        } else {
            addUnknownCallIcecandidatesMessages(message: ice)
            ValidationLogger.shared().logString("Threema call: No contact set in manager -> ice candidates message from contact \(String(describing: ice.contact?.identity))")
            completion()
        }
    }
    
    /**
     Handle the hangup message if the contact in the answer message is the same as in the call service and call state is receivedOffer, ringing, sendAnswer, initializing, calling or reconnecting.
     It will dismiss the CallViewController after the call was ended.
     - parameter hangup: VoIPCallHangupMessage
     - parameter completion: Completion block
     */
    private func handleHangupMessage(hangup: VoIPCallHangupMessage, completion: @escaping (() -> Void)) {
        DDLogNotice("Threema call: handle incoming hangup from \(hangup.contact.identity ?? "?") with callId \(hangup.callId.callId)")
        if contact != nil {
            if let callId = callId, contact!.identity == hangup.contact.identity && callId.isSame(hangup.callId)  {
                switch state {
                case .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer, .initalizing, .calling, .reconnecting:
                    RTCAudioSession.sharedInstance().isAudioEnabled = false
                    state = .remoteEnded
                    callKitManager?.endCall()
                    dismissCallView()
                    disconnectPeerConnection()
                    break
                default:
                    ValidationLogger.shared().logString("Threema call with \(String(describing: contact!.identity)): Can't handle hangup message, because \(callStateString()) is the wrong state")
                }
            } else {
                ValidationLogger.shared().logString("Threema call with \(String(describing: contact!.identity)) (\(callId?.callId ?? 0): Contact in manager is different to hangup message \(String(describing: hangup.contact.identity)) (\(hangup.callId.callId)")
            }
        } else {
            ValidationLogger.shared().logString("Threema call: No contact set in manager -> hangup message contact \(String(describing: hangup.contact.identity))")
        }
        completion()
    }
    
    /**
     Handle a new outgoing call if Threema calls are enabled and permission for microphone is granted.
     It will present the CallViewController.
     - parameter action: VoIPCallUserAction
     - parameter completion: Completion block
     */
    private func startCallAsInitiator(action: VoIPCallUserAction, completion: @escaping (() -> Void)) {
        if UserSettings.shared().enableThreemaCall == true && is64Bit == 1 {
            RTCAudioSession.sharedInstance().useManualAudio = true
            if state == .idle {
                AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
                    if granted == true {
                        self.callInitiator = true
                        self.contact = action.contact
                        self.createPeerConnectionForInitiator(action: action, completion: completion)
                    } else {
                        // no access to microphone, stop call
                        let alertTitle = BundleUtil.localizedString(forKey: "call_microphone_permission_title")
                        let alertMessage = BundleUtil.localizedString(forKey: "call_microphone_permission_text")
                        let alert = UIAlertController.init(title:alertTitle , message: alertMessage, preferredStyle: .alert)
                        alert.addAction(UIAlertAction.init(title: BundleUtil.localizedString(forKey: "settings"), style: .default, handler: { (action) in
                            UIApplication.shared.open(NSURL.init(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil)
                        }))
                        alert.addAction(UIAlertAction(title: BundleUtil.localizedString(forKey: "ok"), style: .default, handler: nil))
                        DispatchQueue.main.async {
                            let rootVC = UIApplication.shared.keyWindow?.rootViewController!
                            rootVC?.present(alert, animated: true, completion: nil)
                        }
                        completion()
                    }
                }
            } else {
                // do nothing because it's the wrong state
                ValidationLogger.shared().logString("Threema call with \(String(describing: contact!.identity)): Can't handle call, because \(callStateString()) is the wrong state")
                completion()
            }
        } else {
            // do nothing because Threema calls are disabled or unavailable
            completion()
        }
    }
    
    /**
     Accept a incoming call if state is ringing. Will send a answer message to initiator and update CallViewController.
     It will present the CallViewController.
     - parameter action: VoIPCallUserAction
     - parameter completion: Completion block
     */
    private func acceptIncomingCall(action: VoIPCallUserAction, completion: @escaping (() -> Void)) {
        createPeerConnectionForIncomingCall {
            RTCAudioSession.sharedInstance().useManualAudio = true
            if self.state == .incomingRinging {
                self.state = .sendAnswer
                if #available(iOS 14.0, *) {
                    self.presentCallViewController()
                }
                self.peerConnectionClient?.answer(completion: { (sdp) in
                    if self.threemaVideoCallAvailable && UserSettings.shared().enableVideoCall {
                        self.threemaVideoCallAvailable = true
                        self.callViewController?.enableThreemaVideoCall()
                    } else {
                        self.threemaVideoCallAvailable = false
                        self.callViewController?.disableThreemaVideoCall()
                    }

                    let answerMessage = VoIPCallAnswerMessage.init(action: .call, contact: action.contact, answer: sdp, rejectReason: nil, features: nil, isVideoAvailable: self.threemaVideoCallAvailable, callId: self.callId!, completion: nil)
                    VoIPCallSender.sendVoIPCall(answer: answerMessage)
                    if action.action != .acceptCallKit {
                        self.callKitManager?.callAccepted()
                    }
                    self.receivedIceCandidatesLockQueue.sync {
                        if let receivedCandidatesBeforeCall = self.receivedUnknowCallIcecandidatesMessages[action.contact.identity] {
                            for ice in receivedCandidatesBeforeCall {
                                if ice.callId.callId == self.callId?.callId {
                                    self.receivedIcecandidatesMessages.append(ice)
                                }
                            }
                            self.receivedUnknowCallIcecandidatesMessages.removeAll()
                        }
                        
                        for message in self.receivedIcecandidatesMessages {
                            if message.removed == false {
                                for candidate in message.candidates {
                                    if self.shouldAddLocalCandidate(candidate) == true {
                                        self.peerConnectionClient?.set(addRemoteCandidate: candidate)
                                    }
                                }
                            }
                        }
                        self.receivedIcecandidatesMessages.removeAll()
                    }
                    completion()
                    return
                })
            } else {
                // dismiss call view because it's the wrong state
                let identity = action.contact.identity ?? "?"
                ValidationLogger.shared().logString("Threema call with \(identity): Can't handle accept call, because \(self.callStateString()) is the wrong state")
                self.callKitManager?.answerFailed()
                self.dismissCallView()
                self.disconnectPeerConnection()
                completion()
                return
            }
        }
    }
    
    /**
     Creates the peer connection for the initiator and set the offer.
     After this, it will present the CallViewController.
     - parameter action: VoIPCallUserAction
     - parameter completion: Completion block
     */
    private func createPeerConnectionForInitiator(action: VoIPCallUserAction, completion: @escaping (() -> Void)) {
        FeatureMask.check(Int(FEATURE_MASK_VOIP_VIDEO), forContacts: [contact!]) { (unsupportedContacts) in
            self.threemaVideoCallAvailable = false
            if unsupportedContacts!.count == 0 && UserSettings.shared().enableVideoCall {
                self.threemaVideoCallAvailable = true
            }
            self.peerConnectionClient?.peerConnection.close()
            self.peerConnectionClient = nil
            let forceTurn: Bool = Int(truncating: self.contact!.verificationLevel) == kVerificationLevelUnverified || UserSettings.shared()?.alwaysRelayCalls == true
            let peerConnectionParameters = VoIPCallPeerConnectionClient.PeerConnectionParameters(isVideoCallAvailable: self.threemaVideoCallAvailable, videoCodecHwAcceleration: self.threemaVideoCallAvailable, forceTurn: forceTurn, gatherContinually: true, allowIpv6: UserSettings.shared().enableIPv6, isDataChannelAvailable: false)
            
            VoIPCallPeerConnectionClient.instantiate(contact: self.contact!, peerConnectionParameters: peerConnectionParameters) { (result) in               
                do {
                    self.peerConnectionClient = try result.get()
                } catch let error {
                    self.callCantCreateOffer(error: error)
                    return
                }
                self.peerConnectionClient?.delegate = self
                
                if UserSettings.shared()?.enableCallKit == true && Locale.current.regionCode != "CN" {
                    if self.callKitManager == nil {
                        self.callKitManager = VoIPCallKitManager.init()
                    }
                } else {
                    self.callKitManager = nil
                }
                self.peerConnectionClient?.offer(completion: { (sdp, sdpError) in
                    if let error = sdpError {
                        self.callCantCreateOffer(error: error)
                        return
                    }
                    guard let sdp = sdp  else {
                        self.callCantCreateOffer(error: nil)
                        return
                    }
                    self.callId = VoIPCallId.generate()
                    let offerMessage = VoIPCallOfferMessage.init(offer: sdp, contact: self.contact!, features: nil, isVideoAvailable: self.threemaVideoCallAvailable, callId: self.callId!, completion: nil)
                    VoIPCallSender.sendVoIPCall(offer: offerMessage)
                    self.state = .sendOffer
                    DispatchQueue.main.async {
                        self.initCallTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.kIncomingCallTimeout, repeats: false, block: { (timeout) in
                            BackgroundTaskManager.shared.newBackgroundTask(key: kAppVoIPBackgroundTask, timeout: Int(kAppPushBackgroundTaskTime)) {
                                ServerConnector.shared()?.connectWait()
                                RTCAudioSession.sharedInstance().isAudioEnabled = false
                                DDLogNotice("Threema call: HangupBug -> call ringing timeout -> hangup")
                                let hangupMessage = VoIPCallHangupMessage(contact: self.contact!, callId: self.callId!, completion: nil)
                                VoIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage, wait: false)
                                self.state = .ended
                                self.disconnectPeerConnection()
                                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
                                    self.dismissCallView(rejected: false, completion: {
                                        self.callKitManager?.endCall()
                                        self.invalidateInitCallTimeout()
                                        
                                        let rootVC = UIApplication.shared.keyWindow?.rootViewController!
                                        UIAlertTemplate.showAlert(owner: rootVC!, title: BundleUtil.localizedString(forKey: "call_voip_not_supported_title"), message: BundleUtil.localizedString(forKey: "call_contact_not_reachable"))
                                    })
                                })
                            }
                        })
                    }
                    self.alreadyAccepted = true
                    self.presentCallView(contact: self.contact!, alreadyAccepted: true, isCallInitiator: true, isThreemaVideoCallAvailable: self.threemaVideoCallAvailable, videoActive: action.action == .callWithVideo, receivingVideo: false, viewWasHidden: false)
                    self.callKitManager?.startCall(contact: self.contact!)
                    completion()
                })
            }
        }
    }
    
    /**
     Creates the peer connection for the incoming call and set the offer if contact is set in the offer.
     After this, it will present the CallViewController.
     - parameter action: VoIPCallUserAction
     - parameter completion: Completion block
     */
    private func createPeerConnectionForIncomingCall(completion: @escaping (() -> Void)) {
        peerConnectionClient?.peerConnection.close()
        peerConnectionClient = nil
        
        guard let offer = self.incomingOffer, let contact = offer.contact else {
            self.state = .idle
            completion()
            return
        }
        
        FeatureMask.check(Int(FEATURE_MASK_VOIP_VIDEO), forContacts: [contact]) { (unsupportedContacts) in
            if self.incomingOffer?.isVideoAvailable ?? false && UserSettings.shared().enableVideoCall {
                self.threemaVideoCallAvailable = true
                self.callViewController?.enableThreemaVideoCall()
            } else {
                self.threemaVideoCallAvailable = false
                self.callViewController?.disableThreemaVideoCall()
            }
            
            let forceTurn = Int(truncating: contact.verificationLevel) == kVerificationLevelUnverified || UserSettings.shared().alwaysRelayCalls
            let peerConnectionParameters = VoIPCallPeerConnectionClient.PeerConnectionParameters(isVideoCallAvailable: self.threemaVideoCallAvailable, videoCodecHwAcceleration: self.threemaVideoCallAvailable, forceTurn: forceTurn, gatherContinually: true, allowIpv6: UserSettings.shared().enableIPv6, isDataChannelAvailable: false)
            
            VoIPCallPeerConnectionClient.instantiate(contact: contact, peerConnectionParameters: peerConnectionParameters) { (result) in
                do {
                    self.peerConnectionClient = try result.get()
                } catch let error {
                    print("Can't instantiate client: \(error)")
                }
                self.peerConnectionClient?.delegate = self
                
                self.peerConnectionClient?.set(remoteSdp: offer.offer!, completion: { (error) in
                    if error == nil {
                        completion()
                    } else {
                        // reject because we can't add offer
                        print("We can't add the offer \(String(describing: error))")
                        let action = VoIPCallUserAction.init(action: .reject, contact: contact, callId: offer.callId, completion: offer.completion)
                        self.rejectCall(action: action)
                    }
                })
            }
        }
    }
    
    /**
     Removes the peer connection, reset the call state and reset all other values
     */
    private func disconnectPeerConnection() {
        // remove peerConnection
        
        func reset() {
            peerConnectionClient?.peerConnection.close()
            peerConnectionClient = nil
            contact = nil
            callId = nil
            threemaVideoCallAvailable = false
            alreadyAccepted = false
            callInitiator = false
            audioMuted = false
            speakerActive = false
            videoActive = false
            isReceivingVideo = false
            state = .idle
            incomingOffer = nil
            localRenderer = nil
            remoteRenderer = nil
            audioPlayer?.pause()
            
            do {
                RTCAudioSession.sharedInstance().lockForConfiguration()
                try RTCAudioSession.sharedInstance().setActive(false)
                RTCAudioSession.sharedInstance().unlockForConfiguration()
            } catch {
                DDLogError("Could not set shared session to not active. Error: \(error)")
            }
            
            DispatchQueue.main.async {
                VoIPHelper.shared()?.isCallActiveInBackground = false
                VoIPHelper.shared()?.contactName = nil
                NotificationCenter.default.post(name: NSNotification.Name(kNotificationCallInBackgroundTimeChanged), object: nil)
            }
        }
        
        if peerConnectionClient != nil {
            peerConnectionClient!.stopVideoCall()
            peerConnectionClient?.logDebugEndStats {
                reset()
            }
        } else {
            reset()
        }
    }
    
    /**
     Present the CallViewController in the main thread.
     - parameter contact: Contact of the call
     - parameter alreadyAccepted: Set to true if the call was alreay accepted
     - parameter isCallInitiator: If user is the call initiator
     */
    private func presentCallView(contact: Contact, alreadyAccepted: Bool, isCallInitiator: Bool, isThreemaVideoCallAvailable: Bool, videoActive: Bool, receivingVideo: Bool, viewWasHidden: Bool, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            var viewWasHidden = viewWasHidden
            if self.callViewController == nil {
                let callStoryboard = UIStoryboard.init(name: "CallStoryboard", bundle: nil)
                let callVC = callStoryboard.instantiateInitialViewController() as! CallViewController
                self.callViewController = callVC
                viewWasHidden = false
            }
            let rootVC = UIApplication.shared.keyWindow?.rootViewController
            var presentingVC = (rootVC?.presentedViewController ?? rootVC)
            if let navController = presentingVC as? UINavigationController {
                presentingVC = navController.viewControllers.last
            }
            if !(presentingVC?.isKind(of: CallViewController.self))! {
                if let presentedVC = presentingVC?.presentedViewController {
                    if presentedVC.isKind(of: CallViewController.self) {
                        return
                    }
                }
                if UIApplication.shared.applicationState == .active
                    && !self.callViewController!.isBeingPresented
                    && !self.isModal {
                    self.callViewController!.viewWasHidden = viewWasHidden
                    self.callViewController!.voIPCallStatusChanged(state: self.state, oldState: self.state)
                    self.callViewController!.contact = contact
                    self.callViewController!.alreadyAccepted = alreadyAccepted
                    self.callViewController!.isCallInitiator = isCallInitiator
                    self.callViewController!.threemaVideoCallAvailable = isThreemaVideoCallAvailable
                    self.callViewController!.isLocalVideoActive = videoActive
                    self.callViewController!.isReceivingRemoteVideo = receivingVideo
                    if UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT") {
                        self.callViewController!.isTesting = true
                    }
                    self.callViewController!.modalPresentationStyle = .overFullScreen
                    presentingVC?.present(self.callViewController!, animated: false, completion: {
                        if completion != nil {
                            completion!()
                        }
                    })
                }
            }
        }
    }
    
    /**
     Dismiss the CallViewController in the main thread.
     */
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
                    Timer.scheduledTimer(withTimeInterval: 4, repeats: false, block: { (timer) in
                        callVC.dismiss(animated: true, completion: {
                            switch self.state {
                            case .sendOffer, .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer, .receivedAnswer, .initalizing, .calling, .reconnecting: break
                            case .idle, .ended, .remoteEnded, .rejected, .rejectedBusy, .rejectedTimeout, .rejectedDisabled, .rejectedOffHours, .rejectedUnknown, .microphoneDisabled:
                                self.callViewController = nil
                            }
                            if AppDelegate.shared()?.isAppLocked == true {
                                AppDelegate .shared()?.presentPasscodeView()
                            }
                            completion?()
                        })
                    })
                } else {
                    callVC.dismiss(animated: true, completion: {
                        switch self.state {
                        case .sendOffer, .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer, .receivedAnswer, .initalizing, .calling, .reconnecting: break
                        case .idle, .ended, .remoteEnded, .rejected, .rejectedBusy, .rejectedTimeout, .rejectedDisabled, .rejectedOffHours, .rejectedUnknown, .microphoneDisabled:
                            self.callViewController = nil
                        }
                        if AppDelegate.shared()?.isAppLocked == true {
                            AppDelegate .shared()?.presentPasscodeView()
                        }
                        completion?()
                    })
                }
            }
        }
    }
    
    /**
     Reject the call with the reason given in the action.
     Will end call and dismiss the CallViewController.
     - parameter action: VoIPCallUserAction with the given reject reason
     - parameter closeCallView: Default is true. If set false, it will not disconnect the peer connection and will not close the call view
     */
    private func rejectCall(action: VoIPCallUserAction, closeCallView: Bool? = true) {
        var reason: VoIPCallAnswerMessage.MessageRejectReason = .reject
        
        switch action.action {
        case .rejectDisabled:
            reason = .disabled
            if action.contact == contact {
                state = .rejectedDisabled
            }
            break
        case .rejectTimeout:
            reason = .timeout
            if action.contact == contact {
                state = .rejectedTimeout
            }
            break
        case .rejectBusy:
            reason = .busy
            if action.contact == contact {
                state = .rejectedBusy
            }
            break
        case .rejectOffHours:
            reason = .offHours
            if action.contact == contact {
                state = .rejectedOffHours
            }
            break
        case .rejectUnknown:
            reason = .unknown
            if action.contact == contact {
                state = .rejectedUnknown
            }
            break
        default:
            if action.contact == contact {
                state = .rejected
            }
            break
        }
        
        let answer = VoIPCallAnswerMessage.init(action: .reject, contact: action.contact, answer: nil, rejectReason: reason, features: nil, isVideoAvailable: UserSettings.shared().enableVideoCall, callId: action.callId!, completion: nil)
        VoIPCallSender.sendVoIPCall(answer: answer)
        if contact == action.contact {
            callKitManager?.rejectCall()
            if closeCallView == true {
                // remove peerConnection
                self.dismissCallView()
                self.disconnectPeerConnection()
            }
        } else {
            addRejectedMessageToConversation(contact: action.contact, reason: kSystemMessageCallMissed)
        }
    }
        
    /**
     It will check the current call state and play the correct tone if it's needed
     */
    private func handleTones(state: VoIPCallService.CallState, oldState: VoIPCallService.CallState) {
        switch state {
        case .outgoingRinging, .incomingRinging:
            if callInitiator == true {
                let soundFilePath = BundleUtil.path(forResource: "ringing-tone-ch-fade", ofType: "mp3")
                let soundUrl = URL.init(fileURLWithPath: soundFilePath!)
                setupAudioSession()
                playSound(soundUrl: soundUrl, loops: -1)
            } else {
                if UserSettings.shared().enableCallKit == false {
                    var voIPSound = UserSettings.shared().voIPSound
                    if voIPSound == "default" {
                        voIPSound = "threema_best"
                    }
                    let soundFilePath = BundleUtil.path(forResource: voIPSound, ofType: "caf")
                    let soundUrl = URL.init(fileURLWithPath: soundFilePath!)
                    
                    setupAudioSession(true)
                    playSound(soundUrl: soundUrl, loops: -1)
                } else {
                    audioPlayer?.stop()
                }
            }
            break
        case .rejected, .rejectedBusy, .rejectedTimeout, .rejectedOffHours, .rejectedUnknown, .rejectedDisabled:
            if PendingMessagesManager.canMasterDndSendPush() == false || self.isCallInitiator() == false  {
                // do not play sound if dnd mode is active and user is not the call initiator
                audioPlayer?.stop()
            }
            else {
                let soundFilePath = BundleUtil.path(forResource: "busy-4x", ofType: "mp3")
                let soundUrl = URL.init(fileURLWithPath: soundFilePath!)
                setupAudioSession()
                playSound(soundUrl: soundUrl, loops: 0)
            }
            break
        case .ended, .remoteEnded:
            if oldState != .incomingRinging {
                let soundFilePath = BundleUtil.path(forResource: "threema_hangup", ofType: "mp3")
                let soundUrl = URL.init(fileURLWithPath: soundFilePath!)
                setupAudioSession()
                playSound(soundUrl: soundUrl, loops: 0)
            } else {
                audioPlayer?.stop()
            }
            break
        case .calling:
            if oldState != .reconnecting {
                let soundFilePath = BundleUtil.path(forResource: "threema_pickup", ofType: "mp3")
                let soundUrl = URL.init(fileURLWithPath: soundFilePath!)
                setupAudioSession()
                playSound(soundUrl: soundUrl, loops: 0)
            } else {
                audioPlayer?.stop()
            }
            break
        case .reconnecting:
            let soundFilePath = BundleUtil.path(forResource: "threema_problem", ofType: "mp3")
            let soundUrl = URL.init(fileURLWithPath: soundFilePath!)
            setupAudioSession()
            playSound(soundUrl: soundUrl, loops: -1)
            break
        case .idle:
            break
        case .sendOffer, .receivedOffer, .sendAnswer, .receivedAnswer, .initalizing:
            // do nothing
            break
        case .microphoneDisabled:
            // do nothing
            break
        }
    }
    
    private func setupAudioSession(_ soloAmbient: Bool = false) {
        let audioSession = AVAudioSession.sharedInstance()
        if soloAmbient == true {
            do {
                try audioSession.setCategory(.soloAmbient, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
                try audioSession.overrideOutputAudioPort(speakerActive ? .speaker : .none)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch let error {
                print(error.localizedDescription)
            }
        } else {
            do {
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP])
                try audioSession.overrideOutputAudioPort(speakerActive ? .speaker : .none)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
    
    /**
     It will play the given sound
     - parameter soundUrl: URL of the sound file
     - parameter loop: -1 for endless
     - parameter playOnSpeaker: True or false if should play the tone over the speaker
     */
    private func playSound(soundUrl: URL, loops: Int) {
        audioPlayer?.stop()
        do {
            let player = try AVAudioPlayer(contentsOf: soundUrl, fileTypeHint: AVFileType.mp3.rawValue)
            player.numberOfLoops = loops
            audioPlayer = player
            player.play()
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    /**
     Invalidate the timers per call state
     - parameter state: new set state of the call state
     */
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
        case .initalizing:
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
    
    /**
     Invalidate the incoming call timer
     */
    private func invalidateIncomingCallTimeout() {
        incomingCallTimeoutTimer?.invalidate()
        incomingCallTimeoutTimer = nil
    }
    
    /**
     Invalidate the init call timer
    */
    private func invalidateInitCallTimeout() {
        initCallTimeoutTimer?.invalidate()
        initCallTimeoutTimer = nil
    }
    
    /**
     Invalidate the call duration timer and set the callDurationTime to 0
     */
    private func invalidateCallDuration() {
        callDurationTimer?.invalidate()
        callDurationTimer = nil
        callDurationTime = 0
    }
    
    /**
     Invalidate the call duration timer and set the callDurationTime to 0
     */
    private func invalidateCallFailedTimer() {
        callFailedTimer?.invalidate()
        callFailedTimer = nil
    }
    
    /**
     Add icecandidate to local array if it's in the correct state. Start a timer to send candidates as packets all 0.05 seconds
     - parameter candidate: RTCIceCandidate
     */
    private func handleLocalIceCandidates(_ candidates: [RTCIceCandidate]) {
        func addCandidateToLocalArray(_ addedCadidates: [RTCIceCandidate]) {
            iceCandidatesLockQueue.sync {
                for (_, candidate) in addedCadidates.enumerated() {
                    if shouldAddLocalCandidate(candidate) == true {
                        localAddedIceCandidates.append(candidate)
                    }
                }
            }
        }
        
        switch state {
        case .sendOffer, .outgoingRinging, .receivedAnswer, .initalizing, .calling, .reconnecting:
            addCandidateToLocalArray(candidates)
            let seperatedCandidates = self.localAddedIceCandidates.take(localAddedIceCandidates.count)
            if (seperatedCandidates.count > 0) {
                let message = VoIPCallIceCandidatesMessage.init(removed: false, candidates: seperatedCandidates, contact: self.contact, callId: self.callId!, completion: nil)
                VoIPCallSender.sendVoIPCall(iceCandidates: message)
            }
            self.localAddedIceCandidates.removeAll()
            break
        case .idle, .receivedOffer, .incomingRinging, .sendAnswer:
            addCandidateToLocalArray(candidates)
            break
        case .ended, .remoteEnded, .rejected, .rejectedBusy, .rejectedTimeout, .rejectedOffHours, .rejectedUnknown, .rejectedDisabled, .microphoneDisabled:
            // do nothing
            
            break
        }
    }
    
    /**
     Check if should add a ice candidate
     - parameter candidate: RTCIceCandidate
     - Returns: true or false
     */
    private func shouldAddLocalCandidate(_ candidate: RTCIceCandidate) -> Bool {
        let parts = candidate.sdp.components(separatedBy: CharacterSet.init(charactersIn: " "))
        
        // Invalid candidate but who knows what they're doing, so we'll just eat it...
        if parts.count < 8 {
            return true
        }
        
        // Discard loopback
        let ip = parts[4]
        if ip == "172.0.0.1" || ip == "::1" {
            debugPrint("Call: Discarding loopback candidate: \(candidate.sdp)")
            return false
        }
        
        // Discard IPv6 if disabled
        if UserSettings.shared()?.enableIPv6 == false && ip.contains(":") {
            debugPrint("Call: Discarding local IPv6 candidate: \(candidate.sdp)")
            return false
        }
        
        // Always add if not relay
        let type = parts[7]
        if type != "relay" || parts.count < 10 {
            return true
        }
        
        // Always add if related address is any
        let relatedAddress = parts[9]
        if relatedAddress == "0.0.0.0" {
            return true
        }
        
        // Discard relay candidates with the same related address
        // Important: This only works as long as we don't do ICE restarts and don't add further relay transport types!
        if localRelatedAddresses.contains(relatedAddress) {
            debugPrint("Call: Discarding local relay candidate (duplicate related address: \(relatedAddress)): \(candidate.sdp)")
            return false
        } else {
            localRelatedAddresses.insert(relatedAddress)
        }
        
        // Add it!
        return true
    }
    
    /**
     Check if an IP address is IPv6
     - parameter ipToValidate: String of the ip
     - Returns: true or false
     */
    private func isIPv6Address(_ ipToValidate: String) -> Bool {
        var sin6 = sockaddr_in6()
        if ipToValidate.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
            return true
        }
        
        return false
    }
    
    /**
     Handle notification if needed
     */
    private func handleLocalNotification() {
        func addIncomCall() {
            if self.callKitManager == nil {
                // callkit is disabled --> show local notification
                DispatchQueue.main.async {
                    if UIApplication.shared.applicationState != .active {
                        let notification = UNMutableNotificationContent.init()
                        notification.categoryIdentifier = "INCOMCALL"
                        
                        if let pushSetting = PushSetting.find(forIdentity: self.contact!.identity) {
                            if pushSetting.canSendPush() && pushSetting.silent == false {
                                var soundName = "threema_best.caf"
                                if UserSettings.shared().voIPSound != "default" {
                                    soundName = "\(UserSettings.shared().voIPSound!).caf"
                                }
                                notification.sound = UNNotificationSound.init(named: UNNotificationSoundName.init(soundName))
                            }
                        } else {
                            var soundName = "threema_best.caf"
                            if UserSettings.shared().voIPSound != "default" {
                                soundName = "\(UserSettings.shared().voIPSound!).caf"
                            }
                            notification.sound = UNNotificationSound.init(named: UNNotificationSoundName.init(soundName))
                        }

                        notification.userInfo = ["threema": ["cmd": "newcall", "from": self.contact!.displayName ?? "Unknown", "callId": self.callId?.callId ?? 0]]
                        if !UserSettings.shared().pushShowNickname {
                            notification.title = self.contact!.displayName
                        } else {
                            if self.contact!.publicNickname != nil && self.contact!.publicNickname.count > 0 {
                                notification.title = self.contact!.publicNickname
                            } else {
                                notification.title = self.contact!.identity
                            }
                        }
                        notification.body = BundleUtil.localizedString(forKey: "call_incoming_ended")
                        
                        notification.threadIdentifier = "INCOMCALL-\(self.contact?.identity ?? "")"
                        
                        let notificationRequest = UNNotificationRequest.init(identifier: self.contact!.identity, content: notification, trigger: nil)
                        UNUserNotificationCenter.current().add(notificationRequest, withCompletionHandler: { (error) in
                        })
                    }
                }
            }
        }
        
        func removeIncomCall() {
            if self.callKitManager == nil {
                // callkit is disabled --> delete local notification
                if let identity = self.contact?.identity {
                    DispatchQueue.main.async {
                        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identity])
                    }
                }
            }
        }
        
        func addMissedCall() {
            if let contact = self.contact {
                DispatchQueue.main.async {
                    if AppDelegate.shared().isAppInBackground() == true {
                        if self.isCallInitiator() == false && self.callDurationTime == 0 {
                            var canSendPush = true
                            var foundPushSetting: PushSetting?
                            if let pushSetting = PushSetting.find(forIdentity: contact.identity) {
                                foundPushSetting = pushSetting
                                canSendPush = pushSetting.canSendPush()
                            }
                            if canSendPush == true {
                                // callkit is disabled --> show missed notification
                                
                                let notification = UNMutableNotificationContent.init()
                                notification.categoryIdentifier = "CALL"
                                
                                if UserSettings.shared().pushSound != "none" {
                                    if foundPushSetting != nil {
                                        if foundPushSetting?.silent == false {
                                            notification.sound = UNNotificationSound.init(named: UNNotificationSoundName(rawValue: UserSettings.shared().pushSound! + ".caf"))
                                        }
                                    } else {
                                        notification.sound = UNNotificationSound.init(named: UNNotificationSoundName(rawValue: UserSettings.shared().pushSound! + ".caf"))
                                    }
                                }
                                
                                notification.userInfo = ["threema": ["cmd": "missedcall", "from": contact.displayName]]
                                if !UserSettings.shared().pushShowNickname {
                                    notification.title = contact.displayName
                                } else {
                                    if contact.publicNickname != nil && contact.publicNickname.count > 0 {
                                        notification.title = contact.publicNickname
                                    } else {
                                        notification.title = contact.identity
                                    }
                                }
                                notification.body = BundleUtil.localizedString(forKey: "call_missed")
                                
                                // Group notification together with others from the same contact
                                notification.threadIdentifier = "SINGLE-\(self.contact?.identity ?? "")"
                                
                                let notificationRequest = UNNotificationRequest.init(identifier: contact.identity, content: notification, trigger: nil)
                                UNUserNotificationCenter.current().add(notificationRequest, withCompletionHandler: { (error) in
                                })
                            }
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
            addIncomCall()
            break
        case .sendAnswer:
            removeIncomCall()
            break
        case .receivedAnswer:
            break
        case .initalizing:
            removeIncomCall()
            break
        case .calling:
            break
        case .reconnecting:
            break
        case .ended:
            removeIncomCall()
            break
        case .remoteEnded:
            removeIncomCall()
            addMissedCall()
            break
        case .rejected, .rejectedOffHours, .rejectedUnknown, .rejectedDisabled:
            removeIncomCall()
            break
        case .rejectedBusy, .rejectedTimeout:
            removeIncomCall()
            addMissedCall()
            break
        case .microphoneDisabled:
            removeIncomCall()
            break
        }
    }
    
    /**
     Add call message to conversation
     */
    private func addCallMessageToConversation(oldCallState: CallState) {
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
        case .initalizing:
            break
        case .calling:
            break
        case .reconnecting:
            break
        case .ended, .remoteEnded:
            // add call message
            if (UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT")) {
                return
            }
            
            // if remoteEnded is incoming at the same time like user tap on end call button
            if oldCallState == .ended || oldCallState == .remoteEnded {
                return
            }
            
            let entityManager = EntityManager()
            let conversation = entityManager.conversation(for: contact!, createIfNotExisting: true)
            entityManager.performSyncBlockAndSafe({
                let systemMessage = entityManager.entityCreator.systemMessage(for: conversation)
                systemMessage?.type = NSNumber(value: kSystemMessageCallEnded)
                
                var callInfo = ["DateString": DateFormatter.shortStyleTimeNoDate(Date()), "CallInitiator": NSNumber(booleanLiteral: self.isCallInitiator())] as [String : Any]
                if self.callDurationTime > 0 {
                    callInfo["CallTime"] = DateFormatter.timeFormatted(self.callDurationTime)
                }
                do {
                    let callInfoData = try JSONSerialization.data(withJSONObject: callInfo, options: .prettyPrinted)
                    systemMessage?.arg = callInfoData
                    systemMessage?.isOwn = NSNumber(booleanLiteral: self.isCallInitiator())
                    systemMessage?.conversation = conversation
                    conversation?.lastMessage = systemMessage
                    if self.state == .remoteEnded  && self.callDurationTime == 0 {
                        conversation?.unreadMessageCount = NSNumber(integerLiteral: (conversation?.unreadMessageCount.intValue)!+1)
                    }
                }
                catch let error {
                    print(error)
                }
            })
            if state == .remoteEnded  && self.callDurationTime == 0 {
                DispatchQueue.main.async {
                    NotificationManager.sharedInstance()?.updateUnreadMessagesCount(false)
                }
            }
            break
        case .rejected:
            // add call message
            if contact != nil {
                addRejectedMessageToConversation(contact: contact!, reason: kSystemMessageCallRejected)
            }
            break
        case .rejectedTimeout:
            // add call message
            let reason = self.isCallInitiator() ? kSystemMessageCallRejectedTimeout : kSystemMessageCallMissed
            if contact != nil {
                addRejectedMessageToConversation(contact: contact!, reason: reason)
            }
            break
        case .rejectedBusy:
            // add call message
            let reason = self.isCallInitiator() ? kSystemMessageCallRejectedBusy : kSystemMessageCallMissed
            if contact != nil {
                addRejectedMessageToConversation(contact: contact!, reason: reason)
            }
            break
        case .rejectedOffHours:
            // add call message
            let reason = self.isCallInitiator() ? kSystemMessageCallRejectedOffHours : kSystemMessageCallMissed
            if contact != nil {
                addRejectedMessageToConversation(contact: contact!, reason: reason)
            }
            break
        case .rejectedUnknown:
            // add call message
            let reason = self.isCallInitiator() ? kSystemMessageCallRejectedUnknown : kSystemMessageCallMissed
            if contact != nil {
                addRejectedMessageToConversation(contact: contact!, reason: reason)
            }
            break
        case .rejectedDisabled:
            // add call message
            if callInitiator == true {
                if contact != nil {
                    addRejectedMessageToConversation(contact: contact!, reason: kSystemMessageCallRejectedDisabled)
                }
            }
            break
        case .microphoneDisabled:
            break
        }
    }
    
    private func addRejectedMessageToConversation(contact: Contact, reason: Int) {
        let entityManager = EntityManager()
        let conversation = entityManager.conversation(for: contact, createIfNotExisting: true)
        entityManager.performSyncBlockAndSafe({
            let systemMessage = entityManager.entityCreator.systemMessage(for: conversation)
            systemMessage?.type = NSNumber(value: reason)
            let callInfo = ["DateString": DateFormatter.shortStyleTimeNoDate(Date()), "CallInitiator": NSNumber(booleanLiteral: self.isCallInitiator())] as [String : Any]
            do {
                let callInfoData = try JSONSerialization.data(withJSONObject: callInfo, options: .prettyPrinted)
                systemMessage?.arg = callInfoData
                systemMessage?.isOwn = NSNumber(booleanLiteral: self.isCallInitiator())
                systemMessage?.conversation = conversation
                conversation?.lastMessage = systemMessage
                if reason == kSystemMessageCallMissed || reason == kSystemMessageCallRejectedBusy || reason == kSystemMessageCallRejectedTimeout || reason == kSystemMessageCallRejectedDisabled {
                    conversation?.unreadMessageCount = NSNumber(integerLiteral: (conversation?.unreadMessageCount.intValue)!+1)
                } else {
                    systemMessage?.read = true
                    systemMessage?.readDate = Date()
                }
            }
            catch let error {
                print(error)
            }
        })
        if reason == kSystemMessageCallMissed || reason == kSystemMessageCallRejectedBusy || reason == kSystemMessageCallRejectedTimeout || reason == kSystemMessageCallRejectedDisabled {
            DispatchQueue.main.async {
                NotificationManager.sharedInstance()?.updateUnreadMessagesCount(false)
            }
        }
    }
    
    private func addUnknownCallIcecandidatesMessages(message: VoIPCallIceCandidatesMessage) {
        receivedIceCandidatesLockQueue.sync {
            guard let contact = message.contact else {
                return
            }
            if var contactCandidates = receivedUnknowCallIcecandidatesMessages[contact.identity] {
                contactCandidates.append(message)
            } else {
                receivedUnknowCallIcecandidatesMessages[contact.identity] = [message]
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
        DDLogNotice("Threema call: peerconnection new state failed -> close connection")
        var message = BundleUtil.localizedString(forKey: "call_status_failed_connected_message")
        if !self.iceWasConnected {
            // show error as notification
            if self.contact != nil {
                let hangupMessage = VoIPCallHangupMessage(contact: self.contact!, callId: self.callId!, completion: nil)
                VoIPCallSender.sendVoIPCallHangup(hangupMessage: hangupMessage, wait: false)
            }
            message = BundleUtil.localizedString(forKey: "call_status_failed_initializing_message")
        }
        NotificationBannerHelper.newErrorToast(title: BundleUtil.localizedString(forKey: "call_status_failed_title"), body: message!)
        invalidateCallFailedTimer()
        handleTones(state: .ended, oldState: .reconnecting)
        callKitManager?.endCall()
        dismissCallView()
        disconnectPeerConnection()
    }

    private func callCantCreateOffer(error: Error?) {
        DDLogNotice("Threema call: Can't create offer -> \(error?.localizedDescription ?? "error is missing")")
        let message = BundleUtil.localizedString(forKey: "call_status_failed_sdp_patch_message")
        NotificationBannerHelper.newErrorToast(title: BundleUtil.localizedString(forKey: "call_status_failed_title"), body: message!)
        invalidateCallFailedTimer()
        handleTones(state: .ended, oldState: .reconnecting)
        callKitManager?.endCall()
        dismissCallView()
        disconnectPeerConnection()
    }
}

extension VoIPCallService: VoIPCallPeerConnectionClientDelegate {
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, removedCandidates: [RTCIceCandidate]) {
        // ICE candidate messages are currently allowed to have a "removed" flag. However, this is non-standard.
        // Ignore generated ICE candidates with removed set to true coming from libwebrtc
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, addedCandidate: RTCIceCandidate) {
        if contact != nil {
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
            try audioSession.setCategory(.playAndRecord, mode: speakerActive ? .videoChat : .voiceChat, options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.overrideOutputAudioPort(speakerActive ? .speaker : .none)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, receivingVideo: Bool) {
        if self.isReceivingVideo != receivingVideo {
            self.isReceivingVideo = receivingVideo
        }
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, didChangeConnectionState state: RTCIceConnectionState) {
        DDLogNotice("Threema call: peerConnectionClient state changed: new state \(state.rawValue))")
        
        switch state {
        case .new:
            break
        case .checking:
            self.state = .initalizing
        case .connected:
            invalidateCallFailedTimer()
            iceWasConnected = true
            if self.state != .reconnecting {
                self.state = .calling
                ValidationLogger.shared().logString("Threema call status is calling: \(self.callStateString())")
                DispatchQueue.main.async {
                    self.callDurationTime = 0
                    self.callDurationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { (timer) in
                        self.callDurationTime = self.callDurationTime + 1
                        if self.state == .calling {
                            self.callViewController?.voIPCallDurationChanged(self.callDurationTime)
                        } else {
                            self.callViewController?.voIPCallStatusChanged(state: self.state, oldState: self.state)
                            ValidationLogger.shared().logString("Threema call status is connected, but shows something different: \(self.callStateString())")
                        }
                        if VoIPHelper.shared()?.isCallActiveInBackground == true {
                            NotificationCenter.default.post(name: NSNotification.Name(kNotificationCallInBackgroundTimeChanged), object: self.callDurationTime)
                        }
                    })
                }
                self.callViewController?.startDebugMode(connection: client.peerConnection)
                callKitManager?.callConnected()
            } else {
                ValidationLogger.shared().logString("Threema call status is reconnecting: \(self.callStateString())")
                self.state = .calling
                ValidationLogger.shared().logString("Threema call status is calling: \(self.callStateString())")
            }
            self.activateRTCAudio()
        case .completed:
            break
        case .failed:
            if self.state == .reconnecting {
                callFailed()
            } else {
                if self.iceWasConnected {
                    self.state = .reconnecting
                    DDLogNotice("Threema call: peerconnection failed, set state to reconnecting -> start callFailedTimer")
                } else {
                    self.state = .initalizing
                    DDLogNotice("Threema call: peerconnection failed, set state to initalizing -> start callFailedTimer")
                }
                // start timer and wait if state change back to connected
                DispatchQueue.main.async {
                    self.invalidateCallFailedTimer()
                    self.callFailedTimer = Timer.scheduledTimer(withTimeInterval: self.kCallFailedTimeout, repeats: false, block: { (timeout) in
                        self.callFailed()
                    })
                }
            }
        case .disconnected:
            if self.state == .calling || self.state == .initalizing {
                self.state = .reconnecting
            }
        case .closed:
            break
        case .count:
            break
        @unknown default:
            break
        }
    }
    
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, didReceiveData: Data) {
        let threemaVideoCallSignalingMessage = CallsignalingProtocol.decodeThreemaVideoCallSignalingMessage(didReceiveData)
        
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
                default: break
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
