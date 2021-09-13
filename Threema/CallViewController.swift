//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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
import WebRTC
import ThreemaFramework
import CocoaLumberjackSwift

class CallViewController: UIViewController {
    @IBOutlet private weak var backgroundImage: UIImageView!
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var contactLabel: UILabel!
    @IBOutlet private weak var verificationLevel: UIImageView!
    @IBOutlet private weak var debugLabel: UILabel!
    
    @IBOutlet private weak var acceptButton: UIButton!
    @IBOutlet private weak var rejectButton: UIButton!
    
    @IBOutlet private weak var hideButton: UIButton!
    @IBOutlet private weak var cellularWarningButton: UIButton!
    @IBOutlet private weak var timerLabel: UILabel!
    
    @IBOutlet private weak var localVideoView: UIView!
    @IBOutlet private weak var remoteVideoView: UIView!
    
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var speakerButton: UIButton!
    @IBOutlet weak var endButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var cameraSwitchButton: UIButton!
        
    @IBOutlet weak var callInfoStackView: UIStackView!
    @IBOutlet weak var callInfoStackViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var phoneButtonsStackView: UIStackView!
    @IBOutlet weak var phoneButtonsStackViewBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var localVideoViewConstraintHeight: NSLayoutConstraint!
    @IBOutlet weak var localVideoViewConstraintWidth: NSLayoutConstraint!
    
    @IBOutlet weak var localVideoViewConstraintLeft: NSLayoutConstraint!
    @IBOutlet weak var localVideoViewConstraintRight: NSLayoutConstraint!
    @IBOutlet weak var localVideoViewConstraintBottom: NSLayoutConstraint!
    @IBOutlet weak var localVideoViewConstraintBottomNavigation: NSLayoutConstraint!
    @IBOutlet weak var localVideoViewConstraintTop: NSLayoutConstraint!
    @IBOutlet weak var localVideoViewConstraintTopNavigation: NSLayoutConstraint!
    @IBOutlet weak var localVideoViewConstraintTopNavigationLabel: NSLayoutConstraint!
        
    @IBOutlet weak var phoneButtonsGradientView: UIView!
    @IBOutlet weak var callInfoGradientView: UIView!

    var contact: Contact?
    var alreadyAccepted: Bool = false
    var isCallInitiator: Bool = false
    var isTesting: Bool = false
    var viewWasHidden: Bool = false
    var threemaVideoCallAvailable: Bool = false
    var isLocalVideoActive: Bool = false
    var isReceivingRemoteVideo: Bool = false  {
        didSet {
            if self.isReceivingRemoteVideo {
                self.startRemoteVideo()
                DispatchQueue.main.async {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                }
            } else {
                self.endRemoteVideo()
            }
        }
    }
    var isRemoteVideoPortrait: Bool = false
    var shouldShowCellularCallWarning: Bool = false  {
        didSet {
            DispatchQueue.main.async {
                if let warningButton = self.cellularWarningButton, warningButton.isHidden == self.shouldShowCellularCallWarning {
                    warningButton.isHidden = !self.shouldShowCellularCallWarning
                    if self.shouldShowCellularCallWarning {
                        self.playCellularCallWarningSound()
                    }
                }
            }
        }
    }
    
    private var statsTimer: Timer?
    
    private var useBackCamera: Bool = false

    private var myVolumeView: UIView?
    
    private var initiatorVideoCallShowcase: MaterialShowcase?
    private var remoteVideoActivatedShowcase: MaterialShowcase?
    private var speakerShowcase: MaterialShowcase?
    private var cameraDisabledShowcase: MaterialShowcase?
    
    private var didRotateDevice: Bool = false
    
    private var audioPlayer: AVAudioPlayer?
    
    private var audioRouteChangeObserver: NSObjectProtocol?
        
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
        
    deinit {
        if let observer = audioRouteChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        modalPresentationCapturesStatusBarAppearance = true
        
        cellularWarningButton.isHidden = true
        
        audioRouteChangeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] n in
            guard let self = self else { return }
            let currentRoute = AVAudioSession.sharedInstance().currentRoute
            
            for output in currentRoute.outputs {
                if self.isBeingDismissed {
                    UIDevice.current.isProximityMonitoringEnabled = false
                } else {
                    if output.portType == AVAudioSession.Port.builtInReceiver {
                        if UserSettings.shared()?.disableProximityMonitoring == false && !UIDevice.current.isProximityMonitoringEnabled && VoIPCallStateManager.shared.currentCallState() != .idle {
                            UIDevice.current.isProximityMonitoringEnabled = true
                        }
                    } else {
                        if UIDevice.current.isProximityMonitoringEnabled {
                            UIDevice.current.isProximityMonitoringEnabled = false
                        }
                    }
                }
                
                if output.portType == AVAudioSession.Port.builtInSpeaker {
                    self.speakerButton.setImage(UIImage.init(named: "SpeakerActive"), for: .normal)
                    self.speakerButton.setImage(UIImage.init(named: "SpeakerActive"), for: .highlighted)
                    self.speakerButton.setImage(UIImage.init(named: "SpeakerActive"), for: .selected)
                    self.speakerButton.tag = 1
                }
                else if output.portType == AVAudioSession.Port.headphones {
                    self.speakerButton.setImage(UIImage.init(named: "HeadphoneActive"), for: .normal)
                    self.speakerButton.setImage(UIImage.init(named: "HeadphoneActive"), for: .highlighted)
                    self.speakerButton.setImage(UIImage.init(named: "HeadphoneActive"), for: .selected)
                    self.speakerButton.tag = 2
                }
                else if output.portType == AVAudioSession.Port.bluetoothA2DP || output.portType == AVAudioSession.Port.bluetoothHFP || output.portType == AVAudioSession.Port.bluetoothLE {
                    self.speakerButton.setImage(UIImage.init(named: "BluetoothActive"), for: .normal)
                    self.speakerButton.setImage(UIImage.init(named: "BluetoothActive"), for: .highlighted)
                    self.speakerButton.setImage(UIImage.init(named: "BluetoothActive"), for: .selected)
                    self.speakerButton.tag = 3
                }
                else {
                    self.speakerButton.setImage(UIImage.init(named: "SpeakerInactive"), for: .normal)
                    self.speakerButton.setImage(UIImage.init(named: "SpeakerInactive"), for: .highlighted)
                    self.speakerButton.setImage(UIImage.init(named: "SpeakerInactive"), for: .selected)
                    self.speakerButton.tag = 0
                }
                self.updateAccessibilityLabels()
                
                guard let info = n.userInfo,
                      let value = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: value) else { return }
                
                switch reason {
                case .newDeviceAvailable, .oldDeviceUnavailable:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                        self.checkAndHandleAvailableBluetoothDevices()
                    })
                    break
                default: break
                }
            }
        }
        
        let longPressRecognizer = UILongPressGestureRecognizer.init(target: self, action: #selector(handleLongPress))
        hideButton.addGestureRecognizer(longPressRecognizer)
        
        let panGR = UIPanGestureRecognizer(target: self, action: #selector(didPan(gesture:)))
        localVideoView.addGestureRecognizer(panGR)
        
        let showHideNavigation = UITapGestureRecognizer(target: self, action: #selector(showHideNavigation(gesture:)))
        remoteVideoView.addGestureRecognizer(showHideNavigation)
        
        let switchVideoViews = UITapGestureRecognizer(target: self, action: #selector(switchVideoViews(gesture:)))
        localVideoView.addGestureRecognizer(switchVideoViews)
                
        updateConstraintsAfterRotation(size: CGSize(width: 80.0, height: 107.0))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
                
        VoIPHelper.shared()?.isCallActiveInBackground = false
        muteButton.isSelected = VoIPCallStateManager.shared.isCallMuted()
        if isTesting == false {
            if UserSettings.shared()?.disableProximityMonitoring == false {
                UIDevice.current.isProximityMonitoringEnabled = true
            }
        }
        UIApplication.shared.isIdleTimerDisabled = true
        setupView()
        updateAccessibilityLabels()
        
        if !isNavigationVisible() {
            moveLocalVideoViewToCorrectPosition(moveNavigation: true)
        }
        
        checkAndHandleAvailableBluetoothDevices()
    }
    
    override internal func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        showInitiatorVideoCallInfo()
        
        updateGradientBackground()
    }
    
    override internal func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
                
        UIDevice.current.isProximityMonitoringEnabled = false
        UIApplication.shared.isIdleTimerDisabled = false
        switch VoIPCallStateManager.shared.currentCallState() {
        case .ended, .remoteEnded, .rejected, .rejectedBusy, .rejectedTimeout, .rejectedDisabled, .rejectedOffHours, .rejectedUnknown, .microphoneDisabled:
            DispatchQueue.main.async {
                self.removeAllSubviewsFromVideoViews()
            }
            break
        default:
            break
        }
        
        hideInitiatorVideoCallInfo()
        hideRemoteVideoActivatedInfo()
        hideSpeakerInfo()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        didRotateDevice = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if didRotateDevice {
            didRotateDevice = false
            updateGradientBackground()

            #if arch(arm64)
            if let rR = VoIPCallStateManager.shared.remoteVideoRenderer(),
               let remoteRenderer = rR as? RTCMTLVideoView {
                updateRemoteVideoContentMode(videoView: remoteRenderer)
            }
            #endif
        }
    }
        
    override internal var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if #available(iOS 11.0, *) {
            return .all
        } else {
            return .portrait
        }
    }
    
    override internal var shouldAutorotate: Bool {
        if #available(iOS 11.0, *) {
            return true
        } else {
            return false
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

extension CallViewController {
    // MARK: Public functions
    
    func voIPCallStatusChanged(state: VoIPCallService.CallState, oldState: VoIPCallService.CallState) {
        if isTesting == true {
            return
        }
        var timerString = ""
        switch state {
        case .idle:
            timerString = BundleUtil.localizedString(forKey: "call_status_wait_ringing")
            break
        case .sendOffer:
            timerString = BundleUtil.localizedString(forKey: "call_status_wait_ringing")
            break
        case .receivedOffer:
            timerString = BundleUtil.localizedString(forKey: "call_status_wait_ringing")
            break
        case .outgoingRinging:
            timerString = BundleUtil.localizedString(forKey: "call_status_ringing")
            break
        case .incomingRinging:
            timerString = BundleUtil.localizedString(forKey: "call_status_incom_ringing")
        case .sendAnswer:
            timerString = BundleUtil.localizedString(forKey: "call_status_ringing")
            break
        case .receivedAnswer:
            timerString = BundleUtil.localizedString(forKey: "call_status_ringing")
            break
        case .initializing:
            timerString = BundleUtil.localizedString(forKey: "call_status_initializing")
            break
        case .calling:
            timerString = BundleUtil.localizedString(forKey: "call_status_calling")
            break
        case .reconnecting:
            if oldState != .remoteEnded && oldState != .ended {
                timerString = BundleUtil.localizedString(forKey: "call_status_reconnecting")
            }
            break
        case .ended, .remoteEnded:
            timerString = BundleUtil.localizedString(forKey: "call_end")
            break
        case .rejected:
            timerString = BundleUtil.localizedString(forKey: "call_rejected")
            break
        case .rejectedBusy:
            timerString = BundleUtil.localizedString(forKey: "call_rejected_busy")
            break
        case .rejectedTimeout:
            timerString = BundleUtil.localizedString(forKey: "call_rejected_timeout")
            break
        case .rejectedOffHours:
            timerString = BundleUtil.localizedString(forKey: "call_rejected")
            break
        case .rejectedUnknown:
            timerString = BundleUtil.localizedString(forKey: "call_rejected")
            break
        case .rejectedDisabled:
            timerString = BundleUtil.localizedString(forKey: "call_rejected_disabled")
            break
        case .microphoneDisabled:
            timerString = BundleUtil.localizedString(forKey: "call_microphone_permission_title")
            break
        }
        DispatchQueue.main.async {
            self.timerLabel?.text = timerString
            self.muteButton?.isEnabled = state == .calling || state == .reconnecting
        }
        
        updateView()
    }
    
    func voIPCallDurationChanged(_ time: Int) {
        DispatchQueue.main.async {
            if self.timerLabel != nil {
                self.timerLabel.text = DateFormatter.timeFormatted(time)
            }
        }
    }
    
    func startDebugMode(connection: RTCPeerConnection) {
        let dict = ["connection": connection]
        statsTimer?.invalidate()
        statsTimer = nil
        DispatchQueue.main.async {
            var previousState: VoIPStatsState? = nil
            self.statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { (timer) in
                if let connection = dict["connection"] {
                    connection.statistics { (report) in
                        let options = VoIPStatsOptions.init()
                        options.selectedCandidatePair = true
                        options.transport = true
                        options.crypto = true
                        options.inboundRtp = true
                        options.outboundRtp = true
                        options.tracks = true
                        options.candidatePairsFlag = .OVERVIEW
                        let stats = VoIPStats.init(report: report, options: options, transceivers: connection.transceivers, previousState: previousState)
                        previousState = stats.buildVoIPStatsState()
                        DispatchQueue.main.async {
                            if self.debugLabel != nil {
                                if self.debugLabel.isHidden == false {
                                    var statsString = stats.getShortRepresentation()
                                    if self.threemaVideoCallAvailable {
                                        statsString += "\n\n\(CallsignalingProtocol.printDebugQualityProfiles(remoteProfile: VoIPCallStateManager.shared.remoteVideoQualityProfile(), networkIsRelayed: VoIPCallStateManager.shared.networkIsRelayed()))"
                                    }
                                    self.debugLabel.text = statsString
                                }
                            }
                        }
                    }
                }
            })
        }
    }
    
    func resetStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }
    
    func enableThreemaVideoCall() {
        DispatchQueue.main.async {
            self.threemaVideoCallAvailable = true
        }
    }
    
    func disableThreemaVideoCall() {
        DispatchQueue.main.async {
            self.threemaVideoCallAvailable = false
            if VoIPCallStateManager.shared.localVideoRenderer() != nil && UserSettings.shared().enableVideoCall {
                self.showCameraDisabledInfo()
            }
            self.endLocalVideo()
        }
    }
}

extension CallViewController {
    // MARK: Private functions
    
    private func setupView() {
        contactLabel.text = contact?.displayName
        
        backgroundImage.contentMode = contact!.isProfilePictureSet() ? .scaleAspectFill : .scaleAspectFit
        if let contact = self.contact {
            setBackgroundForContact(contact: contact)
        }
        backgroundImage.backgroundColor = Colors.black()
        verificationLevel.image = contact?.verificationLevelImage()

        if isTesting == false {
            debugLabel.isHidden = true
            
            updateView()
            timerLabel.isHidden = false
        }
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            speakerButton.isSelected = true
        }
                
        debugLabel.text = ""
        
        acceptButton.setImage(UIImage.init(named: "AcceptCall", in: Colors.green()), for: .normal)
        acceptButton.setImage(UIImage.init(named: "AcceptCall", in: Colors.green()), for: .selected)
        acceptButton.setImage(UIImage.init(named: "AcceptCall", in: Colors.green()), for: .highlighted)
        
        rejectButton.setImage(UIImage.init(named: "RejectCall", in: Colors.red()), for: .normal)
        rejectButton.setImage(UIImage.init(named: "RejectCall", in: Colors.red()), for: .selected)
        rejectButton.setImage(UIImage.init(named: "RejectCall", in: Colors.red()), for: .highlighted)
        
        endButton.setImage(UIImage.init(named: "RejectCall", in: Colors.red()), for: .normal)
        endButton.setImage(UIImage.init(named: "RejectCall", in: Colors.red()), for: .selected)
        endButton.setImage(UIImage.init(named: "RejectCall", in: Colors.red()), for: .highlighted)
        
        cameraButton.setImage(UIImage.init(named: "VideoInactive"), for: .normal)
        cameraButton.setImage(UIImage.init(named: "VideoInactive"), for: .selected)
        cameraButton.setImage(UIImage.init(named: "VideoInactive"), for: .highlighted)
        cameraButton.layer.cornerRadius = cameraButton.frame.width / 2
        cameraButton.layer.masksToBounds = false
        
        contactLabel.layer.shadowColor = UIColor.black.cgColor
        contactLabel.layer.shadowOffset = CGSize(width: 0, height: 0)
        contactLabel.layer.shadowRadius = 1.0
        contactLabel.layer.shadowOpacity = 0.2
        
        timerLabel.layer.shadowColor = UIColor.black.cgColor
        timerLabel.layer.shadowOffset = CGSize(width: 0, height: 0)
        timerLabel.layer.shadowRadius = 1.0
        timerLabel.layer.shadowOpacity = 0.2
        
        cameraSwitchButton.setImage(UIImage.init(named: "SwitchCam"), for: .normal)
        cameraSwitchButton.setImage(UIImage.init(named: "SwitchCam"), for: .selected)
        cameraSwitchButton.setImage(UIImage.init(named: "SwitchCam"), for: .highlighted)
        cameraSwitchButton.layer.cornerRadius = cameraSwitchButton.frame.width / 2
        cameraSwitchButton.layer.masksToBounds = false
        
        muteButton.setImage(UIImage.init(named: "MuteInactive"), for: .normal)
        muteButton.setImage(UIImage.init(named: "MuteActive"), for: .selected)
        muteButton.layer.cornerRadius = muteButton.frame.width / 2
        muteButton.layer.masksToBounds = false
        
        speakerButton.layer.cornerRadius = speakerButton.frame.width / 2
        speakerButton.layer.masksToBounds = false
        hideButton.layer.cornerRadius = hideButton.frame.width / 2
        hideButton.layer.shadowColor = UIColor.black.cgColor
        hideButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        hideButton.layer.shadowRadius = 1.0
        hideButton.layer.shadowOpacity = 0.2
        hideButton.layer.masksToBounds = false
                        
        if isTesting == true {
            setupForIncomCallTest()
        }
    }
    
    func setBackgroundForContact(contact : Contact) {
        guard let avatarImage = AvatarMaker.shared().callBackground(for: contact) else {
            DDLogError("Could not create avatar image")
            return
        }
        if contact.isProfilePictureSet() {
            self.backgroundImage.image = self.blurImage(image: avatarImage, blurRadius: 4.0)
        } else {
            self.backgroundImage.image = avatarImage
        }
    }
    
    private func updateView() {
        if isTesting == false {
            DispatchQueue.main.async {
                if VoIPCallStateManager.shared.currentCallState() == .microphoneDisabled {
                    self.endButton?.isHidden = true
                    self.acceptButton?.isHidden = false
                    self.rejectButton?.isHidden = false
                    self.muteButton?.isHidden = true
                    self.phoneButtonsGradientView?.isHidden = true
                    self.speakerButton?.isHidden = true
                    self.cameraButton?.isHidden = true
                    self.cameraSwitchButton?.isHidden = true
                    self.localVideoView?.isHidden = true
                    self.remoteVideoView?.isHidden = true
                    
                    self.endButton?.isEnabled = false
                    self.acceptButton?.isEnabled = false
                    self.rejectButton?.isEnabled = false
                    self.muteButton?.isEnabled = false
                    self.speakerButton?.isEnabled = false
                    self.cameraButton?.isEnabled = false
                    self.cameraSwitchButton?.isEnabled = false
                    
                    self.voIPCallStatusChanged(state: .microphoneDisabled, oldState: .microphoneDisabled)
                } else {
                    self.endButton?.isHidden = !self.isCallInitiator && !self.alreadyAccepted
                    self.acceptButton?.isHidden = self.isCallInitiator || self.alreadyAccepted
                    self.rejectButton?.isHidden = self.isCallInitiator || self.alreadyAccepted
                    self.muteButton?.isHidden = !self.isCallInitiator && !self.alreadyAccepted
                    self.phoneButtonsGradientView?.isHidden = !self.isCallInitiator && !self.alreadyAccepted
                    self.phoneButtonsGradientView?.isHidden = !self.isCallInitiator && !self.alreadyAccepted
                    self.speakerButton?.isHidden = !self.isCallInitiator && !self.alreadyAccepted
                    
                    self.endButton?.isEnabled = true
                    self.acceptButton?.isEnabled = true
                    self.muteButton?.isEnabled = true
                    self.speakerButton?.isEnabled = true
                    
                    self.updateVideoViews()
                }
            }
        }
    }
    
    private func updateVideoViews() {
        if contact != nil, threemaVideoCallAvailable == true {
            let cameraImageName = self.isLocalVideoActive ? "VideoActive" : "VideoInactive"
            cameraButton?.setImage(UIImage.init(named: cameraImageName), for: .normal)
            cameraButton?.setImage(UIImage.init(named: cameraImageName), for: .selected)
            cameraButton?.setImage(UIImage.init(named: cameraImageName), for: .highlighted)
            cameraButton?.accessibilityLabel = BundleUtil.localizedString(forKey: self.isLocalVideoActive ? "call_camera_deactivate_button" : "call_camera_activate_button")
            cameraButton?.alpha = 1.0
            cameraButton?.isHidden = !self.isCallInitiator && !self.alreadyAccepted
            cameraSwitchButton?.isHidden = !(self.isLocalVideoActive && (AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) != nil))
            cameraButton?.isEnabled = true
            cameraSwitchButton?.isEnabled = true
            
            localVideoView?.isHidden = !(self.isLocalVideoActive && isReceivingRemoteVideo)
            remoteVideoView?.isHidden = !(self.isLocalVideoActive || isReceivingRemoteVideo)
        } else {
            if alreadyAccepted && UserSettings.shared().enableVideoCall {
                cameraButton?.setImage(UIImage.init(named: "VideoInactive")!.withTint(Colors.gray()), for: .normal)
                cameraButton?.setImage(UIImage.init(named: "VideoInactive")!.withTint(Colors.gray()), for: .selected)
                cameraButton?.setImage(UIImage.init(named: "VideoInactive")!.withTint(Colors.gray()), for: .highlighted)
                cameraButton?.accessibilityLabel = BundleUtil.localizedString(forKey: "call_camera_deactivate_button")
                cameraButton?.isHidden = isCallInitiator && !UserSettings.shared().enableVideoCall
                cameraButton?.alpha = 0.9
            } else {
                cameraButton?.alpha = 1.0
                cameraButton?.isHidden = true
            }
            
            localVideoView?.isHidden = true
            remoteVideoView?.isHidden = true
            cameraSwitchButton?.isHidden = true
            cameraButton?.isEnabled = true
            cameraSwitchButton?.isEnabled = false
        }
    }
    
    private func setupForIncomCallTest() {
        DispatchQueue.main.async {
            self.endButton.isHidden = true
            self.acceptButton.isHidden = false
            self.rejectButton.isHidden = false
            self.muteButton.isHidden = true
            self.speakerButton.isHidden = true
            self.timerLabel.isHidden = false
            self.cameraButton.isHidden = true
            self.cameraSwitchButton.isHidden = true
            self.debugLabel.isHidden = true
            self.cellularWarningButton.isHidden = true
        
            self.timerLabel.text = BundleUtil.localizedString(forKey: "call_status_incom_ringing")
        }
    }
    
    private func setupForConnectedCallTest() {
        debugLabel.isHidden = true
        endButton.isHidden = false
        acceptButton.isHidden = true
        rejectButton.isHidden = true
        muteButton.isHidden = false
        speakerButton.isHidden = false
        timerLabel.isHidden = false
        cameraButton.isHidden = false
        cameraSwitchButton.isHidden = true
        cellularWarningButton.isHidden = true
                
        self.endButton?.isEnabled = true
        self.muteButton?.isEnabled = true
        self.speakerButton?.isEnabled = true
        self.cameraButton?.isEnabled = true
        self.cameraSwitchButton.isEnabled = true
                
        DispatchQueue.main.async {
            self.timerLabel.text = "08:15"
        }
        speakerButton.setImage(UIImage.init(named: "SpeakerInactive"), for: .normal)
        speakerButton.setImage(UIImage.init(named: "SpeakerActive"), for: .highlighted)
        
        cameraButton?.setImage(UIImage.init(named: "VideoInactive"), for: .normal)
        cameraButton?.setImage(UIImage.init(named: "VideoInactive"), for: .selected)
        cameraButton?.setImage(UIImage.init(named: "VideoInactive"), for: .highlighted)
    }
    
    private func setupForVideoCallTest() {
        debugLabel.isHidden = true
        endButton.isHidden = false
        acceptButton.isHidden = true
        rejectButton.isHidden = true
        muteButton.isHidden = false
        speakerButton.isHidden = false
        timerLabel.isHidden = false
        cameraButton.isHidden = false
        cameraButton.isSelected = true
        cameraSwitchButton.isHidden = false
        cellularWarningButton.isHidden = true
        
        self.endButton?.isEnabled = true
        self.muteButton?.isEnabled = true
        self.speakerButton?.isEnabled = true
        self.cameraButton?.isEnabled = true
        self.cameraSwitchButton.isEnabled = true
        
        let cameraImageName = "VideoActive"
        self.cameraButton?.setImage(UIImage.init(named: cameraImageName), for: .normal)
        self.cameraButton?.setImage(UIImage.init(named: cameraImageName), for: .selected)
        self.cameraButton?.setImage(UIImage.init(named: cameraImageName), for: .highlighted)
        
        DispatchQueue.main.async {
            self.timerLabel.text = "08:15"
        }
        speakerButton.setImage(UIImage.init(named: "SpeakerActive"), for: .normal)
        speakerButton.setImage(UIImage.init(named: "SpeakerActive"), for: .highlighted)
        
        self.localVideoView?.isHidden = false
        self.remoteVideoView?.isHidden = false
        
        var meImage = AvatarMaker.shared().unknownPersonImage()
        if let profilePicture = MyIdentityStore.shared()?.profilePicture {
            if let data = profilePicture["ProfilePicture"] {
                meImage = UIImage(data: data as! Data)
            }
        }
        
        let meImageView = UIImageView(image: meImage)
        meImageView.contentMode = .scaleAspectFill
        embedView(meImageView, into: localVideoView)
        
        let remoteImageView = UIImageView()
        remoteImageView.image = AvatarMaker.shared()?.avatar(for: contact, size: remoteVideoView.frame.size.width, masked: false)
        remoteImageView.contentMode = .scaleAspectFill
        embedView(remoteImageView, into: remoteVideoView)
    }
    
    private func startLocalVideo(useBackCamera: Bool = false, switchCamera: Bool = false) {
        DispatchQueue.main.async {
            self.backgroundImage.image = nil
            #if arch(arm64)
            // Using metal (arm64 only)
            let localRenderer = RTCMTLVideoView(frame: self.localVideoView?.frame ?? CGRect.zero)
            localRenderer.videoContentMode = .scaleAspectFill
            #else
            // Using OpenGLES for the rest
            let localRenderer = RTCEAGLVideoView(frame: self.localVideoView?.frame ?? CGRect.zero)
            #endif
            localRenderer.delegate = self
            VoIPCallStateManager.shared.startCaptureLocalVideo(renderer: localRenderer, useBackCamera: useBackCamera, switchCamera: switchCamera)
            
            if (!self.isReceivingRemoteVideo) {
                if let remoteVideoView = self.remoteVideoView {
                    self.embedView(localRenderer, into: remoteVideoView)
                    self.flipLocalRenderer()
                    self.updateVideoViews()
                    if switchCamera == false {
                        self.activateSpeakerForVideo()
                    }
                }
            } else {
                if let localVideoView = self.localVideoView {
                    if self.isRemoteRendererInRemoteView() {
                        self.embedView(localRenderer, into: localVideoView)
                    } else {
                        self.embedView(localRenderer, into: self.remoteVideoView)
                    }
                    
                    self.flipLocalRenderer()
                    self.updateVideoViews()
                    if switchCamera == false {
                        self.activateSpeakerForVideo()
                    }
                }
            }
        }
    }
    
    private func endLocalVideo(switchCamera: Bool = false) {
        VoIPCallStateManager.shared.endCaptureLocalVideo(switchCamera: switchCamera)
        
        DispatchQueue.main.async {
            if (self.isReceivingRemoteVideo) {
                if let remoteRenderer = VoIPCallStateManager.shared.remoteVideoRenderer() {
                    if self.localVideoView.subviews.first == remoteRenderer as? UIView {
                        if !switchCamera {
                            self.moveEmbedView(remoteRenderer as! UIView, from: self.localVideoView, into: self.remoteVideoView)
                        } else {
                            self.removeSubviewsFromRemoteView()
                        }
                    }
                    else if self.remoteVideoView.subviews.first == remoteRenderer as? UIView {
                        self.removeSubviewsFromLocalView()
                    }
                }
            } else {
                if let contact = self.contact {
                    self.setBackgroundForContact(contact: contact)
                }
                self.removeAllSubviewsFromVideoViews()
            }
            self.flipLocalRenderer()
            self.updateVideoViews()
        }
    }
    private func startRemoteVideo() {
        DispatchQueue.main.async {
            if self.viewIfLoaded?.window != nil {
                self.backgroundImage.image = nil
                #if arch(arm64)
                // Using metal (arm64 only)
                let remoteRenderer = RTCMTLVideoView(frame: self.remoteVideoView?.frame ?? CGRect.zero)
                remoteRenderer.videoContentMode = .scaleAspectFill
                #else
                // Using OpenGLES for the rest
                let remoteRenderer = RTCEAGLVideoView(frame: self.remoteVideoView?.frame ?? CGRect.zero)
                #endif
                remoteRenderer.delegate = self
                VoIPCallStateManager.shared.renderRemoteVideo(to: remoteRenderer)
                
                if (!self.isLocalVideoActive || self.localVideoView.subviews.first == VoIPCallStateManager.shared.localVideoRenderer() as? UIView) {
                    if let remoteVideoView = self.remoteVideoView {
                        self.embedView(remoteRenderer, into: remoteVideoView)
                        self.updateVideoViews()
                    }
                } else {
                    if let localRenderer = VoIPCallStateManager.shared.localVideoRenderer() {
                        self.moveEmbedView(localRenderer as! UIView, from: self.remoteVideoView, into: self.localVideoView)
                        self.flipLocalRenderer()
                    }
                    if let remoteVideoView = self.remoteVideoView {
                        self.embedView(remoteRenderer, into: remoteVideoView)
                        self.updateVideoViews()
                    }
                }
                
                if !self.isLocalVideoActive && self.isReceivingRemoteVideo && !self.viewWasHidden && self.isViewLoaded && self.view.window != nil {
                    self.showRemoteVideoActivatedInfo()
                    self.showSpeakerInfo()
                }
            }
        }
    }
    
    private func endRemoteVideo() {
        VoIPCallStateManager.shared.endRemoteVideo()
        DispatchQueue.main.async {
            if self.viewIfLoaded?.window != nil {
                if (self.isLocalVideoActive) {
                    self.moveOrRemoveLocalRenderer()
                } else {
                    if let contact = self.contact {
                        self.setBackgroundForContact(contact: contact)
                    }
                    self.removeAllSubviewsFromVideoViews()
                }
                self.flipLocalRenderer()
                self.updateVideoViews()
            }
        }
    }
    
    private func moveOrRemoveLocalRenderer() {
        if let localRenderer = VoIPCallStateManager.shared.localVideoRenderer() {
            if self.localVideoView.subviews.first == localRenderer as? UIView {
                self.moveEmbedView(localRenderer as! UIView, from: self.localVideoView, into: self.remoteVideoView)
            }
            else if self.remoteVideoView.subviews.first == localRenderer as? UIView {
                self.removeSubviewsFromLocalView()
            }
        }
    }
    
    private func embedView(_ view: UIView, into containerView: UIView) {
        containerView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.masksToBounds = true

        containerView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        containerView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        containerView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        containerView.layoutIfNeeded()
    }
    
    private func moveEmbedView(_ view: UIView, from fromContainerView: UIView, into containerView: UIView) {
        self.removeAllSubviewsFromVideoViews()
        self.embedView(view, into: containerView)
    }
    
    private func switchCamera() {
        useBackCamera = !useBackCamera
        cameraSwitchButton.accessibilityLabel = BundleUtil.localizedString(forKey: useBackCamera ? "call_camera_switch_to_front_button" : "call_camera_switch_to_back_button")
        endLocalVideo(switchCamera: true)
        startLocalVideo(useBackCamera: useBackCamera, switchCamera: true)
    }
    
    private func isLocalRendererInLocalView() -> Bool {
        if let localRenderer = VoIPCallStateManager.shared.localVideoRenderer() as? UIView {
            if self.localVideoView.subviews.first == localRenderer {
                return true
            }
        }
        return false
    }
    
    private func isLocalRendererInRemoteView() -> Bool {
        if let localRenderer = VoIPCallStateManager.shared.localVideoRenderer() as? UIView {
            if self.remoteVideoView.subviews.first == localRenderer {
                return true
            }
        }
        return false
    }
    
    private func isRemoteRendererInRemoteView() -> Bool {
        if let remoteRenderer = VoIPCallStateManager.shared.remoteVideoRenderer() as? UIView {
            if self.remoteVideoView.subviews.first == remoteRenderer {
                return true
            }
        }
        return false
    }
    
    private func isRemoteRendererInLocalView() -> Bool {
        if let remoteRenderer = VoIPCallStateManager.shared.remoteVideoRenderer() as? UIView {
            if self.localVideoView.subviews.first == remoteRenderer {
                return true
            }
        }
        return false
    }
    
    private func removeSubviewsFromLocalView() {
        guard localVideoView != nil else {
            return
        }
        guard localVideoView.subviews.count > 0 else {
            return
        }
        self.localVideoView.subviews.forEach({ $0.removeFromSuperview() })
    }
    
    private func removeSubviewsFromRemoteView() {
        guard remoteVideoView != nil else {
            return
        }
        guard remoteVideoView.subviews.count > 0 else {
            return
        }
        self.remoteVideoView.subviews.forEach({ $0.removeFromSuperview() })
    }
    
    private func removeAllSubviewsFromVideoViews() {
        removeSubviewsFromLocalView()
        removeSubviewsFromRemoteView()
        
        // show navigation if needed
        if !isNavigationVisible() {
            moveLocalVideoViewToCorrectPosition(moveNavigation: true)
        }
    }
    
    private func flipLocalRenderer() {
        if useBackCamera == false {
            if isLocalRendererInLocalView() {
                if localVideoView != nil {
                    localVideoView.layer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
                }
            } else {
                if localVideoView != nil {
                    localVideoView.layer.setAffineTransform(CGAffineTransform(scaleX: 1, y: 1))
                }
            }
            
            if isLocalRendererInRemoteView() {
                if remoteVideoView != nil {
                    remoteVideoView.layer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
                }
            } else {
                if remoteVideoView != nil {
                    remoteVideoView.layer.setAffineTransform(CGAffineTransform(scaleX: 1, y: 1))
                }
            }
        } else {
            if localVideoView != nil {
                localVideoView.layer.setAffineTransform(CGAffineTransform(scaleX: 1, y: 1))
            }
            if remoteVideoView != nil {
                remoteVideoView.layer.setAffineTransform(CGAffineTransform(scaleX: 1, y: 1))
            }
        }
    }
    
    private func hasCameraAccess() -> Bool {
        let access = AVCaptureDevice.authorizationStatus(for: .video)
        if access ==  .authorized {
            return true
        }
        else if access ==  .denied || access == .restricted {
            self.showCameraAccessAlert()
        }
        else if access ==  .notDetermined {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                if granted {
                    self.isLocalVideoActive = !self.isLocalVideoActive
                    if self.isLocalVideoActive == true {
                        self.startLocalVideo()
                    } else {
                        self.endLocalVideo()
                    }
                } else {
                    self.showCameraAccessAlert()
                }
            })
        }
        return false
    }

    private func showCameraAccessAlert() {
        UIAlertTemplate.showAlert(owner: self, title: BundleUtil.localizedString(forKey: "camera_disabled_title"), message: BundleUtil.localizedString(forKey: "camera_disabled_message"))
    }
    
    private func activateSpeakerForVideo()  {
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        
        for output in currentRoute.outputs {
            if output.portType == AVAudioSession.Port.builtInReceiver {
                let action = VoIPCallUserAction.init(action: .speakerOn, contact: self.contact!, callId: VoIPCallStateManager.shared.currentCallId(), completion: nil)
                VoIPCallStateManager.shared.processUserAction(action)
            }
        }
    }
    
    private func isNavigationVisible() -> Bool {
        guard let navigationConstraint = phoneButtonsStackViewBottomConstraint else {
            return true
        }
        return navigationConstraint.constant == 0.0
    }
    
    private func removeAllLocalVideoViewConstraints() {
        localVideoViewConstraintLeft.isActive = false
        localVideoViewConstraintRight.isActive = false
        localVideoViewConstraintBottom.isActive = false
        localVideoViewConstraintBottomNavigation.isActive = false
        localVideoViewConstraintTop.isActive = false
        localVideoViewConstraintTopNavigation.isActive = false
        localVideoViewConstraintTopNavigationLabel.isActive = false
        self.view.layoutIfNeeded()
    }
    
    private func moveLocalVideoViewToCorrectPosition(moveNavigation: Bool = false) {
        let localVideoViewCenterX = localVideoView.center.x
        let localVideoViewCenterY = localVideoView.center.y
        let screenMiddleX = self.view.frame.size.width / 2
        let screenMiddleY = self.view.frame.size.height / 2
        
        self.removeAllLocalVideoViewConstraints()
                
        guard let _ = phoneButtonsStackViewBottomConstraint,
              let _ = callInfoStackViewTopConstraint,
              let _ = phoneButtonsStackView,
              let _ = callInfoStackView,
              let phoneButtonsStackViewSuperView = phoneButtonsStackView.superview,
              let callInfoStackViewSuperView = callInfoStackView.superview else {
            return
        }
        
        if moveNavigation {
            if isNavigationVisible() {
                self.phoneButtonsStackViewBottomConstraint.constant = self.phoneButtonsStackView.frame.size.height + phoneButtonsStackViewSuperView.layoutMargins.bottom + 50.0
                self.callInfoStackViewTopConstraint.constant = -(self.callInfoStackView.frame.size.height + callInfoStackViewSuperView.layoutMargins.top + 50.0)
            } else {
                self.phoneButtonsStackViewBottomConstraint.constant = 0
                self.callInfoStackViewTopConstraint.constant = 16.0
            }
        }
        
        if localVideoViewCenterX < screenMiddleX && localVideoViewCenterY < screenMiddleY {
            self.addConstraintToTopLeftForLocalVideoView()
        }
        else if localVideoViewCenterX > screenMiddleX && localVideoViewCenterY < screenMiddleY {
            self.addConstraintToTopRightForLocalVideoView()
        }
        else if localVideoViewCenterX < screenMiddleX && localVideoViewCenterY > screenMiddleY {
            self.addConstraintToBottomLeftForLocalVideoView()
        }
        else if localVideoViewCenterX > screenMiddleX && localVideoViewCenterY > screenMiddleY {
            self.addConstraintToBottomRightForLocalVideoView()
        }
        
        UIView.animate(withDuration: 0.35, animations: {
            self.phoneButtonsGradientView.setNeedsLayout()
            self.phoneButtonsGradientView.layoutIfNeeded()
            self.callInfoGradientView.setNeedsLayout()
            self.callInfoGradientView.layoutIfNeeded()
            self.view.layoutIfNeeded()
        })
    }
    
    private func addConstraintToTopLeftForLocalVideoView() {
        localVideoViewConstraintLeft.isActive = true
        
        if isNavigationVisible() {
            localVideoViewConstraintTopNavigationLabel.isActive = true
        } else {
            localVideoViewConstraintTop.isActive = true
        }
    }
    
    private func addConstraintToTopRightForLocalVideoView() {
        localVideoViewConstraintRight.isActive = true
        if isNavigationVisible() {
            localVideoViewConstraintTopNavigation.isActive = true
        } else {
            localVideoViewConstraintTop.isActive = true
        }
    }
    
    private func addConstraintToBottomLeftForLocalVideoView() {
        localVideoViewConstraintLeft.isActive = true
        if isNavigationVisible() {
            localVideoViewConstraintBottomNavigation.isActive = true
        } else {
            localVideoViewConstraintBottom.isActive = true
        }
    }
    
    private func addConstraintToBottomRightForLocalVideoView() {
        localVideoViewConstraintRight.isActive = true
        if isNavigationVisible() {
            localVideoViewConstraintBottomNavigation.isActive = true
        } else {
            localVideoViewConstraintBottom.isActive = true
        }
    }
    
    private func updateConstraintsAfterRotation(size: CGSize?) {
        if isLocalRendererInLocalView() || isRemoteRendererInLocalView() {
            var maxSize: CGFloat = 100
            var newSize = size ?? CGSize(width: maxSize, height: 134.0)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                maxSize = 200
                newSize = size ?? CGSize(width: maxSize, height: 268.0)
            }
            
            if UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    maxSize = 270.0
                } else {
                    maxSize = 150.0
                }
            }
            
            let ratio = newSize.width / maxSize
            localVideoViewConstraintHeight.constant = newSize.height / ratio
            localVideoViewConstraintWidth.constant = newSize.width / ratio
            
            self.view.layoutIfNeeded()
        }
    }
    
    private func checkAndHandleAvailableBluetoothDevices() {
        var bluetoothAvailable = false
        if let inputs = AVAudioSession.sharedInstance().availableInputs {
            for input in inputs {
                if input.portType == AVAudioSession.Port.bluetoothA2DP || input.portType == AVAudioSession.Port.bluetoothHFP || input.portType == AVAudioSession.Port.bluetoothLE {
                    bluetoothAvailable = true
                }
            }
        }
        
        if bluetoothAvailable {
            if myVolumeView == nil {
                if #available(iOS 11.0, *) {
                    myVolumeView = AVRoutePickerView.init(frame: CGRect.init(x: 0.0, y: 0.0, width: speakerButton.frame.size.width, height: speakerButton.frame.size.height))
                    (myVolumeView as! AVRoutePickerView).activeTintColor = UIColor.clear
                    (myVolumeView as! AVRoutePickerView).tintColor = UIColor.clear
                    (myVolumeView as! AVRoutePickerView).isOpaque = true
                    (myVolumeView as! AVRoutePickerView).alpha = 1.0
                    (myVolumeView as! AVRoutePickerView).delegate = self
                    if #available(iOS 13.0, *) {
                        if isLocalVideoActive || isReceivingRemoteVideo {
                            (myVolumeView as! AVRoutePickerView).prioritizesVideoDevices = true
                        }
                    }
                    speakerButton.addSubview(myVolumeView!)
                } else {
                    myVolumeView = MPVolumeView(frame: CGRect.init(x: 0.0, y: 0.0, width: speakerButton.frame.size.width, height: speakerButton.frame.size.height))
                    (myVolumeView as! MPVolumeView).showsVolumeSlider = false
                    (myVolumeView as! MPVolumeView).showsRouteButton = true
                    (myVolumeView as! MPVolumeView).setRouteButtonImage(UIImage.init(named: "SpeakerInactive")!.resizedImage(newSize: CGSize(width: 45.0, height: 45.0)), for: .normal)
                    (myVolumeView as! MPVolumeView).setRouteButtonImage(UIImage.init(named: "SpeakerActive")!.resizedImage(newSize: CGSize(width: 45.0, height: 45.0)), for: .selected)
                    speakerButton.setImage(nil, for: .normal)
                    speakerButton.addSubview(myVolumeView!)
                }
            }
        } else {
            speakerButton.subviews.forEach({
                if $0 == myVolumeView {
                    $0.removeFromSuperview()
                }
            })
            myVolumeView = nil
        }
    }
    
    private func showInitiatorVideoCallInfo() {
        if let contact = contact, contact.isVideoCallAvailable() && isNavigationVisible() && isCallInitiator && UserSettings.shared().enableVideoCall && !UserSettings.shared().videoCallInfoShown && threemaVideoCallAvailable {
            self.presentInitiatorVideoCallMaterialShowcase()
        }
    }
    
    private func presentInitiatorVideoCallMaterialShowcase(completion handler: (()-> Void)? = nil) {
        if viewIfLoaded?.window != nil {
            if initiatorVideoCallShowcase == nil {
                initiatorVideoCallShowcase = MaterialShowcase()
                initiatorVideoCallShowcase!.setTargetView(button: cameraButton)
                
                initiatorVideoCallShowcase!.primaryText = BundleUtil.localizedString(forKey: "call_threema_video_in_chat_info_title")
                initiatorVideoCallShowcase!.secondaryText = BundleUtil.localizedString(forKey: "call_threema_initiator_video_info")
                initiatorVideoCallShowcase!.backgroundPromptColor = LicenseStore.requiresLicenseKey() ? Colors.workBlue() : Colors.green()
                
                initiatorVideoCallShowcase!.backgroundPromptColorAlpha = 0.7
                initiatorVideoCallShowcase!.backgroundRadius = -1
                initiatorVideoCallShowcase!.targetHolderColor = Colors.black()?.withAlphaComponent(0.2)
                initiatorVideoCallShowcase!.primaryTextSize = 24.0
                initiatorVideoCallShowcase!.secondaryTextSize = 18.0
                initiatorVideoCallShowcase!.primaryTextColor = Colors.white()
                
                initiatorVideoCallShowcase!.primaryTextAlignment = .right
                initiatorVideoCallShowcase!.secondaryTextAlignment = .right
                initiatorVideoCallShowcase!.onTapThrough = {
                    self.startVideoAction(self.cameraButton)
                }
                initiatorVideoCallShowcase!.delegate = self
            }
            
            initiatorVideoCallShowcase!.show(hasSkipButton: false, completion: handler)
        }
    }
    
    private func hideInitiatorVideoCallInfo() {
        if let showcase = initiatorVideoCallShowcase {
            showcase.completeShowcase()
        }
    }
    
    private func showRemoteVideoActivatedInfo() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
            if !self.isLocalVideoActive {
                if let contact = self.contact, self.isNavigationVisible() && contact.isVideoCallAvailable() && UserSettings.shared().enableVideoCall && self.threemaVideoCallAvailable  {
                    self.presentRemoteVideoActivatedMaterialShowcase {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: {
                            self.hideRemoteVideoActivatedInfo()
                        })
                    }
                }
            }
        })
    }
        
    private func presentRemoteVideoActivatedMaterialShowcase(completion handler: (()-> Void)?) {
        if viewIfLoaded?.window != nil {
            if remoteVideoActivatedShowcase == nil {
                remoteVideoActivatedShowcase = MaterialShowcase()
                remoteVideoActivatedShowcase!.setTargetView(button: cameraButton)
                remoteVideoActivatedShowcase!.primaryText = BundleUtil.localizedString(forKey: "call_threema_remote_video_activated_info_title")
                remoteVideoActivatedShowcase!.secondaryText = BundleUtil.localizedString(forKey: "call_threema_remote_video_activated_info")
                remoteVideoActivatedShowcase!.backgroundPromptColor = Colors.darkGrey()
                
                remoteVideoActivatedShowcase!.backgroundPromptColorAlpha = 0.7
                remoteVideoActivatedShowcase!.backgroundRadius = -1
                remoteVideoActivatedShowcase!.targetHolderColor = Colors.black()?.withAlphaComponent(0.2)
                remoteVideoActivatedShowcase!.primaryTextSize = 24.0
                remoteVideoActivatedShowcase!.secondaryTextSize = 18.0
                remoteVideoActivatedShowcase!.primaryTextColor = Colors.white()
                remoteVideoActivatedShowcase!.primaryTextAlignment = .right
                remoteVideoActivatedShowcase!.secondaryTextAlignment = .right
                remoteVideoActivatedShowcase!.onTapThrough = {
                    self.startVideoAction(self.cameraButton)
                }
                
            }
            remoteVideoActivatedShowcase!.show(hasSkipButton: false, completion: handler)
        }
    }
    
    private func hideRemoteVideoActivatedInfo() {
        if let showcase = remoteVideoActivatedShowcase {
            showcase.completeShowcase()
        }
    }
    
    private func showSpeakerInfo() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: {
            var showSpeakerInfo = true
            let currentRoute = AVAudioSession.sharedInstance().currentRoute
            for output in currentRoute.outputs {
                if output.portType == AVAudioSession.Port.builtInSpeaker {
                    showSpeakerInfo = false
                }
                else if output.portType == AVAudioSession.Port.headphones {
                    showSpeakerInfo = false
                }
                else if output.portType == AVAudioSession.Port.bluetoothA2DP || output.portType == AVAudioSession.Port.bluetoothHFP || output.portType == AVAudioSession.Port.bluetoothLE {
                   showSpeakerInfo = false
                }
            }
            if !self.isLocalVideoActive && showSpeakerInfo {
                if let contact = self.contact, self.isNavigationVisible() && contact.isVideoCallAvailable() && UserSettings.shared().enableVideoCall && !UserSettings.shared().videoCallSpeakerInfoShown && self.threemaVideoCallAvailable && self.isViewLoaded && self.view.window != nil {
                    self.presentSpaekerMaterialShowcase {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
                            self.hideSpeakerInfo()
                        })
                    }
                }
            }
        })

    }
    
    private func presentSpaekerMaterialShowcase(completion handler: (()-> Void)?) {
        if viewIfLoaded?.window != nil {
            if speakerShowcase == nil {
                speakerShowcase = MaterialShowcase()
                speakerShowcase!.setTargetView(button: speakerButton)
                speakerShowcase!.primaryText = ""
                speakerShowcase!.secondaryText = BundleUtil.localizedString(forKey: "call_threema_speaker_info")
                speakerShowcase!.backgroundPromptColor = Colors.darkGrey()
                
                speakerShowcase!.backgroundPromptColorAlpha = 0.7
                speakerShowcase!.backgroundRadius = -1
                speakerShowcase!.targetHolderColor = Colors.black()?.withAlphaComponent(0.2)
                speakerShowcase!.secondaryTextSize = 18.0
                speakerShowcase!.primaryTextColor = Colors.white()
                speakerShowcase!.primaryTextAlignment = .left
                speakerShowcase!.secondaryTextAlignment = .left
                speakerShowcase!.onTapThrough = {
                    UserSettings.shared().videoCallSpeakerInfoShown = true
                    self.speakerShowcase!.completeShowcase()
                    self.speakerAction(self.speakerButton, forEvent: UIEvent())
                }
                speakerShowcase!.skipButton = {
                    UserSettings.shared().videoCallSpeakerInfoShown = true
                    self.speakerShowcase!.completeShowcase()
                }
            }
            
            speakerShowcase!.layoutMargins = UIEdgeInsets(top: (speakerShowcase!.containerView.frame.size.height / 3) * 2, left: 0.0, bottom: 0.0, right: 0.0)
            speakerShowcase!.show(hasSkipButton: true, completion: handler)
        }
    }
    
    private func hideSpeakerInfo() {
        if let showcase = speakerShowcase {
            showcase.completeShowcase()
        }
    }
    
    private func showCameraDisabledInfo() {
        if isNavigationVisible() {
            presentCameraDisabledMaterialShowcase {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
                    self.hideCameraDisalbedInfo()
                })
            }
        }
    }
    
    private func presentCameraDisabledMaterialShowcase(completion handler: (()-> Void)?) {
        if viewIfLoaded?.window != nil {
            if cameraDisabledShowcase == nil {
                cameraDisabledShowcase = MaterialShowcase()
                cameraDisabledShowcase!.setTargetView(button: cameraButton)
                cameraDisabledShowcase!.primaryText = ""
                cameraDisabledShowcase!.secondaryText = BundleUtil.localizedString(forKey: "call_threema_camera_disabled_info")
                cameraDisabledShowcase!.backgroundPromptColor = Colors.darkGrey()
                
                cameraDisabledShowcase!.backgroundPromptColorAlpha = 0.7
                cameraDisabledShowcase!.backgroundRadius = -1
                cameraDisabledShowcase!.targetHolderColor = Colors.black()?.withAlphaComponent(0.2)
                cameraDisabledShowcase!.secondaryTextSize = 18.0
                cameraDisabledShowcase!.primaryTextColor = Colors.white()
                cameraDisabledShowcase!.primaryTextAlignment = .right
                cameraDisabledShowcase!.secondaryTextAlignment = .right
            }
            
            cameraDisabledShowcase!.show(hasSkipButton: false, completion: handler)
        }
    }
    
    private func hideCameraDisalbedInfo() {
        if let showcase = cameraDisabledShowcase {
            showcase.completeShowcase()
        }
    }
    
    private func blurImage(image: UIImage, blurRadius: CGFloat) -> UIImage {
        let context = CIContext(options: nil)
        let inputImage = CIImage(cgImage: image.cgImage!)

        let blurFilter = CIFilter(name: "CIGaussianBlur")
        blurFilter?.setValue(inputImage, forKey: kCIInputImageKey)
        blurFilter?.setValue(blurRadius, forKey: "inputRadius")
        
        var bounds = inputImage.extent
        if AvatarMaker.shared().isDefaultAvatar(for: contact) {
            bounds = CGRect(x: -10.0, y: -10.0, width: image.size.width + 20.0, height: image.size.height + 20.0)
        } else {
            bounds = CGRect(x: bounds.origin.x + 10.0, y: bounds.origin.y + 10.0, width: bounds.size.width - 20.0, height: bounds.size.height - 20.0)
        }
        
        let outputImage = blurFilter?.value(forKey: kCIOutputImageKey) as? CIImage
        let cgImage = context.createCGImage(outputImage ?? CIImage(), from: bounds)
        return UIImage(cgImage: cgImage!)
    }
    
    private func addGradientToView(view: UIView, startColor: UIColor, middleColor: UIColor, endColor: UIColor, locations: [NSNumber]) {
        let gradientLayerMask = CAGradientLayer()
        gradientLayerMask.colors = [startColor.cgColor, middleColor.cgColor, endColor.cgColor]
        gradientLayerMask.locations = locations
        gradientLayerMask.frame = view.bounds
        view.layer.insertSublayer(gradientLayerMask, at: 0)
        view.backgroundColor = .clear
    }
    
    private func updateGradientBackground() {
        
        self.callInfoGradientView.setNeedsLayout()
        self.callInfoGradientView.layoutIfNeeded()
        self.phoneButtonsGradientView.setNeedsLayout()
        self.phoneButtonsGradientView.layoutIfNeeded()
        
        self.callInfoGradientView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        self.phoneButtonsGradientView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        self.addGradientToView(view: self.callInfoGradientView, startColor: UIColor.black.withAlphaComponent(0.2), middleColor: UIColor.black.withAlphaComponent(0.1), endColor: UIColor.white.withAlphaComponent(0.0), locations: [0, 0.7, 1])
        self.addGradientToView(view: self.phoneButtonsGradientView, startColor: UIColor.white.withAlphaComponent(0.0), middleColor: UIColor.black.withAlphaComponent(0.1),endColor: UIColor.black.withAlphaComponent(0.2), locations: [0, 0.3, 1])
    }
    
    private func updateRemoteVideoContentMode(videoView: RTCVideoRenderer) {
        #if arch(arm64)
        if let rR = VoIPCallStateManager.shared.remoteVideoRenderer(),
           let remoteRenderer = rR as? RTCMTLVideoView,
           remoteRenderer.isEqual(videoView) {
            if UIApplication.shared.statusBarOrientation.isPortrait &&
               isRemoteVideoPortrait {
                remoteRenderer.videoContentMode = .scaleAspectFill
            } else {
                if UIApplication.shared.statusBarOrientation.isLandscape &&
                   !isRemoteVideoPortrait {
                    remoteRenderer.videoContentMode = .scaleAspectFill
                } else {
                    remoteRenderer.videoContentMode = .scaleAspectFit
                }
            }
        }
        #endif
    }
    
    private func updateAccessibilityLabels() {
        muteButton.accessibilityLabel = BundleUtil.localizedString(forKey: muteButton.isSelected ? "call_unmute" : "call_mute")
        speakerButton.accessibilityLabel = BundleUtil.localizedString(forKey: speakerButton.tag == 1 ? "call_earpiece" : "call_speaker")
        endButton.accessibilityLabel = BundleUtil.localizedString(forKey: "call_end")
        acceptButton.accessibilityLabel = BundleUtil.localizedString(forKey: "call_accept")
        rejectButton.accessibilityLabel = BundleUtil.localizedString(forKey: "call_reject")
        hideButton.accessibilityLabel = BundleUtil.localizedString(forKey: "call_hide_call")
        
        cameraButton.accessibilityLabel = BundleUtil.localizedString(forKey: self.isLocalVideoActive ? "call_camera_deactivate_button" : "call_camera_activate_button")
        cameraSwitchButton.accessibilityLabel = BundleUtil.localizedString(forKey: "call_camera_switch_to_back_button")
    }
    
    /**
     It will play the problem sound
     */
    private func playCellularCallWarningSound() {
        audioPlayer?.stop()
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.overrideOutputAudioPort(VoIPCallStateManager.shared.isSpeakerActive() ? .speaker : .none)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let soundFilePath = BundleUtil.path(forResource: "threema_problem", ofType: "mp3")
            let soundUrl = URL.init(fileURLWithPath: soundFilePath!)
            let player = try AVAudioPlayer(contentsOf: soundUrl, fileTypeHint: AVFileType.mp3.rawValue)
            player.numberOfLoops = 2
            audioPlayer = player
            player.play()
        } catch let error {
            print(error.localizedDescription)
        }
    }
}

extension CallViewController {
    // MARK: Actions
    
    @objc private func handleLongPress(gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .began {
            // Toggle debug label
            debugLabel.isHidden = !debugLabel.isHidden
            
            if debugLabel.isHidden == true {
                debugLabel.text = ""
            }
        }
        
        updateViewConstraints()
    }
    
    @IBAction func hideView(sender: UIButton) {
        if isTesting == true {
            setupForConnectedCallTest()
        } else {
            VoIPHelper.shared()?.isCallActiveInBackground = true
            VoIPHelper.shared()?.contactName = contact?.displayName
            
            UIDevice.current.isProximityMonitoringEnabled = false
            dismiss(animated: true) {
                if AppDelegate.shared()?.isAppLocked == true {
                    AppDelegate.shared()?.presentPasscodeView()
                }
            }
        }
    }
    
    @IBAction func acceptAction(_ sender: UIButton, forEvent event: UIEvent) {
        let action = VoIPCallUserAction.init(action: .accept, contact: contact!, callId: VoIPCallStateManager.shared.currentCallId(), completion: nil)
        VoIPCallStateManager.shared.processUserAction(action)
    }
    
    @IBAction func rejectAction(_ sender: UIButton, forEvent event: UIEvent) {
        if isTesting == true {
            dismiss(animated: true, completion: nil)
        } else {
            let action = VoIPCallUserAction.init(action: .reject, contact: contact!, callId: VoIPCallStateManager.shared.currentCallId(), completion: nil)
            VoIPCallStateManager.shared.processUserAction(action)
        }
    }
    
    @IBAction func endAction(_ sender: UIButton, forEvent event: UIEvent) {
        DDLogNotice("VoipCallService: [cid=\(VoIPCallStateManager.shared.currentCallId()?.callId ?? 0)]: User pressed the hangup button")

        let action = VoIPCallUserAction.init(action: .end, contact: contact!, callId: VoIPCallStateManager.shared.currentCallId(), completion: nil)
        VoIPCallStateManager.shared.processUserAction(action)
    }
    
    @IBAction func muteAction(_ sender: UIButton, forEvent event: UIEvent) {
        let action = VoIPCallUserAction.init(action: VoIPCallStateManager.shared.isCallMuted() ? .unmuteAudio : .muteAudio , contact: contact!, callId: VoIPCallStateManager.shared.currentCallId(), completion: nil)
        muteButton.isSelected = action.action == .muteAudio
        updateAccessibilityLabels()
        VoIPCallStateManager.shared.processUserAction(action)
    }
    
    @IBAction func speakerAction(_ sender: UIButton, forEvent event: UIEvent) {
        self.checkAndHandleAvailableBluetoothDevices()
        
        let audioSession = AVAudioSession.sharedInstance()
        for output in audioSession.currentRoute.outputs {
            switch output.portType {
            case .builtInReceiver:
                let action = VoIPCallUserAction.init(action: .speakerOn , contact: contact!, callId: VoIPCallStateManager.shared.currentCallId(), completion: nil)
                VoIPCallStateManager.shared.processUserAction(action)
                break
            case .builtInSpeaker:
                let action = VoIPCallUserAction.init(action: .speakerOff , contact: contact!, callId: VoIPCallStateManager.shared.currentCallId(), completion: nil)
                VoIPCallStateManager.shared.processUserAction(action)
                break
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                let action = VoIPCallUserAction.init(action: .speakerOn , contact: contact!, callId: VoIPCallStateManager.shared.currentCallId(), completion: nil)
                VoIPCallStateManager.shared.processUserAction(action)
                break
            case .headphones:
                let action = VoIPCallUserAction.init(action: .speakerOn , contact: contact!, callId: VoIPCallStateManager.shared.currentCallId(), completion: nil)
                VoIPCallStateManager.shared.processUserAction(action)
            break
            default:
                break
            }
        }
        updateAccessibilityLabels()
    }
    
    @IBAction func startVideoAction(_ sender: UIButton) {
        if isTesting == true {
            setupForVideoCallTest()
        } else {
            if threemaVideoCallAvailable {
                if hasCameraAccess() {
                    self.isLocalVideoActive = !self.isLocalVideoActive
                    if self.isLocalVideoActive == true {
                        startLocalVideo()
                    } else {
                        endLocalVideo()
                    }
                }
            } else {
                self.showCameraDisabledInfo()
            }
        }
    }
    
    @IBAction func switchCameraAction(_ sender: UIButton, forEvent event: UIEvent) {
        switchCamera()
    }
    
    @IBAction func showCellularWarningAction() {
        UIAlertTemplate.showAlert(owner: self, title: BundleUtil.localizedString(forKey: "call_threema_cellular_instead_of_wifi_title"), message: BundleUtil.localizedString(forKey: "call_threema_cellular_instead_of_wifi_text"))
    }
        
    @objc func switchVideoViews(gesture: UITapGestureRecognizer) {
        DispatchQueue.main.async {
            if self.isLocalRendererInLocalView() && self.isRemoteRendererInRemoteView() {
                self.removeAllSubviewsFromVideoViews()
                self.embedView(VoIPCallStateManager.shared.remoteVideoRenderer()! as! UIView, into: self.localVideoView)
                self.embedView(VoIPCallStateManager.shared.localVideoRenderer() as! UIView, into: self.remoteVideoView)
                self.flipLocalRenderer()
            }
            else if self.isLocalRendererInRemoteView() && self.isRemoteRendererInLocalView() {
                self.removeAllSubviewsFromVideoViews()
                self.embedView(VoIPCallStateManager.shared.localVideoRenderer()! as! UIView, into: self.localVideoView)
                self.embedView(VoIPCallStateManager.shared.remoteVideoRenderer() as! UIView, into: self.remoteVideoView)
                self.flipLocalRenderer()
            }
        }
    }
        
    @objc func showHideNavigation(gesture: UITapGestureRecognizer) {
        moveLocalVideoViewToCorrectPosition(moveNavigation: true)
    }
        
    @objc func didPan(gesture: UIPanGestureRecognizer) {
        guard let dragView = gesture.view else {
            return
        }
        
        if (gesture.state == .began) {
            dragView.center = gesture.location(in: self.view)
        }
        
        let newCenter: CGPoint = gesture.location(in: self.view)
        let dX = newCenter.x - dragView.center.x
        let dY = newCenter.y - dragView.center.y
        dragView.center = CGPoint(x: dragView.center.x + dX, y: dragView.center.y + dY)
        localVideoView.center = dragView.center

        if gesture.state == .ended {
            moveLocalVideoViewToCorrectPosition()
        }
    }
}

@available(iOS 11.0, *)
extension CallViewController: AVRoutePickerViewDelegate {
    func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
        self.checkAndHandleAvailableBluetoothDevices()
    }
}

extension CallViewController: RTCVideoViewDelegate {
    func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        isRemoteVideoPortrait = size.height > size.width
        updateRemoteVideoContentMode(videoView: videoView)

        if let localRenderer = VoIPCallStateManager.shared.localVideoRenderer(),
           localRenderer.isEqual(videoView) {
            updateConstraintsAfterRotation(size: size)
        }
    }
}

extension CallViewController: MaterialShowcaseDelegate {
    func showCaseDidDismiss(showcase: MaterialShowcase, didTapTarget: Bool) {
        if showcase == initiatorVideoCallShowcase {
            UserSettings.shared().videoCallInfoShown = true
        }
    }
}
